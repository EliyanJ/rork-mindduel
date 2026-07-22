// aiReview.ts — client for the AI-assisted question review. Calls the
// project's own backend as a stateless relay (functions/index.ts), which
// forwards the request to the chosen provider using the caller-supplied API
// key and immediately discards it — the key is never written to any
// database, log, or file. On the client, the key only ever lives in React
// state for the current browser session (never localStorage).

import type { FlatQuestion } from "./moderation";

export type AiDecision = "approve" | "reject" | "edit";

export type AiReviewResult = {
  decision: AiDecision;
  confidence: number; // 0-100
  notes: string;
  correctedQuestion: {
    prompt?: string;
    options?: string[];
    answer?: string;
    explanation?: string;
  } | null;
};

export type AiProvider = "anthropic" | "openai" | "google" | "perplexity";

export type AiConfig = {
  provider: AiProvider;
  model: string;
  apiKey: string;
};

const FN_URL = import.meta.env.VITE_RORK_FUNCTIONS_URL
  ?? import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL
  ?? "https://mindduel-kqfozex-backend.rork.app";

function buildSystemPrompt(): string {
  return "Tu es un correcteur expert et rigoureux de questions de culture générale en français pour l'app éducative Minduel. Tu réponds uniquement en JSON valide, sans aucun texte ni markdown autour.";
}

function buildUserPrompt(item: FlatQuestion): string {
  const q = item.question;
  return `Analyse cette question de quiz et vérifie cinq points précis. Tu as accès à internet : utilise-le pour vérifier les faits concrets, dates, noms, records, palmarès, événements historiques, et toute affirmation susceptible d'être vérifiable en ligne. Ne te fie pas à ta mémoire pour les faits précis.

1. Orthographe et grammaire françaises (prompt, options, explication).
2. La réponse indiquée comme correcte est-elle réellement exacte ? Pour les faits précis, fais une recherche web dans ta tête et vérifie plusieurs sources si elles se contredisent. Exemples de piège : "Ronaldo a eu le Soulier d'Or 2020" → faux, c'est Lewandowski. "La guerre de 14-18 a duré jusqu'en 1919" → faux, armistice le 11 novembre 1918. Si tu as un doute, baisse la confiance et explique.
3. La question est-elle formulée clairement, sans ambiguïté ?
4. Les mauvaises réponses proposées sont-elles plausibles mais clairement fausses ?
5. L'explication est-elle factuellement correcte et cohérente avec la bonne réponse ?

Contexte : discipline "${item.disciplineName}", chapitre "${item.chapterTitle}", niveau "${item.level}".

Question (JSON) :
${JSON.stringify({ type: q.type, prompt: q.prompt, options: q.options, answer: q.answer, explanation: q.explanation })}

Réponds UNIQUEMENT avec ce JSON exact :
{
  "decision": "approve" | "reject" | "edit",
  "confidence": <entier 0-100>,
  "notes": "<explication brève en français. Mentionne explicitement si tu as fait une vérification factuelle et si tu as trouvé une contradiction>",
  "correctedQuestion": null ou { "prompt": "...", "options": [...] (si applicable au type), "answer": "...", "explanation": "..." }
}

Règles :
- "approve" si tout est correct tel quel — correctedQuestion doit être null.
- "edit" si tu identifies un problème réparable (faute, réponse imprécise, formulation à clarifier, fait à corriger) — fournis correctedQuestion complet avec la version corrigée.
- "reject" seulement si la question est irrécupérable (absurde, invérifiable malgré la recherche, hors sujet, dupliquée).
- confidence doit refléter ta certitude réelle — mets une valeur basse (< 60) dès que tu as un doute ou que les sources se contredisent. Pour une question purement locale (orthographe/clarté) sans fait vérifiable, tu peux mettre une confiance plus élevée.
Pas de texte hors JSON, pas de backticks.`;
}

/** Best-effort repair for JSON truncated mid-string/object due to a token
 * limit — closes unterminated strings and balances braces/brackets. */
function repairTruncatedJson(text: string): string {
  let result = text;
  let inString = false;
  let escaped = false;
  const stack: string[] = [];
  for (const ch of result) {
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch === "\\") {
      escaped = true;
      continue;
    }
    if (ch === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (ch === "{" || ch === "[") stack.push(ch);
    else if (ch === "}" || ch === "]") stack.pop();
  }
  if (inString) result += '"';
  while (stack.length > 0) {
    const open = stack.pop();
    result += open === "{" ? "}" : "]";
  }
  return result;
}

function extractJson(raw: string): string {
  let text = raw.trim();
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first !== -1 && last !== -1 && last > first) return text.slice(first, last + 1);
  return text;
}

/** Reviews a single question with the configured AI provider/model/key. */
export async function reviewQuestionWithAi(item: FlatQuestion, config: AiConfig): Promise<AiReviewResult> {
  const res = await fetch(`${FN_URL}/api/moderation/ai-review`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      provider: config.provider,
      apiKey: config.apiKey.trim(),
      model: config.model,
      systemPrompt: buildSystemPrompt(),
      userPrompt: buildUserPrompt(item),
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error((err as { error?: string }).error ?? `Erreur API (${res.status})`);
  }
  const data = (await res.json()) as { content?: string };
  const raw = data.content ?? "";
  if (!raw) throw new Error("Réponse vide du modèle");
  const jsonStr = extractJson(raw);
  let parsed: Partial<AiReviewResult>;
  try {
    parsed = JSON.parse(jsonStr);
  } catch {
    // Retry once with a repaired JSON string (handles truncated output by
    // closing dangling braces/brackets/strings) before giving up.
    try {
      parsed = JSON.parse(repairTruncatedJson(jsonStr));
    } catch {
      const preview = jsonStr.slice(0, 160).replace(/\s+/g, " ");
      throw new Error(`JSON invalide renvoyé par le modèle (aperçu: « ${preview}»…)`);
    }
  }
  const decision: AiDecision =
    parsed.decision === "approve" || parsed.decision === "reject" || parsed.decision === "edit"
      ? parsed.decision
      : "edit";
  const confidence = typeof parsed.confidence === "number" ? Math.max(0, Math.min(100, Math.round(parsed.confidence))) : 50;
  const notes = typeof parsed.notes === "string" ? parsed.notes : "";
  const correctedQuestion =
    parsed.correctedQuestion && typeof parsed.correctedQuestion === "object" ? parsed.correctedQuestion : null;
  return { decision, confidence, notes, correctedQuestion };
}
