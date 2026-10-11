/**
 * Editorial exclusions: the app does not carry any content about the theory
 * of the evolution of species. Applied to every published catalogue, every
 * archived version and the learning-path layout, so nothing can come back
 * through a republish or a rollback.
 */

const EXCLUDED_CHAPTERS = new Set(["sciences_evolution"]);
const EXCLUDED_QUESTIONS = new Set(["sc_ge_3", "nature_oiseaux_f_31", "na_di_f_9", "na_di_f_19", "nature_dinosaures_f_23"]);
const EXPLANATION_FIXES: Record<string, string> = {
  na_di_f_3: "Les dinosaures avaient disparu depuis très longtemps quand les premiers humains sont arrivés sur Terre : ils n'ont jamais vécu à la même époque.",
};
const OPTION_FIXES: Record<string, [string, string]> = {
  sc_ge_2: ["Charles Darwin et Gregor Mendel", "Isaac Newton et Gregor Mendel"],
  sciences_genetique_f_42: ["Évolution", "Photosynthèse"],
};
const FORBIDDEN = new RegExp(
  [
    "darwin", "s[ée]lection naturelle", "origine des esp[eè]ces", "[ée]volution des esp[eè]ces", "th[ée]orie de l.[ée]volution",
    "ancêtres? commun", "parent[ée] [ée]volutive", "hominid", "hominin", "n[ée]andert", "australopith", "cha[iî]non manquant",
    "maillon manquant", "fossile de transition", "lamarck", "sp[ée]ciation", "ancêtres? des oiseaux", "ancêtres? de l.homme",
    "descend(ent)? (du|des) (singe|chimpanz)",
  ].join("|"),
  "i",
);

type Question = { id?: string; prompt?: string; answer?: string; explanation?: string; options?: string[] };
type Chapter = { id?: string; questions?: Question[]; levels?: Record<string, { questions?: Question[] }> };
type Catalogue = { disciplines?: Array<{ chapters?: Chapter[] }> };

function cleanQuestions(list: Question[] | undefined): Question[] | undefined {
  if (!Array.isArray(list)) return list;
  const kept: Question[] = [];
  for (const q of list) {
    const id = q.id ?? "";
    if (EXPLANATION_FIXES[id]) q.explanation = EXPLANATION_FIXES[id];
    const optionFix = OPTION_FIXES[id];
    if (optionFix && Array.isArray(q.options)) q.options = q.options.map((o) => (o === optionFix[0] ? optionFix[1] : o));
    const text = [q.prompt, q.answer, q.explanation, ...(q.options ?? [])].filter(Boolean).join(" | ");
    if (EXCLUDED_QUESTIONS.has(id) || FORBIDDEN.test(text)) continue;
    kept.push(q);
  }
  return kept;
}

/** Returns the catalogue without any excluded chapter or question (mutates in place). */
export function stripExcludedContent<T>(content: T): T {
  const catalogue = content as Catalogue;
  for (const discipline of catalogue.disciplines ?? []) {
    discipline.chapters = (discipline.chapters ?? []).filter((c) => !EXCLUDED_CHAPTERS.has(c.id ?? ""));
    for (const chapter of discipline.chapters) {
      if (chapter.questions) chapter.questions = cleanQuestions(chapter.questions);
      for (const level of Object.values(chapter.levels ?? {})) {
        if (level.questions) level.questions = cleanQuestions(level.questions);
      }
    }
  }
  return content;
}

/** Removes excluded chapters from a learning-path layout (mutates in place). */
export function stripExcludedLayout<T>(layout: T): T {
  const value = layout as { chapterOrder?: Record<string, string[]> };
  for (const [key, ids] of Object.entries(value.chapterOrder ?? {})) {
    if (Array.isArray(ids)) value.chapterOrder![key] = ids.filter((id) => !EXCLUDED_CHAPTERS.has(id));
  }
  return layout;
}

/** Number of questions in a catalogue, matching the publish counter. */
export function countQuestions(content: unknown): number {
  let total = 0;
  for (const discipline of (content as Catalogue).disciplines ?? []) {
    for (const chapter of discipline.chapters ?? []) {
      total += chapter.questions?.length ?? 0;
      for (const level of Object.values(chapter.levels ?? {})) total += level.questions?.length ?? 0;
    }
  }
  return total;
}
