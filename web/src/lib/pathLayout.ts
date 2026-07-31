// Learning-path organisation shared by the admin "Parcours" tool and the app.
//
// This file is the TypeScript twin of the Swift `RingBuilder` / `PathLayout`.
// Both must build the exact same rings from the same catalog, otherwise the
// admin preview would lie about what players actually see. Keep them in sync.

import type { Chapter, Content, Discipline, Question } from "./generator";

export const ADMIN_PASSWORD = "minduel-admin";

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

/** Questions per ring. */
export const RING_SIZE = 15;
/** A trailing group smaller than this is merged into the previous ring. */
export const MIN_TRAILING_RING = 6;

/** Difficulty buckets, easiest first — mirrors Swift's `DifficultyLevel`. */
export const LEVEL_ORDER = ["facile", "intermediaire", "difficile", "maitre", "legende"] as const;

export type RingKind = "normal" | "recap";

export type RingSlot = {
  kind: RingKind;
  /** Index of the default normal ring this slot plays. Absent for recaps. */
  source?: number;
};

export type PathLayout = {
  disciplineOrder: string[];
  /** disciplineId → ordered chapter ids. */
  chapterOrder: Record<string, string[]>;
  /** chapterId → explicit ring timeline. */
  ringLayout: Record<string, RingSlot[]>;
};

export const EMPTY_LAYOUT: PathLayout = {
  disciplineOrder: [],
  chapterOrder: {},
  ringLayout: {},
};

/** Built-in ordering: History is chronological, the rest goes from the most
 * familiar/concrete to the most specialised. Mirrors Swift's `PathDefaults`. */
export const DEFAULT_DISCIPLINE_ORDER: string[] = [
  "histoire", "geographie", "sciences", "litterature",
  "arts", "nature", "technologie", "football",
];

export const DEFAULT_CHAPTER_ORDER: Record<string, string[]> = {
  histoire: [
    "histoire_antiquite", "histoire_moyen_age", "histoire_decouvertes",
    "histoire_revolution", "histoire_guerres_mondiales",
  ],
  geographie: [
    "geo_france", "geo_europe", "geo_capitales", "geo_oceans_continents",
    "geo_amerique", "geo_asie", "geo_afrique", "geo_fleuves_montagnes",
    "geo_climats",
  ],
  sciences: [
    "sciences_systeme_solaire", "sciences_terre", "sciences_corps_humain",
    "sciences_evolution", "sciences_genetique", "sciences_chimie",
    "sciences_atome", "sciences_energie", "sciences_gravite",
  ],
  litterature: [
    "litt_theatre_antique", "litt_contes_legendes", "litt_ecrivains",
    "litt_poesie_theatre", "litt_heros", "litt_femmes_ecrivaines",
    "litt_prix_litteraires", "litt_contemporaine", "litt_bd_comics",
  ],
  arts: [
    "arts_peinture", "arts_monuments", "arts_musique", "arts_instruments",
    "arts_opera", "arts_danse", "arts_photographie", "arts_cinema",
    "arts_mode_design",
  ],
  nature: [
    "nature_animaux_domestiques", "nature_mammiferes", "nature_oiseaux",
    "nature_ocean", "nature_reptiles_amphibiens", "nature_insectes",
    "nature_plantes", "nature_ecosystemes", "nature_records",
    "nature_dinosaures",
  ],
  technologie: [
    "tech_inventions", "tech_espace", "tech_telescopes_astronomie",
    "tech_informatique", "tech_internet_reseaux", "tech_jeux_video",
    "tech_robots_ia", "tech_medecine", "tech_energie_environnement",
  ],
  football: [
    "football_cm_internationaux", "football_euro_2024", "football_ligue1",
    "football_pl_2023_2025", "football_liga_seriea", "football_cdm_2023_2025",
    "football_ballon_or", "football_transferts", "football_stars_records",
  ],
};

export function defaultLayout(): PathLayout {
  return {
    disciplineOrder: [...DEFAULT_DISCIPLINE_ORDER],
    chapterOrder: Object.fromEntries(
      Object.entries(DEFAULT_CHAPTER_ORDER).map(([k, v]) => [k, [...v]]),
    ),
    ringLayout: {},
  };
}

/** Reorders `values` to match `order`, keeping unknown ids at the end in their
 * original position. Never drops or duplicates an entry. */
export function applyOrder<T>(order: string[], values: T[], id: (v: T) => string): T[] {
  if (order.length === 0) return values;
  const rank = new Map(order.map((v, i) => [v, i]));
  return values
    .map((value, offset) => ({ value, offset }))
    .sort((a, b) => {
      const l = rank.get(id(a.value)) ?? Number.MAX_SAFE_INTEGER;
      const r = rank.get(id(b.value)) ?? Number.MAX_SAFE_INTEGER;
      return l === r ? a.offset - b.offset : l - r;
    })
    .map((entry) => entry.value);
}

