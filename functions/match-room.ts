// functions/match-room.ts — one Durable Object instance per ranked duel.
// Both players connect over WebSocket; the room drives the rounds
// (server-authoritative timing), relays answers, computes points, and
// settles ELO via the Hub DO when the match ends.

import { DurableObject } from "cloudflare:workers";

type Env = { DO: Fetcher };

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
  questionCount: number;
  roundDuration: number;
  players: PlayerInfo[];
  phase: "waiting" | "playing" | "reveal" | "finished";
  round: number;
  scores: Record<string, number>;
  answers: Record<string, RoundAnswer>[];
  settled: boolean;
};

type Attachment = { userId: string };

const REVEAL_MS = 2_600;
const COUNTDOWN_MS = 3_200;
const GRACE_MS = 1_200;

export class MatchRoom extends DurableObject<Env> {
  private state: MatchState | null = null;
  private roundTimer: ReturnType<typeof setTimeout> | null = null;

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
      // Lazy init from the first connector's matched ticket.
      const initialized = await this.initFromParams(url);
      if (!initialized) {
        return new Response("match not initialized", { status: 400 });
      }
    }

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

  private async initFromParams(url: URL): Promise<boolean> {
    const raw = url.searchParams.get("init");
    if (!raw) return false;
    try {
      const ticket = JSON.parse(raw) as {
        seed?: string;
        questionCount?: number;
        roundDuration?: number;
        you?: PlayerInfo;
        opponent?: PlayerInfo;
      };
      if (!ticket.seed || !ticket.you || !ticket.opponent) return false;
      const state: MatchState = {
        seed: ticket.seed,
        questionCount: ticket.questionCount ?? 8,
        roundDuration: ticket.roundDuration ?? 15,
        players: [ticket.you, ticket.opponent],
        phase: "waiting",
        round: -1,
        scores: { [ticket.you.id]: 0, [ticket.opponent.id]: 0 },
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
    if (index >= state.questionCount) {
      this.ctx.waitUntil(this.finishMatch(null));
      return;
    }
    state.round = index;
    while (state.answers.length <= index) state.answers.push({});
    this.persist();
    const endsInMs = state.roundDuration * 1000;
    this.broadcast({ type: "round", index, durationMs: endsInMs });
    this.armTimer(endsInMs + GRACE_MS, () => this.closeRound(index));
  }

  override async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string") return;
    const attachment = ws.deserializeAttachment() as Attachment | null;
    if (!attachment) return;

    let msg: { type?: string; index?: number; answer?: string; correct?: boolean; timeMs?: number };
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    const state = await this.loadState();
    if (!state) return;

    if (msg.type === "answer" && typeof msg.index === "number") {
      if (state.phase !== "playing" || msg.index !== state.round) return;
      const roundAnswers = state.answers[msg.index];
      if (!roundAnswers || roundAnswers[attachment.userId]) return;

      const timeMs = clamp(msg.timeMs ?? state.roundDuration * 1000, 0, state.roundDuration * 1000);
      const correct = msg.correct === true;
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
    state.phase = "finished";
    state.settled = true;
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
        }),
      });
      const response = await this.env.DO.fetch(request);
      if (response.ok) {
        const settled = (await response.json()) as {
          eloChanges?: Record<string, number>;
          newElos?: Record<string, number>;
        };
        eloChanges = settled.eloChanges ?? {};
        newElos = settled.newElos ?? {};
      } else {
        console.error("elo settlement failed", response.status);
      }
    } catch (err) {
      console.error("elo settlement error", err);
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
    const attachment = ws.deserializeAttachment() as Attachment | null;
    const state = await this.loadState();
    if (!state || !attachment) return;

    const stillConnected = this.connectedUserIds();
    if (state.phase === "finished") return;

    if (stillConnected.length === 0) {
      // Everyone left — nothing to do; state stays for a late reconnect.
      this.clearTimer();
      return;
    }

    if (state.phase === "waiting") {
      this.broadcast({ type: "cancelled", reason: "opponent_left" });
      return;
    }

    // Mid-match disconnect = forfeit for the leaver.
    this.ctx.waitUntil(this.finishMatch(attachment.userId));
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

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
