// aiDifficulty.ts — AI estimation of a question's difficulty and theme.
//
// Why this is not just "ask the model if it's hard": an LLM knows the capital of
// Burkina Faso and the date of the Treaty of Westphalia, so when asked "is this
// difficult?" it effectively answers "do *I* know this?" — and rates almost
// everything as easy. That single bias is what made the previous tier
// assignments unusable.
//
// Two corrections are applied here:
//  1. The model is asked for a *population* estimate ("out of 100 random French
//     adults, how many answer correctly without looking it up"), never for a
//     label. That forces it to simulate people instead of introspecting.
//  2. Human-scored reference questions are injected into the prompt as anchors,
//     so the judgement becomes comparative rather than absolute — which is where
//     language models are genuinely reliable.

import type { AiConfig } from "./aiReview";
import {
  clampScore,
  scoreToExpectedSuccessPercent,
  scoreToLevel,
  successPercentToScore,
  type DifficultyLevel,
} from "./difficulty";
import type { FlatQuestion } from "./moderation";

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

export type AiDifficultyResult = {
  /** Share of a random adult population expected to answer correctly (0-100). */
  percentCorrect: number;
  /** Derived difficulty score (100 - percentCorrect), clamped to 0-100. */
  score: number;
  level: DifficultyLevel;
  /** One-sentence justification in French, shown next to the proposal. */
  reason: string;
  /** The model's own confidence, 0-100. */
  confidence: number;
  /** Most likely theme for this question, when it looks mis-filed. */
  suggestedDisciplineName: string | null;
  suggestedChapterTitle: string | null;
};

function buildSystemPrompt(): string {
  return [
    "Tu es un expert en psychométrie et en calibrage de questions de quiz en français pour l'app Minduel.",
    "Ta seule mission : estimer quelle PROPORTION DE LA POPULATION FRANÇAISE ADULTE répondrait correctement à une question, sans recherche et sans aide.",
    "",
    "RÈGLE ABSOLUE : tu n'évalues JAMAIS si TOI tu connais la réponse. Tu connais presque tout, ce qui te rendrait incapable de juger.",
    "Tu simules un échantillon représentatif de 100 adultes français tirés au hasard : tous les niveaux d'études, tous les âges, tous les milieux.",
    "La majorité de ces gens n'ont pas de culture générale poussée. Un fait qui te semble « évident » est souvent inconnu de la moitié d'entre eux.",
    "",
    "La difficulté ne dépend PAS du thème. Une question d'histoire peut être très facile (« En quelle année a eu lieu la Révolution française ? ») et une question de géographie très dure. Tu juges la question, jamais sa catégorie.",
    "",
    "Tu réponds uniquement en JSON valide, sans texte ni markdown autour.",
  ].join("\n");
}

/** Renders anchors as a calibrated scale the model positions the question against. */
function buildAnchorBlock(anchors: FlatQuestion[]): string {
  if (anchors.length === 0) return "";
  const lines = anchors
    .map((anchor) => {
      const score = clampScore(anchor.question.difficultyScore ?? 50);
      const percent = scoreToExpectedSuccessPercent(score);
      return `- [${percent}/100 réussissent] (${anchor.disciplineName}) « ${anchor.question.prompt} » → ${anchor.question.answer}`;
    })
    .join("\n");
  return [
    "",
    "ÉCHELLE DE RÉFÉRENCE — ces questions ont été calibrées à la main par l'équipe Minduel et servent de vérité terrain.",
    "Positionne la nouvelle question PAR RAPPORT à celles-ci : trouve celles de difficulté comparable, puis ajuste.",
    lines,
    "",
  ].join("\n");
}

