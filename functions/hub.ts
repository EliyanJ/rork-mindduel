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
  /**
   * Behaviour counter, entirely separate from skill: rewards finishing what
   * you start and punishes abandoning a lobby or a live party game. Floored
   * at 0, uncapped above, purely informational for now.
   */
  reputation: number;
  /**
   * Personal daily learning goal (1-3 lessons/day), set during onboarding.
   * Persisted server-side so it survives reinstalls/devices and can drive
   * how many reminders we plan to send.
   */
  dailyGoal: number;
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
  reputation: number;
  daily_goal: number;
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

// MARK: party modes (10v10 and 1v19)
export const PARTY_CAPACITY = 20;
/** How long a lobby waits for real players before bots fill the rest. */
const PARTY_FILL_MS = 15_000;
/** A finalized-but-never-connected lobby is abandoned after this long. */
const PARTY_STALE_TICKET_MS = 120_000;
export type PartyMode = "team10" | "solo" | "duo";

/** Seats to fill for each party format before bots top up the rest. */
function partyCapacity(mode: PartyMode): number {
  return mode === "duo" ? 4 : PARTY_CAPACITY;
}

/** Team formats (score cumulated per side) vs. individual-ranking formats. */
function isTeamMode(mode: PartyMode): boolean {
  return mode === "team10" || mode === "duo";
}

/** Shared secret guarding every admin route. */
const ADMIN_PASSWORD = "minduel-admin";

/**
 * Back-office roles. `premium` here means *offered* premium only; a paid
 * subscription lives in `entitlements` and is never expressed as a role, so
 * a gift can never be confused with a purchase.
 */
export const ADMIN_ROLES = ["standard", "beta", "premium", "admin", "banned"] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

function normalizeRole(raw: string | null | undefined): AdminRole {
  return ADMIN_ROLES.includes(raw as AdminRole) ? (raw as AdminRole) : "standard";
}

/** Who performed an admin action, for the audit trail. */
function actorFrom(raw: string | null | undefined): string {
  const clean = (raw ?? "").trim();
  return clean.length > 0 ? clean.slice(0, 80) : "admin";
}

type AdminPlayerRow = PlayerRow & {
  role: string | null;
  email: string | null;
  created_at: number;
  granted_premium_until: number | null;
};

type EntitlementRow = {
  user_id: string;
  product_id: string | null;
  store: string | null;
  status: string;
  started_at: number | null;
  expires_at: number | null;
  updated_at: number;
};

type RefundRow = {
  event_id: string;
  user_id: string;
  product_id: string | null;
  store: string | null;
  amount_cents: number | null;
  currency: string | null;
  refunded_at: number;
  reason: string | null;
};

type AuditRow = {
  id: number;
  at: number;
  actor: string;
  action: string;
  target_user: string | null;
  detail: string | null;
};

export type AccessState = {
  grantedPremium: boolean;
  /** 0 means "no expiry", null means no active gift. */
  grantedPremiumUntil: number | null;
  purchasedPremium: boolean;
  purchase: {
    productId: string | null;
    store: string | null;
    status: string;
    startedAt: number | null;
    expiresAt: number | null;
  } | null;
  isPremium: boolean;
};

export type AdminUserSummary = {
  id: string;
  name: string;
  emoji: string;
  email: string | null;
  role: AdminRole;
  friendCode: string;
  createdAt: number;
  lastSeenAt: number;
  duels: number;
  wins: number;
  losses: number;
  draws: number;
  points: number;
  elo: number;
  isPremium: boolean;
  grantedPremium: boolean;
  purchasedPremium: boolean;
};

/** Subset of the RevenueCat webhook payload we act on. */
type RevenueCatEvent = {
  id?: string;
  type?: string;
  app_user_id?: string;
  product_id?: string;
  store?: string;
  price?: number;
  currency?: string;
  cancel_reason?: string;
  event_timestamp_ms?: number;
  purchased_at_ms?: number;
  expiration_at_ms?: number;
};

function rowToRefund(row: RefundRow) {
  return {
    eventId: row.event_id,
    userId: row.user_id,
    productId: row.product_id,
    store: row.store,
    amountCents: row.amount_cents,
    currency: row.currency,
    refundedAt: row.refunded_at,
    reason: row.reason,
  };
}

