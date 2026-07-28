import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";

const AUTH_URL = (import.meta.env.EXPO_PUBLIC_RORK_AUTH_URL as string | undefined) ?? "https://auth.rork.com";
const APP_KEY = import.meta.env.EXPO_PUBLIC_RORK_APP_KEY as string | undefined;

const ACCESS_TOKEN_KEY = "rork:access_token";
const REFRESH_TOKEN_KEY = "rork:refresh_token";
const CODE_VERIFIER_KEY = "rork:pkce_verifier";

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function generateCodeVerifier(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

async function generateCodeChallenge(verifier: string): Promise<string> {
  const data = new TextEncoder().encode(verifier);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return base64Url(new Uint8Array(hash));
}

export interface AuthUser {
  id: string;
  email: string;
  name?: string;
  picture?: string;
}

interface TokenPayload {
  sub?: string;
  email?: string;
  name?: string;
  picture?: string;
  exp?: number;
}

/** Decode the JWT payload to extract user info and check expiration. */
function userFromToken(token: string): AuthUser | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(base64)) as TokenPayload;
    if (payload.exp && payload.exp * 1000 < Date.now()) return null;
    if (!payload.sub) return null;
    return {
      id: payload.sub,
      email: payload.email ?? "",
      name: payload.name,
      picture: payload.picture,
    };
  } catch {
    return null;
  }
}

interface AuthContextType {
  user: AuthUser | null;
  isLoading: boolean;
  isSigningIn: boolean;
  error: string | null;
  signIn: (provider: "google" | "apple") => Promise<void>;
  signOut: () => void;
  clearError: () => void;
  /** Exchanges an OAuth `code` for tokens (used by the /auth/callback route). */
  exchangeCode: (code: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSigningIn, setIsSigningIn] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const messageListenerRef = useRef<((event: MessageEvent) => void) | null>(null);

  const clearError = useCallback(() => setError(null), []);

  const signOut = useCallback(() => {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(CODE_VERIFIER_KEY);
    setUser(null);
  }, []);

  const refreshToken = useCallback(async () => {
    const stored = localStorage.getItem(REFRESH_TOKEN_KEY);
    if (!stored || !APP_KEY) {
      signOut();
      return;
    }
    const response = await fetch(`${AUTH_URL}/oauth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ app_key: APP_KEY, refresh_token: stored }),
    });
    if (!response.ok) {
      signOut();
      return;
    }
    const data = (await response.json()) as { access_token?: string };
    if (!data.access_token) {
      signOut();
      return;
    }
    localStorage.setItem(ACCESS_TOKEN_KEY, data.access_token);
    setUser(userFromToken(data.access_token));
  }, [signOut]);

  const exchangeCode = useCallback(async (code: string) => {
    const verifier = localStorage.getItem(CODE_VERIFIER_KEY);
    if (!verifier || !APP_KEY) {
      setError("Session de connexion expirée — réessaie.");
      return;
    }
    localStorage.removeItem(CODE_VERIFIER_KEY);

    const response = await fetch(`${AUTH_URL}/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ app_key: APP_KEY, code, code_verifier: verifier }),
    });

    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as { error?: string };
      setError(body.error ?? `Connexion échouée (${response.status})`);
      return;
    }

    const data = (await response.json()) as {
      access_token: string;
      refresh_token: string;
      user?: AuthUser;
    };
    localStorage.setItem(ACCESS_TOKEN_KEY, data.access_token);
    localStorage.setItem(REFRESH_TOKEN_KEY, data.refresh_token);
    setUser(data.user ?? userFromToken(data.access_token));
  }, []);

  useEffect(() => {
    const run = async () => {
      try {
        const accessToken = localStorage.getItem(ACCESS_TOKEN_KEY);
        if (accessToken) {
          const decoded = userFromToken(accessToken);
          if (decoded) {
            setUser(decoded);
            return;
          }
        }
        if (localStorage.getItem(REFRESH_TOKEN_KEY)) {
          await refreshToken();
        }
      } finally {
        setIsLoading(false);
      }
    };
    void run();
  }, [refreshToken]);

  useEffect(
    () => () => {
      if (messageListenerRef.current) {
        window.removeEventListener("message", messageListenerRef.current);
        messageListenerRef.current = null;
      }
    },
    [],
  );

  const signIn = useCallback(
    async (provider: "google" | "apple") => {
      if (!APP_KEY) {
        setError("Connexion Google indisponible (configuration manquante).");
        return;
      }
      setIsSigningIn(true);
      setError(null);
      try {
        const verifier = generateCodeVerifier();
        const challenge = await generateCodeChallenge(verifier);
        localStorage.setItem(CODE_VERIFIER_KEY, verifier);

        const isPreview = window.parent !== window;
        const body: Record<string, unknown> = {
          app_key: APP_KEY,
          provider,
          code_challenge: challenge,
          target: "web",
          env: isPreview ? "preview" : "production",
        };
        if (isPreview) body.app_path = "web";

        const response = await fetch(`${AUTH_URL}/oauth/initiate`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });

        if (!response.ok) {
          localStorage.removeItem(CODE_VERIFIER_KEY);
          const errorBody = (await response.json().catch(() => ({}))) as { error?: string };
          setError(errorBody.error ?? `Connexion échouée (${response.status})`);
          return;
        }

        const { auth_url: authUrl } = (await response.json()) as { auth_url: string };

        if (isPreview) {
          const popup = window.open(authUrl, "_blank", "width=500,height=650");
          if (!popup) {
            setError("Fenêtre bloquée — autorise les pop-ups pour ce site.");
            localStorage.removeItem(CODE_VERIFIER_KEY);
            return;
          }
          await new Promise<void>((resolve) => {
            const onMessage = (event: MessageEvent) => {
              const payload = event.data as { type?: string; code?: string } | undefined;
              if (payload?.type !== "rork_auth_callback") return;
              window.removeEventListener("message", onMessage);
              messageListenerRef.current = null;
              clearInterval(pollTimer);
              if (payload.code) {
                void exchangeCode(payload.code).finally(() => resolve());
              } else {
                resolve();
              }
            };
            messageListenerRef.current = onMessage;
            window.addEventListener("message", onMessage);

            const pollTimer = setInterval(() => {
              if (popup.closed) {
                clearInterval(pollTimer);
                window.removeEventListener("message", onMessage);
                messageListenerRef.current = null;
                localStorage.removeItem(CODE_VERIFIER_KEY);
                resolve();
              }
            }, 500);
          });
        } else {
          window.location.href = authUrl;
        }
      } catch (err) {
        console.error("Sign in failed:", err);
        setError(err instanceof Error ? err.message : "Connexion échouée");
        localStorage.removeItem(CODE_VERIFIER_KEY);
      } finally {
        setIsSigningIn(false);
      }
    },
    [exchangeCode],
  );

  return (
    <AuthContext.Provider value={{ user, isLoading, isSigningIn, error, signIn, signOut, clearError, exchangeCode }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}
