// functions/party-room.ts — one Durable Object instance per party game
// (10 vs 10 teams, or 1 vs 19 individual ranking). Up to 20 participants,
// a mix of real players (over WebSocket) and server-simulated bots that
// filled empty lobby slots. The room is the sole authority on timing and
// scoring; it settles ladder points and reputation with the Hub DO when the
// game ends.

import { DurableObject } from "cloudflare:workers";

type Env = { DO: Fetcher };

type PartyMode = "team10" | "solo";

type PlayerInfo = {
  id: string;
  name: string;
  emoji: string;
  elo: number;
  isBot: boolean;
  team?: "A" | "B";
};

type RoundAnswer = {
  correct: boolean;
  timeMs: number;
  points: number;
};

type PartyState = {
  partyId: string;
  mode: PartyMode;
  seed: string;
  rounds: number;
  questionsPerRound: number;
  roundDuration: number;
  players: PlayerInfo[];
  phase: "waiting" | "playing" | "reveal" | "finished";
  globalIndex: number;
  scores: Record<string, number>;
  answers: Record<string, RoundAnswer>[];
  /** Real players who disconnected after the game had already started. */
  leftMidGame: string[];
  settled: boolean;
};

type Attachment = { userId: string };

const REVEAL_MS = 2_600;
const COUNTDOWN_MS = 3_200;
const GRACE_MS = 1_200;
/** A real player who never opens the socket after being matched is forfeited
 * rather than holding up 19 other people indefinitely. */
const WAIT_TIMEOUT_MS = 15_000;

export class PartyRoom extends DurableObject<Env> {
  private state: PartyState | null = null;
  private roundTimer: ReturnType<typeof setTimeout> | null = null;
  private waitTimer: ReturnType<typeof setTimeout> | null = null;
  private botTimers: ReturnType<typeof setTimeout>[] = [];