function rowToAudit(row: AuditRow) {
  return {
    id: row.id,
    at: row.at,
    actor: row.actor,
    action: row.action,
    targetUser: row.target_user,
    detail: row.detail,
  };
}

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
      CREATE TABLE IF NOT EXISTS party_lobbies (
        lobby_id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        started INTEGER NOT NULL DEFAULT 0
      )
    `);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS party_queue (
        user_id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        elo INTEGER NOT NULL,
        lobby_id TEXT NOT NULL,
        queued_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        match_payload TEXT
      )
    `);
    // Behaviour counter — added after `players` already existed in the wild.
    try {
      this.ctx.storage.sql.exec("ALTER TABLE players ADD COLUMN reputation INTEGER NOT NULL DEFAULT 0");
    } catch {
      // column already exists
    }
    // Personal daily goal (1-3), collected during onboarding — added after
    // `players` already existed in the wild.
    try {
      this.ctx.storage.sql.exec("ALTER TABLE players ADD COLUMN daily_goal INTEGER NOT NULL DEFAULT 3");
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
    // Nothing here is ever hard-deleted. A moderation decision that leaves the
    // pending queue is copied here first, so a mistaken "clear" (or a publish
    // that silently dropped stale decisions) can always be replayed instead of
    // costing hours of human review.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS review_state_archive (
        archive_id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        question_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        reason TEXT,
        archived_at INTEGER NOT NULL
      )
    `);
    // Full snapshots of every published content version. Publishing overwrites
    // a single row, so without history one bad publish is unrecoverable.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS content_history (
        version INTEGER PRIMARY KEY,
        json TEXT NOT NULL,
        question_count INTEGER NOT NULL,
        moderated_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    `);
    // Learning-path ordering published from the admin "Parcours" tool:
    // discipline order, per-discipline chapter order and per-chapter ring
    // timelines. Kept apart from `content` so reordering the path never
    // rewrites (or risks losing) the question catalog itself.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS path_layout (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        json TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      )
    `);
    // Snapshots of every published layout, same safety net as content_history.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS path_layout_history (
        version INTEGER PRIMARY KEY,
        json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    `);
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

    // MARK: back-office account management
    // Roles and manually offered premium live on the player row. They are an
    // admin-only concept: the app never sets them, only the password-protected
    // /api/admin/* routes do.
    for (const migration of [
      "ALTER TABLE players ADD COLUMN role TEXT NOT NULL DEFAULT 'standard'",
      "ALTER TABLE players ADD COLUMN email TEXT",
      "ALTER TABLE players ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0",
      // Manually offered premium. NULL = never granted, 0 = no expiry,
      // timestamp = expiry date. Deliberately separate from purchased
      // entitlements so a gift can never be mistaken for a paid subscription.
      "ALTER TABLE players ADD COLUMN granted_premium_until INTEGER",
    ]) {
      try {
        this.ctx.storage.sql.exec(migration);
      } catch {
        // column already exists
      }
    }
    // Rows created before created_at existed fall back to the only date known.
    try {
      this.ctx.storage.sql.exec("UPDATE players SET created_at = last_seen_at WHERE created_at = 0");
    } catch {
      // table not migrated yet
    }

    // Purchased entitlements mirrored from the store webhook. Apple (through
    // RevenueCat) is the source of truth — we only cache the current state.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS entitlements (
        user_id TEXT PRIMARY KEY,
        product_id TEXT,
        store TEXT,
        status TEXT NOT NULL,
        started_at INTEGER,
        expires_at INTEGER,
        updated_at INTEGER NOT NULL
      )
    `);

    // Refunds granted by Apple. We can never issue one ourselves: this is a
    // read-only ledger that also drives automatic access revocation.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS refunds (
        event_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id TEXT,
        store TEXT,
        amount_cents INTEGER,
        currency TEXT,
        refunded_at INTEGER NOT NULL,
        reason TEXT
      )
    `);

    // Every back-office action on a personal account is traced: a GDPR
    // accountability requirement, and the only way to understand later why an
    // account was changed.
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS admin_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at INTEGER NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        target_user TEXT,
        detail TEXT
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
    if (path === "/internal/party-result" && request.method === "POST") {
      return this.settleParty(await request.json());
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
    // Recovery routes — archived decisions and previous content versions.
    if (path === "/api/review/archive" && request.method === "GET") {
      return this.getReviewArchive(url.searchParams.get("password"));
    }
    if (path === "/api/review/archive/restore" && request.method === "POST") {
      return this.restoreReviewArchive(await request.json());
    }
    if (path === "/api/content/history" && request.method === "GET") {
      return this.getContentHistory(url.searchParams.get("password"));
    }
    if (path === "/api/content/rollback" && request.method === "POST") {
      return this.rollbackContent(await request.json());
    }
    // Difficulty telemetry read-out for the admin calibration tool.
    if (path === "/api/stats/questions" && request.method === "GET") {
      return this.questionStats(url.searchParams.get("password"));
    }
    // Learning-path ordering — public GET (the app reads it like the catalog),
    // password-protected POST from the admin "Parcours" tool.
    if (path === "/api/path-layout" && request.method === "GET") {
      return this.getPathLayout();
    }
    if (path === "/api/path-layout" && request.method === "POST") {
      return this.publishPathLayout(await request.json());
    }

    // MARK: back-office user administration (password-protected)
    if (path === "/api/admin/users" && request.method === "GET") {
      return this.adminListUsers(url);
    }
    if (path === "/api/admin/users/detail" && request.method === "GET") {
      return this.adminUserDetail(url);
    }
    if (path === "/api/admin/users/export" && request.method === "GET") {
      return this.adminExportUser(url);
    }
    if (path === "/api/admin/users/role" && request.method === "POST") {
      return this.adminSetRole(await request.json().catch(() => ({})));
    }
    if (path === "/api/admin/users/premium" && request.method === "POST") {
      return this.adminSetGrantedPremium(await request.json().catch(() => ({})));
    }
    if (path === "/api/admin/users/delete" && request.method === "POST") {
      return this.adminDeleteUser(await request.json().catch(() => ({})));
    }
    if (path === "/api/admin/refunds" && request.method === "GET") {
      return this.adminRefunds(url.searchParams.get("password"));
    }
    if (path === "/api/admin/audit" && request.method === "GET") {
      return this.adminAudit(url);
    }
    // Store webhook (RevenueCat). Authenticated by a shared bearer secret, not
    // the admin password, because it is called machine-to-machine.
    if (path === "/api/webhooks/revenuecat" && request.method === "POST") {
      return this.storeWebhook(request);
    }

    const userId = request.headers.get("X-Rork-User-Id");
    if (!userId) {
      return Response.json({ error: "authentification requise" }, { status: 401 });
    }
    const userName = decodeHeader(request.headers.get("X-Rork-User-Name")) ?? "Joueur";
    // Captured opportunistically: the platform only stamps it for providers
    // that share the address. Never required, never used as an identifier.
    const userEmail = decodeHeader(request.headers.get("X-Rork-User-Email"));
    if (userEmail) this.rememberEmail(userId, userEmail);

    // A banned account keeps its data but loses every online capability.
    if (this.roleOf(userId) === "banned") {
      return Response.json({ error: "compte suspendu" }, { status: 403 });
    }

    try {
      if (path === "/api/hub/profile/sync" && request.method === "POST") {
        const body = (await request.json().catch(() => ({}))) as {
          initialElo?: number;
          name?: string;
          emoji?: string;
          dailyGoal?: number;
        };
        const profile = this.ensureProfile(userId, body.name ?? userName, body.initialElo, body.dailyGoal);
        return Response.json({ profile });
      }

      if (path === "/api/hub/profile/update" && request.method === "POST") {
        const body = (await request.json()) as { name?: string; emoji?: string; dailyGoal?: number };
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
        if (typeof body.dailyGoal === "number" && Number.isFinite(body.dailyGoal)) {
          this.ctx.storage.sql.exec(
            "UPDATE players SET daily_goal = ? WHERE user_id = ?",
            Math.max(1, Math.min(3, Math.round(body.dailyGoal))),
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

      if (path === "/api/hub/party/queue/join" && request.method === "POST") {
        const body = (await request.json().catch(() => ({}))) as { mode?: string };
        this.ensureProfile(userId, userName);
        return this.partyQueueJoin(userId, body.mode === "team10" ? "team10" : body.mode === "duo" ? "duo" : "solo");
      }

      if (path === "/api/hub/party/queue/poll" && request.method === "GET") {
        return this.partyQueuePoll(userId);
      }

      if (path === "/api/hub/party/queue/leave" && request.method === "POST") {
        return this.partyQueueLeave(userId);
      }

      return Response.json({ error: "not found" }, { status: 404 });
    } catch (err) {
      console.error("hub error", path, err);
      return Response.json({ error: "erreur serveur" }, { status: 500 });
    }
  }

  // MARK: profiles

  private ensureProfile(userId: string, name: string, initialElo?: number, dailyGoal?: number): PlayerProfile {
    const existing = this.playerRow(userId);
    if (existing) {
      this.ctx.storage.sql.exec(
        "UPDATE players SET last_seen_at = ? WHERE user_id = ?",
        Date.now(), userId,
      );
      // A daily goal sent on a later sync (e.g. changed on another device)
      // keeps this profile's copy up to date without a dedicated round trip.
      if (typeof dailyGoal === "number" && Number.isFinite(dailyGoal)) {
        this.ctx.storage.sql.exec(
          "UPDATE players SET daily_goal = ? WHERE user_id = ?",
          Math.max(1, Math.min(3, Math.round(dailyGoal))),
          userId,
        );
        return rowToProfile(this.playerRow(userId)!);
      }
      return rowToProfile(existing);
    }
    const elo = clampElo(initialElo ?? 1000);
    const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)] ?? "🧠";
    const code = this.generateFriendCodeFor(name);
    const goal = Math.max(1, Math.min(3, Math.round(dailyGoal ?? 3)));
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO players (user_id, name, emoji, elo, points, wins, losses, draws, friend_code, last_seen_at, created_at, daily_goal)
       VALUES (?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?)`,
      userId, name.slice(0, 24), emoji, elo, elo, code, now, now, goal,
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
    this.ctx.storage.sql.exec("DELETE FROM entitlements WHERE user_id = ?", userId);
    this.ctx.storage.sql.exec("DELETE FROM players WHERE user_id = ?", userId);
    return Response.json({ ok: true });
  }

  // MARK: back-office administration

  /** Stores the address the identity provider shared, if any. */
  private rememberEmail(userId: string, email: string): void {
    const clean = email.trim().toLowerCase().slice(0, 160);
    if (!clean.includes("@")) return;
    this.ctx.storage.sql.exec(
      "UPDATE players SET email = ? WHERE user_id = ? AND (email IS NULL OR email <> ?)",
      clean, userId, clean,
    );
  }

  private roleOf(userId: string): AdminRole {
    const rows = this.ctx.storage.sql
      .exec<{ role: string | null }>("SELECT role FROM players WHERE user_id = ?", userId)
      .toArray();
    return normalizeRole(rows[0]?.role);
  }

  private logAudit(actor: string, action: string, targetUser: string | null, detail: string): void {
    this.ctx.storage.sql.exec(
      "INSERT INTO admin_audit (at, actor, action, target_user, detail) VALUES (?, ?, ?, ?, ?)",
      Date.now(), actor.slice(0, 80), action.slice(0, 60), targetUser, detail.slice(0, 500),
    );
  }

  /** Current access state, keeping the gift and the purchase strictly apart. */
  private accessOf(userId: string, row?: AdminPlayerRow | null): AccessState {
    const player = row ?? this.adminPlayerRow(userId);
    const ent = this.ctx.storage.sql
      .exec<EntitlementRow>("SELECT * FROM entitlements WHERE user_id = ?", userId)
      .toArray()[0] ?? null;
    const now = Date.now();
    const grantedUntil = player?.granted_premium_until ?? null;
    const grantActive = grantedUntil !== null && (grantedUntil === 0 || grantedUntil > now);
    const purchaseActive =
      ent !== null
      && ent.status === "active"
      && (ent.expires_at === null || ent.expires_at > now);
    return {
      grantedPremium: grantActive,
      grantedPremiumUntil: grantActive ? grantedUntil : null,
      purchasedPremium: purchaseActive,
      purchase: ent
        ? {
            productId: ent.product_id,
            store: ent.store,
            status: ent.status,
            startedAt: ent.started_at,
            expiresAt: ent.expires_at,
          }
        : null,
      isPremium: grantActive || purchaseActive,
    };
  }

  private adminPlayerRow(userId: string): AdminPlayerRow | null {
    return this.ctx.storage.sql
      .exec<AdminPlayerRow>("SELECT * FROM players WHERE user_id = ?", userId)
      .toArray()[0] ?? null;
  }

  private adminListUsers(url: URL): Response {
    if (url.searchParams.get("password") !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const search = (url.searchParams.get("search") ?? "").trim().toLowerCase();
    const roleFilter = url.searchParams.get("role");
    const inactiveDays = Number(url.searchParams.get("inactiveDays") ?? "0");
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? "200"), 1), 500);
    const offset = Math.max(Number(url.searchParams.get("offset") ?? "0"), 0);

    const all = this.ctx.storage.sql
      .exec<AdminPlayerRow>("SELECT * FROM players ORDER BY last_seen_at DESC")
      .toArray();
    const now = Date.now();
    const filtered = all.filter((row) => {
      if (search) {
        const haystack = `${row.name} ${row.email ?? ""} ${row.friend_code} ${row.user_id}`.toLowerCase();
        if (!haystack.includes(search)) return false;
      }
      if (roleFilter && roleFilter !== "all" && normalizeRole(row.role) !== roleFilter) return false;
      if (Number.isFinite(inactiveDays) && inactiveDays > 0) {
        if (now - row.last_seen_at < inactiveDays * 86_400_000) return false;
      }
      return true;
    });

    const users = filtered.slice(offset, offset + limit).map((row) => this.adminUserSummary(row));
    const roleCounts: Record<string, number> = {};
    for (const row of all) {
      const role = normalizeRole(row.role);
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }
    const activeSevenDays = all.filter((r) => now - r.last_seen_at < 7 * 86_400_000).length;

    return Response.json({
      users,
      total: filtered.length,
      totalPlayers: all.length,
      roleCounts,
      activeSevenDays,
      premiumCount: all.filter((r) => this.accessOf(r.user_id, r).isPremium).length,
    });
  }

  private adminUserSummary(row: AdminPlayerRow): AdminUserSummary {
    const access = this.accessOf(row.user_id, row);
    return {
      id: row.user_id,
      name: row.name,
      emoji: row.emoji,
      email: row.email,
      role: normalizeRole(row.role),
      friendCode: row.friend_code,
      createdAt: row.created_at || row.last_seen_at,
      lastSeenAt: row.last_seen_at,
      duels: row.wins + row.losses + row.draws,
      wins: row.wins,
      losses: row.losses,
      draws: row.draws,
      points: row.points,
      elo: row.elo,
      isPremium: access.isPremium,
      grantedPremium: access.grantedPremium,
      purchasedPremium: access.purchasedPremium,
    };
  }

  private adminUserDetail(url: URL): Response {
    if (url.searchParams.get("password") !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const userId = url.searchParams.get("userId") ?? "";
    const row = this.adminPlayerRow(userId);
    if (!row) return Response.json({ error: "joueur introuvable" }, { status: 404 });

    const friends = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM friendships WHERE a = ? OR b = ?", userId, userId)
      .toArray()[0]?.n ?? 0;
    const refunds = this.ctx.storage.sql
      .exec<RefundRow>("SELECT * FROM refunds WHERE user_id = ? ORDER BY refunded_at DESC", userId)
      .toArray()
      .map(rowToRefund);
    const audit = this.ctx.storage.sql
      .exec<AuditRow>(
        "SELECT * FROM admin_audit WHERE target_user = ? ORDER BY id DESC LIMIT 50",
        userId,
      )
      .toArray()
      .map(rowToAudit);

    return Response.json({
      user: this.adminUserSummary(row),
      access: this.accessOf(userId, row),
      friends,
      refunds,
      audit,
      queued: this.ctx.storage.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM queue WHERE user_id = ?", userId)
        .toArray()[0]?.n ?? 0,
    });
  }

  /** GDPR portability: everything the server holds about one person. */
  private adminExportUser(url: URL): Response {
    if (url.searchParams.get("password") !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const userId = url.searchParams.get("userId") ?? "";
    const row = this.adminPlayerRow(userId);
    if (!row) return Response.json({ error: "joueur introuvable" }, { status: 404 });

    const friendships = this.ctx.storage.sql
      .exec("SELECT * FROM friendships WHERE a = ? OR b = ?", userId, userId)
      .toArray();
    const requests = this.ctx.storage.sql
      .exec("SELECT * FROM friend_requests WHERE from_id = ? OR to_id = ?", userId, userId)
      .toArray();
    const entitlement = this.ctx.storage.sql
      .exec("SELECT * FROM entitlements WHERE user_id = ?", userId)
      .toArray();
    const refunds = this.ctx.storage.sql
      .exec("SELECT * FROM refunds WHERE user_id = ?", userId)
      .toArray();

    this.logAudit(actorFrom(url.searchParams.get("actor")), "export", userId, "Export RGPD");

    return Response.json({
      exportedAt: new Date().toISOString(),
      note:
        "Donn\u00e9es d\u00e9tenues par le serveur Minduel. La progression d'apprentissage "
        + "reste sur l'appareil du joueur et n'est pas incluse.",
      player: row,
      friendships,
      friendRequests: requests,
      entitlement,
      refunds,
    });
  }

  private adminSetRole(body: unknown): Response {
    const p = body as { password?: string; userId?: string; role?: string; actor?: string };
    if (p.password !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const userId = p.userId ?? "";
    const row = this.adminPlayerRow(userId);
    if (!row) return Response.json({ error: "joueur introuvable" }, { status: 404 });
    if (!ADMIN_ROLES.includes(p.role as AdminRole)) {
      return Response.json({ error: "r\u00f4le inconnu" }, { status: 400 });
    }
    const role = p.role as AdminRole;
    const previous = normalizeRole(row.role);
    this.ctx.storage.sql.exec("UPDATE players SET role = ? WHERE user_id = ?", role, userId);
    // A ban also clears the matchmaking queue so the account cannot stay paired.
    if (role === "banned") {
      this.ctx.storage.sql.exec("DELETE FROM queue WHERE user_id = ?", userId);
    }
    this.logAudit(actorFrom(p.actor), "role", userId, `${previous} \u2192 ${role}`);
    return Response.json({ user: this.adminUserSummary(this.adminPlayerRow(userId)!) });
  }

  private adminSetGrantedPremium(body: unknown): Response {
    const p = body as {
      password?: string;
      userId?: string;
      grant?: boolean;
      expiresAt?: number | null;
      actor?: string;
    };
    if (p.password !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const userId = p.userId ?? "";
    if (!this.adminPlayerRow(userId)) {
      return Response.json({ error: "joueur introuvable" }, { status: 404 });
    }
    if (p.grant === true) {
      const until = typeof p.expiresAt === "number" && p.expiresAt > Date.now() ? p.expiresAt : 0;
      this.ctx.storage.sql.exec(
        "UPDATE players SET granted_premium_until = ? WHERE user_id = ?",
        until, userId,
      );
      this.logAudit(
        actorFrom(p.actor),
        "premium.grant",
        userId,
        until === 0 ? "Premium offert sans limite" : `Premium offert jusqu'au ${new Date(until).toISOString()}`,
      );
    } else {
      this.ctx.storage.sql.exec(
        "UPDATE players SET granted_premium_until = NULL WHERE user_id = ?",
        userId,
      );
      this.logAudit(actorFrom(p.actor), "premium.revoke", userId, "Premium offert retir\u00e9");
    }
    const row = this.adminPlayerRow(userId)!;
    return Response.json({ user: this.adminUserSummary(row), access: this.accessOf(userId, row) });
  }

  private adminDeleteUser(body: unknown): Response {
    const p = body as { password?: string; userId?: string; actor?: string };
    if (p.password !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const userId = p.userId ?? "";
    const row = this.adminPlayerRow(userId);
    if (!row) return Response.json({ error: "joueur introuvable" }, { status: 404 });
    // The audit line is written before deletion and deliberately keeps only the
    // account name, never the address: proof the erasure happened, without
    // re-creating the personal data that was just erased.
    this.logAudit(actorFrom(p.actor), "delete", userId, `Suppression RGPD du compte "${row.name}"`);
    return this.deleteAccount(userId);
  }

  private adminRefunds(password: string | null): Response {
    if (password !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const refunds = this.ctx.storage.sql
      .exec<RefundRow & { name: string | null }>(
        `SELECT r.*, p.name AS name FROM refunds r
         LEFT JOIN players p ON p.user_id = r.user_id
         ORDER BY r.refunded_at DESC LIMIT 200`,
      )
      .toArray()
      .map((row) => ({ ...rowToRefund(row), playerName: row.name }));
    return Response.json({ refunds });
  }

  private adminAudit(url: URL): Response {
    if (url.searchParams.get("password") !== ADMIN_PASSWORD) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? "100"), 1), 500);
    const entries = this.ctx.storage.sql
      .exec<AuditRow>("SELECT * FROM admin_audit ORDER BY id DESC LIMIT ?", limit)
      .toArray()
      .map(rowToAudit);
    return Response.json({ entries });
  }

  /**
   * RevenueCat webhook. Mirrors subscription state and records refunds, which
   * only Apple can grant \u2014 a CANCELLATION carrying a refund reason revokes
   * access immediately.
   */
  private async storeWebhook(request: Request): Promise<Response> {
    const secret = (this.env as { REVENUECAT_WEBHOOK_SECRET?: string } | undefined)
      ?.REVENUECAT_WEBHOOK_SECRET;
    // Fail closed: without a configured secret the endpoint stays inert rather
    // than accepting unauthenticated entitlement changes.
    if (!secret) {
      return Response.json({ error: "webhook non configur\u00e9" }, { status: 503 });
    }
    if (request.headers.get("Authorization") !== `Bearer ${secret}`) {
      return Response.json({ error: "non autoris\u00e9" }, { status: 401 });
    }

    const body = (await request.json().catch(() => null)) as { event?: RevenueCatEvent } | null;
    const event = body?.event;
    if (!event?.type || !event.app_user_id) {
      return Response.json({ error: "\u00e9v\u00e9nement invalide" }, { status: 400 });
    }
    const userId = event.app_user_id;
    const now = Date.now();
    const type = event.type.toUpperCase();
    const isRefund = type === "REFUND" || (type === "CANCELLATION" && event.cancel_reason === "CUSTOMER_SUPPORT");

    if (isRefund) {
      this.ctx.storage.sql.exec(
        `INSERT OR REPLACE INTO refunds
         (event_id, user_id, product_id, store, amount_cents, currency, refunded_at, reason)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        event.id ?? `${userId}-${now}`,
        userId,
        event.product_id ?? null,
        event.store ?? "APP_STORE",
        typeof event.price === "number" ? Math.round(event.price * 100) : null,
        event.currency ?? null,
        event.event_timestamp_ms ?? now,
        event.cancel_reason ?? type,
      );
      this.ctx.storage.sql.exec(
        "UPDATE entitlements SET status = 'refunded', updated_at = ? WHERE user_id = ?",
        now, userId,
      );
      this.logAudit("apple", "refund", userId, `Remboursement Apple (${event.product_id ?? "produit inconnu"})`);
      return Response.json({ ok: true, handled: "refund" });
    }

    const expired = type === "EXPIRATION";
    this.ctx.storage.sql.exec(
      `INSERT OR REPLACE INTO entitlements
       (user_id, product_id, store, status, started_at, expires_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      userId,
      event.product_id ?? null,
      event.store ?? "APP_STORE",
      expired ? "expired" : "active",
      event.purchased_at_ms ?? now,
      event.expiration_at_ms ?? null,
      now,
    );
    return Response.json({ ok: true, handled: type });
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

  // MARK: party queue (10v10 / 1v19 lobbies, called by the app)

  private partyQueueJoin(userId: string, mode: PartyMode): Response {
    this.purgePartyQueue();
    const me = this.playerRow(userId);
    if (!me) {
      return Response.json({ error: "profil introuvable" }, { status: 400 });
    }
    const existing = this.partyQueueRow(userId);
    if (existing?.match_payload) {
      return this.deliverPartyTicket(existing);
    }
    if (!existing) {
      const lobbyId = this.openLobbyFor(mode);
      this.ctx.storage.sql.exec(
        `INSERT INTO party_queue (user_id, mode, elo, lobby_id, queued_at, last_seen_at, match_payload)
         VALUES (?, ?, ?, ?, ?, ?, NULL)`,
        userId, mode, me.elo, lobbyId, Date.now(), Date.now(),
      );
      this.maybeFinalizeLobby(lobbyId);
    } else {
      this.ctx.storage.sql.exec(
        "UPDATE party_queue SET last_seen_at = ? WHERE user_id = ?",
        Date.now(), userId,
      );
      this.maybeFinalizeLobby(existing.lobby_id);
    }
    return this.partyQueuePoll(userId);
  }

  private partyQueuePoll(userId: string): Response {
    this.purgePartyQueue();
    const row = this.partyQueueRow(userId);
    if (!row) {
      return Response.json({ status: "idle" });
    }
    this.ctx.storage.sql.exec(
      "UPDATE party_queue SET last_seen_at = ? WHERE user_id = ?",
      Date.now(), userId,
    );
    if (row.match_payload) {
      return this.deliverPartyTicket(row);
    }
    this.maybeFinalizeLobby(row.lobby_id);
    const after = this.partyQueueRow(userId);
    if (after?.match_payload) {
      return this.deliverPartyTicket(after);
    }
    const lobby = this.partyLobbyRow(row.lobby_id);
    const members = this.ctx.storage.sql
      .exec<{ user_id: string }>("SELECT user_id FROM party_queue WHERE lobby_id = ?", row.lobby_id)
      .toArray()
      .map((m) => this.getProfile(m.user_id))
      .filter((p): p is PlayerProfile => p !== null);
    return Response.json({
      status: "waiting",
      lobbyId: row.lobby_id,
      mode: row.mode,
      capacity: partyCapacity(row.mode as PartyMode),
      players: members,
      waitingSince: lobby?.created_at ?? row.queued_at,
    });
  }

  private partyQueueLeave(userId: string): Response {
    const row = this.partyQueueRow(userId);
    if (!row) return Response.json({ ok: true });
    if (row.match_payload) {
      // Already handed the ticket — leaving now is a mid-game forfeit, handled
      // by the party room itself over the websocket, not through this route.
      return Response.json({ error: "la partie a déjà commencé" }, { status: 400 });
    }
    this.ctx.storage.sql.exec("DELETE FROM party_queue WHERE user_id = ?", userId);
    this.adjustReputation(userId, -PARTY_LOBBY_LEAVE_PENALTY);
    return Response.json({ ok: true });
  }

  private partyQueueRow(userId: string): PartyQueueRow | null {
    return this.ctx.storage.sql
      .exec<PartyQueueRow>("SELECT * FROM party_queue WHERE user_id = ?", userId)
      .toArray()[0] ?? null;
  }

  private partyLobbyRow(lobbyId: string): PartyLobbyRow | null {
    return this.ctx.storage.sql
      .exec<PartyLobbyRow>("SELECT * FROM party_lobbies WHERE lobby_id = ?", lobbyId)
      .toArray()[0] ?? null;
  }

  private deliverPartyTicket(row: PartyQueueRow): Response {
    this.ctx.storage.sql.exec("DELETE FROM party_queue WHERE user_id = ?", row.user_id);
    return new Response(row.match_payload, { headers: { "Content-Type": "application/json" } });
  }

  /** Finds a lobby for `mode` still filling up, or opens a fresh one. */
  private openLobbyFor(mode: PartyMode): string {
    const candidates = this.ctx.storage.sql
      .exec<PartyLobbyRow>(
        "SELECT * FROM party_lobbies WHERE mode = ? AND started = 0 ORDER BY created_at ASC",
        mode,
      )
      .toArray();
    for (const lobby of candidates) {
      const count = this.ctx.storage.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM party_queue WHERE lobby_id = ?", lobby.lobby_id)
        .toArray()[0]?.n ?? 0;
      if (count < partyCapacity(mode)) return lobby.lobby_id;
    }
    const lobbyId = crypto.randomUUID();
    this.ctx.storage.sql.exec(
      "INSERT INTO party_lobbies (lobby_id, mode, created_at, started) VALUES (?, ?, ?, 0)",
      lobbyId, mode, Date.now(),
    );
    return lobbyId;
  }

  /**
   * Fills a lobby with bots and hands out match tickets once it is full or
   * has been waiting `PARTY_FILL_MS`. Bots are generated fresh each time —
   * nothing about them is ever persisted beyond this one match.
   */
  private maybeFinalizeLobby(lobbyId: string): void {
    const lobby = this.partyLobbyRow(lobbyId);
    if (!lobby || lobby.started) return;
    const realRows = this.ctx.storage.sql
      .exec<PartyQueueRow>("SELECT * FROM party_queue WHERE lobby_id = ?", lobbyId)
      .toArray();
    if (realRows.length === 0) return;
    const age = Date.now() - lobby.created_at;
    const capacity = partyCapacity(lobby.mode as PartyMode);
    if (realRows.length < capacity && age < PARTY_FILL_MS) return;

    const realPlayers: PartyPlayer[] = realRows
      .map((r) => this.getProfile(r.user_id))
      .filter((p): p is PlayerProfile => p !== null)
      .map((p) => ({ id: p.id, name: p.name, emoji: p.emoji, elo: p.elo, isBot: false }));
    if (realPlayers.length === 0) return;

    const usedNames = new Set(realPlayers.map((p) => p.name.trim().toLowerCase()));
    const avgElo = Math.round(realPlayers.reduce((s, p) => s + p.elo, 0) / realPlayers.length);
    const botsNeeded = Math.max(0, capacity - realPlayers.length);
    const bots = generateBotRoster(botsNeeded, avgElo, usedNames, lobbyId);

    const allPlayers = shuffled([...realPlayers, ...bots]);
    if (isTeamMode(lobby.mode as PartyMode)) balanceTeams(allPlayers);

    const seed = randomSeed();
    const base = {
      status: "matched",
      partyId: lobbyId,
      mode: lobby.mode,
      seed,
      rounds: 1,
      questionsPerRound: 20,
      roundDuration: 10,
      players: allPlayers,
    };
    const now = Date.now();
    for (const row of realRows) {
      const you = allPlayers.find((p) => p.id === row.user_id);
      if (!you) continue;
      const payload = JSON.stringify({ ...base, you });
      this.ctx.storage.sql.exec(
        "UPDATE party_queue SET match_payload = ?, last_seen_at = ? WHERE user_id = ?",
        payload, now, row.user_id,
      );
    }
    this.ctx.storage.sql.exec("UPDATE party_lobbies SET started = 1 WHERE lobby_id = ?", lobbyId);
  }

  private purgePartyQueue(): void {
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "DELETE FROM party_queue WHERE match_payload IS NULL AND last_seen_at < ?",
      now - QUEUE_STALE_MS,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM party_queue WHERE match_payload IS NOT NULL AND last_seen_at < ?",
      now - PARTY_STALE_TICKET_MS,
    );
    this.ctx.storage.sql.exec(
      `DELETE FROM party_lobbies WHERE created_at < ?
         AND lobby_id NOT IN (SELECT DISTINCT lobby_id FROM party_queue)`,
      now - PARTY_STALE_TICKET_MS,
    );
  }

  /** Floored at 0, never negative — called for both lobby and mid-game exits. */
  private adjustReputation(userId: string, delta: number): void {
    this.ctx.storage.sql.exec(
      "UPDATE players SET reputation = MAX(0, reputation + ?) WHERE user_id = ?",
      delta, userId,
    );
  }

  /**
   * Settles a finished (or abandoned) party game: visible ladder points for
   * real players based on final rank/team result, plus the reputation moves
   * for finishing (and winning) or for leaving mid-game. Bots are never
   * looked up here — they simply have no matching player row.
   */
  private settleParty(body: unknown): Response {
    const payload = body as {
      partyId?: string;
      mode?: string;
      results?: Array<{ userId: string; score: number; team?: string; isBot?: boolean }>;
      leftMidGame?: string[];
    };
    const results = (payload.results ?? []).filter((r) => typeof r.userId === "string");
    const leftMidGame = new Set(payload.leftMidGame ?? []);
    const pointsChanges: Record<string, number> = {};
    const reputationChanges: Record<string, number> = {};

    if (payload.mode === "team10" || payload.mode === "duo") {
      let sumA = 0;
      let sumB = 0;
      for (const r of results) {
        if (r.team === "A") sumA += r.score;
        else if (r.team === "B") sumB += r.score;
      }
      const winner = sumA === sumB ? null : sumA > sumB ? "A" : "B";
      for (const r of results) {
        if (r.isBot || !this.playerRow(r.userId)) continue;
        if (leftMidGame.has(r.userId)) {
          this.adjustReputation(r.userId, -PARTY_MIDGAME_LEAVE_PENALTY);
          reputationChanges[r.userId] = -PARTY_MIDGAME_LEAVE_PENALTY;
          continue;
        }
        const won = winner !== null && r.team === winner;
        const pts = winner === null ? TEAM_DRAW_POINTS : won ? TEAM_WIN_POINTS : TEAM_LOSE_POINTS;
        const rep = PARTY_FINISH_REPUTATION + (won ? PARTY_WIN_REPUTATION_BONUS : 0);
        this.applyPartyResult(r.userId, pts, rep);
        pointsChanges[r.userId] = pts;
        reputationChanges[r.userId] = rep;
      }
    } else {
      const ranked = [...results].sort((a, b) => b.score - a.score);
      ranked.forEach((r, index) => {
        if (r.isBot || !this.playerRow(r.userId)) return;
        const rank = index + 1;
        if (leftMidGame.has(r.userId)) {
          this.adjustReputation(r.userId, -PARTY_MIDGAME_LEAVE_PENALTY);
          reputationChanges[r.userId] = -PARTY_MIDGAME_LEAVE_PENALTY;
          return;
        }
        const pts = partyRankPoints(rank);
        const rep = PARTY_FINISH_REPUTATION + (rank <= 3 ? PARTY_WIN_REPUTATION_BONUS : 0);
        this.applyPartyResult(r.userId, pts, rep);
        pointsChanges[r.userId] = pts;
        reputationChanges[r.userId] = rep;
      });
    }
    // Anyone who left before any score was ever reported (pure forfeit) still
    // takes the mid-game penalty even if the room settled without them.
    for (const userId of leftMidGame) {
      if (userId in reputationChanges) continue;
      if (!this.playerRow(userId)) continue;
      this.adjustReputation(userId, -PARTY_MIDGAME_LEAVE_PENALTY);
      reputationChanges[userId] = -PARTY_MIDGAME_LEAVE_PENALTY;
    }
    return Response.json({ ok: true, pointsChanges, reputationChanges });
  }

  private applyPartyResult(userId: string, pointsDelta: number, reputationDelta: number): void {
    const row = this.playerRow(userId);
    if (!row) return;
    const newPoints = clampPoints(row.points + pointsDelta);
    this.ctx.storage.sql.exec(
      "UPDATE players SET points = ?, reputation = MAX(0, reputation + ?), last_seen_at = ? WHERE user_id = ?",
      newPoints, reputationDelta, Date.now(), userId,
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

  // MARK: learning-path layout

  private getPathLayout(): Response {
    const rows = this.ctx.storage.sql
      .exec<{ json: string; version: number; updated_at: number }>(
        "SELECT json, version, updated_at FROM path_layout WHERE id = 1",
      )
      .toArray();
    if (rows.length === 0) {
      return Response.json({ published: false });
    }
    const row = rows[0]!;
    return new Response(row.json, {
      headers: {
        "Content-Type": "application/json",
        "X-Layout-Version": String(row.version),
        "X-Layout-Updated-At": String(row.updated_at),
        "Cache-Control": "public, max-age=30",
      },
    });
  }

  private publishPathLayout(body: unknown): Response {
    const payload = body as { layout?: unknown; password?: string };
    if (payload.password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    if (!payload.layout || typeof payload.layout !== "object") {
      return Response.json({ error: "Organisation invalide" }, { status: 400 });
    }
    const jsonStr = JSON.stringify(payload.layout);
    const existing = this.ctx.storage.sql
      .exec<{ version: number }>("SELECT version FROM path_layout WHERE id = 1")
      .toArray();
    const newVersion = (existing[0]?.version ?? 0) + 1;
    const now = Date.now();

    // Snapshot before overwriting so a bad reorder can always be rolled back.
    this.ctx.storage.sql.exec(
      `INSERT INTO path_layout_history (version, json, created_at) VALUES (?, ?, ?)
       ON CONFLICT(version) DO UPDATE SET json = excluded.json, created_at = excluded.created_at`,
      newVersion, jsonStr, now,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM path_layout_history WHERE version <= ?",
      newVersion - 12,
    );
    this.ctx.storage.sql.exec(
      `INSERT INTO path_layout (id, json, version, updated_at) VALUES (1, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET json = excluded.json, version = excluded.version, updated_at = excluded.updated_at`,
      jsonStr, newVersion, now,
    );
    return Response.json({ ok: true, version: newVersion, updatedAt: now });
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
    let moderatedCount = 0;
    for (const disc of content.disciplines ?? []) {
      for (const ch of disc.chapters ?? []) {
        const buckets: unknown[][] = [ch.questions ?? []];
        for (const lvl of Object.values(ch.levels ?? {})) buckets.push(lvl.questions ?? []);
        for (const bucket of buckets) {
          for (const q of bucket) {
            if ((q as { moderationStatus?: string }).moderationStatus) moderatedCount += 1;
          }
        }
      }
    }

    const existing = this.ctx.storage.sql
      .exec<{ version: number }>("SELECT version FROM content WHERE id = 1")
      .toArray();
    const newVersion = (existing[0]?.version ?? 0) + 1;
    const now = Date.now();

    // Snapshot BEFORE overwriting, so a publish that loses moderation work can
    // always be rolled back. Only the 12 most recent versions are kept.
    this.ctx.storage.sql.exec(
      `INSERT INTO content_history (version, json, question_count, moderated_count, created_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(version) DO UPDATE SET json = excluded.json, question_count = excluded.question_count, moderated_count = excluded.moderated_count, created_at = excluded.created_at`,
      newVersion, jsonStr, questionCount, moderatedCount, now,
    );
    this.ctx.storage.sql.exec(
      "DELETE FROM content_history WHERE version <= ?",
      newVersion - 12,
    );
    this.ctx.storage.sql.exec(
      `INSERT INTO content (id, json, version, question_count, updated_at) VALUES (1, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET json = excluded.json, version = excluded.version, question_count = excluded.question_count, updated_at = excluded.updated_at`,
      jsonStr, newVersion, questionCount, now,
    );
    return Response.json({
      ok: true,
      version: newVersion,
      questionCount,
      moderatedCount,
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

  /**
   * Every decision that ever left the pending queue, newest first. This is the
   * safety net: the queue itself is disposable, this is not.
   */
  private getReviewArchive(password: string | null): Response {
    if (password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const rows = this.ctx.storage.sql
      .exec<{ archive_id: number; kind: string; question_id: string; payload: string; reason: string | null; archived_at: number }>(
        "SELECT archive_id, kind, question_id, payload, reason, archived_at FROM review_state_archive ORDER BY archived_at DESC, archive_id DESC LIMIT 5000",
      )
      .toArray();
    const entries = rows.flatMap((row) => {
      try {
        return [{
          archiveId: row.archive_id,
          kind: row.kind,
          questionId: row.question_id,
          payload: JSON.parse(row.payload) as unknown,
          reason: row.reason ?? "unknown",
          archivedAt: row.archived_at,
        }];
      } catch {
        return [];
      }
    });
    return Response.json({ entries, count: entries.length });
  }

  /**
   * Puts archived decisions back into the live queue. Existing live decisions
   * always win, so restoring can never undo newer work.
   */
  private restoreReviewArchive(body: unknown): Response {
    const payload = body as { password?: string; archiveIds?: number[]; since?: number };
    if (payload.password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const ids = Array.isArray(payload.archiveIds) ? payload.archiveIds.filter((n) => Number.isFinite(n)) : [];
    const rows = ids.length > 0
      ? ids.flatMap((id) =>
          this.ctx.storage.sql
            .exec<{ kind: string; question_id: string; payload: string }>(
              "SELECT kind, question_id, payload FROM review_state_archive WHERE archive_id = ?",
              id,
            )
            .toArray(),
        )
      : this.ctx.storage.sql
          .exec<{ kind: string; question_id: string; payload: string }>(
            "SELECT kind, question_id, payload FROM review_state_archive WHERE archived_at >= ? ORDER BY archived_at ASC, archive_id ASC",
            typeof payload.since === "number" ? payload.since : 0,
          )
          .toArray();
    const now = Date.now();
    let restored = 0;
    for (const row of rows) {
      const existing = this.ctx.storage.sql
        .exec<{ n: number }>(
          "SELECT COUNT(*) AS n FROM review_state WHERE kind = ? AND question_id = ?",
          row.kind, row.question_id,
        )
        .toArray();
      if ((existing[0]?.n ?? 0) > 0) continue;
      this.ctx.storage.sql.exec(
        "INSERT INTO review_state (kind, question_id, payload, updated_at) VALUES (?, ?, ?, ?)",
        row.kind, row.question_id, row.payload, now,
      );
      restored += 1;
    }
    return Response.json({ ok: true, restored, candidates: rows.length });
  }

  private getContentHistory(password: string | null): Response {
    if (password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const rows = this.ctx.storage.sql
      .exec<{ version: number; question_count: number; moderated_count: number; created_at: number }>(
        "SELECT version, question_count, moderated_count, created_at FROM content_history ORDER BY version DESC",
      )
      .toArray();
    return Response.json({
      versions: rows.map((r) => ({
        version: r.version,
        questionCount: r.question_count,
        moderatedCount: r.moderated_count,
        createdAt: r.created_at,
      })),
    });
  }

  /** Republishes an archived version as the newest one (never rewrites history). */
  private rollbackContent(body: unknown): Response {
    const payload = body as { password?: string; version?: number };
    if (payload.password !== "minduel-admin") {
      return Response.json({ error: "Mot de passe admin requis" }, { status: 403 });
    }
    const target = this.ctx.storage.sql
      .exec<{ json: string; question_count: number }>(
        "SELECT json, question_count FROM content_history WHERE version = ?",
        payload.version ?? -1,
      )
      .toArray();
    const row = target[0];
    if (!row) return Response.json({ error: "Version introuvable" }, { status: 404 });
    return this.publishContent({ password: "minduel-admin", content: JSON.parse(row.json) as unknown });
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
      reason?: string;
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
    const reason = typeof payload.reason === "string" ? payload.reason.slice(0, 120) : "client";
    for (const d of payload.deletes ?? []) {
      if ((d.kind !== "change" && d.kind !== "note") || !d.questionId) continue;
      // Archive first — a decision leaving the queue must never be the only copy
      // that existed. This is what makes an accidental clear recoverable.
      const current = this.ctx.storage.sql
        .exec<{ payload: string }>(
          "SELECT payload FROM review_state WHERE kind = ? AND question_id = ?",
          d.kind, d.questionId,
        )
        .toArray();
      if (current[0]) {
        this.ctx.storage.sql.exec(
          "INSERT INTO review_state_archive (kind, question_id, payload, reason, archived_at) VALUES (?, ?, ?, ?, ?)",
          d.kind, d.questionId, current[0].payload, reason, now,
        );
      }
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
    reputation: row.reputation ?? 0,
    dailyGoal: row.daily_goal ?? 3,
  };
}

type PartyQueueRow = {
  user_id: string;
  mode: string;
  elo: number;
  lobby_id: string;
  queued_at: number;
  last_seen_at: number;
  match_payload: string | null;
};

type PartyLobbyRow = {
  lobby_id: string;
  mode: string;
  created_at: number;
  started: number;
};

export type PartyPlayer = {
  id: string;
  name: string;
  emoji: string;
  elo: number;
  isBot: boolean;
  team?: "A" | "B";
};

const PARTY_FINISH_REPUTATION = 1;
const PARTY_WIN_REPUTATION_BONUS = 2;
const PARTY_LOBBY_LEAVE_PENALTY = 3;
const PARTY_MIDGAME_LEAVE_PENALTY = 5;
const TEAM_WIN_POINTS = 60;
const TEAM_LOSE_POINTS = 20;
const TEAM_DRAW_POINTS = 40;

/**
 * End-of-game ladder points for the 1v19 mode: podium-heavy, then a gentle
 * linear decay so 4th place still feels meaningfully better than 20th.
 */
function partyRankPoints(rank: number): number {
  if (rank <= 0) return 0;
  if (rank === 1) return 100;
  if (rank === 2) return 70;
  if (rank === 3) return 55;
  return Math.max(10, Math.round(45 - (rank - 4) * (35 / 16)));
}

const BOT_FIRST_NAMES = [
  "Lea", "Hugo", "Emma", "Nolan", "Chloe", "Liam", "Zoe", "Adam", "Lina", "Noah",
  "Mila", "Ethan", "Rose", "Sacha", "Nina", "Leo", "Alice", "Malo", "Camille", "Theo",
  "Jade", "Enzo", "Louise", "Yanis", "Manon", "Tom", "Sarah", "Nathan", "Anna", "Jules",
];
const BOT_WORDS = [
  "Panda", "Ninja", "Tigre", "Comete", "Pixel", "Faucon", "Renard", "Loup", "Eclair",
  "Nova", "Zenith", "Cobra", "Phenix", "Atlas", "Lynx", "Orage", "Vortex", "Onyx",
];

/** A plausible player-style handle, never distinguishable from a real one. */
function generateBotName(used: Set<string>): string {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const first = BOT_FIRST_NAMES[Math.floor(Math.random() * BOT_FIRST_NAMES.length)]!;
    const candidate = Math.random() < 0.5
      ? `${first}${Math.random() < 0.7 ? Math.floor(Math.random() * 99) : ""}`
      : `${first}${BOT_WORDS[Math.floor(Math.random() * BOT_WORDS.length)]}`;
    const key = candidate.toLowerCase();
    if (!used.has(key)) {
      used.add(key);
      return candidate;
    }
  }
  const fallback = `Joueur${Math.floor(Math.random() * 9999)}`;
  used.add(fallback.toLowerCase());
  return fallback;
}

/**
 * Bots pitched around the lobby's average rating (±120), so a strong lobby's
 * bots answer better and faster than a beginner lobby's — never omniscient,
 * never perfectly on time.
 */
function generateBotRoster(
  count: number,
  avgElo: number,
  usedNames: Set<string>,
  lobbyId: string,
): PartyPlayer[] {
  const bots: PartyPlayer[] = [];
  for (let i = 0; i < count; i += 1) {
    const jitter = Math.round((Math.random() - 0.5) * 240);
    bots.push({
      id: `bot_${lobbyId}_${i}`,
      name: generateBotName(usedNames),
      emoji: EMOJIS[Math.floor(Math.random() * EMOJIS.length)] ?? "🧠",
      elo: clampElo(avgElo + jitter),
      isBot: true,
    });
  }
  return bots;
}

/** Greedy balance: strongest player always joins whichever team is behind. */
function balanceTeams(players: PartyPlayer[]): void {
  const sorted = [...players].sort((a, b) => b.elo - a.elo);
  let sumA = 0;
  let sumB = 0;
  for (const p of sorted) {
    if (sumA <= sumB) {
      p.team = "A";
      sumA += p.elo;
    } else {
      p.team = "B";
      sumB += p.elo;
    }
  }
}

function shuffled<T>(items: T[]): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j]!, copy[i]!];
  }
  return copy;
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