function buildUserPrompt(
  item: FlatQuestion,
  anchors: FlatQuestion[],
  options?: { classifyTheme?: boolean; availableThemes?: string[] },
): string {
  const q = item.question;
  const themeBlock =
    options?.classifyTheme && options.availableThemes && options.availableThemes.length > 0
      ? [
          "",
          "Indique aussi le thème le plus probable de cette question parmi cette liste (recopie exactement l'intitulé, ou null si le thème actuel est déjà le bon) :",
          options.availableThemes.map((t) => `- ${t}`).join("\n"),
        ].join("\n")
      : "";

  return `Estime la difficulté de cette question de quiz.

${buildAnchorBlock(anchors)}
Question à calibrer — thème actuel : « ${item.disciplineName} / ${item.chapterTitle} »
${JSON.stringify(
  { type: q.type, prompt: q.prompt, options: q.options, answer: q.answer },
  null,
  2,
)}

Raisonne dans cet ordre :
1. Qui, dans la population générale, a réellement croisé cette information ? (école obligatoire ? culture populaire ? presse ? uniquement les passionnés du sujet ?)
2. Le format aide-t-il ? Un choix multiple à 4 options donne 25% de réussite au hasard : ta réponse ne peut donc PAS être inférieure à environ 25 pour une question à 4 options, ni inférieure à 50 pour un vrai/faux. Les mauvaises réponses sont-elles évidemment fausses (ce qui facilite) ou crédibles (ce qui complique) ?
3. Conclus par un nombre sur 100.

Repères d'étalonnage :
- 85-100 réussissent : connaissance quasi universelle (capitale de la France).
- 70-84 : connu du grand public, vu à l'école primaire ou collège.
- 45-69 : culture générale d'adulte plutôt cultivé ; environ la moitié réussit.
- 20-44 : demande un vrai intérêt pour le sujet.
- 5-19 : réservé aux passionnés ou aux spécialistes.
${themeBlock}

Réponds UNIQUEMENT avec ce JSON exact :
{
  "percentCorrect": <entier 0-100 : combien d'adultes français sur 100 répondraient juste>,
  "reason": "<une seule phrase en français justifiant l'estimation, en parlant de la population et non de toi>",
  "confidence": <entier 0-100 : ta certitude sur cette estimation>,
  "suggestedDisciplineName": <null ou "intitulé exact du thème plus probable">,
  "suggestedChapterTitle": <null ou "intitulé exact du chapitre plus probable">
}
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

/**
 * Floor imposed by the answer format: a 4-option question cannot realistically
 * fall below random-guess level, and a true/false cannot fall below a coin flip.
 * Models routinely forget this and return single-digit estimates, which would
 * push perfectly answerable questions into the top tier.
 */
function guessFloor(item: FlatQuestion): number {
  const q = item.question;
  if (q.type === "trueFalse") return 50;
  const count = q.options?.length ?? 0;
  if (count >= 2) return Math.floor(100 / count);
  return 0;
}

/** Estimates one question's difficulty, grounded in human-calibrated anchors. */
export async function estimateDifficultyWithAi(
  item: FlatQuestion,
  anchors: FlatQuestion[],
  config: AiConfig,
  options?: { classifyTheme?: boolean; availableThemes?: string[] },
): Promise<AiDifficultyResult> {
  const res = await fetch(`${FN_URL}/api/moderation/ai-review`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      provider: config.provider,
      apiKey: config.apiKey.trim(),
      model: config.model,
      systemPrompt: buildSystemPrompt(),
      userPrompt: buildUserPrompt(item, anchors, options),
    }),
  });
  if (!res.ok) {
    const err = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(err.error ?? `Erreur API (${res.status})`);
  }
  const data = (await res.json()) as { content?: string };
  const raw = data.content ?? "";
  if (!raw) throw new Error("Réponse vide du modèle");

  let parsed: Partial<AiDifficultyResult> & { percentCorrect?: unknown };
  try {
    parsed = JSON.parse(extractJson(raw)) as typeof parsed;
  } catch {
    const preview = raw.slice(0, 160).replace(/\s+/g, " ");
    throw new Error(`JSON invalide renvoyé par le modèle (aperçu : « ${preview} »…)`);
  }

  const rawPercent =
    typeof parsed.percentCorrect === "number" ? parsed.percentCorrect : Number(parsed.percentCorrect);
  if (!Number.isFinite(rawPercent)) {
    throw new Error("Le modèle n'a pas renvoyé d'estimation chiffrée");
  }
  const percentCorrect = Math.max(
    guessFloor(item),
    Math.max(0, Math.min(100, Math.round(rawPercent))),
  );
  const score = successPercentToScore(percentCorrect);

  return {
    percentCorrect,
    score,
    level: scoreToLevel(score),
    reason: typeof parsed.reason === "string" ? parsed.reason.trim() : "",
    confidence:
      typeof parsed.confidence === "number"
        ? Math.max(0, Math.min(100, Math.round(parsed.confidence)))
        : 50,
    suggestedDisciplineName:
      typeof parsed.suggestedDisciplineName === "string" && parsed.suggestedDisciplineName.trim()
        ? parsed.suggestedDisciplineName.trim()
        : null,
    suggestedChapterTitle:
      typeof parsed.suggestedChapterTitle === "string" && parsed.suggestedChapterTitle.trim()
        ? parsed.suggestedChapterTitle.trim()
        : null,
  };
}

/**
 * Asks the model which of two questions is harder. Pairwise comparison is much
 * more reliable than absolute scoring, so this is used to bootstrap anchors and
 * to sanity-check the scale.
 */
export async function comparePairWithAi(
  a: FlatQuestion,
  b: FlatQuestion,
  config: AiConfig,
): Promise<{ harderId: string; reason: string }> {
  const res = await fetch(`${FN_URL}/api/moderation/ai-review`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      provider: config.provider,
      apiKey: config.apiKey.trim(),
      model: config.model,
      systemPrompt: buildSystemPrompt(),
      userPrompt: `Deux questions de quiz. Dis laquelle serait réussie par le MOINS d'adultes français tirés au hasard (donc la plus difficile).

QUESTION A (id: ${a.question.id}) — ${a.disciplineName}
« ${a.question.prompt} » → ${a.question.answer}

QUESTION B (id: ${b.question.id}) — ${b.disciplineName}
« ${b.question.prompt} » → ${b.question.answer}

Réponds UNIQUEMENT avec ce JSON :
{ "harder": "A" | "B", "reason": "<une phrase en français>" }`,
    }),
  });
  if (!res.ok) {
    const err = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(err.error ?? `Erreur API (${res.status})`);
  }
  const data = (await res.json()) as { content?: string };
  const parsed = JSON.parse(extractJson(data.content ?? "{}")) as {
    harder?: string;
    reason?: string;
  };
  return {
    harderId: parsed.harder === "B" ? b.question.id : a.question.id,
    reason: typeof parsed.reason === "string" ? parsed.reason : "",
  };
}
