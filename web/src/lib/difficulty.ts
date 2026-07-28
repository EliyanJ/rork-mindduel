// difficulty.ts — the single source of truth for how hard a question is.
//
// The whole system is built on one number: a 0-100 `difficultyScore` that reads
// directly as a population statement. A score S means a baseline player has a
// (100 - S)% chance of answering correctly:
//
//   score 25 -> 75% of people succeed  (Facile)
//   score 50 -> half succeed           (Intermédiaire)
//   score 75 -> a quarter succeed      (Difficile)
//   score 90 -> one in ten succeeds    (Maître)
//
// That definition is what makes the three estimation sources comparable: the AI
// is asked "how many out of 100 would get this right", a human sets the same
// number on a slider, and the backend solves the same number from real answers.
// Themes get no special treatment — a "Facile" in history and a "Facile" in
// science must have the same expected success rate, otherwise the ladder means
// nothing in a duel where two players face different themes.

import type { Content, Question } from "./generator";
import { flattenQuestions, type FlatQuestion, type QuestionRef } from "./moderation";

/** The four difficulty tiers, ordered from easiest to hardest. */
export const DIFFICULTY_LEVELS = ["facile", "intermediaire", "difficile", "maitre"] as const;
export type DifficultyLevel = (typeof DIFFICULTY_LEVELS)[number];

export const DIFFICULTY_LEVEL_LABEL: Record<DifficultyLevel, string> = {
  facile: "Facile",
  intermediaire: "Intermédiaire",
  difficile: "Difficile",
  maitre: "Maître",
};

/** Upper bound of each tier on the 0-100 scale (inclusive). */
export const LEVEL_MAX_SCORE: Record<DifficultyLevel, number> = {
  facile: 25,
  intermediaire: 50,
  difficile: 75,
  maitre: 100,
};

/**
 * Representative score used when a question only has a tier and no number yet
 * (e.g. every pre-existing question, filed by folder). Deliberately the middle
 * of each band so converting tier -> score -> tier is stable.
 */
export const LEVEL_MIDPOINT_SCORE: Record<DifficultyLevel, number> = {
  facile: 13,
  intermediaire: 38,
  difficile: 63,
  maitre: 88,
};

export function scoreToLevel(score: number): DifficultyLevel {
  if (score <= LEVEL_MAX_SCORE.facile) return "facile";
  if (score <= LEVEL_MAX_SCORE.intermediaire) return "intermediaire";
  if (score <= LEVEL_MAX_SCORE.difficile) return "difficile";
  return "maitre";
}

/** Expected share of players (0-100) answering correctly at the given score. */
export function scoreToExpectedSuccessPercent(score: number): number {
  return Math.max(0, Math.min(100, Math.round(100 - score)));
}

/** Inverse of the above — used to turn an AI population estimate into a score. */
export function successPercentToScore(percentCorrect: number): number {
  return clampScore(100 - percentCorrect);
}

export function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 50;
  return Math.max(0, Math.min(100, Math.round(value)));
}

/**
 * Normalises a stored level name to one of the four tiers.
 *
 * "legende" folds into "maitre" (the fifth tier was retired), and legacy
 * chapters — which have no tier at all — are treated as "facile" only as a last
 * resort, since that is where the generator historically put them.
 */
export function normalizeLevel(raw: string | null | undefined): DifficultyLevel {
  const value = (raw ?? "").toLowerCase();
  if (value.startsWith("f")) return "facile";
  if (value.startsWith("i") || value.startsWith("moy")) return "intermediaire";
  if (value.startsWith("d")) return "difficile";
  if (value.startsWith("m")) return "maitre";
  if (value.startsWith("l") && value !== "legacy") return "maitre"; // légende -> maître
  return "facile";
}

export type DifficultySource = "human" | "ai" | "empirical";

export const SOURCE_LABEL: Record<DifficultySource, string> = {
  human: "Validé à la main",
  ai: "Estimé par l'IA",
  empirical: "Mesuré sur les joueurs",
};