  override async fetch(request: Request): Promise<Response> {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    const url = new URL(request.url);
    const userId = url.searchParams.get("userId");
    if (!userId) {
      return new Response("missing user", { status: 400 });
    }

    const state = await this.loadState();
    if (!state) {
      const initialized = await this.initFromParams(url);
      if (!initialized) {
        return new Response("party not initialized", { status: 400 });
      }
    }

    const current = await this.loadState();
    const me = current?.players.find((p) => p.id === userId);
    if (!current || !me || me.isBot) {
      return new Response("not a player of this party", { status: 403 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [`user:${userId}`]);
    server.serializeAttachment({ userId } satisfies Attachment);

    this.ctx.waitUntil(this.afterConnect(userId));
    return new Response(null, { status: 101, webSocket: client });
  }

  private async initFromParams(url: URL): Promise<boolean> {
    const raw = url.searchParams.get("init");
    if (!raw) return false;
    try {
      const ticket = JSON.parse(raw) as {
        partyId?: string;
        mode?: PartyMode;
        seed?: string;
        rounds?: number;
        questionsPerRound?: number;
        roundDuration?: number;
        players?: PlayerInfo[];
      };
      if (!ticket.partyId || !ticket.seed || !ticket.players?.length) return false;
      const state: PartyState = {
        partyId: ticket.partyId,
        mode: ticket.mode === "team10" ? "team10" : "solo",
        seed: ticket.seed,
        rounds: ticket.rounds ?? 3,
        questionsPerRound: ticket.questionsPerRound ?? 20,
        roundDuration: ticket.roundDuration ?? 10,
        players: ticket.players,
        phase: "waiting",
        globalIndex: -1,
        scores: Object.fromEntries(ticket.players.map((p) => [p.id, 0])),
        answers: [],
        leftMidGame: [],
        settled: false,
      };
      const existing = await this.ctx.storage.get<PartyState>("state");
      if (existing) return true;
      await this.ctx.storage.put("state", state);
      this.state = state;
      return true;
    } catch {
      return false;
    }
  }

  private async loadState(): Promise<PartyState | null> {
    if (this.state) return this.state;
    const stored = await this.ctx.storage.get<PartyState>("state");
    this.state = stored ?? null;
    return this.state;
  }

  private persist(): void {
    if (this.state) {
      this.ctx.storage.put("state", this.state, { allowUnconfirmed: true });
    }
  }

  private totalQuestions(state: PartyState): number {
    return state.rounds * state.questionsPerRound;
  }

  private realPlayers(state: PartyState): PlayerInfo[] {
    return state.players.filter((p) => !p.isBot);
  }

  private async afterConnect(userId: string): Promise<void> {
    const state = await this.loadState();
    if (!state) return;

    if (state.phase === "finished") {
      this.sendTo(userId, { type: "finish", scores: state.scores, alreadyOver: true });
      return;
    }

    const connectedIds = this.connectedUserIds();
    this.broadcast({ type: "lobby", connected: connectedIds, players: state.players });

    if (state.phase !== "waiting") return;

    if (!this.waitTimer) {
      this.waitTimer = setTimeout(() => this.forceStart(), WAIT_TIMEOUT_MS);
    }

    const allConnected = this.realPlayers(state).every((p) => connectedIds.includes(p.id));
    if (allConnected) this.startGame();
  }

  /** Starts with whoever is connected once the grace period elapses. */
  private forceStart(): void {
    this.waitTimer = null;
    const state = this.state;
    if (!state || state.phase !== "waiting") return;
    const connected = new Set(this.connectedUserIds());
    for (const p of this.realPlayers(state)) {
      if (!connected.has(p.id) && !state.leftMidGame.includes(p.id)) {
        state.leftMidGame.push(p.id);
      }
    }
    this.startGame();
  }

  private startGame(): void {
    const state = this.state;
    if (!state || state.phase !== "waiting") return;
    if (this.waitTimer) {
      clearTimeout(this.waitTimer);
      this.waitTimer = null;
    }
    state.phase = "playing";
    this.persist();
    this.broadcast({
      type: "start",
      seed: state.seed,
      mode: state.mode,
      rounds: state.rounds,
      questionsPerRound: state.questionsPerRound,
      roundDuration: state.roundDuration,
      players: state.players,
    });
    this.armTimer(COUNTDOWN_MS, () => this.startRound(0));
  }

  private startRound(globalIndex: number): void {
    const state = this.state;
    if (!state || state.phase === "finished") return;
    if (globalIndex >= this.totalQuestions(state)) {
      this.ctx.waitUntil(this.finishMatch());
      return;
    }
    state.phase = "playing";
    state.globalIndex = globalIndex;
    while (state.answers.length <= globalIndex) state.answers.push({});
    this.persist();

    const durationMs = state.roundDuration * 1000;
    this.broadcast({
      type: "round",
      globalIndex,
      round: Math.floor(globalIndex / state.questionsPerRound),
      question: globalIndex % state.questionsPerRound,
      durationMs,
    });
    this.scheduleBotAnswers(globalIndex, durationMs);
    this.armTimer(durationMs + GRACE_MS, () => this.closeRound(globalIndex));
  }

  /** Bots "answer" on their own schedule — simulated, never omniscient. */
  private scheduleBotAnswers(globalIndex: number, durationMs: number): void {
    const state = this.state;
    if (!state) return;
    for (const bot of state.players.filter((p) => p.isBot)) {
      // Higher-rated bots answer faster and more accurately, but never
      // instantly and never with certainty.
      const successProb = clamp(0.35 + (bot.elo - 1000) / 1600, 0.25, 0.9);
      const speedFraction = clamp(0.75 - (bot.elo - 1000) / 3000, 0.22, 0.85);
      const jitter = (Math.random() - 0.5) * 0.3;
      const answerAt = clamp((speedFraction + jitter) * durationMs, 400, durationMs - 150);
      const timer = setTimeout(() => {
        this.recordAnswer(bot.id, globalIndex, Math.random() < successProb, answerAt);
      }, answerAt);
      this.botTimers.push(timer);
    }
  }

  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string") return;
    const attachment = ws.deserializeAttachment() as Attachment | null;
    if (!attachment) return;

    let msg: { type?: string; index?: number; correct?: boolean; timeMs?: number };
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (msg.type === "answer" && typeof msg.index === "number") {
      const state = this.state;
      if (!state || state.phase !== "playing" || msg.index !== state.globalIndex) return;
      this.recordAnswer(
        attachment.userId,
        msg.index,
        msg.correct === true,
        clamp(msg.timeMs ?? state.roundDuration * 1000, 0, state.roundDuration * 1000),
      );
    }
  }

  private recordAnswer(userId: string, globalIndex: number, correct: boolean, timeMs: number): void {
    const state = this.state;
    if (!state || state.phase !== "playing" || state.globalIndex !== globalIndex) return;
    const roundAnswers = state.answers[globalIndex];
    if (!roundAnswers || roundAnswers[userId]) return;

    const durationMs = state.roundDuration * 1000;
    const fraction = 1 - clamp(timeMs, 0, durationMs) / durationMs;
    const points = correct ? 100 + Math.round(fraction * 100) : 0;
    roundAnswers[userId] = { correct, timeMs, points };
    this.persist();

    const activePlayers = state.players.filter((p) => !state.leftMidGame.includes(p.id));
    const everyone = activePlayers.every((p) => roundAnswers[p.id] !== undefined);
    if (everyone) this.closeRound(globalIndex);
  }

  private closeRound(globalIndex: number): void {
    const state = this.state;
    if (!state || state.phase !== "playing" || state.globalIndex !== globalIndex) return;
    this.clearRoundTimer();
    this.clearBotTimers();

    const roundAnswers = state.answers[globalIndex] ?? {};
    let correctCount = 0;
    for (const player of state.players) {
      if (state.leftMidGame.includes(player.id)) continue;
      if (!roundAnswers[player.id]) {
        roundAnswers[player.id] = { correct: false, timeMs: state.roundDuration * 1000, points: 0 };
      }
      if (roundAnswers[player.id]?.correct) correctCount += 1;
      state.scores[player.id] = (state.scores[player.id] ?? 0) + (roundAnswers[player.id]?.points ?? 0);
    }
    state.answers[globalIndex] = roundAnswers;
    state.phase = "reveal";
    this.persist();

    let teamScores: { A: number; B: number } | undefined;
    if (state.mode === "team10") {
      teamScores = { A: 0, B: 0 };
      for (const p of state.players) {
        if (p.team === "A") teamScores.A += state.scores[p.id] ?? 0;
        else if (p.team === "B") teamScores.B += state.scores[p.id] ?? 0;
      }
    }

    this.broadcast({
      type: "reveal",
      globalIndex,
      correctCount,
      totalAnswered: Object.keys(roundAnswers).length,
      scores: state.scores,
      teamScores,
    });

    this.armTimer(REVEAL_MS, () => {
      const s = this.state;
      if (!s || s.phase === "finished") return;
      s.phase = "playing";
      this.startRound(globalIndex + 1);
    });
  }

  private async finishMatch(): Promise<void> {
    const state = this.state;
    if (!state || state.phase === "finished" || state.settled) return;
    state.phase = "finished";
    state.settled = true;
    this.clearRoundTimer();
    this.clearBotTimers();
    this.persist();

    const results = state.players.map((p) => ({
      userId: p.id,
      score: state.scores[p.id] ?? 0,
      team: p.team,
      isBot: p.isBot,
    }));

    let pointsChanges: Record<string, number> = {};
    let reputationChanges: Record<string, number> = {};
    try {
      const request = new Request("https://internal/internal/party-result", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Rork-DO-Class": "Hub",
          "X-Rork-DO-Id": "global",
        },
        body: JSON.stringify({
          partyId: state.partyId,
          mode: state.mode,
          results,
          leftMidGame: state.leftMidGame,
        }),
      });
      const response = await this.env.DO.fetch(request);
      if (response.ok) {
        const settled = (await response.json()) as {
          pointsChanges?: Record<string, number>;
          reputationChanges?: Record<string, number>;
        };
        pointsChanges = settled.pointsChanges ?? {};
        reputationChanges = settled.reputationChanges ?? {};
      } else {
        console.error("party settlement failed", response.status);
      }
    } catch (err) {
      console.error("party settlement error", err);
    }

