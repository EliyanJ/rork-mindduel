import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

import { useAuth } from "@/hooks/useAuth";
import {
  clearAdminSession,
  credentialsValid,
  isEmailAllowed,
  loadAdminSession,
  saveAdminSession,
  type AdminSession,
} from "@/lib/adminAuth";

interface AdminAuthContextType {
  session: AdminSession | null;
  /** True while the stored session is being restored on first paint. */
  isRestoring: boolean;
  /** Non-null when a Google account signed in but is not on the allow-list. */
  rejectedEmail: string | null;
  signInWithCredentials: (username: string, password: string) => boolean;
  signOutAdmin: () => void;
}

const AdminAuthContext = createContext<AdminAuthContextType | null>(null);

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const { user, signOut: signOutRork } = useAuth();
  const [session, setSession] = useState<AdminSession | null>(null);
  const [isRestoring, setIsRestoring] = useState<boolean>(true);
  const [rejectedEmail, setRejectedEmail] = useState<string | null>(null);

  useEffect(() => {
    setSession(loadAdminSession());
    setIsRestoring(false);
  }, []);

  // A Google sign-in only becomes an admin session if the e-mail is allowed.
  useEffect(() => {
    if (!user) return;
    if (isEmailAllowed(user.email)) {
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
  }, [user, signOutRork]);

  const signInWithCredentials = useCallback((username: string, password: string): boolean => {
    if (!credentialsValid(username, password)) return false;
    const next: AdminSession = { method: "password", label: username.trim(), grantedAt: Date.now() };
    saveAdminSession(next);
    setSession(next);
    setRejectedEmail(null);
    return true;
  }, []);

  const signOutAdmin = useCallback(() => {
    clearAdminSession();
    setSession(null);
    setRejectedEmail(null);
    signOutRork();
  }, [signOutRork]);

  const value = useMemo<AdminAuthContextType>(
    () => ({ session, isRestoring, rejectedEmail, signInWithCredentials, signOutAdmin }),
    [session, isRestoring, rejectedEmail, signInWithCredentials, signOutAdmin],
  );

  return <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>;
}

export function useAdminAuth(): AdminAuthContextType {
  const context = useContext(AdminAuthContext);
  if (!context) throw new Error("useAdminAuth must be used within AdminAuthProvider");
  return context;
}
