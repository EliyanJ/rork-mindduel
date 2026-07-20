// functions/hub.ts — singleton "global" Hub Durable Object.
// Owns player profiles, friends, the world leaderboard, the ranked
// matchmaking queue (HTTP polling) and ELO settlement of finished matches.

import { DurableObject } from "cloudflare:workers";

export type PlayerProfile = {
  id: string;
  name: string;
  emoji: string;
  elo: number;
  wins: number;
  losses: number;
  draws: number;
  friendCode: string;
};

type PlayerRow = {
  user_id: string;
  name: string;
  emoji: string;
  elo: number;
  wins: number;
  losses: number;
  draws: number;
  friend_code: string;
  last_seen_at: number;
};

type QueueRow = {
  user_id: string;
  elo: number;
  queued_at: number;
  last_seen_at: number;
  match_payload: string | null;
  discipline_id: string | null;
};

const QUEUE_STALE_MS = 12_000;
const EMOJIS = ["🧠", "🦊", "🦉", "🐼", "🐸", "🐨", "🐯", "🦁", "🐙", "🦄"];

export class Hub extends DurableObject {
  constructor(ctx: DurableObjectState, env: unknown) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS players (
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        elo INTEGER NOT NULL,
        wins INTEGER NOT NULL DEFAULT 0,
        losses INTEGER NOT NULL DEFAULT 0,
        draws INTEGER NOT NULL DEFAULT 0,
        friend_code TEXT NOT NULL UNIQUE,
        last_seen_at INTEGER NOT NULL
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS friendships (
        a TEXT NOT NULL,
        b TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (a, b)
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS friend_requests (
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (from_id, to_id)
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS queue (
        user_id TEXT PRIMARY KEY,
        elo INTEGER NOT NULL,
        queued_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        match_payload TEXT,
        discipline_id TEXT
      )
    `);
    // Migration: the queue table may predate the discipline_id column
    // (CREATE TABLE IF NOT EXISTS does not add new columns to existing tables).
    try {
      this.ctx.storage.sql.exec("ALTER TABLE queue ADD COLUMN discipline_id TEXT");
    } catch {
      // column already exists
    }
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS content (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        json TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        question_count INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    `);
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Internal (DO-to-DO) routes — never forwarded by the public entrypoint.
    if (path === "/internal/match-result" && request.method === "POST") {
      return this.settleMatch(await request.json());
    }

    // Content delivery routes — public GET (app fetches latest content),
    // password-protected POST (admin pushes new content from the generator panel).
    if (path === "/api/content" && request.method === "GET") {
      return this.getContent();
    }
    if (path === "/api/content/publish" && request.method === "POST") {
      return this.publishContent(await request.json());
    }

    const userId = request.headers.get("X-Rork-User-Id");
    if (!userId) {
      return Response.json({ error: "authentification requise" }, { status: 401 });
    }
    const userName = decodeHeader(request.headers.get("X-Rork-User-Name")) ?? "Joueur";

    try {
      if (path === "/api/hub/profile/sync" && request.method === "POST") {
        const body = (await request.json().catch(() => ({}))) as {
          initialElo?: number;
          name?: string;
          emoji?: string;
        };
        const profile = this.ensureProfile(userId, body.name ?? userName, body.initialElo);
        return Response.json({ profile });
      }

      if (path === "/api/hub/profile/update" && request.method === "POST") {
        const body = (await request.json()) as { name?: string; emoji?: string };
        this.ensureProfile(userId, userName);
        if (typeof body.name === "string" && body.name.trim().length > 0) {
          this.ctx.storage.sql.exec(
            "UPDATE players SET name = ? WHERE user_id = ?",
            body.name.trim().slice(0, 24),
            userId,
          );
        }
        if (typeof body.emoji === "string" && body.emoji.length > 0) {
          this.ctx.storage.sql.exec(
            "UPDATE players SET emoji = ? WHERE user_id = ?",
            body.emoji.slice(0, 8),
            userId,
          );
        }
        return Response.json({ profile: this.getProfile(userId) });
      }

      if (path === "/api/hub/leaderboard" && request.method === "GET") {
        return this.leaderboard(userId);
      }

      if (path === "/api/hub/friends" && request.method === "GET") {
        this.ensureProfile(userId, userName);
        return this.friendsPayload(userId);
      }

      if (path === "/api/hub/friends/request" && request.method === "POST") {
        const body = (await request.json()) as { code?: string };
        return this.sendFriendRequest(userId, userName, body.code ?? "");
      }

      if (path === "/api/hub/friends/respond" && request.method === "POST") {
        const body = (await request.json()) as { fromId?: string; accept?: boolean };
        return this.respondFriendRequest(userId, body.fromId ?? "", body.accept === true);
      }

      if (path === "/api/hub/friends/remove" && request.method === "POST") {
        const body = (await request.json()) as { friendId?: string };
        const friendId = body.friendId ?? "";
        this.ctx.storage.sql.exec(
          "DELETE FROM friendships WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)",
          userId, friendId, friendId, userId,
        );
        return this.friendsPayload(userId);
      }

      if (path === "/api/hub/queue/join" && request.method === "POST") {
        const body = (await request.json().catch(() => ({}))) as { disciplineId?: string };
        this.ensureProfile(userId, userName);
        return this.queueJoin(userId, body.disciplineId ?? null);
      }

      if (path === "/api/hub/queue/poll" && request.method === "GET") {
        return this.queuePoll(userId);
      }

      if (path === "/api/hub/queue/leave" && request.method === "POST") {
        this.ctx.storage.sql.exec(
          "DELETE FROM queue WHERE user_id = ? AND match_payload IS NULL",
          userId,
        );
        return Response.json({ ok: true });
      }

      if (path === "/api/hub/account/delete" && request.method === "POST") {
        return this.deleteAccount(userId);
      }

      return Response.json({ error: "not found" }, { status: 404 });
    } catch (err) {
      console.error("hub error", path, err);
      return Response.json({ error: "erreur serveur" }, { status: 500 });
    }
  }

  // MARK: profiles

  private ensureProfile(userId: string, name: string, initialElo?: number): PlayerProfile {
    const existing = this.playerRow(userId);
    if (existing) {
      this.ctx.storage.sql.exec(
        "UPDATE players SET last_seen_at = ? WHERE user_id = ?",
        Date.now(), userId,
      );
      return rowToProfile(existing);
    }
    const elo = clampElo(initialElo ?? 1000);
    const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)] ?? "🧠";
    let code = generateFriendCode();
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const clash = this.ctx.storage.sql
        .exec("SELECT user_id FROM players WHERE friend_code = ?", code)
        .toArray();
      if (clash.length === 0) break;
      code = generateFriendCode();
    }
    this.ctx.storage.sql.exec(
      `INSERT INTO players (user_id, name, emoji, elo, wins, losses, draws, friend_code, last_seen_at)
       VALUES (?, ?, ?, ?, 0, 0, 0, ?, ?)`,
      userId, name.slice(0, 24), emoji, elo, code, Date.now(),
    );
    return rowToProfile(this.playerRow(userId)!);
  }

  private playerRow(userId: string): PlayerRow | null {
    const rows = this.ctx.storage.sql
      .exec<PlayerRow>("SELECT * FROM players WHERE user_id = ?", userId)
      .toArray();
    return rows[0] ?? null;
  }

  private getProfile(userId: string): PlayerProfile | null {
    const row = this.playerRow(userId);
    return row ? rowToProfile(row) : null;
  }

  private leaderboard(userId: string): Response {
    const top = this.ctx.storage.sql
      .exec<PlayerRow>("SELECT * FROM players ORDER BY elo DESC, wins DESC LIMIT 50")
      .toArray()
      .map((row, index) => ({ rank: index + 1, ...rowToProfile(row) }));
    const mine = this.playerRow(userId);
    let myRank: number | null = null;
    if (mine) {
      const better = this.ctx.storage.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM players WHERE elo > ?", mine.elo)
        .toArray();
      myRank = (better[0]?.n ?? 0) + 1;
    }
    return Response.json({ top, myRank, totalPlayers: this.playerCount() });
  }

  private playerCount(): number {
    const rows = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM players")
      .toArray();
    return rows[0]?.n ?? 0;
  }

  // MARK: account

  private deleteAccount(userId: string): Response {
    this.ctx.storage.sql.exec(
      "DELETE FROM friendships WHERE a = ? OR b = ?",
      userId, userId,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM friend_requests WHERE from_id = ? OR to_id = ?",
      userId, userId,
    );
    this.ctx.storage.sql.exec("DELETE FROM queue WHERE user_id = ?", userId);
    this.ctx.storage.sql.exec("DELETE FROM players WHERE user_id = ?", userId);
    return Response.json({ ok: true });
  }

  // MARK: friends

  private friendsPayload(userId: string): Response {
    const friendRows = this.ctx.storage.sql
      .exec<{ a: string; b: string }>(
        "SELECT a, b FROM friendships WHERE a = ? OR b = ?",
        userId, userId,
      )
      .toArray();
    const friendIds = friendRows.map((r) => (r.a === userId ? r.b : r.a));
    const friends = friendIds
      .map((id) => this.getProfile(id))
      .filter((p): p is PlayerProfile => p !== null)
      .sort((x, y) => y.elo - x.elo);

    const incoming = this.ctx.storage.sql
      .exec<{ from_id: string }>("SELECT from_id FROM friend_requests WHERE to_id = ?", userId)
      .toArray()
      .map((r) => this.getProfile(r.from_id))
      .filter((p): p is PlayerProfile => p !== null);

    const outgoing = this.ctx.storage.sql
      .exec<{ to_id: string }>("SELECT to_id FROM friend_requests WHERE from_id = ?", userId)
      .toArray()
      .map((r) => this.getProfile(r.to_id))
      .filter((p): p is PlayerProfile => p !== null);

    return Response.json({ friends, incoming, outgoing });
  }

  private sendFriendRequest(userId: string, userName: string, rawCode: string): Response {
    this.ensureProfile(userId, userName);
    const code = rawCode.trim().toUpperCase();
    if (code.length < 4) {
      return Response.json({ error: "Code ami invalide" }, { status: 400 });
    }
    const target = this.ctx.storage.sql
      .exec<PlayerRow>("SELECT * FROM players WHERE friend_code = ?", code)
      .toArray()[0];
    if (!target) {
      return Response.json({ error: "Aucun joueur avec ce code" }, { status: 404 });
    }
    if (target.user_id === userId) {
      return Response.json({ error: "C'est ton propre code 😄" }, { status: 400 });
    }
    const already = this.ctx.storage.sql
      .exec(
        "SELECT a FROM friendships WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)",
        userId, target.user_id, target.user_id, userId,
      )
      .toArray();
    if (already.length > 0) {
      return Response.json({ error: "Vous êtes déjà amis" }, { status: 400 });
    }
    // If they already asked us, accept directly.
    const reverse = this.ctx.storage.sql
      .exec("SELECT from_id FROM friend_requests WHERE from_id = ? AND to_id = ?", target.user_id, userId)
      .toArray();
    if (reverse.length > 0) {
      this.createFriendship(userId, target.user_id);
      return this.friendsPayload(userId);
    }
    this.ctx.storage.sql.exec(
      `INSERT INTO friend_requests (from_id, to_id, created_at) VALUES (?, ?, ?)
       ON CONFLICT(from_id, to_id) DO NOTHING`,
      userId, target.user_id, Date.now(),
    );
    return this.friendsPayload(userId);
  }

  private respondFriendRequest(userId: string, fromId: string, accept: boolean): Response {
    this.ctx.storage.sql.exec(
      "DELETE FROM friend_requests WHERE from_id = ? AND to_id = ?",
      fromId, userId,
    );
    if (accept && fromId.length > 0) {
      this.createFriendship(userId, fromId);
    }
    return this.friendsPayload(userId);
  }

  private createFriendship(x: string, y: string): void {
    const [a, b] = x < y ? [x, y] : [y, x];
    this.ctx.storage.sql.exec(
      "INSERT INTO friendships (a, b, created_at) VALUES (?, ?, ?) ON CONFLICT(a, b) DO NOTHING",
      a, b, Date.now(),
    );
    // Clean any remaining requests in both directions.
    this.ctx.storage.sql.exec(
      "DELETE FROM friend_requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)",
      x, y, y, x,
    );
  }

  // MARK: matchmaking queue

  private queueJoin(userId: string, disciplineId: string | null): Response {
    this.purgeStaleQueue();
    const me = this.playerRow(userId);
    if (!me) {
      return Response.json({ error: "profil introuvable" }, { status: 400 });
    }
    const existing = this.queueRow(userId);
    if (existing?.match_payload) {
      return this.deliverMatch(existing);
    }
    if (!existing) {
      this.ctx.storage.sql.exec(
        `INSERT INTO queue (user_id, elo, queued_at, last_seen_at, match_payload, discipline_id)
         VALUES (?, ?, ?, ?, NULL, ?)`,
        userId, me.elo, Date.now(), Date.now(), disciplineId,
      );
    } else {
      this.ctx.storage.sql.exec(
        "UPDATE queue SET last_seen_at = ?, discipline_id = ? WHERE user_id = ?",
        Date.now(), disciplineId, userId,
      );
    }
    this.tryPair(userId);
    return this.queuePoll(userId);
  }

  private queuePoll(userId: string): Response {
    this.purgeStaleQueue();
    const row = this.queueRow(userId);
    if (!row) {
      return Response.json({ status: "idle" });
    }
    this.ctx.storage.sql.exec(
      "UPDATE queue SET last_seen_at = ? WHERE user_id = ?",
      Date.now(), userId,
    );
    if (row.match_payload) {
      return this.deliverMatch(row);
    }
    this.tryPair(userId);
    const after = this.queueRow(userId);
    if (after?.match_payload) {
      return this.deliverMatch(after);
    }
    return Response.json({ status: "searching", waitingSince: row.queued_at });
  }

  private deliverMatch(row: QueueRow): Response {
    this.ctx.storage.sql.exec("DELETE FROM queue WHERE user_id = ?", row.user_id);
    return new Response(row.match_payload, {
      headers: { "Content-Type": "application/json" },
    });
  }

  private queueRow(userId: string): QueueRow | null {
    const rows = this.ctx.storage.sql
      .exec<QueueRow>("SELECT * FROM queue WHERE user_id = ?", userId)
      .toArray();
    return rows[0] ?? null;
  }

  private purgeStaleQueue(): void {
    this.ctx.storage.sql.exec(
      "DELETE FROM queue WHERE match_payload IS NULL AND last_seen_at < ?",
      Date.now() - QUEUE_STALE_MS,
    );
    // Matched-but-never-claimed tickets die after 2 minutes.
    this.ctx.storage.sql.exec(
      "DELETE FROM queue WHERE match_payload IS NOT NULL AND last_seen_at < ?",
      Date.now() - 120_000,
    );
  }

  private tryPair(userId: string): void {
    const me = this.queueRow(userId);
    if (!me || me.match_payload) return;

    const waitedSec = (Date.now() - me.queued_at) / 1000;
    // ELO window widens the longer you wait: ±150 at 0s, +40 per second.
    const window = 150 + Math.floor(waitedSec * 40);

    // Prefer an opponent who picked the same theme; otherwise take the closest
    // ELO opponent regardless of theme — the duel then mixes both themes.
    const sameTheme = this.ctx.storage.sql
      .exec<QueueRow>(
        `SELECT * FROM queue
         WHERE user_id != ? AND match_payload IS NULL
           AND (discipline_id IS ? OR discipline_id = ?)
         ORDER BY ABS(elo - ?) ASC LIMIT 1`,
        userId, me.discipline_id, me.discipline_id, me.elo,
      )
      .toArray();
    let opponent: QueueRow | null = sameTheme[0] ?? null;
    if (!opponent || Math.abs(opponent.elo - me.elo) > window) {
      const anyTheme = this.ctx.storage.sql
        .exec<QueueRow>(
          `SELECT * FROM queue
           WHERE user_id != ? AND match_payload IS NULL
           ORDER BY ABS(elo - ?) ASC LIMIT 1`,
          userId, me.elo,
        )
        .toArray();
      opponent = anyTheme[0] ?? null;
    }
    if (!opponent) return;
    if (Math.abs(opponent.elo - me.elo) > window) return;

    const myProfile = this.getProfile(me.user_id);
    const oppProfile = this.getProfile(opponent.user_id);
    if (!myProfile || !oppProfile) return;

    const matchId = crypto.randomUUID();
    const seed = randomSeed();
    // Both players receive the same sorted theme list so their clients derive
    // an identical mixed question set from the shared seed.
    const themes = [me.discipline_id ?? "all", opponent.discipline_id ?? "all"].sort();
    const base = { status: "matched", matchId, seed, questionCount: 15, roundDuration: 15, themes };
    const forMe = JSON.stringify({ ...base, you: myProfile, opponent: oppProfile });
    const forOpp = JSON.stringify({ ...base, you: oppProfile, opponent: myProfile });

    this.ctx.storage.sql.exec(
      "UPDATE queue SET match_payload = ?, last_seen_at = ? WHERE user_id = ?",
      forMe, Date.now(), me.user_id,
    );
    this.ctx.storage.sql.exec(
      "UPDATE queue SET match_payload = ?, last_seen_at = ? WHERE user_id = ?",
      forOpp, Date.now(), opponent.user_id,
    );
  }

  // MARK: ELO settlement (called by MatchRoom via env.DO)

  private settleMatch(body: unknown): Response {
    const payload = body as {
      matchId?: string;
      results?: { userId: string; score: number }[];
      forfeitBy?: string;
    };
    const results = payload.results ?? [];
    if (results.length !== 2) {
      return Response.json({ error: "invalid results" }, { status: 400 });
    }
    const [p1, p2] = results as [
      { userId: string; score: number },
      { userId: string; score: number },
    ];

    const row1 = this.playerRow(p1.userId);
    const row2 = this.playerRow(p2.userId);
    if (!row1 || !row2) {
      return Response.json({ error: "unknown players" }, { status: 400 });
    }

    let outcome1: number; // 1 = p1 wins, 0.5 = draw, 0 = p1 loses
    if (payload.forfeitBy === p1.userId) outcome1 = 0;
    else if (payload.forfeitBy === p2.userId) outcome1 = 1;
    else if (p1.score > p2.score) outcome1 = 1;
    else if (p1.score < p2.score) outcome1 = 0;
    else outcome1 = 0.5;

    const expected1 = 1 / (1 + Math.pow(10, (row2.elo - row1.elo) / 400));
    const k = 32;
    const change1 = Math.round(k * (outcome1 - expected1));
    const change2 = -change1;

    const newElo1 = clampElo(row1.elo + change1);
    const newElo2 = clampElo(row2.elo + change2);

    this.applyResult(p1.userId, newElo1, outcome1);
    this.applyResult(p2.userId, newElo2, 1 - outcome1);

    return Response.json({
      eloChanges: { [p1.userId]: change1, [p2.userId]: change2 },
      newElos: { [p1.userId]: newElo1, [p2.userId]: newElo2 },
    });
  }

  private applyResult(userId: string, newElo: number, outcome: number): void {
    const col = outcome === 1 ? "wins" : outcome === 0 ? "losses" : "draws";
    this.ctx.storage.sql.exec(
      `UPDATE players SET elo = ?, ${col} = ${col} + 1, last_seen_at = ? WHERE user_id = ?`,
      newElo, Date.now(), userId,
    );
  }

  // MARK: content delivery

  private getContent(): Response {
    const rows = this.ctx.storage.sql
      .exec<{ json: string; version: number; question_count: number; updated_at: number }>(
        "SELECT json, version, question_count, updated_at FROM content WHERE id = 1",
      )
      .toArray();
    if (rows.length === 0) {
      return Response.json({ published: false });
    }
    const row = rows[0]!;
    return new Response(row.json, {
      headers: {
        "Content-Type": "application/json",
        "X-Content-Version": String(row.version),
        "X-Content-Question-Count": String(row.question_count),
        "X-Content-Updated-At": String(row.updated_at),
        "Cache-Control": "public, max-age=300",
      },
    });
  }

  private publishContent(body: unknown): Response {
    const payload = body as { content?: unknown; password?: string };
    if (payload.password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    if (!payload.content || typeof payload.content !== "object") {
      return Response.json({ error: "Contenu invalide" }, { status: 400 });
    }
    const jsonStr = JSON.stringify(payload.content);
    const content = payload.content as { disciplines?: Array<{ chapters?: Array<{ questions?: unknown[]; levels?: Record<string, { questions?: unknown[] }> }> }> };
    let questionCount = 0;
    for (const disc of content.disciplines ?? []) {
      for (const ch of disc.chapters ?? []) {
        if (ch.questions) questionCount += ch.questions.length;
        if (ch.levels) {
          for (const lvl of Object.values(ch.levels)) {
            questionCount += lvl.questions?.length ?? 0;
          }
        }
      }
    }
    const existing = this.ctx.storage.sql
      .exec<{ version: number }>("SELECT version FROM content WHERE id = 1")
      .toArray();
    const newVersion = (existing[0]?.version ?? 0) + 1;
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO content (id, json, version, question_count, updated_at) VALUES (1, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET json = excluded.json, version = excluded.version, question_count = excluded.question_count, updated_at = excluded.updated_at`,
      jsonStr, newVersion, questionCount, now,
    );
    return Response.json({
      ok: true,
      version: newVersion,
      questionCount,
      updatedAt: now,
    });
  }
}

function rowToProfile(row: PlayerRow): PlayerProfile {
  return {
    id: row.user_id,
    name: row.name,
    emoji: row.emoji,
    elo: row.elo,
    wins: row.wins,
    losses: row.losses,
    draws: row.draws,
    friendCode: row.friend_code,
  };
}

function clampElo(elo: number): number {
  if (!Number.isFinite(elo)) return 1000;
  return Math.max(400, Math.min(4000, Math.round(elo)));
}

function generateFriendCode(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

function randomSeed(): string {
  const buf = new Uint32Array(2);
  crypto.getRandomValues(buf);
  // 53-bit-safe: combine into a decimal string parsed as UInt64 on the client.
  return `${buf[0]}${String(buf[1]).padStart(10, "0")}`.slice(0, 18);
}

/** RFC 2047 / URI-encoded header values arrive as plain UTF-8 percent-encoding. */
function decodeHeader(value: string | null): string | null {
  if (!value) return null;
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
