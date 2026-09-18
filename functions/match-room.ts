// functions/match-room.ts — one Durable Object instance per ranked duel.
// Both players connect over WebSocket; the room drives the rounds
// (server-authoritative timing), relays answers, computes points, and
// settles ELO via the Hub DO when the match ends.

import { DurableObject } from "cloudflare:workers";
import { flagAnswer, verifyAnswer, type GameQuestion } from "./game-security";
import { isLegacyExpired, legacyAnswer, LEGACY_DEADLINE_MS } from "./security-rollout";

type Env = { DO: Fetcher & { setAlarm(className: string, id: string, time: number): Promise<void> } };

type PlayerInfo = {
  id: string;
  name: string;
  emoji: string;
  elo: number;
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
  phase: "waiting" | "playing" | "reveal" | "finished";
  round: number;
  scores: Record<string, number>;
  answers: Record<string, RoundAnswer>[];
  settled: boolean;
  noResult?: boolean;
};

type Attachment = { userId: string };

const REVEAL_MS = 2_600;
const COUNTDOWN_MS = 3_200;
const GRACE_MS = 1_200;

export class MatchRoom extends DurableObject<Env> {
  private state: MatchState | null = null;
  private roundTimer: ReturnType<typeof setTimeout> | null = null;
  private legacyTimer: ReturnType<typeof setTimeout> | null = null;

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
    if (!current || !current.players.some((p) => p.id === userId)) {
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
      const ticket = await request.json() as { seed: string; questionCount: number; roundDuration: number; players: PlayerInfo[]; questions: GameQuestion[] };
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
    } else if (this.state && !this.state.questions && this.state.phase !== "finished") {
      this.legacyTimer = setTimeout(() => this.cancelWithoutResult("security_transition_expired"), Math.max(0, LEGACY_DEADLINE_MS - Date.now()));
      this.ctx.waitUntil(this.env.DO.setAlarm("MatchRoom", this.ctx.id.name ?? "", LEGACY_DEADLINE_MS));
    }
    // Timers are volatile across redeployments. Resume only attached live sockets.
    if (this.state && this.ctx.getWebSockets().length > 0) {
      const s = this.state;
      if (s.phase === "playing") {
        if (s.round < 0) this.armTimer(COUNTDOWN_MS, () => this.startRound(0));
        else this.armTimer(Math.max(0, (s.roundStartedAt ?? Date.now()) + s.roundDuration * 1000 + GRACE_MS - Date.now()), () => this.closeRound(s.round));
      } else if (s.phase === "reveal") this.armTimer(REVEAL_MS, () => this.startRound(s.round + 1));
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
    this.broadcast({ type: "lobby", connected: connectedIds, players: state.players });

    const bothConnected = state.players.every((p) => connectedIds.includes(p.id));
    if (bothConnected && state.phase === "waiting") {
      state.phase = "playing";
      state.round = -1;
      this.persist();
      this.broadcast({
        type: "start",
        seed: state.seed,
        questions: state.questions,
        questionCount: state.questionCount,
        roundDuration: state.roundDuration,
        players: state.players,
      });
      this.armTimer(COUNTDOWN_MS, () => this.startRound(0));
    }
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
    this.armTimer(endsInMs + GRACE_MS, () => this.closeRound(index));
  }

  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    const receivedAt = Date.now();
    if (typeof raw !== "string") return;
    const attachment = ws.deserializeAttachment() as Attachment | null;
    if (!attachment) return;

    let msg: { type?: string; index?: number; answer?: string; correct?: boolean; timeMs?: number; emote?: string };
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
      return;
    }

    const state = await this.loadState();
    if (!state || state.phase === "finished") return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    if (msg.type === "leave") {
      if (state.phase === "waiting") this.cancelWithoutResult("player_left_before_start");
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
      const fraction = 1 - timeMs / (state.roundDuration * 1000);
      const points = correct ? 100 + Math.round(fraction * 100) : 0;
      roundAnswers[attachment.userId] = {
        answer: typeof msg.answer === "string" ? msg.answer.slice(0, 200) : null,
        correct,
        timeMs,
        points,
      };
      this.persist();

      // Tell the opponent (without leaking the answer).
      for (const peer of this.ctx.getWebSockets()) {
        const meta = peer.deserializeAttachment() as Attachment | null;
        if (meta && meta.userId !== attachment.userId) {
          trySend(peer, { type: "opponent_answered", index: msg.index });
        }
      }

      const everyone = state.players.every((p) => roundAnswers[p.id] !== undefined);
      if (everyone) {
        this.closeRound(msg.index);
      }
    }
  }

  private closeRound(index: number): void {
    const state = this.state;
    if (!state || state.phase !== "playing" || state.round !== index) return;
    if (isLegacyExpired(state)) { this.cancelWithoutResult("security_transition_expired"); return; }
    this.clearTimer();

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

    this.broadcast({ type: "reveal", index, answers: roundAnswers, scores: state.scores });

    this.armTimer(REVEAL_MS, () => {
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

  override async webSocketClose(_ws: WebSocket): Promise<void> {
    await this.loadState();
    this.cancelWithoutResult("server_interruption");
  }

  override async webSocketError(_ws: WebSocket, _error: unknown): Promise<void> {
    await this.loadState();
    this.cancelWithoutResult("server_interruption");
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

function trySend(ws: WebSocket, msg: unknown): void {
  try {
    ws.send(JSON.stringify(msg));
  } catch {
    // socket mid-close
  }
}

