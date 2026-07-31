import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from "react";

import {
  type ChangeOrigin,
  type Deletion,
  type PendingChange,
  type Upsert,
  pushReviewState,
} from "@/lib/reviewSync";

type PendingMap = Record<string, PendingChange>;
type SyncState = "idle" | "saving" | "saved" | "error";

export const ORIGIN_LABEL: Record<ChangeOrigin | "autre", string> = {
  moderation: "modération",
  calibration: "calibrage",
  migration: "migration",
  path: "parcours",
  autre: "autre",
};

type PendingChangesContextValue = {
  /** The one queue of unpublished decisions, shared by every admin tool. */
  changes: PendingMap;
  setChanges: Dispatch<SetStateAction<PendingMap>>;
  /** Merges the server-persisted queue in (server wins on conflict) and turns
   * on live sync. Safe to call from several pages mounting at once. */
  hydrate: (serverChanges: PendingMap, localBackup?: PendingMap) => void;
  syncState: SyncState;
  lastSavedAt: number | null;
  counts: { total: number; byOrigin: Partial<Record<ChangeOrigin | "autre", number>> };
  /** "8 calibrage · 45 modération" — empty string when the queue is empty. */
  breakdownLabel: string;
};

const PendingChangesContext = createContext<PendingChangesContextValue | null>(null);

/**
 * Single source of truth for unpublished admin decisions.
 *
 * Modération and Calibrage both write into the same server-side queue; before
 * this provider each page kept its own stale copy, so the publish button could
 * say "8" and silently publish 53. Mounted once in the admin layout, every
 * page now sees the same queue, the same counter, and one sync loop.
 */
export const PendingChangesProvider = ({ children }: { children: ReactNode }) => {
  const [changes, setChanges] = useState<PendingMap>({});
  const [syncState, setSyncState] = useState<SyncState>("idle");
  const [lastSavedAt, setLastSavedAt] = useState<number | null>(null);
  const [retryTick, setRetryTick] = useState(0);
  const lastSynced = useRef<PendingMap>({});
  const syncEnabled = useRef(false);

  const hydrate = useCallback((serverChanges: PendingMap, localBackup?: PendingMap) => {
    lastSynced.current = { ...lastSynced.current, ...serverChanges };
    syncEnabled.current = true;
    // Server wins on conflict; in-memory and local-backup entries the server
    // doesn't know yet are kept and re-pushed by the sync loop below.
    setChanges((prev) => ({ ...(localBackup ?? {}), ...prev, ...serverChanges }));
  }, []);

  // Live diff sync: every decision reaches the server within ~1 s, deletions
  // included (the backend archives anything removed, so nothing is ever lost).
  useEffect(() => {
    if (!syncEnabled.current) return;
    const t = setTimeout(async () => {
      const upserts: Upsert[] = [];
      const deletes: Deletion[] = [];
      for (const [id, ch] of Object.entries(changes)) {
        const prev = lastSynced.current[id];
        if (!prev || JSON.stringify(prev) !== JSON.stringify(ch)) {
          upserts.push({ kind: "change", questionId: id, payload: ch });
        }
      }
      for (const id of Object.keys(lastSynced.current)) {
        if (!(id in changes)) deletes.push({ kind: "change", questionId: id });
      }
      if (upserts.length === 0 && deletes.length === 0) return;
      setSyncState("saving");
      try {
        await pushReviewState(upserts, deletes, "admin-shared-sync");
        lastSynced.current = changes;
        setSyncState("saved");
        setLastSavedAt(Date.now());
      } catch {
        setSyncState("error");
        window.setTimeout(() => setRetryTick((n) => n + 1), 10000);
      }
    }, 800);
    return () => clearTimeout(t);
  }, [changes, retryTick]);

  const counts = useMemo(() => {
    const byOrigin: Partial<Record<ChangeOrigin | "autre", number>> = {};
    for (const ch of Object.values(changes)) {
      const key = ch.origin ?? "autre";
      byOrigin[key] = (byOrigin[key] ?? 0) + 1;
    }
    return { total: Object.keys(changes).length, byOrigin };
  }, [changes]);

  const breakdownLabel = useMemo(() => {
    const parts = Object.entries(counts.byOrigin)
      .filter(([, n]) => n > 0)
      .map(([origin, n]) => `${n} ${ORIGIN_LABEL[origin as ChangeOrigin | "autre"]}`);
    return parts.length > 1 ? parts.join(" · ") : "";
  }, [counts]);

  const value = useMemo(
    () => ({ changes, setChanges, hydrate, syncState, lastSavedAt, counts, breakdownLabel }),
    [changes, hydrate, syncState, lastSavedAt, counts, breakdownLabel],
  );

  return <PendingChangesContext.Provider value={value}>{children}</PendingChangesContext.Provider>;
};

export function usePendingChanges(): PendingChangesContextValue {
  const ctx = useContext(PendingChangesContext);
  if (!ctx) throw new Error("usePendingChanges must be used within PendingChangesProvider");
  return ctx;
}
