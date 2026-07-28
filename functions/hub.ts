// functions/hub.ts — singleton "global" Hub Durable Object.
// Owns player profiles, friends, the world leaderboard, the ranked
// matchmaking queue (HTTP polling) and ELO settlement of finished matches.

import { DurableObject } from "cloudflare:workers";

export type PlayerProfile = {
  id: string;
  name: string;
  emoji: string;
  /**
   * Hidden skill rating. Drives matchmaking and weights the difficulty
   * telemetry — never shown to the player as their rank.
   */
  elo: number;
  /**
   * Visible ladder points. Move up on a win and down on a loss (chess.com
   * style), sized by how the opponent compared on hidden rating: beating
   * someone stronger pays a lot, beating someone weaker pays little.
   */
  points: number;
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
  points: number;
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
    // Migration: displayed ladder points were split out of the hidden rating.
    // Existing players keep their current number as their starting points, so
    // nobody sees their rank reset.
    try {
      this.ctx.storage.sql.exec("ALTER TABLE players ADD COLUMN points INTEGER NOT NULL DEFAULT 1000");
      this.ctx.storage.sql.exec("UPDATE players SET points = elo");
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
    // Moderation review state — every admin decision (approve/reject/edit/
    // delete/move) and every AI review note is persisted here in real time,
    // keyed by question id, so the admin-review page never loses history on
    // refresh or across devices. kind: "change" | "note".
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS review_state (
        kind TEXT NOT NULL,
        question_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (kind, question_id)
      )
    `);

    // MARK: difficulty telemetry
    // Aggregates only — we never keep one row per answer, so storage stays flat
    // no matter how many duels are played. `question_stats` holds the global
    // counters, `question_elo_stats` splits them per player-strength bucket (so
    // a success rate can be normalised against who was answering), and
    // `question_choice_stats` counts how often each option was picked (the
    // wrong-answer distribution is the best broken-question detector we have).
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS question_stats (
        question_id TEXT PRIMARY KEY,
        discipline_id TEXT,
        level TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        correct INTEGER NOT NULL DEFAULT 0,
        sum_time_ms INTEGER NOT NULL DEFAULT 0,
        sum_correct_time_ms INTEGER NOT NULL DEFAULT 0,
        timeouts INTEGER NOT NULL DEFAULT 0,
        first_seen_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS question_elo_stats (
        question_id TEXT NOT NULL,
        bucket INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        correct INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (question_id, bucket)
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS question_choice_stats (
        question_id TEXT NOT NULL,
        choice TEXT NOT NULL,
        picks INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (question_id, choice)
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
    // Review-state routes — real-time persistence of moderation decisions and
    // AI notes for the admin review tool (password-protected).
    if (path === "/api/review/state" && request.method === "GET") {
      return this.getReviewState(url.searchParams.get("password"));
    }
    if (path === "/api/review/state" && request.method === "POST") {
      return this.saveReviewState(await request.json());
    }
    // Difficulty telemetry read-out for the admin calibration tool.
    if (path === "/api/stats/questions" && request.method === "GET") {
      return this.questionStats(url.searchParams.get("password"));
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

      if (path === "/api/hub/answers" && request.method === "POST") {
        return this.ingestAnswers(userId, await request.json().catch(() => ({})));
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
    const code = this.generateFriendCodeFor(name);
    this.ctx.storage.sql.exec(
      `INSERT INTO players (user_id, name, emoji, elo, points, wins, losses, draws, friend_code, last_seen_at)
       VALUES (?, ?, ?, ?, ?, 0, 0, 0, ?, ?)`,
      userId, name.slice(0, 24), emoji, elo, elo, code, Date.now(),
    );
    return rowToProfile(this.playerRow(userId)!);
  }

  /** Builds a `Firstname#NNN` friend code, NNN being a per-first-name sequential counter. */
  private generateFriendCodeFor(rawName: string): string {
    const cleanName = cleanFirstNameForCode(rawName);
    if (!cleanName) {
      let fallback = generateFriendCode();
      for (let attempt = 0; attempt < 5; attempt += 1) {
        const clash = this.ctx.storage.sql
          .exec("SELECT user_id FROM players WHERE friend_code = ?", fallback)
          .toArray();
        if (clash.length === 0) break;
        fallback = generateFriendCode();
      }
      return fallback;
    }
    const existingCount = this.ctx.storage.sql
      .exec<{ n: number }>(
        "SELECT COUNT(*) AS n FROM players WHERE friend_code LIKE ?",
        `${cleanName}#%`,
      )
      .toArray()[0]?.n ?? 0;
    let counter = existingCount + 1;
    let code = `${cleanName}#${String(counter).padStart(3, "0")}`;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const clash = this.ctx.storage.sql
        .exec("SELECT user_id FROM players WHERE friend_code = ?", code)
        .toArray();
      if (clash.length === 0) break;
      counter += 1;
      code = `${cleanName}#${String(counter).padStart(3, "0")}`;
    }
    return code;
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
    // The ladder is ranked on visible points, not on the hidden rating.
    const top = this.ctx.storage.sql
      .exec<PlayerRow>("SELECT * FROM players ORDER BY points DESC, wins DESC LIMIT 50")
      .toArray()
      .map((row, index) => ({ rank: index + 1, ...rowToProfile(row) }));
    const mine = this.playerRow(userId);
    let myRank: number | null = null;
    if (mine) {
      const better = this.ctx.storage.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM players WHERE points > ?", mine.points)
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
    // Codes now look like "Firstname#003" (mixed case). Keep the lookup
    // case-insensitive so "florent#003", "FLORENT#003" etc. all resolve —
    // the '#' and digits are unaffected by case.
    const code = rawCode.trim();
    if (code.length < 4) {
      return Response.json({ error: "Code ami invalide" }, { status: 400 });
    }
    const target = this.ctx.storage.sql
      .exec<PlayerRow>("SELECT * FROM players WHERE UPPER(friend_code) = UPPER(?)", code)
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

    // Hidden rating: plain Elo, the number that decides who you get matched with.
    const expected1 = 1 / (1 + Math.pow(10, (row2.elo - row1.elo) / 400));
    const k = 32;
    const change1 = Math.round(k * (outcome1 - expected1));
    const change2 = -change1;

    const newElo1 = clampElo(row1.elo + change1);
    const newElo2 = clampElo(row2.elo + change2);

    // Visible points move separately, sized by the hidden-rating gap.
    const pointsChange1 = ladderPointsChange(outcome1, expected1);
    const pointsChange2 = ladderPointsChange(1 - outcome1, 1 - expected1);
    const newPoints1 = clampPoints(row1.points + pointsChange1);
    const newPoints2 = clampPoints(row2.points + pointsChange2);

    this.applyResult(p1.userId, newElo1, newPoints1, outcome1);
    this.applyResult(p2.userId, newElo2, newPoints2, 1 - outcome1);

    return Response.json({
      // `eloChanges` keeps its name for older clients, but now carries the
      // visible points delta — that is what a player should see after a duel.
      eloChanges: { [p1.userId]: pointsChange1, [p2.userId]: pointsChange2 },
      newElos: { [p1.userId]: newPoints1, [p2.userId]: newPoints2 },
      pointsChanges: { [p1.userId]: pointsChange1, [p2.userId]: pointsChange2 },
      newPoints: { [p1.userId]: newPoints1, [p2.userId]: newPoints2 },
      hiddenRatings: { [p1.userId]: newElo1, [p2.userId]: newElo2 },
    });
  }

  private applyResult(userId: string, newElo: number, newPoints: number, outcome: number): void {
    const col = outcome === 1 ? "wins" : outcome === 0 ? "losses" : "draws";
    this.ctx.storage.sql.exec(
      `UPDATE players SET elo = ?, points = ?, ${col} = ${col} + 1, last_seen_at = ? WHERE user_id = ?`,
      newElo, newPoints, Date.now(), userId,
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
        // Deliberately short: a long max-age made freshly published moderation
        // decisions look like they had been lost, because the app and the admin
        // tools kept being handed a pre-publish copy from cache.
        "Cache-Control": "public, max-age=30",
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

  // MARK: review state (real-time moderation persistence)

  private getReviewState(password: string | null): Response {
    if (password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const rows = this.ctx.storage.sql
      .exec<{ kind: string; question_id: string; payload: string; updated_at: number }>(
        "SELECT kind, question_id, payload, updated_at FROM review_state",
      )
      .toArray();
    const changes: Record<string, unknown> = {};
    const notes: Record<string, unknown> = {};
    for (const row of rows) {
      try {
        const parsed = JSON.parse(row.payload) as unknown;
        if (row.kind === "change") changes[row.question_id] = parsed;
        else if (row.kind === "note") notes[row.question_id] = parsed;
      } catch {
        // corrupted row — skip silently
      }
    }
    return Response.json({ changes, notes, count: rows.length });
  }

  // MARK: difficulty telemetry ingest

  /**
   * Records a batch of answered questions. Fire-and-forget from the client's
   * point of view: a malformed event is skipped rather than failing the batch,
   * because losing one telemetry row must never surface as an error to a player
   * mid-duel.
   */
  private ingestAnswers(userId: string, body: unknown): Response {
    const payload = body as {
      events?: Array<{
        questionId?: string;
        correct?: boolean;
        timeMs?: number;
        selected?: string;
        timedOut?: boolean;
        disciplineId?: string;
        level?: string;
      }>;
    };
    const events = Array.isArray(payload.events) ? payload.events.slice(0, 60) : [];
    if (events.length === 0) return Response.json({ ok: true, recorded: 0 });

    // The player's strength at answering time is what makes a success rate
    // interpretable, so it is resolved once per batch from the live profile.
    const elo = this.playerRow(userId)?.elo ?? 1000;
    const bucket = eloBucket(elo);
    const now = Date.now();
    let recorded = 0;

    for (const ev of events) {
      const questionId = typeof ev.questionId === "string" ? ev.questionId.slice(0, 80) : "";
      if (!questionId || typeof ev.correct !== "boolean") continue;
      const correct = ev.correct ? 1 : 0;
      const timedOut = ev.timedOut === true ? 1 : 0;
      // Clamp so a stalled client clock can't poison the average response time.
      const timeMs = Number.isFinite(ev.timeMs)
        ? Math.max(0, Math.min(120_000, Math.round(ev.timeMs as number)))
        : 0;

      this.ctx.storage.sql.exec(
        `INSERT INTO question_stats
           (question_id, discipline_id, level, attempts, correct, sum_time_ms, sum_correct_time_ms, timeouts, first_seen_at, updated_at)
         VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(question_id) DO UPDATE SET
           attempts = attempts + 1,
           correct = correct + excluded.correct,
           sum_time_ms = sum_time_ms + excluded.sum_time_ms,
           sum_correct_time_ms = sum_correct_time_ms + excluded.sum_correct_time_ms,
           timeouts = timeouts + excluded.timeouts,
           discipline_id = COALESCE(excluded.discipline_id, discipline_id),
           level = COALESCE(excluded.level, level),
           updated_at = excluded.updated_at`,
        questionId,
        typeof ev.disciplineId === "string" ? ev.disciplineId.slice(0, 60) : null,
        typeof ev.level === "string" ? ev.level.slice(0, 24) : null,
        correct,
        timeMs,
        correct === 1 ? timeMs : 0,
        timedOut,
        now,
        now,
      );

      this.ctx.storage.sql.exec(
        `INSERT INTO question_elo_stats (question_id, bucket, attempts, correct)
         VALUES (?, ?, 1, ?)
         ON CONFLICT(question_id, bucket) DO UPDATE SET
           attempts = attempts + 1,
           correct = correct + excluded.correct`,
        questionId, bucket, correct,
      );

      // Only wrong picks carry information about distractor quality; a timeout
      // is tracked separately so it never looks like a chosen option.
      if (typeof ev.selected === "string" && ev.selected.length > 0 && timedOut === 0) {
        this.ctx.storage.sql.exec(
          `INSERT INTO question_choice_stats (question_id, choice, picks)
           VALUES (?, ?, 1)
           ON CONFLICT(question_id, choice) DO UPDATE SET picks = picks + 1`,
          questionId, ev.selected.slice(0, 160),
        );
      }
      recorded += 1;
    }

    return Response.json({ ok: true, recorded });
  }

  /**
   * Admin read-out of the telemetry, with the empirical difficulty already
   * solved server-side so every consumer agrees on the same number.
   */
  private questionStats(password: string | null): Response {
    if (password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const rows = this.ctx.storage.sql
      .exec<{
        question_id: string;
        discipline_id: string | null;
        level: string | null;
        attempts: number;
        correct: number;
        sum_time_ms: number;
        sum_correct_time_ms: number;
        timeouts: number;
        updated_at: number;
      }>(
        `SELECT question_id, discipline_id, level, attempts, correct,
                sum_time_ms, sum_correct_time_ms, timeouts, updated_at
           FROM question_stats ORDER BY attempts DESC`,
      )
      .toArray();

    const eloRows = this.ctx.storage.sql
      .exec<{ question_id: string; bucket: number; attempts: number; correct: number }>(
        "SELECT question_id, bucket, attempts, correct FROM question_elo_stats",
      )
      .toArray();
    const byQuestionElo = new Map<string, Array<{ bucket: number; attempts: number; correct: number }>>();
    for (const r of eloRows) {
      const list = byQuestionElo.get(r.question_id) ?? [];
      list.push({ bucket: r.bucket, attempts: r.attempts, correct: r.correct });
      byQuestionElo.set(r.question_id, list);
    }

    const choiceRows = this.ctx.storage.sql
      .exec<{ question_id: string; choice: string; picks: number }>(
        "SELECT question_id, choice, picks FROM question_choice_stats",
      )
      .toArray();
    const byQuestionChoice = new Map<string, Record<string, number>>();
    for (const r of choiceRows) {
      const map = byQuestionChoice.get(r.question_id) ?? {};
      map[r.choice] = r.picks;
      byQuestionChoice.set(r.question_id, map);
    }

    const stats = rows.map((row) => {
      const buckets = byQuestionElo.get(row.question_id) ?? [];
      const empiricalScore = solveEmpiricalScore(buckets, row.correct);
      const avgTimeMs = row.attempts > 0 ? Math.round(row.sum_time_ms / row.attempts) : 0;
      const avgCorrectTimeMs = row.correct > 0 ? Math.round(row.sum_correct_time_ms / row.correct) : 0;
      return {
        questionId: row.question_id,
        disciplineId: row.discipline_id,
        level: row.level,
        attempts: row.attempts,
        correct: row.correct,
        successRate: row.attempts > 0 ? row.correct / row.attempts : 0,
        avgTimeMs,
        avgCorrectTimeMs,
        timeouts: row.timeouts,
        empiricalScore,
        choices: byQuestionChoice.get(row.question_id) ?? {},
        updatedAt: row.updated_at,
      };
    });

    return Response.json({ stats, count: stats.length });
  }

  private saveReviewState(body: unknown): Response {
    const payload = body as {
      password?: string;
      upserts?: Array<{ kind?: string; questionId?: string; payload?: unknown }>;
      deletes?: Array<{ kind?: string; questionId?: string }>;
    };
    if (payload.password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const now = Date.now();
    let upserted = 0;
    let deleted = 0;
    for (const u of payload.upserts ?? []) {
      if ((u.kind !== "change" && u.kind !== "note") || !u.questionId || u.payload === undefined) continue;
      this.ctx.storage.sql.exec(
        `INSERT INTO review_state (kind, question_id, payload, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(kind, question_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`,
        u.kind, u.questionId, JSON.stringify(u.payload), now,
      );
      upserted += 1;
    }
    for (const d of payload.deletes ?? []) {
      if ((d.kind !== "change" && d.kind !== "note") || !d.questionId) continue;
      this.ctx.storage.sql.exec(
        "DELETE FROM review_state WHERE kind = ? AND question_id = ?",
        d.kind, d.questionId,
      );
      deleted += 1;
    }
    return Response.json({ ok: true, upserted, deleted, savedAt: now });
  }
}

/**
 * Visible ladder points won or lost for one duel.
 *
 * `expected` is the win probability from the hidden ratings, so an upset pays
 * near the maximum while beating a much weaker opponent pays near the minimum.
 * Losses subtract (chess.com behaviour, not a one-way progress bar), and losing
 * to a stronger player costs little.
 */
function ladderPointsChange(outcome: number, expected: number): number {
  const MIN = 5;
  const SPAN = 30;
  if (outcome === 1) return Math.round(MIN + SPAN * (1 - expected));
  if (outcome === 0) return -Math.round(MIN + SPAN * expected);
  // Draw: a small correction toward what the ratings predicted.
  return Math.round(16 * (0.5 - expected));
}

function clampPoints(points: number): number {
  if (!Number.isFinite(points)) return 1000;
  return Math.max(0, Math.min(100_000, Math.round(points)));
}

function rowToProfile(row: PlayerRow): PlayerProfile {
  return {
    id: row.user_id,
    name: row.name,
    emoji: row.emoji,
    elo: row.elo,
    // Older rows created before the split have no points value yet.
    points: row.points ?? row.elo,
    wins: row.wins,
    losses: row.losses,
    draws: row.draws,
    friendCode: row.friend_code,
  };
}

/** Player-strength buckets of 100 ELO, so success rates stay interpretable. */
function eloBucket(elo: number): number {
  return Math.max(4, Math.min(40, Math.round(elo / 100)));
}

/**
 * Solves the question's difficulty on the 0-100 scale from observed answers.
 *
 * The scale is defined so the number reads directly as a population statement:
 * a score of S means a baseline player (ELO 1000) has a (100 - S)% chance of
 * answering correctly. So 25 -> 75% succeed (facile), 50 -> half succeed,
 * 75 -> a quarter succeed, 90 -> only one in ten succeeds.
 *
 * Under the hood this is a one-parameter logistic (Rasch) fit: we look for the
 * difficulty `b`, expressed on the ELO scale, that best explains how many
 * correct answers were observed given who was answering. Bisection is enough —
 * the expected-score curve is strictly decreasing in `b`.
 */
function solveEmpiricalScore(
  buckets: Array<{ bucket: number; attempts: number; correct: number }>,
  totalCorrect: number,
): number | null {
  const totalAttempts = buckets.reduce((sum, b) => sum + b.attempts, 0);
  if (totalAttempts === 0) return null;

  const expectedCorrect = (b: number): number =>
    buckets.reduce(
      (sum, row) => sum + row.attempts / (1 + Math.pow(10, (b - row.bucket * 100) / 400)),
      0,
    );

  let lo = 200;
  let hi = 3200;
  // All-correct / all-wrong have no interior solution: peg them to the bounds
  // instead of letting bisection wander.
  if (totalCorrect >= totalAttempts) hi = lo;
  else if (totalCorrect <= 0) lo = hi;
  else {
    for (let i = 0; i < 40; i += 1) {
      const mid = (lo + hi) / 2;
      if (expectedCorrect(mid) > totalCorrect) lo = mid;
      else hi = mid;
    }
  }
  const b = (lo + hi) / 2;
  const baselineSuccess = 1 / (1 + Math.pow(10, (b - 1000) / 400));
  return Math.max(0, Math.min(100, Math.round((1 - baselineSuccess) * 100)));
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

/** Strips accents/spaces/punctuation and title-cases a first name for use in friend codes. */
function cleanFirstNameForCode(rawName: string): string | null {
  const firstToken = rawName.trim().split(/\s+/)[0] ?? "";
  const normalized = firstToken
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z]/g, "");
  if (normalized.length < 2) return null;
  const generic = new Set(["joueur", "player", "user", "guest", "invite", "invit"]);
  if (generic.has(normalized.toLowerCase())) return null;
  const capped = normalized.slice(0, 16);
  return capped.charAt(0).toUpperCase() + capped.slice(1).toLowerCase();
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
