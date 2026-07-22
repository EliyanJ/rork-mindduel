// generator.ts — Minduel question generation engine (client-side).
// Calls the Rork AI proxy directly (toolkit secret is a public env var),
// validates/auto-corrects the JSON output, merges into the content structure,
// and detects/plans chapters that need more questions (including bulk runs).

export type QuestionType = "multipleChoice" | "trueFalse" | "fillBlank" | "anagram";

/** How well-known a fact is, so a level never mixes trivia that's too obscure for its audience. */
export type Familiarity = "commun" | "moyen" | "pointu";

export const FAMILIARITY_LABEL: Record<Familiarity, string> = {
  commun: "Connu de tous",
  moyen: "Culture moyenne",
  pointu: "Pointu / expert",
};

/** Moderation lifecycle for a question — defaults to "pending" when absent
 * (all pre-existing questions start untouched, nothing is auto-approved). */
export type ModerationStatus = "pending" | "approved" | "rejected";
export type ModeratedBy = "human" | "ai";

export type Question = {
  id: string;
  type: QuestionType;
  prompt: string;
  options?: string[];
  answer: string;
  explanation: string;
  /** Optional for backward-compat with old content.json entries that predate this field. */
  familiarity?: Familiarity;
  /** Moderation metadata written by the admin review tool. Absent = pending. */
  moderationStatus?: ModerationStatus;
  moderatedBy?: ModeratedBy;
  moderatedAt?: number;
};

export type Level = {
  questions: Question[];
};

export type Chapter = {
  id: string;
  title: string;
  levels?: Record<string, Level>;
  questions?: Question[]; // legacy format
};

/** Whether a discipline is general culture or a specific domain (e.g. football).
 * Used by matchmaking and the diagnostic to weight theme selection. */
export type DisciplineKind = "generale" | "specifique";

export type Discipline = {
  id: string;
  name: string;
  icon: string;
  colorHex: string;
  chapters: Chapter[];
  /** Optional for backward-compat with older content.json entries that predate this field. */
  kind?: DisciplineKind;
};

export type Content = {
  disciplines: Discipline[];
};

export type LogEntry = {
  time: string;
  level: "info" | "success" | "warn" | "error";
  message: string;
};

export type GenTarget = {
  disciplineId: string;
  disciplineName: string;
  chapterId: string;
  chapterTitle: string;
  level: string; // "facile" | "intermediaire" | "difficile" | "maitre" | "legende" | "legacy"
  count: number;
  /** Whether the discipline is general culture or a specific domain (e.g. football).
   * Drives the familiarity mix: generale -> 40/40/20, specifique -> 0/50/50. */
  kind?: DisciplineKind;
};

export type GenResult = {
  target: GenTarget;
  questions: Question[];
  ok: boolean;
  error?: string;
  rejectedReasons?: string[];
};

const TOOLKIT_URL = import.meta.env.VITE_TOOLKIT_URL ?? import.meta.env.EXPO_PUBLIC_TOOLKIT_URL;
const SECRET_KEY = import.meta.env.VITE_RORK_TOOLKIT_SECRET_KEY ?? import.meta.env.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY;
const MODEL_ID = "openai/gpt-4o-mini";
const TARGET_PER_LEVEL = 20;
const COST_PER_QUESTION_USD = 0.0008; // ~500 tokens output at $0.60/M + 300 input at $0.15/M
/** Max questions requested per single AI call — smaller batches = far fewer JSON/format errors. */
const DEFAULT_BATCH_SIZE = 8;

/** Fetch the current content.json from the public folder. */
export async function fetchContent(): Promise<Content> {
  const res = await fetch("/content.json");
  if (!res.ok) throw new Error(`content.json fetch failed: ${res.status}`);
  return (await res.json()) as Content;
}

/** Count questions in a chapter, handling both legacy and new formats. */
export function countQuestions(chapter: Chapter, level?: string): number {
  if (chapter.questions) return chapter.questions.length;
  if (chapter.levels) {
    if (level && chapter.levels[level]) return chapter.levels[level].questions.length;
    return Object.values(chapter.levels).reduce((sum, l) => sum + l.questions.length, 0);
  }
  return 0;
}

