// functions/match-room.ts — one Durable Object instance per ranked duel.
// Both players connect over WebSocket; the room drives the rounds
// (server-authoritative timing), relays answers, computes points, and
// settles ELO via the Hub DO when the match ends.

import { DurableObject } from "cloudflare:workers";
import { flagAnswer, standInLevel, verifyAnswer, type GameQuestion } from "./game-security";
import { isLegacyExpired, legacyAnswer, LEGACY_DEADLINE_MS } from "./security-rollout";

type Env = { DO: Fetcher & { setAlarm(className: string, id: string, time: number): Promise<void> } };

type PlayerInfo = {
  id: string;
  name: string;
  emoji: string;
  elo: number;
  /** Server-simulated opponent (queue filler). Never sent to clients. */
  isBot?: boolean;
  /** Server-only ladder level the simulated opponent plays at. */
  skill?: number;
};

type RoundAnswer = {
  answer: string | null;
  correct: boolean;
  timeMs: number;
  points: number;
};

type MatchState = {
  seed: string;
  questions?: GameQuestion[];
  roundStartedAt?: number;
  questionCount: number;
  roundDuration: number;
  players: PlayerInfo[];
  phase: "waiting" | "draft" | "playing" | "reveal" | "finished";
  round: number;
  scores: Record<string, number>;
  answers: Record<string, RoundAnswer>[];
  settled: boolean;
  noResult?: boolean;
  /** Four themes offered to both players before the first question. */
  draftThemes?: string[];
  /** Theme each player picked during the draft. */
  picks?: Record<string, string>;
  draftEndsAt?: number;
  /** The two themes the questions are drawn from once the draft is over. */
  themes?: string[];
};

type Attachment = { userId: string };

const REVEAL_MS = 2_600;
const COUNTDOWN_MS = 3_200;
const GRACE_MS = 1_200;
/** The app hides the choices for this long at the start of every round. */
const CLIENT_READING_MS = 4_500;
/** Time both players get to pick one of the four offered themes. */
const DRAFT_MS = 10_000;
/** How long the app shows the two chosen themes before the countdown. */
const DRAFT_REVEAL_MS = 3_000;
/** A player who drops mid-game has this long to come back before forfeiting. */
const RECONNECT_GRACE_MS = 10_000;
const EMOTES = ["😂", "🔥", "👏", "😲", "😎", "🤔", "👍", "💯", "😭"];

export class MatchRoom extends DurableObject<Env> {
  private state: MatchState | null = null;
  private roundTimer: ReturnType<typeof setTimeout> | null = null;
  private legacyTimer: ReturnType<typeof setTimeout> | null = null;
  private botTimers: ReturnType<typeof setTimeout>[] = [];
  private draftTimer: ReturnType<typeof setTimeout> | null = null;
  private disconnectTimers = new Map<string, ReturnType<typeof setTimeout>>();

