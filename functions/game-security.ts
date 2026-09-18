/** Deterministic counterpart of iOS MatchQuestionPicker (including legacy pool rules). */
export type GameQuestion = { id: string; answer: string; type: string; moderationStatus?: string; [key: string]: unknown };
type Chapter = { levels?: Record<string, { questions: GameQuestion[] }>; questions?: GameQuestion[] };
export type GameCatalog = { disciplines: { id: string; kind?: string; chapters: Chapter[] }[] };
const levels = ["facile", "intermediaire", "difficile", "maitre", "legende"];

export function pickQuestions(catalog: GameCatalog, seed: string, count: number, rawThemes: string[], elo: number): GameQuestion[] {
  const themes = [...new Set(rawThemes.filter(Boolean))].sort();
  if (!themes.length) themes.push("all");
  const allowed = elo < 1100 ? levels.slice(0, 2) : elo < 1400 ? levels.slice(0, 3) : elo < 1800 ? levels.slice(1, 4) : levels.slice(2);
  const mask = (1n << 64n) - 1n;
  let state = BigInt(seed);
  const next = (): bigint => {
    state = (state + 0x9E3779B97F4A7C15n) & mask;
    let z = state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & mask;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & mask;
    return z ^ (z >> 31n);
  };
  const shuffle = (items: GameQuestion[]): GameQuestion[] => {
    for (let i = items.length - 1; i > 0; i--) {
      const j = Number(next() % BigInt(i + 1));
      [items[i], items[j]] = [items[j]!, items[i]!];
    }
    return items;
  };
  const pool = (theme: string, restricted: boolean, basic = false): GameQuestion[] => {
    const result: GameQuestion[] = [];
    for (const d of catalog.disciplines) {
      if (basic ? ((d.kind ?? "generale") !== "generale" || themes.includes(d.id)) : (theme !== "all" && d.id !== theme)) continue;
      for (const c of d.chapters) {
        // Match older clients exactly: their level-restricted branch predates rejection filtering.
        const qs = c.levels
          ? (restricted ? allowed : levels).flatMap(l => c.levels?.[l]?.questions ?? [])
          : c.questions ?? [];
        result.push(...qs.filter(q => q.type !== "anagram" && ((c.levels && restricted) || q.moderationStatus !== "rejected")));
      }
    }
    return result.sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  };
  const used = new Set<string>();
  const pick = (source: GameQuestion[], n: number): GameQuestion[] => {
    const out: GameQuestion[] = [];
    for (const q of source) {
      if (out.length >= n) break;
      if (!used.has(q.id)) { used.add(q.id); out.push(q); }
    }
    return out;
  };
  const bucket = (theme: string, n: number, basic = false): GameQuestion[] => {
    let qs = pool(theme, true, basic);
    if (qs.length < n) qs = pool(theme, false, basic);
    return shuffle(qs);
  };
  let buckets: GameQuestion[][];
  if (themes.length === 2 && !themes.includes("all")) {
    const n = Math.floor(count / 3) + (count % 3 > 0 ? 1 : 0);
    const b = Math.floor(count / 3);
    const aPool = bucket(themes[0]!, n);
    const bPool = bucket(themes[1]!, n);
    const basicPool = bucket("all", b, true);
    buckets = [pick(aPool, n), pick(bPool, n), pick(basicPool, b)];
    count = 2 * n + b;
  } else {
    buckets = themes.map((theme, i) => {
      const n = Math.floor(count / themes.length) + (i < count % themes.length ? 1 : 0);
      return pick(bucket(theme, n), n);
    });
  }
  const result: GameQuestion[] = [];
  for (let i = 0; result.length < count && buckets.some(b => i < b.length); i++) {
    for (const b of buckets) if (b[i] && result.length < count) result.push(b[i]!);
  }
  if (result.length < count) result.push(...pick(shuffle(pool("all", false)), count - result.length));
  return result;
}

/** Never accepts correctness or timing claimed by the client. */
export function verifyAnswer(question: GameQuestion | undefined, answer: unknown, startedAt: number | undefined, receivedAt: number, durationMs: number): { correct: boolean; timeMs: number; reason?: string } {
  const elapsed = startedAt === undefined ? durationMs : Math.max(0, receivedAt - startedAt);
  const timeMs = Math.min(elapsed, durationMs);
  if (startedAt !== undefined && elapsed < 300) return { correct: false, timeMs, reason: "answer_too_fast" };
  if (elapsed > durationMs + 1200) return { correct: false, timeMs, reason: "answer_too_late" };
  if (!question) return { correct: false, timeMs, reason: "question_unavailable" };
  if (typeof answer !== "string" || answer.length > 2000 || !answer.trim()) return { correct: false, timeMs, reason: "missing_or_invalid_answer" };
  const key = (s: string): string => s.normalize("NFD").replace(/\p{M}/gu, "").trim().toLocaleLowerCase("fr-FR");
  return { correct: key(answer) === key(question.answer), timeMs };
}

export type VersionEnvironment = { MIN_APP_VERSION?: string; MIN_PARTY_VERSION?: string };
export function versionAtLeast(version: string | null, minimum: string): boolean {
  const valid = (v: string): boolean => /^\d{1,6}\.\d{1,6}\.\d{1,6}$/.test(v);
  if (!version || !valid(version) || !valid(minimum)) return false;
  const a = version.split(".").map(Number), b = minimum.split(".").map(Number);
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i]! > b[i]!;
  return true;
}
export function appConfig(env: VersionEnvironment): { min_version: string; min_version_party: string } {
  return { min_version: env.MIN_APP_VERSION ?? "1.0.0", min_version_party: env.MIN_PARTY_VERSION ?? "1.0.0" };
}
export function partyUpdateRequired(): Response {
  return Response.json({ error: "Mets à jour Minduel pour jouer en groupe.", code: "party_update_required" }, { status: 426 });
}

/** Internal calls cannot be routed through the public worker entrypoint. */
export async function hubCall(env: { DO: Fetcher }, path: string, body: unknown): Promise<Response> {
  return env.DO.fetch(new Request(`https://internal/internal/${path}`, {
    method: "POST", headers: { "Content-Type": "application/json", "X-Rork-DO-Class": "Hub", "X-Rork-DO-Id": "global" }, body: JSON.stringify(body),
  }));
}
export async function flagAnswer(env: { DO: Fetcher }, userId: string, matchId: string, index: number, reason: string): Promise<void> {
  try {
    const response = await hubCall(env, "cheat-flag", { userId, matchId, index, reason });
    if (!response.ok) console.error("cheat flag persistence failed", response.status);
  } catch { console.error("cheat flag persistence unavailable"); }
}