/**
 * The effective score of a question: its explicit score when it has one,
 * otherwise the midpoint of the folder it currently sits in. `isExplicit`
 * distinguishes "really calibrated" from "inherited from its folder", which is
 * what the dashboard counts as calibration progress.
 */
export function effectiveScore(q: Question, level: string): {
  score: number;
  level: DifficultyLevel;
  source: DifficultySource | null;
  confidence: number;
  isExplicit: boolean;
} {
  if (typeof q.difficultyScore === "number") {
    const score = clampScore(q.difficultyScore);
    return {
      score,
      level: scoreToLevel(score),
      source: q.difficultySource ?? null,
      confidence: q.difficultyConfidence ?? 0,
      isExplicit: true,
    };
  }
  const tier = normalizeLevel(level);
  return {
    score: LEVEL_MIDPOINT_SCORE[tier],
    level: tier,
    source: null,
    confidence: 0,
    isExplicit: false,
  };
}

/** A human decision is treated as locked: automation may never overwrite it. */
export function isHumanLocked(q: Question): boolean {
  return q.difficultySource === "human";
}

// MARK: applying a score

/**
 * Returns the patch that stamps a difficulty decision onto a question. Kept
 * separate from any tree mutation so callers can pair it with `moveQuestion`
 * when the tier changes, or apply it in place when only the score moved.
 */
export function difficultyPatch(
  score: number,
  source: DifficultySource,
  options?: { confidence?: number; reason?: string },
): Partial<Question> {
  const clamped = clampScore(score);
  return {
    difficultyScore: clamped,
    difficultySource: source,
    difficultyConfidence:
      typeof options?.confidence === "number"
        ? Math.max(0, Math.min(1, options.confidence))
        : source === "human"
          ? 1
          : 0.5,
    difficultyReason: options?.reason,
    difficultyUpdatedAt: Date.now(),
  };
}

// MARK: telemetry

/** One question's aggregated play statistics, as returned by the backend. */
export type QuestionStat = {
  questionId: string;
  disciplineId: string | null;
  level: string | null;
  attempts: number;
  correct: number;
  successRate: number;
  avgTimeMs: number;
  avgCorrectTimeMs: number;
  timeouts: number;
  /** Difficulty solved from real answers, normalised for player strength. */
  empiricalScore: number | null;
  /** Pick count per answer text, including the correct one. */
  choices: Record<string, number>;
  updatedAt: number;
};

export type StatsPayload = { stats: QuestionStat[]; count: number };

const FN_URL: string =
  (import.meta.env.VITE_RORK_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ??
  "https://mindduel-kqfozex-backend.rork.app";

export async function fetchQuestionStats(password: string): Promise<Map<string, QuestionStat>> {
  const res = await fetch(
    `${FN_URL}/api/stats/questions?password=${encodeURIComponent(password)}`,
    { cache: "no-store" },
  );
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(body.error ?? `Statistiques indisponibles (${res.status})`);
  }
  const data = (await res.json()) as StatsPayload;
  const map = new Map<string, QuestionStat>();
  for (const stat of data.stats ?? []) map.set(stat.questionId, stat);
  return map;
}

// MARK: blending prior + evidence

/** Answers needed before real data fully outweighs the prior estimate. */
const EVIDENCE_HALF_WEIGHT = 40;
/** Below this, a measurement is too thin to even suggest a change. */
export const MIN_ATTEMPTS_TO_SUGGEST = 12;

/**
 * How much to trust the measured score versus the prior. Deliberately gradual:
 * with 5 answers the score barely budges, by ~200 the prior is irrelevant.
 * Without this ramp questions would flip tier after three games.
 */
export function evidenceWeight(attempts: number): number {
  if (attempts <= 0) return 0;
  return attempts / (attempts + EVIDENCE_HALF_WEIGHT);
}

/**
 * Response time as a secondary difficulty signal. Correct-but-slow means the
 * question was harder than the raw success rate suggests; instant answers mean
 * it was easier. Capped at ±8 points so it can only nudge, never dominate.
 */