// MARK: - Ring building

export type RingTier = "decouverte" | "solide" | "pointu";

export const TIER_LABEL: Record<RingTier, string> = {
  decouverte: "Découverte",
  solide: "Solide",
  pointu: "Pointu",
};

/** Rank of a familiarity level on the easy → hard axis. */
function familiarityRank(q: Question): number {
  switch (q.familiarity) {
    case "commun": return 0;
    case "pointu": return 2;
    default: return 1;
  }
}

function tierFrom(questions: Question[]): RingTier {
  if (questions.length === 0) return "decouverte";
  const avg = questions.reduce((sum, q) => sum + familiarityRank(q), 0) / questions.length;
  if (avg < 0.67) return "decouverte";
  if (avg < 1.34) return "solide";
  return "pointu";
}

function notRejected(q: Question): boolean {
  return q.moderationStatus !== "rejected";
}

/** All questions of a chapter, easiest first. Difficulty bucket wins, then how
 * well-known the fact is; equal difficulty keeps the authored order. */
export function orderedQuestions(chapter: Chapter): Question[] {
  const ranked: { question: Question; level: number; fam: number; offset: number }[] = [];
  let offset = 0;
  LEVEL_ORDER.forEach((level, levelIndex) => {
    for (const q of chapter.levels?.[level]?.questions ?? []) {
      if (!notRejected(q)) continue;
      ranked.push({ question: q, level: levelIndex, fam: familiarityRank(q), offset: offset++ });
    }
  });
  // Legacy flat chapters have no levels at all.
  if (ranked.length === 0) {
    for (const q of chapter.questions ?? []) {
      if (!notRejected(q)) continue;
      ranked.push({ question: q, level: 0, fam: familiarityRank(q), offset: offset++ });
    }
  }
  return ranked
    .sort((a, b) => (a.level - b.level) || (a.fam - b.fam) || (a.offset - b.offset))
    .map((r) => r.question);
}

function chunk(questions: Question[]): Question[][] {
  if (questions.length === 0) return [];
  const chunks: Question[][] = [];
  for (let start = 0; start < questions.length; start += RING_SIZE) {
    chunks.push(questions.slice(start, Math.min(start + RING_SIZE, questions.length)));
  }
  const last = chunks[chunks.length - 1];
  if (last && last.length < MIN_TRAILING_RING && chunks.length >= 2) {
    chunks[chunks.length - 2]!.push(...last);
    chunks.pop();
  }
  return chunks;
}

/** Default timeline: every normal ring in ramp order, closed by one recap. */
export function defaultSlots(normalRingCount: number): RingSlot[] {
  const slots: RingSlot[] = Array.from({ length: normalRingCount }, (_, i) => ({
    kind: "normal" as const,
    source: i,
  }));
  slots.push({ kind: "recap" });
  return slots;
}

/** Keeps a saved timeline safe: drops slots pointing at rings that no longer
 * exist, appends rings the layout predates, guarantees a closing recap. */
export function normalizeSlots(slots: RingSlot[] | undefined, normalRingCount: number): RingSlot[] {
  if (!slots || slots.length === 0) return defaultSlots(normalRingCount);
  const seen = new Set<number>();
  const cleaned: RingSlot[] = [];
  for (const slot of slots) {
    if (slot.kind === "normal") {
      const source = slot.source;
      if (source === undefined || source < 0 || source >= normalRingCount || seen.has(source)) continue;
      seen.add(source);
      cleaned.push(slot);
    } else {
      cleaned.push(slot);
    }
  }
  const missing: RingSlot[] = [];
  for (let i = 0; i < normalRingCount; i++) {
    if (!seen.has(i)) missing.push({ kind: "normal", source: i });
  }
  if (missing.length > 0) {
    const lastRecap = cleaned.map((s) => s.kind).lastIndexOf("recap");
    const insertAt = lastRecap === -1 ? cleaned.length : lastRecap;
    cleaned.splice(insertAt, 0, ...missing);
  }
  if (!cleaned.some((s) => s.kind === "recap")) cleaned.push({ kind: "recap" });
  return cleaned;
}

export type PreviewRing = {
  id: string;
  disciplineId: string;
  chapterId: string;
  chapterTitle: string;
  kind: RingKind;
  /** 1-based label position among the chapter's normal rings. */
  position: number;
  tier: RingTier;
  questions: Question[];
  /** Recap rings show a pool, not a fixed set — the player gets 15 of these. */
  isPool: boolean;
};