  override async fetch(request: Request): Promise<Response> {
    if (new URL(request.url).pathname === "/internal/initialize" && request.method === "POST") {
      return Response.json({ ok: await this.initialize(request) });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    const url = new URL(request.url);
    const userId = url.searchParams.get("userId");
    if (!userId) {
      return new Response("missing user", { status: 400 });
    }

    const state = await this.loadState();
    if (!state) return Response.json({ error: "Partie renouvelée. Relance une recherche.", code: "match_unavailable" }, { status: 400 });

    const current = await this.loadState();
    if (!current || !current.players.some((p) => p.id === userId && !p.isBot)) {
      return new Response("not a player of this match", { status: 403 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [`user:${userId}`]);
    server.serializeAttachment({ userId } satisfies Attachment);

    this.ctx.waitUntil(this.afterConnect(userId));
    return new Response(null, { status: 101, webSocket: client });
  }

  private async initialize(request: Request): Promise<boolean> {
    try {
      const ticket = await request.json() as { seed: string; questionCount: number; roundDuration: number; players: PlayerInfo[]; questions?: GameQuestion[]; draftThemes?: string[] };
      const [you, opponent] = ticket.players;
      if (!you || !opponent) return false;
      const state: MatchState = {
        seed: ticket.seed,
        questions: ticket.questions,
        questionCount: ticket.questionCount ?? 15,
        roundDuration: ticket.roundDuration ?? 15,
        players: [you, opponent],
        phase: "waiting",
        round: -1,
        scores: { [you.id]: 0, [opponent.id]: 0 },
        answers: [],
        settled: false,
        draftThemes: Array.isArray(ticket.draftThemes) && ticket.draftThemes.length >= 2 ? ticket.draftThemes.slice(0, 4) : undefined,
      };
      // First write wins — a duplicated ticket can't overwrite a started game.
      const existing = await this.ctx.storage.get<MatchState>("state");
      if (existing) return true;
      await this.ctx.storage.put("state", state);
      this.state = state;
      return true;
    } catch {
      return false;
    }
  }

  private async loadState(): Promise<MatchState | null> {
    if (this.state) return this.state;
    const stored = await this.ctx.storage.get<MatchState>("state");
    this.state = stored ?? null;
    if (this.state && isLegacyExpired(this.state)) {
      this.cancelWithoutResult("security_transition_expired");
    } else if (this.state && !this.state.questions && !this.state.draftThemes && this.state.phase !== "finished") {
      this.legacyTimer = setTimeout(() => this.cancelWithoutResult("security_transition_expired"), Math.max(0, LEGACY_DEADLINE_MS - Date.now()));
      this.ctx.waitUntil(this.env.DO.setAlarm("MatchRoom", this.ctx.id.name ?? "", LEGACY_DEADLINE_MS));
    }
    // Timers are volatile across redeployments. Resume only attached live sockets.
    if (this.state && this.ctx.getWebSockets().length > 0) {
      const s = this.state;
      if (s.phase === "playing") {
        if (s.round < 0) this.armTimer(COUNTDOWN_MS, () => this.startRound(0));
        else this.armTimer(Math.max(0, (s.roundStartedAt ?? Date.now()) + s.roundDuration * 1000 + GRACE_MS - Date.now()), () => this.closeRound(s.round));
      } else if (s.phase === "reveal") this.armTimer(REVEAL_MS, () => { s.phase = "playing"; this.startRound(s.round + 1); });
      else if (s.phase === "draft" && !this.draftTimer) this.armDraftTimer(Math.max(0, (s.draftEndsAt ?? Date.now()) - Date.now()));
    }
    return this.state;
  }

  private persist(): void {
    if (this.state) {
      this.ctx.storage.put("state", this.state, { allowUnconfirmed: true });
    }
  }

  private async afterConnect(userId: string): Promise<void> {
    const state = await this.loadState();
    if (!state) return;

    if (state.noResult) { this.sendTo(userId, { type: "cancelled", reason: "server_interruption", noResult: true }); return; }
    if (state.phase === "finished") {
      this.sendTo(userId, { type: "finish", scores: state.scores, alreadyOver: true });
      return;
    }

    const connectedIds = this.connectedUserIds();
    const publicPlayers = state.players.map(publicPlayer);
    this.broadcast({ type: "lobby", connected: state.players.filter((p) => p.isBot || connectedIds.includes(p.id)).map((p) => p.id), players: publicPlayers });

    // Back within the grace period: the match simply carries on.
    const pending = this.disconnectTimers.get(userId);
    if (pending) {
      clearTimeout(pending);
      this.disconnectTimers.delete(userId);
      this.broadcastExcept(userId, { type: "opponent_reconnected" });
      this.resync(userId);
      return;
    }

    const bothConnected = state.players.every((p) => p.isBot || connectedIds.includes(p.id));
    if (bothConnected && state.phase === "waiting") {
      if (state.draftThemes) this.startDraft();
      else this.startMatch();
    } else if (state.phase !== "waiting") {
      this.resync(userId);
    }
  }

  /** Brings a (re)connected player back to where the match is. */
  private resync(userId: string): void {
    const state = this.state;
    if (!state) return;
    if (state.phase === "draft" && state.draftThemes) {
      this.sendTo(userId, {
        type: "draft",
        themes: state.draftThemes,
        durationMs: Math.max(0, (state.draftEndsAt ?? Date.now()) - Date.now()),
        picked: state.picks?.[userId] ?? null,
      });
      if (state.themes) this.sendTo(userId, { type: "draft_result", picks: state.picks ?? {}, themes: state.themes });
    } else if (state.phase === "playing" || state.phase === "reveal") {
      this.sendTo(userId, {
        type: "start",
        seed: state.seed,
        questions: state.questions,
        questionCount: state.questionCount,
        roundDuration: state.roundDuration,
        players: state.players.map(publicPlayer),
        themes: state.themes,
        resumed: true,
        scores: state.scores,
      });
      if (state.phase === "playing" && state.round >= 0 && state.roundStartedAt) {
        const remaining = state.roundStartedAt + state.roundDuration * 1000 - Date.now();
        if (remaining > 1_500) this.sendTo(userId, { type: "round", index: state.round, durationMs: remaining });
      }
    }
  }

  private startMatch(): void {
    const state = this.state;
    if (!state || state.phase === "finished") return;
    state.phase = "playing";
    state.round = -1;
    this.persist();
    this.broadcast({
      type: "start",
      seed: state.seed,
      questions: state.questions,
      questionCount: state.questionCount,
      roundDuration: state.roundDuration,
      players: state.players.map(publicPlayer),
      themes: state.themes,
    });
    this.armTimer(COUNTDOWN_MS, () => this.startRound(0));
  }

  // MARK: theme draft

  /** Both players see the same four themes and each picks one. */
  private startDraft(): void {
    const state = this.state;
    if (!state?.draftThemes) return;
    state.phase = "draft";
    state.picks = {};
    state.draftEndsAt = Date.now() + DRAFT_MS;
    this.persist();
    this.broadcast({ type: "draft", themes: state.draftThemes, durationMs: DRAFT_MS, picked: null });
    for (const bot of state.players.filter((p) => p.isBot)) {
      const delay = 1_800 + Math.random() * 4_500;
      this.botTimers.push(setTimeout(() => this.recordPick(bot.id, randomItem(state.draftThemes ?? [])), delay));
    }
    this.armDraftTimer(DRAFT_MS + 400);
  }

  private armDraftTimer(delayMs: number): void {
    if (this.draftTimer) clearTimeout(this.draftTimer);
    this.draftTimer = setTimeout(() => {
      this.draftTimer = null;
      this.ctx.waitUntil(this.resolveDraft());
    }, delayMs);
  }

  private recordPick(userId: string, theme: string | undefined): void {
    const state = this.state;
    if (!state || state.phase !== "draft" || state.themes || !theme) return;
    if (!state.draftThemes?.includes(theme) || state.picks?.[userId]) return;
    state.picks = { ...(state.picks ?? {}), [userId]: theme };
    this.persist();
    this.broadcastExcept(userId, { type: "opponent_picked" });
    if (state.players.every((p) => state.picks?.[p.id])) {
      if (this.draftTimer) clearTimeout(this.draftTimer);
      this.draftTimer = null;
      this.ctx.waitUntil(this.resolveDraft());
    }
  }

  /**
   * Each player's pick becomes one of the two themes. Same pick on both
   * sides: that theme plus a random one among the three others offered.
   * A player who didn't pick in time gets a random offered theme.
   */
  private async resolveDraft(): Promise<void> {
    const state = this.state;
    if (!state || state.phase !== "draft" || state.themes || !state.draftThemes) return;
    const offered = state.draftThemes;
    const picks: Record<string, string> = { ...(state.picks ?? {}) };
    for (const p of state.players) picks[p.id] ??= randomItem(offered)!;
    const [a, b] = state.players.map((p) => picks[p.id]!);
    const themes = a === b ? [a!, randomItem(offered.filter((t) => t !== a))!] : [a!, b!];
    state.picks = picks;
    state.themes = themes;
    this.persist();
    this.broadcast({ type: "draft_result", picks, themes });

    const startedAt = Date.now();
    try {
      const elo = Math.trunc(state.players.reduce((sum, p) => sum + p.elo, 0) / state.players.length);
      const response = await this.env.DO.fetch(new Request("https://internal/internal/game-questions", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Rork-DO-Class": "Hub", "X-Rork-DO-Id": "global" },
        body: JSON.stringify({ matchId: this.ctx.id.name ?? "", seed: state.seed, count: state.questionCount, themes, elo }),
      }));
      if (!response.ok) throw new Error(`questions ${response.status}`);
      const body = await response.json() as { questions?: GameQuestion[] };
      if (!body.questions || body.questions.length < state.questionCount) throw new Error("questions missing");
      state.questions = body.questions;
      this.persist();
    } catch (err) {
      console.error("draft questions unavailable", err instanceof Error ? err.message : "unknown");
      this.cancelWithoutResult("server_interruption");
      return;
    }
    const wait = Math.max(0, DRAFT_REVEAL_MS - (Date.now() - startedAt));
    this.armTimer(wait, () => this.startMatch());
  }

  private startRound(index: number): void {
    const state = this.state;
    if (!state || state.phase === "finished") return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    if (index >= state.questionCount) {
      this.ctx.waitUntil(this.finishMatch(null));
      return;
    }
    state.phase = "playing";
    state.round = index;
    state.roundStartedAt = Date.now();
    while (state.answers.length <= index) state.answers.push({});
    this.persist();
    const endsInMs = state.roundDuration * 1000;
    this.broadcast({ type: "round", index, durationMs: endsInMs });
    this.scheduleBotAnswers(index, endsInMs);
    this.armTimer(endsInMs + GRACE_MS, () => this.closeRound(index));
  }

  /**
   * The simulated opponent answers after the app's reading beat, faster and
   * more accurately the higher its rating, with a light rubber band so a
   * match rarely turns into a blowout either way.
   */
  private scheduleBotAnswers(index: number, durationMs: number): void {
    const state = this.state;
    if (!state) return;
    this.clearBotTimers();
    for (const bot of state.players.filter((p) => p.isBot)) {
      if (Math.random() < 0.04) continue; // occasionally runs out of time
      const human = state.players.find((p) => !p.isBot);
      const lead = (state.scores[bot.id] ?? 0) - (human ? state.scores[human.id] ?? 0 : 0);
      const rubberBand = lead > 400 ? -0.1 : lead < -400 ? 0.05 : 0;
      const level = bot.skill !== undefined
        ? standInLevel(bot.skill)
        : { accuracy: 0.42 + (bot.elo - 1000) / 1500, speed: 0.6 - (bot.elo - 1000) / 2500 };
      const successProb = clamp(level.accuracy + rubberBand, 0.2, 0.97);
      const speed = clamp(level.speed + (Math.random() - 0.5) * 0.4, 0.04, 0.95);
      const window = Math.max(1_000, durationMs - CLIENT_READING_MS - 400);
      const answerAt = CLIENT_READING_MS + 500 + speed * window;
      const question = state.questions?.[index];
      this.botTimers.push(setTimeout(() => {
        const correct = Math.random() < successProb;
        this.recordAnswer(bot.id, index, botAnswer(question, correct), correct, Math.min(answerAt, durationMs));
      }, answerAt));
    }
  }

  private clearBotTimers(): void {
    for (const t of this.botTimers) clearTimeout(t);
    this.botTimers = [];
  }

  private recordAnswer(userId: string, index: number, answer: string | null, correct: boolean, timeMs: number): void {
    const state = this.state;
    if (!state || state.phase !== "playing" || index !== state.round) return;
    const roundAnswers = state.answers[index];
    if (!roundAnswers || roundAnswers[userId]) return;
    const fraction = 1 - timeMs / (state.roundDuration * 1000);
    const points = correct ? 100 + Math.round(fraction * 100) : 0;
    roundAnswers[userId] = { answer, correct, timeMs, points };
    this.persist();

    // Tell the opponent (without leaking the answer).
    for (const peer of this.ctx.getWebSockets()) {
      const meta = peer.deserializeAttachment() as Attachment | null;
      if (meta && meta.userId !== userId) {
        trySend(peer, { type: "opponent_answered", index });
      }
    }

    if (state.players.every((p) => roundAnswers[p.id] !== undefined)) {
      this.closeRound(index);
    }
  }

  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    const receivedAt = Date.now();
    if (typeof raw !== "string") return;
    const attachment = ws.deserializeAttachment() as Attachment | null;
    if (!attachment) return;

    let msg: { type?: string; index?: number; answer?: string; correct?: boolean; timeMs?: number; emote?: string; theme?: string };
    try {
      msg = JSON.parse(raw);
      if (!msg || typeof msg !== "object") return;
    } catch {
      return;
    }

    if (msg.type === "emote" && typeof msg.emote === "string") {
      for (const peer of this.ctx.getWebSockets()) {
        const meta = peer.deserializeAttachment() as Attachment | null;
        if (meta && meta.userId !== attachment.userId) {
          trySend(peer, { type: "emote", emote: msg.emote.slice(0, 8) });
        }
      }
      this.maybeBotEmoteBack(attachment.userId);
      return;
    }

    const state = await this.loadState();
    if (!state || state.phase === "finished") return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    if (msg.type === "pick" && typeof msg.theme === "string") {
      this.recordPick(attachment.userId, msg.theme);
      return;
    }
    if (msg.type === "leave") {
      if (state.phase === "waiting" || state.phase === "draft") this.cancelWithoutResult("player_left_before_start");
      else await this.finishMatch(attachment.userId);
      return;
    }

    if (msg.type === "answer" && typeof msg.index === "number") {
      if (state.phase !== "playing" || msg.index !== state.round) return;
      const roundAnswers = state.answers[msg.index];
      if (!roundAnswers || roundAnswers[attachment.userId]) return;

      const verdict = state.questions
        ? verifyAnswer(state.questions[msg.index], msg.answer, state.roundStartedAt, receivedAt, state.roundDuration * 1000)
        : legacyAnswer(msg.correct, msg.timeMs, state.roundDuration * 1000);
      const { timeMs, correct } = verdict;
      const reason = verdict.reason ?? (msg.correct === true && !correct ? "false_correct_claim" : undefined);
      if (reason) this.ctx.waitUntil(flagAnswer(this.env, attachment.userId, this.ctx.id.name ?? this.ctx.id.toString(), msg.index, reason));
      this.recordAnswer(attachment.userId, msg.index, typeof msg.answer === "string" ? msg.answer.slice(0, 200) : null, correct, timeMs);
    }
  }

  /** A simulated opponent sometimes reacts to the player's emote. */
  private maybeBotEmoteBack(fromUserId: string): void {
    const state = this.state;
    if (!state?.players.some((p) => p.isBot) || Math.random() > 0.35) return;
    setTimeout(() => {
      this.sendTo(fromUserId, { type: "emote", emote: EMOTES[Math.floor(Math.random() * EMOTES.length)] });
    }, 600 + Math.random() * 1_200);
  }

  private closeRound(index: number): void {
    const state = this.state;
    if (!state || state.phase !== "playing" || state.round !== index) return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    this.clearTimer();
    this.clearBotTimers();

    const roundAnswers = state.answers[index] ?? {};
    for (const player of state.players) {
      if (!roundAnswers[player.id]) {
        roundAnswers[player.id] = {
          answer: null,
          correct: false,
          timeMs: state.roundDuration * 1000,
          points: 0,
        };
      }
      state.scores[player.id] = (state.scores[player.id] ?? 0) + (roundAnswers[player.id]?.points ?? 0);
    }
    state.answers[index] = roundAnswers;
    state.phase = "reveal";
    this.persist();

    // 1v1: no ranking page between questions (only the 1 vs 9 shows one).
    const pauseMs = REVEAL_MS;
    this.broadcast({ type: "reveal", index, answers: roundAnswers, scores: state.scores, pauseMs });

    this.armTimer(pauseMs, () => {
      const s = this.state;
      if (!s || s.phase === "finished") return;
      s.phase = "playing";
      this.startRound(index + 1);
    });
  }

  private async finishMatch(forfeitBy: string | null): Promise<void> {
    const state = this.state;
    if (!state || state.phase === "finished" || state.settled) return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    state.phase = "finished";
    state.settled = true;
    if (this.legacyTimer) clearTimeout(this.legacyTimer);
    this.clearTimer();
    this.clearBotTimers();
    this.clearDraftAndDisconnectTimers();
    this.persist();

    const results = state.players.map((p) => ({
      userId: p.id,
      score: state.scores[p.id] ?? 0,
    }));

    let eloChanges: Record<string, number> = {};
    let newElos: Record<string, number> = {};
    try {
      const request = new Request("https://internal/internal/match-result", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Rork-DO-Class": "Hub",
          "X-Rork-DO-Id": "global",
        },
        body: JSON.stringify({
          matchId: this.ctx.id.name ?? "",
          results,
          forfeitBy: forfeitBy ?? undefined,
          // Leaving and not coming back within the grace period both count as a forfeit.
          voluntaryLeave: forfeitBy !== null,
        }),
      });
      const response = await this.env.DO.fetch(request);
      if (response.ok) {
        const settled = (await response.json()) as {
          eloChanges?: Record<string, number>;
          newElos?: Record<string, number>;
          noResult?: boolean;
        };
        if (settled.noResult) { this.cancelWithoutResult("server_interruption", true); return; }
        eloChanges = settled.eloChanges ?? {};
        newElos = settled.newElos ?? {};
      } else {
        console.error("elo settlement failed", response.status);
        this.cancelWithoutResult("settlement_unavailable", true);
        return;
      }
    } catch (err) {
      console.error("elo settlement unavailable");
      this.cancelWithoutResult("settlement_unavailable", true);
      return;
    }