export function timeAdjustment(stat: QuestionStat, roundDurationMs = 15_000): number {
  if (stat.correct < 5 || stat.avgCorrectTimeMs <= 0) return 0;
  const ratio = stat.avgCorrectTimeMs / roundDurationMs;
  // ~0.25 of the timer is a confident answer, ~0.65 is real hesitation.
  const centered = (ratio - 0.25) / 0.4;
  return Math.max(-8, Math.min(8, Math.round(centered * 8)));
}

export type Recalibration = {
  item: FlatQuestion;
  ref: QuestionRef;
  stat: QuestionStat;
  currentScore: number;
  currentLevel: DifficultyLevel;
  /** Prior + evidence, blended by attempt count. */
  blendedScore: number;
  suggestedLevel: DifficultyLevel;
  confidence: number;
  /** True when the tier itself changes — the only case worth surfacing. */
  levelChanges: boolean;
  humanLocked: boolean;
};

/**
 * Computes the empirically-adjusted score for every question that has enough
 * play data, and flags the ones whose tier should move.
 */
export function computeRecalibrations(
  content: Content | null,
  stats: Map<string, QuestionStat>,
): Recalibration[] {
  const out: Recalibration[] = [];
  for (const item of flattenQuestions(content)) {
    const stat = stats.get(item.question.id);
    if (!stat || stat.attempts < MIN_ATTEMPTS_TO_SUGGEST || stat.empiricalScore === null) continue;

    const current = effectiveScore(item.question, item.level);
    const measured = clampScore(stat.empiricalScore + timeAdjustment(stat));
    const weight = evidenceWeight(stat.attempts);
    const blendedScore = clampScore(current.score * (1 - weight) + measured * weight);
    const suggestedLevel = scoreToLevel(blendedScore);

    out.push({
      item,
      ref: { disciplineId: item.disciplineId, chapterId: item.chapterId, level: item.level },
      stat,
      currentScore: current.score,
      currentLevel: current.level,
      blendedScore,
      suggestedLevel,
      confidence: weight,
      levelChanges: suggestedLevel !== current.level,
      humanLocked: isHumanLocked(item.question),
    });
  }
  // Biggest disagreements first — that's where attention is worth spending.
  return out.sort(
    (a, b) =>
      Math.abs(b.blendedScore - b.currentScore) - Math.abs(a.blendedScore - a.currentScore),
  );
}

// MARK: broken-question detection

export type SuspicionKind = "wrong_answer" | "dead_distractor" | "too_hard" | "high_timeout";

export type Suspicion = {
  item: FlatQuestion;
  ref: QuestionRef;
  stat: QuestionStat;
  kinds: SuspicionKind[];
  /** Human-readable reasons, ready to display. */
  reasons: string[];
  /** 0-1, how strongly the data suggests something is wrong. */
  severity: number;
};

export const SUSPICION_LABEL: Record<SuspicionKind, string> = {
  wrong_answer: "Réponse probablement fausse",
  dead_distractor: "Leurre inutile",
  too_hard: "Quasi personne ne réussit",
  high_timeout: "Beaucoup d'abandons",
};

/**
 * Uses the wrong-answer distribution to find questions that are probably
 * broken. This catches real errors that an AI re-read misses, because it is
 * grounded in what actual players did.
 */