/** Check if a chapter uses the legacy flat-questions format (no levels). */
export function isLegacyChapter(chapter: Chapter): boolean {
  return !chapter.levels && Array.isArray(chapter.questions);
}

/** Map a difficulty level name to the single-letter id suffix used in question ids. */
function levelLetter(level: string): string {
  const l = level.toLowerCase();
  if (l.startsWith("f") || l === "legacy") return "f";
  if (l.startsWith("i") || l.startsWith("moy")) return "i";
  if (l.startsWith("d")) return "d";
  if (l.startsWith("m")) return "m";
  if (l.startsWith("l") && l !== "legacy") return "l";
  return "f";
}

/**
 * Target familiarity mix per difficulty level — this is what keeps a "facile"
 * level from suddenly throwing an obscure expert-only fact at a casual player.
 * Expressed as a human-readable instruction injected straight into the prompt.
 */
function familiarityGuidance(level: string): string {
  const letter = levelLetter(level);
  switch (letter) {
    case "f":
      return `Niveau FACILE: uniquement des faits "commun" (connus du grand public, ecole primaire/college) - AUCUNE question "pointu". Un adulte moyen doit connaitre la reponse ou pouvoir la deduire facilement.`;
    case "i":
      return `Niveau INTERMEDIAIRE: majorite "commun"/"moyen" (culture generale de lycee/adulte cultive), au maximum 1 question "pointu" sur ${DEFAULT_BATCH_SIZE}.`;
    case "d":
      return `Niveau DIFFICILE: majorite "moyen", quelques "pointu" acceptees - evite le pur trivia de specialiste.`;
    case "m":
      return `Niveau MAITRE: melange "moyen"/"pointu", peut inclure des faits moins connus mais toujours verifiables et interessants.`;
    case "l":
      return `Niveau LEGENDE: majorite "pointu" (faits rares, precis, reserves aux passionnes/experts du sujet), mais restent 100% verifiables et non anecdotiques inutiles.`;
    default:
      return `Adapte la difficulte au niveau "${level}".`;
  }
}

/** Split a "needed" count into chunks of at most maxBatch, as separate GenTargets. */
function pushChunked(
  targets: GenTarget[],
  base: Omit<GenTarget, "count">,
  needed: number,
  maxBatch: number,
): void {
  let left = needed;
  while (left > 0) {
    const count = Math.min(maxBatch, left);
    targets.push({ ...base, count });
    left -= count;
  }
}

/**
 * Auto-detect chapters that need generation.
 * Flags: legacy chapters (5 Q, no levels) and chapters with < 20 questions per level.
 * Splits large needs into batches of `maxBatch` for higher per-call reliability.
 */
export function detectIncomplete(content: Content, maxBatch: number = DEFAULT_BATCH_SIZE): GenTarget[] {
  const targets: GenTarget[] = [];
  for (const disc of content.disciplines) {
    for (const ch of disc.chapters) {
      if (isLegacyChapter(ch)) {
        const current = ch.questions?.length ?? 0;
        const needed = TARGET_PER_LEVEL - current;
        if (needed > 0) {
          pushChunked(
            targets,
            { disciplineId: disc.id, disciplineName: disc.name, chapterId: ch.id, chapterTitle: ch.title, level: "facile", kind: disc.kind },
            needed,
            maxBatch,
          );
        }
      } else if (ch.levels) {
        for (const [lvlName, lvl] of Object.entries(ch.levels)) {
          const needed = TARGET_PER_LEVEL - lvl.questions.length;
          if (needed > 0) {
            pushChunked(
              targets,
              { disciplineId: disc.id, disciplineName: disc.name, chapterId: ch.id, chapterTitle: ch.title, level: lvlName, kind: disc.kind },
              needed,
              maxBatch,
            );
          }
        }
      }
    }
  }
  return targets;
}

