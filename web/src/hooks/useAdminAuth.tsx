import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

import { useAuth } from "@/hooks/useAuth";
import { useQuery } from "@tanstack/react-query";
import {
  clearAdminApiKey,
  clearAdminSession,
  checkAdminAccess,
  loadAdminApiKey,
  saveAdminApiKey,
  saveAdminSession,
  type AdminSession,
} from "@/lib/adminAuth";

interface AdminAuthContextType {
  session: AdminSession | null;
  /** True while the stored session is being restored on first paint. */
  isRestoring: boolean;
  /** Non-null when a Google account signed in but is not on the allow-list. */
  rejectedEmail: string | null;
  accessError: string | null;
  retryAccess: () => void;
  /** The backend admin API key stored in this browser, if any. */
  apiKey: string;
  setApiKey: (key: string) => void;
  signOutAdmin: () => void;
}

const AdminAuthContext = createContext<AdminAuthContextType | null>(null);

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const { user, isLoading: authLoading, signOut: signOutRork } = useAuth();
  const access = useQuery({
    queryKey: ["admin-access", user?.id],
    queryFn: ({ signal }) => checkAdminAccess(signal),
    enabled: !!user,
    retry: 1,
    staleTime: 0,
  });
  const [session, setSession] = useState<AdminSession | null>(null);
  const [isRestoring, setIsRestoring] = useState<boolean>(true);
  const [rejectedEmail, setRejectedEmail] = useState<string | null>(null);
  const [apiKey, setApiKeyState] = useState<string>("");

  useEffect(() => {
    clearAdminSession();
    setApiKeyState(loadAdminApiKey());
    setIsRestoring(false);
  }, []);

  // A Google sign-in only becomes an admin session if the e-mail is allowed.
  useEffect(() => {
    if (!user || access.data === undefined || access.isError) { setSession(null); return; }
    if (access.data) {
      setRejectedEmail(null);
      setSession((prev) => {
        if (prev?.method === "google" && prev.label === user.email) return prev;
        const next: AdminSession = { method: "google", label: user.email, grantedAt: Date.now() };
        saveAdminSession(next);
        return next;
      });
    } else {
      setRejectedEmail(user.email || "compte inconnu");
      clearAdminSession();
      setSession(null);
      signOutRork();
    }
  }, [user, signOutRork, access.data, access.isError]);

  const setApiKey = useCallback((key: string) => {
    saveAdminApiKey(key);
    setApiKeyState(key.trim());
  }, []);

  const signOutAdmin = useCallback(() => {
    clearAdminSession();
    clearAdminApiKey();
    setApiKeyState("");
    setSession(null);
    setRejectedEmail(null);
    signOutRork();
  }, [signOutRork]);

  const value = useMemo<AdminAuthContextType>(
    () => ({ session: user && access.data === true && !access.isError ? session : null,
      isRestoring: isRestoring || authLoading || (!!user && access.isLoading), rejectedEmail,
      accessError: access.isError ? "Impossible de vérifier l’accès administrateur. Réessaie." : null,
      retryAccess: () => { void access.refetch(); }, apiKey, setApiKey, signOutAdmin }),
    [session, user, access.data, access.isError, access.isLoading, access.refetch, authLoading, isRestoring, rejectedEmail, apiKey, setApiKey, signOutAdmin],
  );

  return <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>;
}

export function useAdminAuth(): AdminAuthContextType {
  const context = useContext(AdminAuthContext);
  if (!context) throw new Error("useAdminAuth must be used within AdminAuthProvider");
  return context;
}