export function detectSuspiciousQuestions(
  content: Content | null,
  stats: Map<string, QuestionStat>,
): Suspicion[] {
  const out: Suspicion[] = [];
  for (const item of flattenQuestions(content)) {
    const stat = stats.get(item.question.id);
    if (!stat || stat.attempts < MIN_ATTEMPTS_TO_SUGGEST) continue;

    const q = item.question;
    const kinds: SuspicionKind[] = [];
    const reasons: string[] = [];
    let severity = 0;

    const totalPicks = Object.values(stat.choices).reduce((sum, n) => sum + n, 0);
    const answerKey = normalizeAnswer(q.answer);
    const wrongPicks = Object.entries(stat.choices).filter(
      ([choice]) => normalizeAnswer(choice) !== answerKey,
    );
    const topWrong = wrongPicks.sort((a, b) => b[1] - a[1])[0];
    const correctPicks = Object.entries(stat.choices).find(
      ([choice]) => normalizeAnswer(choice) === answerKey,
    )?.[1] ?? 0;

    // A distractor beating the official answer is the strongest signal that the
    // answer key itself is wrong.
    if (topWrong && totalPicks >= MIN_ATTEMPTS_TO_SUGGEST && topWrong[1] > correctPicks) {
      const share = Math.round((topWrong[1] / totalPicks) * 100);
      kinds.push("wrong_answer");
      reasons.push(
        `« ${topWrong[0]} » est choisi par ${share}% des joueurs, plus que la réponse officielle « ${q.answer} »`,
      );
      severity = Math.max(severity, 0.9);
    }

    if (stat.successRate < 0.12 && stat.attempts >= 20) {
      kinds.push("too_hard");
      reasons.push(
        `${Math.round(stat.successRate * 100)}% de réussite sur ${stat.attempts} réponses`,
      );
      severity = Math.max(severity, 0.6);
    }

    // An option nobody ever picks means the question effectively has fewer
    // choices than it appears to — it is easier than its tier implies.
    const options = q.options ?? [];
    if (options.length >= 3 && totalPicks >= 25) {
      const dead = options.filter(
        (opt) =>
          normalizeAnswer(opt) !== answerKey &&
          (stat.choices[opt] ?? 0) / totalPicks < 0.02,
      );
      if (dead.length > 0) {
        kinds.push("dead_distractor");
        reasons.push(`Leurre(s) jamais choisi(s) : ${dead.join(", ")}`);
        severity = Math.max(severity, 0.35);
      }
    }

    if (stat.attempts >= 20 && stat.timeouts / stat.attempts > 0.4) {
      kinds.push("high_timeout");
      reasons.push(
        `${Math.round((stat.timeouts / stat.attempts) * 100)}% des joueurs n'ont pas répondu à temps`,
      );
      severity = Math.max(severity, 0.45);
    }

    if (kinds.length > 0) {
      out.push({
        item,
        ref: { disciplineId: item.disciplineId, chapterId: item.chapterId, level: item.level },
        stat,
        kinds,
        reasons,
        severity,
      });
    }
  }
  return out.sort((a, b) => b.severity - a.severity);
}

