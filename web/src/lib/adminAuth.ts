/**
 * Admin access rules.
 *
 * Signing in (Google, allowed accounts checked server-side) only
 * unlocks the admin *pages* in this browser. Talking to the backend admin API
 * additionally requires the `ADMIN_API_KEY` secret, entered once and stored
 * locally on this machine (see `adminAuthHeaders` below) — the web bundle
 * never embeds it, so it can never leak through the published site's source.
 */
export const ADMIN_USERNAME = "Tiliyan";

/** The allow-list lives exclusively in the server's ADMIN_ALLOWED_EMAILS environment variable. */
export async function checkAdminAccess(signal?: AbortSignal): Promise<boolean> {
  const base = (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined)
    ?? (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined)
    ?? "https://mindduel-kqfozex-backend.rork.app";
  const token = localStorage.getItem("rork:access_token");
  if (!token) return false;
  const response = await fetch(`${base}/api/admin/access`, {
    headers: { Authorization: `Bearer ${token}` }, signal,
  });
  if (!response.ok) throw new Error("Impossible de vérifier l’accès administrateur. Réessaie.");
  const body = await response.json() as { allowed?: boolean };
  return body.allowed === true;
}

export type AdminSessionMethod = "google";

export interface AdminSession {
  method: AdminSessionMethod;
  /** Display name shown in the admin header. */
  label: string;
  grantedAt: number;
}

const SESSION_KEY = "minduel:admin_session";
const SESSION_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

export function loadAdminSession(): AdminSession | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<AdminSession>;
    if (parsed.method !== "google") return null;
    if (typeof parsed.grantedAt !== "number") return null;
    if (Date.now() - parsed.grantedAt > SESSION_MAX_AGE_MS) {
      localStorage.removeItem(SESSION_KEY);
      return null;
    }
    return {
      method: parsed.method,
      label: typeof parsed.label === "string" && parsed.label ? parsed.label : ADMIN_USERNAME,
      grantedAt: parsed.grantedAt,
    };
  } catch {
    return null;
  }
}

export function saveAdminSession(session: AdminSession): void {
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  } catch (err) {
    console.warn("Impossible de mémoriser la session admin", err);
  }
}

export function clearAdminSession(): void {
  try {
    localStorage.removeItem(SESSION_KEY);
  } catch {
    /* ignore */
  }
}

// MARK: backend admin key
//
// The key that guards every /api/admin/*, /api/content/publish,
// /api/path-layout POST, /api/review/*, /api/stats/questions and
// /api/admin/images route server-side. Entered once per browser (see
// `AdminLogin`'s "Clé API" field) and kept only in this browser's
// localStorage — it is never hardcoded, never bundled, and never sent to
// any place other than this project's own backend.
const API_KEY_STORAGE_KEY = "minduel:admin_api_key";

export function loadAdminApiKey(): string {
  try {
    return localStorage.getItem(API_KEY_STORAGE_KEY) ?? "";
  } catch {
    return "";
  }
}

export function saveAdminApiKey(key: string): void {
  try {
    localStorage.setItem(API_KEY_STORAGE_KEY, key.trim());
  } catch {
    /* ignore */
  }
}

export function clearAdminApiKey(): void {
  try {
    localStorage.removeItem(API_KEY_STORAGE_KEY);
  } catch {
    /* ignore */
  }
}

/** `Authorization: Bearer <key>` header for every admin API call. */
export function adminAuthHeaders(): Record<string, string> {
  const key = loadAdminApiKey();
  return key ? { Authorization: `Bearer ${key}` } : {};
}
