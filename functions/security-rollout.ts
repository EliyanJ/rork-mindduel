/** Set immediately before the first security deployment. Never extend this deadline on later deployments. */
export const LEGACY_DEADLINE_MS = 0;

/** Compatibility is limited to already-persisted, already-started rooms, never client init payloads. */
export function isLegacyExpired(state: { questions?: unknown[]; phase: string }, now = Date.now()): boolean {
  return !state.questions && state.phase !== "finished" && (now >= LEGACY_DEADLINE_MS || state.phase === "waiting");
}

/** Only used by the bounded, explicitly approved legacy drain. New games never call this. */
export function legacyAnswer(correct: unknown, time: unknown, duration: number): { correct: boolean; timeMs: number; reason?: string } {
  return { correct: correct === true, timeMs: typeof time === "number" && Number.isFinite(time) ? Math.max(0, Math.min(duration, time)) : duration };
}