function normalizeAnswer(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

// MARK: anchors

/** Number of human-scored reference questions before the AI is well grounded. */
export const TARGET_ANCHORS = 40;
/** Reference questions to inject into a single AI request. */
export const ANCHORS_IN_PROMPT = 16;

export type AnchorSummary = {
  total: number;
  byLevel: Record<DifficultyLevel, number>;
  byDiscipline: Record<string, number>;
  /** Tiers still missing reference examples, worst first. */
  missingLevels: DifficultyLevel[];
  isReady: boolean;
};

/** Every question you have scored by hand — the ground truth the AI learns from. */
export function collectAnchors(content: Content | null): FlatQuestion[] {
  return flattenQuestions(content).filter(
    (item) => isHumanLocked(item.question) && typeof item.question.difficultyScore === "number",
  );
}

export function summarizeAnchors(anchors: FlatQuestion[]): AnchorSummary {
  const byLevel: Record<DifficultyLevel, number> = {
    facile: 0,
    intermediaire: 0,
    difficile: 0,
    maitre: 0,
  };
  const byDiscipline: Record<string, number> = {};
  for (const anchor of anchors) {
    const level = scoreToLevel(clampScore(anchor.question.difficultyScore ?? 50));
    byLevel[level] += 1;
    byDiscipline[anchor.disciplineName] = (byDiscipline[anchor.disciplineName] ?? 0) + 1;
  }
  // Each tier needs a few examples, otherwise the AI has nothing to anchor that
  // end of the scale against.
  const perLevelTarget = Math.max(4, Math.floor(TARGET_ANCHORS / DIFFICULTY_LEVELS.length));
  const missingLevels = DIFFICULTY_LEVELS.filter((lvl) => byLevel[lvl] < perLevelTarget);
  return {
    total: anchors.length,
    byLevel,
    byDiscipline,
    missingLevels: [...missingLevels],
    isReady: anchors.length >= 12 && missingLevels.length <= 1,
  };
}

/**
 * Picks a spread of anchors for a prompt: balanced across tiers, and biased
 * toward the same discipline as the question being judged so the comparison is
 * as relevant as possible.
 */
export function selectAnchorsForPrompt(
  anchors: FlatQuestion[],
  disciplineId: string,
  limit = ANCHORS_IN_PROMPT,
): FlatQuestion[] {
  const perLevel = Math.max(1, Math.floor(limit / DIFFICULTY_LEVELS.length));
  const picked: FlatQuestion[] = [];
  for (const level of DIFFICULTY_LEVELS) {
    const pool = anchors.filter(
      (a) => scoreToLevel(clampScore(a.question.difficultyScore ?? 50)) === level,
    );
    const sameDiscipline = pool.filter((a) => a.disciplineId === disciplineId);
    const others = pool.filter((a) => a.disciplineId !== disciplineId);
    picked.push(...[...sameDiscipline, ...others].slice(0, perLevel));
  }
  return picked;
}

// MARK: pairwise comparison

/**
 * Converts "A is harder than B" judgements into scores.
 *
 * LLMs and humans are both far more reliable at comparing two questions than at
 * naming an absolute difficulty, so this is the cheapest way to build accurate
 * anchors. Each comparison nudges both questions apart by a shrinking step
 * (Elo-style), which converges without needing a full ranking pass.
 */
export type PairJudgement = { harderId: string; easierId: string };

export function applyPairwiseJudgements(
  initialScores: Map<string, number>,
  judgements: PairJudgement[],
): Map<string, number> {
  const scores = new Map(initialScores);
  const step = 6;
  judgements.forEach((j, index) => {
    const decay = step * (1 - index / (judgements.length + 1)) * 0.5 + 2;
    const harder = scores.get(j.harderId) ?? 50;
    const easier = scores.get(j.easierId) ?? 50;
    if (harder <= easier) {
      // Order violated — pull them apart around their midpoint.
      const mid = (harder + easier) / 2;
      scores.set(j.harderId, clampScore(mid + decay));
      scores.set(j.easierId, clampScore(mid - decay));
    } else {
      // Already consistent: reinforce gently.
      scores.set(j.harderId, clampScore(harder + decay * 0.25));
      scores.set(j.easierId, clampScore(easier - decay * 0.25));
    }
  });
  return scores;
}

// MARK: migration

/**
 * Folds the retired "legende" tier into "maitre" and seeds an explicit score
 * for questions that never had one, derived from the folder they sit in.
 *
 * Seeded scores are recorded with source "ai" and low confidence rather than
 * "human", so they are treated as a rough prior that real data may override —
 * they were never actually reviewed by anyone.
 */
export function migrateContentDifficulty(content: Content): {
  content: Content;
  movedFromLegende: number;
  seededScores: number;
} {
  const clone: Content = JSON.parse(JSON.stringify(content));
  let movedFromLegende = 0;
  let seededScores = 0;

  for (const disc of clone.disciplines) {
    for (const ch of disc.chapters) {
      if (!ch.levels) continue;
      const legendKeys = Object.keys(ch.levels).filter(
        (k) => k.toLowerCase().startsWith("l") && k.toLowerCase() !== "legacy",
      );
      for (const key of legendKeys) {
        const questions = ch.levels[key]?.questions ?? [];
        const target = ch.levels["maitre"] ?? { questions: [] };
        target.questions = [...target.questions, ...questions];
        ch.levels["maitre"] = target;
        movedFromLegende += questions.length;
        delete ch.levels[key];
      }
      for (const [levelName, lvl] of Object.entries(ch.levels)) {
        const tier = normalizeLevel(levelName);
        for (const q of lvl.questions) {
          if (typeof q.difficultyScore !== "number") {
            q.difficultyScore = LEVEL_MIDPOINT_SCORE[tier];
            q.difficultySource = "ai";
            q.difficultyConfidence = 0.15;
            q.difficultyReason = "Score initial déduit du palier d'origine (non vérifié)";
            seededScores += 1;
          }
        }
      }
    }
  }
  return { content: clone, movedFromLegende, seededScores };
}