/** Builds the rings of one sub-chapter exactly like the app does. */
export function buildRings(
  chapter: Chapter,
  disciplineId: string,
  slots: RingSlot[] | undefined,
): PreviewRing[] {
  const ordered = orderedQuestions(chapter);
  if (ordered.length === 0) return [];
  const groups = chunk(ordered);
  const recapPool = [...ordered].reverse();
  const timeline = normalizeSlots(slots, groups.length);

  const rings: PreviewRing[] = [];
  let normalCounter = 0;
  let recapCounter = 0;
  for (const slot of timeline) {
    if (slot.kind === "normal") {
      const source = slot.source;
      if (source === undefined || !groups[source]) continue;
      const questions = groups[source]!;
      rings.push({
        id: `ring-${chapter.id}-${source}`,
        disciplineId,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        kind: "normal",
        position: normalCounter + 1,
        tier: tierFrom(questions),
        questions,
        isPool: false,
      });
      normalCounter += 1;
    } else {
      const suffix = recapCounter === 0 ? "" : `-${recapCounter}`;
      rings.push({
        id: `recap-${chapter.id}${suffix}`,
        disciplineId,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        kind: "recap",
        position: normalCounter,
        tier: "pointu",
        questions: recapPool,
        isPool: true,
      });
      recapCounter += 1;
    }
  }
  return rings;
}

/** Ordered chapters of a discipline under a given layout. */
export function orderedChapters(discipline: Discipline, layout: PathLayout): Chapter[] {
  const order = layout.chapterOrder[discipline.id] ?? DEFAULT_CHAPTER_ORDER[discipline.id] ?? [];
  return applyOrder(order, discipline.chapters, (c) => c.id);
}

/** Ordered disciplines under a given layout. */
export function orderedDisciplines(content: Content, layout: PathLayout): Discipline[] {
  const order = layout.disciplineOrder.length > 0 ? layout.disciplineOrder : DEFAULT_DISCIPLINE_ORDER;
  return applyOrder(order, content.disciplines, (d) => d.id);
}

/** Every ring of a discipline, in path order. */
export function disciplineRings(discipline: Discipline, layout: PathLayout): PreviewRing[] {
  return orderedChapters(discipline, layout).flatMap((chapter) =>
    buildRings(chapter, discipline.id, layout.ringLayout[chapter.id]),
  );
}

/**
 * The mixed path: one ring per discipline in rotation, favourites visited
 * twice per lap. Mirrors `AppModel.rebuildMixedRings`.
 */
export function mixedRings(
  content: Content,
  layout: PathLayout,
  preferredDisciplineIds: string[] = [],
): PreviewRing[] {
  const disciplines = orderedDisciplines(content, layout);
  const queues = new Map<string, PreviewRing[]>();
  for (const d of disciplines) queues.set(d.id, disciplineRings(d, layout));

  const lap = disciplines.map((d) => d.id);
  for (const id of preferredDisciplineIds) {
    if ((queues.get(id)?.length ?? 0) > 0) lap.push(id);
  }

  const merged: PreviewRing[] = [];
  let guard = 0;
  while ([...queues.values()].some((q) => q.length > 0) && guard < 100_000) {
    for (const id of lap) {
      const queue = queues.get(id);
      if (!queue || queue.length === 0) continue;
      merged.push(queue.shift()!);
      guard += 1;
    }
  }
  return merged;
}

// MARK: - Persistence

export async function fetchPathLayout(): Promise<PathLayout> {
  const res = await fetch(`${FN_URL}/api/path-layout`, { cache: "no-store" });
  if (!res.ok) throw new Error(`serveur ${res.status}`);
  const data = (await res.json()) as Partial<PathLayout> & { published?: boolean };
  if (data.published === false) return defaultLayout();
  return {
    disciplineOrder: data.disciplineOrder ?? [],
    chapterOrder: data.chapterOrder ?? {},
    ringLayout: data.ringLayout ?? {},
  };
}

export async function publishPathLayout(layout: PathLayout): Promise<{ version: number }> {
  const res = await fetch(`${FN_URL}/api/path-layout`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password: ADMIN_PASSWORD, layout }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(text.slice(0, 200));
  }
  return (await res.json()) as { version: number };
}

/** Moves an item inside an array, returning a new array. */
export function moveItem<T>(items: T[], from: number, to: number): T[] {
  if (from === to || from < 0 || to < 0 || from >= items.length || to >= items.length) return items;
  const next = [...items];
  const [moved] = next.splice(from, 1);
  if (moved === undefined) return items;
  next.splice(to, 0, moved);
  return next;
}
