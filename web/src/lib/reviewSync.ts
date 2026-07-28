// reviewSync.ts — shared persistence for admin decisions.
//
// Both admin tools (question review and difficulty calibration) write into the
// same server-side decision store, keyed by question id. That is deliberate:
// there is exactly one queue of unpublished changes and one publish path, so a
// difficulty decision and a moderation decision can never silently overwrite
// each other, and either tool can publish the combined result.

import {
  type Content,
  type Question,
  fetchContent,
} from "./generator";
import { deleteQuestion, moveQuestion, resolveRef, updateQuestion, type QuestionRef } from "./moderation";

export const ADMIN_PASSWORD = "minduel-admin";

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

/**
 * A single unpublished decision.
 * - `question: null` deletes the question.
 * - `moveTo` re-files it under another theme/tier (replayed as delete+insert).
 * - otherwise the stored question replaces the existing one in place.
 */
export type PendingChange = {
  ref: QuestionRef;
  question: Question | null;
  moveTo?: QuestionRef;
};

export type ReviewState = {
  changes: Record<string, PendingChange>;
  notes: Record<string, unknown>;
};

export async function fetchReviewState(): Promise<ReviewState> {
  const res = await fetch(
    `${FN_URL}/api/review/state?password=${encodeURIComponent(ADMIN_PASSWORD)}`,
    { cache: "no-store" },
  );
  if (!res.ok) throw new Error(`serveur ${res.status}`);
  const data = (await res.json()) as Partial<ReviewState>;
  return { changes: data.changes ?? {}, notes: data.notes ?? {} };
}

export type Upsert = { kind: "change" | "note"; questionId: string; payload: unknown };
export type Deletion = { kind: "change" | "note"; questionId: string };

export async function pushReviewState(
  upserts: Upsert[],
  deletes: Deletion[],
  reason = "client",
): Promise<void> {
  if (upserts.length === 0 && deletes.length === 0) return;
  const res = await fetch(`${FN_URL}/api/review/state`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: ADMIN_PASSWORD, upserts, deletes, reason }),
  });
  if (!res.ok) throw new Error(`serveur ${res.status}`);
}

export type ArchiveEntry = {
  archiveId: number;
  kind: "change" | "note";
  questionId: string;
  payload: unknown;
  reason: string;
  archivedAt: number;
};

/** Every decision that ever left the pending queue — the recovery source. */
export async function fetchReviewArchive(): Promise<ArchiveEntry[]> {
  const res = await fetch(
    `${FN_URL}/api/review/archive?password=${encodeURIComponent(ADMIN_PASSWORD)}`,
    { cache: "no-store" },
  );
  if (!res.ok) throw new Error(`serveur ${res.status}`);
  const data = (await res.json()) as { entries?: ArchiveEntry[] };
  return data.entries ?? [];
}

/** Puts archived decisions back in the queue. Live decisions always win. */
export async function restoreReviewArchive(
  archiveIds?: number[],
): Promise<{ restored: number; candidates: number }> {
  const res = await fetch(`${FN_URL}/api/review/archive/restore`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: ADMIN_PASSWORD, archiveIds }),
  });
  if (!res.ok) throw new Error(`serveur ${res.status}`);
  const data = (await res.json()) as { restored?: number; candidates?: number };
  return { restored: data.restored ?? 0, candidates: data.candidates ?? 0 };
}

export type ContentVersion = {
  version: number;
  questionCount: number;
  moderatedCount: number;
  createdAt: number;
};

export async function fetchContentHistory(): Promise<ContentVersion[]> {
  const res = await fetch(
    `${FN_URL}/api/content/history?password=${encodeURIComponent(ADMIN_PASSWORD)}`,
    { cache: "no-store" },
  );
  if (!res.ok) throw new Error(`serveur ${res.status}`);
  const data = (await res.json()) as { versions?: ContentVersion[] };
  return data.versions ?? [];
}

/** Republishes an earlier snapshot as the newest version. */
export async function rollbackContent(version: number): Promise<{ version: number }> {
  const res = await fetch(`${FN_URL}/api/content/rollback`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: ADMIN_PASSWORD, version }),
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(body.error ?? `serveur ${res.status}`);
  }
  const data = (await res.json()) as { version?: number };
  return { version: data.version ?? version };
}

/**
 * Replays decisions on top of a content snapshot. Used both to rebuild the
 * working copy on load and to merge onto the freshest server content at publish
 * time — so publishing can never clobber questions changed elsewhere meanwhile.
 */
export function replayChanges(
  base: Content,
  changes: Record<string, PendingChange>,
): { merged: Content; applied: number; skipped: number; appliedIds: string[]; skippedIds: string[] } {
  let merged = base;
  const appliedIds: string[] = [];
  const skippedIds: string[] = [];
  for (const [questionId, change] of Object.entries(changes)) {
    const before = merged;
    // The stored ref may be stale (ids are positional), so re-resolve where the
    // question lives now instead of dropping the decision.
    const located = resolveRef(merged, change.ref, questionId, change.question?.prompt);
    const ref = located?.ref ?? change.ref;
    const id = located?.questionId ?? questionId;
    if (change.question === null) {
      merged = deleteQuestion(merged, ref, id);
    } else if (change.moveTo) {
      merged = moveQuestion(merged, ref, change.moveTo, id, change.question);
    } else {
      merged = updateQuestion(merged, ref, id, () => change.question as Question);
    }
    if (merged === before) skippedIds.push(questionId);
    else appliedIds.push(questionId);
  }
  return { merged, applied: appliedIds.length, skipped: skippedIds.length, appliedIds, skippedIds };
}

/**
 * Publishes the pending decisions: re-reads the live content, replays every
 * decision onto it, and pushes the result. Returns what the server recorded.
 */
export async function publishPendingChanges(
  changes: Record<string, PendingChange>,
): Promise<{
  version: number;
  questionCount: number;
  applied: number;
  skipped: number;
  appliedIds: string[];
  skippedIds: string[];
}> {
  const freshest = await fetchContent();
  const { merged, applied, skipped, appliedIds, skippedIds } = replayChanges(freshest, changes);
  const res = await fetch(`${FN_URL}/api/content/publish`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: ADMIN_PASSWORD, content: merged }),
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(body.error ?? `Publication refusée (${res.status})`);
  }
  const data = (await res.json()) as { version?: number; questionCount?: number };
  return {
    version: data.version ?? 0,
    questionCount: data.questionCount ?? 0,
    applied,
    skipped,
    appliedIds,
    skippedIds,
  };
}