    this.broadcast({
      type: "finish",
      scores: state.scores,
      teamScores: state.mode === "team10" ? this.finalTeamScores(state) : undefined,
      pointsChanges,
      reputationChanges,
    });

    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.close(1000, "party over");
      } catch {
        // already gone
      }
    }
  }

  private finalTeamScores(state: PartyState): { A: number; B: number } {
    const totals = { A: 0, B: 0 };
    for (const p of state.players) {
      if (p.team === "A") totals.A += state.scores[p.id] ?? 0;
      else if (p.team === "B") totals.B += state.scores[p.id] ?? 0;
    }
    return totals;
  }

  override async webSocketClose(ws: WebSocket): Promise<void> {
    const attachment = ws.deserializeAttachment() as Attachment | null;
    const state = await this.loadState();
    if (!state || !attachment) return;
    if (state.phase === "finished") return;

    if (state.phase === "waiting") {
      // A drop before kickoff is not penalised — everyone is still loading.
      this.broadcast({ type: "lobby", connected: this.connectedUserIds(), players: state.players });
      return;
    }

    // Mid-game disconnect: the game keeps going for everyone else. The
    // leaver's remaining answers are forced timeouts and they take the
    // reputation hit when the party settles.
    if (!state.leftMidGame.includes(attachment.userId)) {
      state.leftMidGame.push(attachment.userId);
      this.persist();
    }

    const anyoneLeft = this.realPlayers(state).some((p) => !state.leftMidGame.includes(p.id));
    if (!anyoneLeft) {
      this.ctx.waitUntil(this.finishMatch());
    }
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
    this.clearRoundTimer();
    this.roundTimer = setTimeout(() => {
      this.roundTimer = null;
      fn();
    }, delayMs);
  }

  private clearRoundTimer(): void {
    if (this.roundTimer) {
      clearTimeout(this.roundTimer);
      this.roundTimer = null;
    }
  }

  private clearBotTimers(): void {
    for (const t of this.botTimers) clearTimeout(t);
    this.botTimers = [];
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
