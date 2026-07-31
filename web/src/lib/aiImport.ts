// aiImport.ts — turns a free-form question file into app-format questions.
//
// The workflow this serves: questions are drafted elsewhere (another AI, a
// markdown file, a plain list) and pasted in here. The model's only job is
// *reformatting* — it must not invent questions, and it must not silently fix
// facts. Everything it returns lands in a preview table the admin ticks through
// before anything is imported, and imported questions enter as "pending" so
// they still go through Moderation.

import type { Familiarity, QuestionType } from "./generator";
import type { AiConfig } from "./aiReview";
import type { DraftQuestion } from "./pathEditor";
import { LEVEL_ORDER, type PathLevel } from "./pathLayout";

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

/** How many raw questions to send per model call — keeps JSON output reliable. */
export const IMPORT_BATCH_SIZE = 10;

export type ImportRow = DraftQuestion & {
  /** Stable key for the preview table. */
  key: string;
  /** What the model couldn't fully resolve, shown as a warning. */
  warning: string | null;
  /** Matches an existing prompt in the target sub-chapter. */
  isDuplicate: boolean;
  selected: boolean;
};

function systemPrompt(): string {
  return "Tu es un convertisseur de format pour l'app éducative française Minduel. Tu reformates des questions existantes vers un schéma JSON strict. Tu ne réponds qu'en JSON valide, sans texte ni markdown autour.";
}

function userPrompt(rawChunk: string, chapterTitle: string, disciplineName: string): string {
  return `Voici des questions de quiz rédigées dans un format libre (markdown, liste, texte brut). Convertis-les au format JSON de l'app.

Contexte : discipline « ${disciplineName} », sous-chapitre « ${chapterTitle} ».

RÈGLES ABSOLUES :
- N'invente AUCUNE question. Convertis uniquement celles présentes dans le texte.
- Ne corrige PAS les faits. Si une réponse te semble fausse, convertis-la telle quelle et signale-le dans "warning".
- Conserve la langue française et la formulation d'origine autant que possible.
- Si une information obligatoire manque (par ex. pas d'explication fournie), rédige-la brièvement toi-même et signale-le dans "warning".

Pour chaque question, détermine :
- "type" : "multipleChoice" (plusieurs propositions), "trueFalse" (vrai/faux), "fillBlank" (texte à trou avec ___ dans l'énoncé), ou "anagram" (un seul mot à reconstituer).
- "options" : le tableau des propositions pour multipleChoice et fillBlank uniquement. La bonne réponse DOIT figurer dedans, à l'identique. Omets ce champ pour trueFalse et anagram.
- "answer" : la bonne réponse. Pour trueFalse, exactement "Vrai" ou "Faux". Pour anagram, un seul mot.
- "explanation" : une phrase courte expliquant pourquoi la réponse est correcte.
- "familiarity" : "commun" (tout le monde le sait), "moyen" (culture générale solide), "pointu" (expert).
- "level" : difficulté estimée parmi "facile", "intermediaire", "difficile", "maitre", "legende".
- "warning" : null si la conversion est nette, sinon une phrase courte décrivant ce que tu as dû deviner, compléter ou ce qui te semble douteux.

Texte source :
"""
${rawChunk}
"""

Réponds UNIQUEMENT avec ce JSON :
{ "questions": [ { "type": "...", "prompt": "...", "options": ["..."], "answer": "...", "explanation": "...", "familiarity": "...", "level": "...", "warning": null } ] }
Pas de texte hors JSON, pas de backticks.`;
}

function extractJson(raw: string): string {
  let text = raw.trim();
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first !== -1 && last !== -1 && last > first) return text.slice(first, last + 1);
  return text;
}

const QUESTION_TYPES: QuestionType[] = ["multipleChoice", "trueFalse", "fillBlank", "anagram"];
const FAMILIARITIES: Familiarity[] = ["commun", "moyen", "pointu"];

function coerceType(value: unknown): QuestionType {
  return QUESTION_TYPES.includes(value as QuestionType) ? (value as QuestionType) : "multipleChoice";
}

function coerceFamiliarity(value: unknown): Familiarity {
  return FAMILIARITIES.includes(value as Familiarity) ? (value as Familiarity) : "moyen";
}

function coerceLevel(value: unknown): PathLevel {
  const raw = String(value ?? "").toLowerCase();
  const match = LEVEL_ORDER.find((l) => raw.startsWith(l.slice(0, 4)));
  return match ?? "facile";
}

function coerceStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v ?? "").trim()).filter(Boolean);
}

/**
 * Splits the pasted text into chunks of roughly `IMPORT_BATCH_SIZE` questions.
 *
 * Rather than guessing a delimiter, we cut on blank lines and count the lines
 * that look like the start of a question (numbered, bulleted, or ending in a
 * question mark). Chunks that are too big for one call get split further.
 */
