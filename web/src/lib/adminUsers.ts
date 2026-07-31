// adminUsers.ts — back-office client for account administration.
//
// Every call is password-protected server-side. Roles and offered premium are
// admin-only concepts: the app never sets them. A *purchased* subscription is
// never exposed as a role, because confusing a gift with a paid subscription
// would produce wrong billing decisions.

import { ADMIN_PASSWORD } from "./reviewSync";

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

export const ADMIN_ROLES = ["standard", "beta", "premium", "admin", "banned"] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

export const ROLE_LABELS: Record<AdminRole, string> = {
  standard: "Standard",
  beta: "Bêta-testeur",
  premium: "Premium offert",
  admin: "Admin",
  banned: "Banni",
};

export const ROLE_HELP: Record<AdminRole, string> = {
  standard: "Accès normal à l'application.",
  beta: "Testeur TestFlight — accès complet et retours attendus.",
  premium: "Accès complet offert manuellement, sans paiement.",
  admin: "Peut ouvrir le back-office.",
  banned: "Compte suspendu : plus aucun accès en ligne, données conservées.",
};

export interface AdminUserSummary {
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
}

export interface AccessState {
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
}

export interface RefundEntry {
  eventId: string;
  userId: string;
  productId: string | null;
  store: string | null;
  amountCents: number | null;
  currency: string | null;
  refundedAt: number;
  reason: string | null;
  playerName?: string | null;
}

export interface AuditEntry {
  id: number;
  at: number;
  actor: string;
  action: string;
  targetUser: string | null;
  detail: string | null;
}

export interface UsersPage {
  users: AdminUserSummary[];
  total: number;
  totalPlayers: number;
  roleCounts: Record<string, number>;
  activeSevenDays: number;
  premiumCount: number;
}

export interface UserDetail {
  user: AdminUserSummary;
  access: AccessState;
  friends: number;
  refunds: RefundEntry[];
  audit: AuditEntry[];
  queued: number;
}

export interface UserFilters {
  search?: string;
  role?: AdminRole | "all";
  inactiveDays?: number;
}

async function readJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? `serveur ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function fetchUsers(filters: UserFilters = {}): Promise<UsersPage> {
  const params = new URLSearchParams({ password: ADMIN_PASSWORD });
  if (filters.search) params.set("search", filters.search);
  if (filters.role && filters.role !== "all") params.set("role", filters.role);
  if (filters.inactiveDays && filters.inactiveDays > 0) {
    params.set("inactiveDays", String(filters.inactiveDays));
  }
  return readJson<UsersPage>(
    await fetch(`${FN_URL}/api/admin/users?${params.toString()}`, { cache: "no-store" }),
  );
}

export async function fetchUserDetail(userId: string): Promise<UserDetail> {
  const params = new URLSearchParams({ password: ADMIN_PASSWORD, userId });
  return readJson<UserDetail>(
    await fetch(`${FN_URL}/api/admin/users/detail?${params.toString()}`, { cache: "no-store" }),
  );
}

export async function setUserRole(
  userId: string,
  role: AdminRole,
  actor: string,
): Promise<AdminUserSummary> {
  const data = await readJson<{ user: AdminUserSummary }>(
    await fetch(`${FN_URL}/api/admin/users/role`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password: ADMIN_PASSWORD, userId, role, actor }),
    }),
  );
  return data.user;
}

/** `expiresAt` null grants unlimited access; ignored when revoking. */
export async function setGrantedPremium(
  userId: string,
  grant: boolean,
  actor: string,
  expiresAt: number | null = null,
): Promise<{ user: AdminUserSummary; access: AccessState }> {
  return readJson<{ user: AdminUserSummary; access: AccessState }>(
    await fetch(`${FN_URL}/api/admin/users/premium`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password: ADMIN_PASSWORD, userId, grant, expiresAt, actor }),
    }),
  );
}

export async function deleteUserAccount(userId: string, actor: string): Promise<void> {
  await readJson<{ ok: boolean }>(
    await fetch(`${FN_URL}/api/admin/users/delete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password: ADMIN_PASSWORD, userId, actor }),
    }),
  );
}

/** GDPR portability export — returns the raw server record for one person. */
export async function exportUserData(userId: string, actor: string): Promise<unknown> {
  const params = new URLSearchParams({ password: ADMIN_PASSWORD, userId, actor });
  return readJson<unknown>(
    await fetch(`${FN_URL}/api/admin/users/export?${params.toString()}`, { cache: "no-store" }),
  );
}

export async function fetchRefunds(): Promise<RefundEntry[]> {
  const params = new URLSearchParams({ password: ADMIN_PASSWORD });
  const data = await readJson<{ refunds: RefundEntry[] }>(
    await fetch(`${FN_URL}/api/admin/refunds?${params.toString()}`, { cache: "no-store" }),
  );
  return data.refunds;
}

export async function fetchAudit(limit = 100): Promise<AuditEntry[]> {
  const params = new URLSearchParams({ password: ADMIN_PASSWORD, limit: String(limit) });
  const data = await readJson<{ entries: AuditEntry[] }>(
    await fetch(`${FN_URL}/api/admin/audit?${params.toString()}`, { cache: "no-store" }),
  );
  return data.entries;
}

// MARK: presentation helpers

/** Compact "il y a ..." label; absolute dates below the day are unhelpful here. */
export function relativeTime(timestamp: number): string {
  if (!timestamp) return "jamais";
  const diff = Date.now() - timestamp;
  if (diff < 60_000) return "à l'instant";
  const minutes = Math.floor(diff / 60_000);
  if (minutes < 60) return `il y a ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `il y a ${hours} h`;
  const days = Math.floor(hours / 24);
  if (days < 31) return `il y a ${days} j`;
  const months = Math.floor(days / 30);
  if (months < 12) return `il y a ${months} mois`;
  return `il y a ${Math.floor(months / 12)} an${months >= 24 ? "s" : ""}`;
}

export function formatDate(timestamp: number): string {
  if (!timestamp) return "—";
  return new Date(timestamp).toLocaleDateString("fr-FR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function formatAmount(cents: number | null, currency: string | null): string {
  if (cents === null) return "montant inconnu";
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: currency ?? "EUR",
  }).format(cents / 100);
}

/** Human label for an audit action code. */
export function auditLabel(action: string): string {
  switch (action) {
    case "role":
      return "Changement de rôle";
    case "premium.grant":
      return "Premium offert";
    case "premium.revoke":
      return "Premium retiré";
    case "delete":
      return "Compte supprimé";
    case "export":
      return "Export RGPD";
    case "refund":
      return "Remboursement Apple";
    default:
      return action;
  }
}
