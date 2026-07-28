import { ADMIN_PASSWORD } from "@/lib/reviewSync";

/**
 * Admin access rules.
 *
 * Two ways in, both landing on the same session:
 * - Google sign-in, restricted to the e-mail addresses listed below.
 * - Username + password, for when Google is unavailable.
 *
 * `ADMIN_PASSWORD` stays the shared secret the backend expects on admin API
 * routes, so once a session exists every sub-page can call the API without
 * ever asking for a password again.
 */
export const ADMIN_USERNAME = "Tiliyan";

/** Google accounts allowed to open the admin tools. Lowercase only. */
export const ALLOWED_ADMIN_EMAILS: readonly string[] = ["eliyanjacquet99@gmail.com"];

export function isEmailAllowed(email: string | undefined | null): boolean {
  if (!email) return false;
  return ALLOWED_ADMIN_EMAILS.includes(email.trim().toLowerCase());
}

export type AdminSessionMethod = "google" | "password";

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
    if (parsed.method !== "google" && parsed.method !== "password") return null;
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

/** Case-insensitive on the username, exact on the password. */
export function credentialsValid(username: string, password: string): boolean {
  return username.trim().toLowerCase() === ADMIN_USERNAME.toLowerCase() && password === ADMIN_PASSWORD;
}