export function splitSource(text: string): string[] {
  const blocks = text
    .split(/\n\s*\n/)
    .map((b) => b.trim())
    .filter(Boolean);
  if (blocks.length === 0) return [];

  const looksLikeStart = (block: string): number => {
    const lines = block.split("\n");
    return Math.max(
      1,
      lines.filter((l) => /^\s*(?:[-*•]|\d+[.)]|Q\s*\d*\s*[:.)])/i.test(l) || /\?\s*$/.test(l)).length,
    );
  };

  const chunks: string[] = [];
  let current: string[] = [];
  let count = 0;
  for (const block of blocks) {
    const weight = looksLikeStart(block);
    if (count > 0 && count + weight > IMPORT_BATCH_SIZE) {
      chunks.push(current.join("\n\n"));
      current = [];
      count = 0;
    }
    current.push(block);
    count += weight;
  }
  if (current.length > 0) chunks.push(current.join("\n\n"));
  return chunks;
}

type RawRow = {
  type?: unknown;
  prompt?: unknown;
  options?: unknown;
  answer?: unknown;
  explanation?: unknown;
  familiarity?: unknown;
  level?: unknown;
  warning?: unknown;
};

/** Converts one chunk of free-form text into draft rows. */
export async function convertChunk(
  chunk: string,
  config: AiConfig,
  context: { chapterTitle: string; disciplineName: string },
): Promise<Omit<ImportRow, "isDuplicate" | "selected">[]> {
  const res = await fetch(`${FN_URL}/api/moderation/ai-review`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      provider: config.provider,
      apiKey: config.apiKey.trim(),
      model: config.model,
      systemPrompt: systemPrompt(),
      userPrompt: userPrompt(chunk, context.chapterTitle, context.disciplineName),
    }),
  });
  if (!res.ok) {
    const err = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(err.error ?? `Erreur API (${res.status})`);
  }
  const data = (await res.json()) as { content?: string };
  if (!data.content) throw new Error("Réponse vide du modèle");

  let parsed: { questions?: RawRow[] };
  try {
    parsed = JSON.parse(extractJson(data.content)) as { questions?: RawRow[] };
  } catch {
    const preview = extractJson(data.content).slice(0, 160).replace(/\s+/g, " ");
    throw new Error(`JSON invalide renvoyé par le modèle (aperçu : « ${preview} »…)`);
  }

  const rows = Array.isArray(parsed.questions) ? parsed.questions : [];
  return rows
    .map((row, i): Omit<ImportRow, "isDuplicate" | "selected"> | null => {
      const prompt = String(row.prompt ?? "").trim();
      const answer = String(row.answer ?? "").trim();
      if (prompt.length === 0 || answer.length === 0) return null;
      const type = coerceType(row.type);
      const options = coerceStringArray(row.options);
      const needsOptions = type === "multipleChoice" || type === "fillBlank";

      const warnings: string[] = [];
      if (typeof row.warning === "string" && row.warning.trim().length > 0) {
        warnings.push(row.warning.trim());
      }
      if (needsOptions && !options.some((o) => o.toLowerCase() === answer.toLowerCase())) {
        // Keep the question but make the gap explicit — the admin fixes it in
        // the preview rather than importing something unplayable.
        options.push(answer);
        warnings.push("La bonne réponse manquait dans les propositions, elle a été ajoutée.");
      }

      return {
        key: `${Date.now().toString(36)}-${i}-${Math.random().toString(36).slice(2, 7)}`,
        type,
        prompt,
        answer,
        options: needsOptions ? options : ["", "", "", ""],
        explanation: String(row.explanation ?? "").trim(),
        familiarity: coerceFamiliarity(row.familiarity),
        level: coerceLevel(row.level),
        warning: warnings.length > 0 ? warnings.join(" ") : null,
      };
    })
    .filter((row): row is Omit<ImportRow, "isDuplicate" | "selected"> => row !== null);
}

/**
 * Converts a whole pasted file, chunk by chunk, reporting progress. Chunks that
 * fail are reported and skipped so one bad batch can't lose the rest.
 */
export async function convertSource(
  text: string,
  config: AiConfig,
  context: { chapterTitle: string; disciplineName: string },
  onProgress: (done: number, total: number, error?: string) => void,
): Promise<Omit<ImportRow, "isDuplicate" | "selected">[]> {
  const chunks = splitSource(text);
  const out: Omit<ImportRow, "isDuplicate" | "selected">[] = [];
  for (let i = 0; i < chunks.length; i++) {
    try {
      out.push(...(await convertChunk(chunks[i]!, config, context)));
      onProgress(i + 1, chunks.length);
    } catch (err) {
      onProgress(i + 1, chunks.length, err instanceof Error ? err.message : String(err));
    }
  }
  return out;
}