    this.broadcast({
      type: "finish",
      scores: state.scores,
      eloChanges,
      newElos,
      forfeitBy: forfeitBy ?? undefined,
    });

    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.close(1000, "match over");
      } catch {
        // already gone
      }
    }
  }

  override async webSocketClose(ws: WebSocket): Promise<void> {
    await this.handleDrop(ws);
  }

  override async webSocketError(ws: WebSocket, _error: unknown): Promise<void> {
    await this.handleDrop(ws);
  }

  /**
   * A dropped socket before the start cancels the match. Once it has
   * started, the player gets a grace period to reconnect; past it, the one
   * still there wins by forfeit.
   */
  private async handleDrop(ws: WebSocket): Promise<void> {
    const state = await this.loadState();
    if (!state || state.phase === "finished") return;
    const meta = ws.deserializeAttachment() as Attachment | null;
    if (state.phase === "waiting" || !meta) {
      this.cancelWithoutResult("server_interruption");
      return;
    }
    const userId = meta.userId;
    if (this.openSocketCount(userId, ws) > 0 || this.disconnectTimers.has(userId)) return;
    const othersOnline = state.players.some((p) => !p.isBot && p.id !== userId && this.openSocketCount(p.id, ws) > 0);
    if (!othersOnline) {
      this.cancelWithoutResult("server_interruption");
      return;
    }
    this.broadcastExcept(userId, { type: "opponent_disconnected", graceMs: RECONNECT_GRACE_MS });
    this.disconnectTimers.set(userId, setTimeout(() => {
      this.disconnectTimers.delete(userId);
      if (this.openSocketCount(userId) > 0) return;
      if (this.state?.phase === "draft" || !this.state?.questions) {
        this.cancelWithoutResult("player_left_before_start");
        return;
      }
      this.ctx.waitUntil(this.finishMatch(userId));
    }, RECONNECT_GRACE_MS));
  }

  private openSocketCount(userId: string, excluding?: WebSocket): number {
    return this.ctx.getWebSockets(`user:${userId}`).filter((s) => s !== excluding && s.readyState === 1).length;
  }

  private clearDraftAndDisconnectTimers(): void {
    if (this.draftTimer) clearTimeout(this.draftTimer);
    this.draftTimer = null;
    for (const t of this.disconnectTimers.values()) clearTimeout(t);
    this.disconnectTimers.clear();
  }

  async onAlarm(): Promise<void> {
    await this.loadState();
    if (this.state && isLegacyExpired(this.state)) this.cancelWithoutResult("security_transition_expired");
  }

  private cancelWithoutResult(reason: string, allowFinished = false): void {
    const state = this.state;
    if (!state || (state.phase === "finished" && !allowFinished)) return;
    state.phase = "finished";
    state.noResult = true;
    state.settled = true;
    this.clearTimer();
    this.clearBotTimers();
    this.clearDraftAndDisconnectTimers();
    if (this.legacyTimer) clearTimeout(this.legacyTimer);
    this.persist();
    // No Hub settlement: no rating, reputation, win/loss or forfeit write for anyone.
    this.broadcast({ type: "cancelled", reason, noResult: true });
    for (const peer of this.ctx.getWebSockets()) { try { peer.close(1000, "no result"); } catch { /* closed */ } }
  }

  private connectedUserIds(): string[] {
    const ids = new Set<string>();
    for (const ws of this.ctx.getWebSockets()) {
      const meta = ws.deserializeAttachment() as Attachment | null;
      if (meta) ids.add(meta.userId);
    }
    return Array.from(ids);
  }

  private broadcast(msg: unknown): void {
    const data = JSON.stringify(msg);
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(data);
      } catch {
        // socket mid-close
      }
    }
  }

  private broadcastExcept(userId: string, msg: unknown): void {
    const data = JSON.stringify(msg);
    for (const ws of this.ctx.getWebSockets()) {
      const meta = ws.deserializeAttachment() as Attachment | null;
      if (meta?.userId === userId) continue;
      try { ws.send(data); } catch { /* socket mid-close */ }
    }
  }

  private sendTo(userId: string, msg: unknown): void {
    const data = JSON.stringify(msg);
    for (const ws of this.ctx.getWebSockets(`user:${userId}`)) {
      try {
        ws.send(data);
      } catch {
        // socket mid-close
      }
    }
  }

  private armTimer(delayMs: number, fn: () => void): void {
    this.clearTimer();
    this.roundTimer = setTimeout(() => {
      this.roundTimer = null;
      fn();
    }, delayMs);
  }

  private clearTimer(): void {
    if (this.roundTimer) {
      clearTimeout(this.roundTimer);
      this.roundTimer = null;
    }
  }
}

function publicPlayer(p: PlayerInfo): Omit<PlayerInfo, "isBot"> {
  return { id: p.id, name: p.name, emoji: p.emoji, elo: p.elo };
}

function randomItem<T>(items: T[]): T | undefined {
  return items.length ? items[Math.floor(Math.random() * items.length)] : undefined;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/** The text the simulated opponent "picked": the answer, or a plausible wrong option. */
function botAnswer(question: GameQuestion | undefined, correct: boolean): string | null {
  if (!question) return null;
  if (correct) return question.answer;
  const key = (s: string) => s.trim().toLowerCase();
  if (question.type === "trueFalse") return key(question.answer) === "vrai" ? "Faux" : "Vrai";
  const options = Array.isArray(question.options) ? (question.options as unknown[]).filter((o): o is string => typeof o === "string") : [];
  const wrong = options.filter((o) => key(o) !== key(question.answer));
  return wrong.length ? wrong[Math.floor(Math.random() * wrong.length)]! : null;
}

function trySend(ws: WebSocket, msg: unknown): void {
  try {
    ws.send(JSON.stringify(msg));
  } catch {
    // socket mid-close
  }
}