/**
 * Plan a bulk run of exactly (up to) `totalCount` questions.
 * Priority 1: fill incomplete chapters/levels first (chunked).
 * Priority 2: if that's not enough to reach totalCount, keep cycling through
 * every chapter/level adding extra batches beyond the normal target — this is
 * what allows "generate 600 questions" to never stop early even once every
 * chapter is already at 20/20.
 */
export function planBulkTargets(content: Content, totalCount: number, maxBatch: number = DEFAULT_BATCH_SIZE): GenTarget[] {
  const targets: GenTarget[] = [];
  let remaining = totalCount;

  const incomplete = detectIncomplete(content, maxBatch);
  for (const t of incomplete) {
    if (remaining <= 0) break;
    const count = Math.min(t.count, remaining);
    targets.push({ ...t, count });
    remaining -= count;
  }

  if (remaining > 0) {
    const allLevels: Omit<GenTarget, "count">[] = [];
    for (const disc of content.disciplines) {
      for (const ch of disc.chapters) {
        if (isLegacyChapter(ch)) {
          allLevels.push({ disciplineId: disc.id, disciplineName: disc.name, chapterId: ch.id, chapterTitle: ch.title, level: "facile", kind: disc.kind });
        } else if (ch.levels) {
          for (const lvlName of Object.keys(ch.levels)) {
            allLevels.push({ disciplineId: disc.id, disciplineName: disc.name, chapterId: ch.id, chapterTitle: ch.title, level: lvlName, kind: disc.kind });
          }
        }
      }
    }
    let i = 0;
    let safety = 0;
    while (remaining > 0 && allLevels.length > 0 && safety < 100000) {
      const base = allLevels[i % allLevels.length];
      const count = Math.min(maxBatch, remaining);
      targets.push({ ...base, count });
      remaining -= count;
      i += 1;
      safety += 1;
    }
  }

  return targets;
}

/** Build a summary of all chapters and their question counts. */
export function contentSummary(content: Content): Array<{
  discipline: string;
  chapter: string;
  level: string;
  current: number;
  target: number;
  complete: boolean;
}> {
  const rows: Array<{ discipline: string; chapter: string; level: string; current: number; target: number; complete: boolean }> = [];
  for (const disc of content.disciplines) {
    for (const ch of disc.chapters) {
      if (isLegacyChapter(ch)) {
        const current = ch.questions?.length ?? 0;
        rows.push({ discipline: disc.name, chapter: ch.title, level: "legacy", current, target: TARGET_PER_LEVEL, complete: current >= TARGET_PER_LEVEL });
      } else if (ch.levels) {
        for (const [lvlName, lvl] of Object.entries(ch.levels)) {
          rows.push({ discipline: disc.name, chapter: ch.title, level: lvlName, current: lvl.questions.length, target: TARGET_PER_LEVEL, complete: lvl.questions.length >= TARGET_PER_LEVEL });
        }
      }
    }
  }
  return rows;
}

/** Build the AI prompt for a generation target, injecting existing questions to avoid duplicates. */
function buildPrompt(target: GenTarget, existing: Question[]): string {
  const existingPrompts = existing.map((q) => `- ${q.prompt}`).join("\n");
  const typeDistribution = `Répartis les types ainsi: ~40% multipleChoice, ~25% trueFalse, ~20% fillBlank, ~15% anagram.`;
  const isSpecifique = target.kind === "specifique";
  const familiarityMix = isSpecifique
    ? `Discipline SPÉCIFIQUE (${target.disciplineName}): vise 0% "commun", ~50% "moyen", ~50% "pointu". Aucune question "commun" — le public cible est déjà passionné par le sujet.`
    : `Discipline GÉNÉRALE: vise ~40% "commun", ~40% "moyen", ~20% "pointu".`;

  return `Tu es un générateur de questions de culture générale pour une app éducative française appelée Minduel.

Génère EXACTEMENT ${target.count} questions sur le sujet: "${target.chapterTitle}" (discipline: ${target.disciplineName}, niveau: ${target.level}).

CONTRAINTES:
- Les questions doivent être en français, factuelles et vérifiables.
- Le niveau de difficulté est "${target.level}" — adapté à un public de culture générale.
- Évite les doublons avec ces questions existantes déjà présentes:
${existingPrompts || "(aucune)"}

${typeDistribution}

CALIBRAGE DE FAMILIARITÉ (TRÈS IMPORTANT — évite les questions hasardeuses hors sujet du niveau):
Chaque question doit avoir un champ "familiarity" indiquant à quel point le fait est connu:
- "commun": fait connu du grand public, évident pour la majorité des gens.
- "moyen": culture générale correcte, pas évident mais pas obscur.
- "pointu": fait de spécialiste/passionné, précis et pointu.
${familiarityMix}
${familiarityGuidance(target.level)}
Ne mélange JAMAIS un fait "pointu" complètement hors du niveau demandé — la cohérence de familiarité au sein du niveau est essentielle.

FORMATS PAR TYPE (NE PAS inclure de champ "id", il est généré automatiquement):
- multipleChoice: { "type": "multipleChoice", "prompt": "...", "options": ["A","B","C","D"], "answer": "B", "explanation": "...", "familiarity": "commun" }
- trueFalse: { "type": "trueFalse", "prompt": "...", "answer": "Vrai", "explanation": "...", "familiarity": "moyen" }  (answer est "Vrai" ou "Faux")
- fillBlank: { "type": "fillBlank", "prompt": "Le ___ est...", "options": ["X","Y","Z","W"], "answer": "X", "explanation": "...", "familiarity": "commun" }
- anagram: { "type": "anagram", "prompt": "Indice: ...", "answer": "motmajuscule", "explanation": "...", "familiarity": "moyen" }  (un seul mot, pas d'options)

RÈGLES IMPORTANTES:
- multipleChoice et fillBlank: exactement 4 options, la valeur "answer" doit être IDENTIQUE (texte exact) à l'une des 4 options.
- trueFalse: answer doit être exactement "Vrai" ou "Faux".
- anagram: un seul mot de 4 à 12 lettres, le prompt donne un indice sans donner la réponse.
- explanation: 1-2 phrases claires qui expliquent le fait.
- familiarity: toujours l'une de "commun", "moyen", "pointu" — jamais vide.
- Ne mets jamais de champ "id" — inutile, il sera ignoré.

Réponds UNIQUEMENT avec un JSON valide: { "questions": [ ... ] }
Pas de texte avant ou après, pas de markdown, pas de backticks.`;
}

/** Extract the first JSON object from a text that might have stray characters. */
function extractJson(raw: string): string {
  let text = raw.trim();
  // Strip markdown code fences
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  // Find first { and last }
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first !== -1 && last !== -1 && last > first) {
    return text.slice(first, last + 1);
  }
  return text;
}

/** Strip accents/diacritics and normalize whitespace/case for fuzzy comparisons. */
function normalizeForCompare(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ")
    .replace(/[.,;:!?"'`]+$/g, "");
}

/**
 * Validate AND auto-correct a raw question object. Rather than rejecting on
 * every minor formatting slip (trailing period, wrong case, model-picked id
 * colliding, etc.), this fixes what it safely can and only rejects when the
 * data is genuinely unusable. This is the main fix for "plein de questions
 * rejetées": most rejections were cosmetic mismatches, not bad content.
 */
/** Fallback familiarity when the model omits/mistypes the field, keyed by level letter. */
function defaultFamiliarity(letter: string): Familiarity {
  if (letter === "f" || letter === "i") return "commun";
  if (letter === "d" || letter === "m") return "moyen";
  return "pointu";
}

/** Normalize any familiarity value/alias the model might send into our 3-tier scale. */
function normalizeFamiliarity(raw: unknown, letter: string): Familiarity {
  const norm = typeof raw === "string" ? normalizeForCompare(raw) : "";
  if (norm === "commun" || norm === "connu" || norm === "facile" || norm === "evident") return "commun";
  if (norm === "moyen" || norm === "intermediaire" || norm === "moyenne") return "moyen";
  if (norm === "pointu" || norm === "rare" || norm === "difficile" || norm === "expert" || norm === "specialiste") return "pointu";
  return defaultFamiliarity(letter);
}

function normalizeQuestion(raw: unknown, prefix: string, letter: string, index: number): { question: Question } | { error: string } {
  if (typeof raw !== "object" || raw === null) return { error: "n'est pas un objet" };
  const obj = raw as Record<string, unknown>;

  const type = obj.type;
  if (type !== "multipleChoice" && type !== "trueFalse" && type !== "fillBlank" && type !== "anagram") {
    return { error: `type invalide: ${String(type)}` };
  }

  const prompt = typeof obj.prompt === "string" ? obj.prompt.trim() : "";
  if (prompt.length < 5) return { error: "prompt manquant ou trop court" };

  const explanation = typeof obj.explanation === "string" ? obj.explanation.trim() : "";
  if (explanation.length < 5) return { error: "explication manquante ou trop courte" };

  let answer = typeof obj.answer === "string" ? obj.answer.trim() : "";
  if (!answer) return { error: "answer manquante" };

  let options: string[] | undefined;

  if (type === "multipleChoice" || type === "fillBlank") {
    if (!Array.isArray(obj.options)) return { error: "options manquantes" };
    const cleanOptions = obj.options.filter((o): o is string => typeof o === "string" && o.trim().length > 0).map((o) => o.trim());
    if (cleanOptions.length < 4) return { error: `seulement ${cleanOptions.length} option(s) valide(s), 4 requises` };
    options = cleanOptions.slice(0, 4);

    // Fuzzy-match the answer to one of the options instead of rejecting on
    // whitespace/case/accent mismatches — this was the #1 rejection cause.
    const normAnswer = normalizeForCompare(answer);
    const match = options.find((o) => normalizeForCompare(o) === normAnswer);
    if (match) {
      answer = match; // canonicalize to the exact option text
    } else if (!options.includes(answer)) {
      return { error: `answer "${answer}" ne correspond à aucune option` };
    }
  }

  if (type === "trueFalse") {
    const norm = normalizeForCompare(answer);
    if (norm === "vrai" || norm === "true" || norm === "v") answer = "Vrai";
    else if (norm === "faux" || norm === "false" || norm === "f") answer = "Faux";
    else return { error: `trueFalse answer invalide: "${answer}"` };
  }

  if (type === "anagram") {
    const letters = answer.replace(/[^a-zA-ZÀ-ÿ]/g, "");
    if (letters.length < 3 || letters.length > 14) return { error: `anagram answer longueur invalide: "${answer}"` };
    answer = letters.toUpperCase();
  }

  // Ids are always generated ourselves (sequential, guaranteed unique/well-formed)
  // rather than trusting the model's — this eliminates a whole class of rejections.
  const id = `${prefix}_${letter}_${index}`;
  const familiarity = normalizeFamiliarity(obj.familiarity, letter);

  const question: Question = { id, type, prompt, answer, explanation, familiarity };
  if (options) question.options = options;
  return { question };
}

/** Derive a short ID prefix from a chapter id. */
function chapterPrefix(chapterId: string): string {
  const parts = chapterId.split("_");
  if (parts.length >= 2) return parts.slice(0, 2).join("_");
  return chapterId.slice(0, 6);
}

/** Call the Rork AI proxy and generate questions for a single target. */
export async function generateForTarget(
  target: GenTarget,
  existingQuestions: Question[],
): Promise<GenResult> {
  const prefix = chapterPrefix(target.chapterId);
  const letter = levelLetter(target.level);
  const prompt = buildPrompt(target, existingQuestions);

  if (!TOOLKIT_URL || !SECRET_KEY) {
    return { target, questions: [], ok: false, error: "Clé Rork Toolkit non configurée (EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY)" };
  }

  try {
    const res = await fetch(`${TOOLKIT_URL}/v2/vercel/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${SECRET_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL_ID,
        messages: [
          { role: "system", content: "Tu es un générateur de questions éducatives. Tu réponds uniquement en JSON valide, sans aucun texte autour." },
          { role: "user", content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 4000,
      }),
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => res.statusText);
      if (res.status === 402 || res.status === 429) {
        return { target, questions: [], ok: false, error: `Crédits insuffisants ou rate limit (${res.status})` };
      }
      return { target, questions: [], ok: false, error: `Erreur API ${res.status}: ${errText.slice(0, 200)}` };
    }

    const data = await res.json();
    const rawContent: string = data?.choices?.[0]?.message?.content ?? "";
    if (!rawContent) {
      return { target, questions: [], ok: false, error: "Réponse vide de l'API" };
    }

    const jsonStr = extractJson(rawContent);
    let parsed: { questions?: unknown[] };
    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      return { target, questions: [], ok: false, error: "JSON invalide — parsing échoué" };
    }

    const rawQuestions = parsed.questions;
    if (!Array.isArray(rawQuestions)) {
      return { target, questions: [], ok: false, error: "Format inattendu: pas de tableau 'questions'" };
    }

    const validQuestions: Question[] = [];
    const rejectedReasons: string[] = [];
    let nextIndex = existingQuestions.length + 1;
    for (let i = 0; i < rawQuestions.length; i++) {
      const result = normalizeQuestion(rawQuestions[i], prefix, letter, nextIndex);
      if ("error" in result) {
        rejectedReasons.push(`Q${i + 1}: ${result.error}`);
      } else {
        validQuestions.push(result.question);
        nextIndex += 1;
      }
    }

    if (validQuestions.length === 0) {
      return { target, questions: [], ok: false, error: `Toutes les questions rejetées: ${rejectedReasons.slice(0, 3).join("; ")}`, rejectedReasons };
    }

    return {
      target,
      questions: validQuestions,
      ok: true,
      error: rejectedReasons.length > 0 ? `${rejectedReasons.length} question(s) rejetée(s) sur ${rawQuestions.length}` : undefined,
      rejectedReasons: rejectedReasons.length > 0 ? rejectedReasons : undefined,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { target, questions: [], ok: false, error: `Exception: ${msg}` };
  }
}

/** Merge generated questions into a content object (immutably). */
export function mergeQuestions(
  content: Content,
  target: GenTarget,
  newQuestions: Question[],
): Content {
  const clone: Content = JSON.parse(JSON.stringify(content));
  const disc = clone.disciplines.find((d) => d.id === target.disciplineId);
  if (!disc) return content;
  const ch = disc.chapters.find((c) => c.id === target.chapterId);
  if (!ch) return content;

  if (target.level === "legacy" || isLegacyChapter(ch)) {
    // Upgrade legacy chapter to new format
    if (!ch.levels) {
      ch.levels = {
        facile: {
          questions: [...(ch.questions ?? [])],
        },
      };
      delete ch.questions;
    }
    const lvl = ch.levels["facile"] ?? { questions: [] };
    lvl.questions.push(...newQuestions);
    ch.levels["facile"] = lvl;
  } else {
    if (!ch.levels) ch.levels = {};
    const lvl = ch.levels[target.level] ?? { questions: [] };
    lvl.questions.push(...newQuestions);
    ch.levels[target.level] = lvl;
  }
  return clone;
}

/** Get existing questions for a target (to avoid duplicates). */
export function getExistingQuestions(content: Content, target: GenTarget): Question[] {
  const disc = content.disciplines.find((d) => d.id === target.disciplineId);
  if (!disc) return [];
  const ch = disc.chapters.find((c) => c.id === target.chapterId);
  if (!ch) return [];
  if (isLegacyChapter(ch)) return ch.questions ?? [];
  if (ch.levels && target.level !== "legacy") return ch.levels[target.level]?.questions ?? [];
  return [];
}

/** Download a JSON file in the browser. */
export function downloadJson(content: Content, filename = "content.json"): void {
  const blob = new Blob([JSON.stringify(content, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/** Estimate cost for a number of questions. */
export function estimateCost(questionCount: number): number {
  return questionCount * COST_PER_QUESTION_USD;
}

export { TARGET_PER_LEVEL, MODEL_ID, COST_PER_QUESTION_USD, DEFAULT_BATCH_SIZE };
