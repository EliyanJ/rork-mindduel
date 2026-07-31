// pathEditor.ts — the editing operations behind the admin "Parcours" tool.
//
// `pathLayout.ts` only *reads* a timeline. This module *changes* one, and it
// exists to enforce a single promise: a question can never be lost. Every
// operation moves ids between rings, and any id that ends up in no ring at all
// is re-filed by `normalizeSlots` on the next read.
//
// Editing a chapter switches its timeline from "auto" (recomputed from
// difficulty order every time) to "explicit" (each ring pins its question ids),
// so a hand-made arrangement is never silently reshuffled by an unrelated edit.

import type { Chapter, Familiarity, Question, QuestionType } from "./generator";
import type { QuestionRef } from "./moderation";
import {
  chapterQuestionIndex,
  chunk,
  dominantLevel,
  isExplicit,
  LEVEL_ORDER,
  levelRank,
  orderedQuestions,
  type PathLayout,
  type PathLevel,
  RING_MAX_OVERFLOW,
  RING_SIZE,
  type RingSlot,
  slotsFor,
} from "./pathLayout";

/**
 * Freezes a chapter's timeline into explicit question ids.
 *
 * Called before the first hand edit of a chapter. The result is exactly what
 * the admin currently sees, so materializing is invisible — it only stops
 * later edits from reshuffling rings the admin didn't touch.
 */
export function materializeSlots(chapter: Chapter, layout: PathLayout): RingSlot[] {
  const slots = slotsFor(chapter, layout);
  if (isExplicit(slots)) return slots;
  const groups = chunk(orderedQuestions(chapter));
  return slots.map((slot) => {
    if (slot.kind === "recap") return { kind: "recap" as const };
    const group = slot.source !== undefined ? groups[slot.source] ?? [] : [];
    return { kind: "normal" as const, questionIds: group.map((q) => q.id) };
  });
}

/** Removes a question id from every ring it appears in. */
export function removeQuestionFromSlots(slots: RingSlot[], questionId: string): RingSlot[] {
  return slots.map((slot) =>
    slot.kind === "normal" && slot.questionIds
      ? { ...slot, questionIds: slot.questionIds.filter((id) => id !== questionId) }
      : slot,
  );
}

/** Difficulty a ring currently represents, falling back to its declared target. */
function slotLevel(
  slot: RingSlot,
  index: Map<string, { question: Question; level: PathLevel }>,
): PathLevel {
  const questions = (slot.questionIds ?? [])
    .map((id) => index.get(id)?.question)
    .filter((q): q is Question => !!q);
  if (questions.length === 0) return slot.targetLevel ?? "facile";
  return dominantLevel(questions, index, slot.targetLevel ?? "facile");
}

/** Position of the closing recap, i.e. where new rings must stay in front of. */
function lastRecapIndex(slots: RingSlot[]): number {
  const found = slots.map((s) => s.kind).lastIndexOf("recap");
  return found === -1 ? slots.length : found;
}

export type PlacementResult = {
  slots: RingSlot[];
  /** Index of the ring the question landed in. */
  slotIndex: number;
  /** 1-based position of that ring among the chapter's normal rings. */
  position: number;
  /** True when a brand-new ring had to be created to hold it. */
  createdRing: boolean;
};

/**
 * Files a question into the furthest ring of the requested difficulty.
 *
 * `chapter` must already reflect the new difficulty (the caller moves the
 * question between level buckets first), and `slots` must already have had the
 * question removed. Rules, in order:
 *
 *  1. Target the **last** ring of that difficulty — a question promoted to
 *     "difficile" in a chapter with two difficult rings joins the second.
 *  2. That ring takes it while it stays under `RING_MAX_OVERFLOW`. Overflowing
 *     past 15 beats spawning a ring with 2 questions in it.
 *  3. Once it's saturated, a fresh ring is created straight after it.
 *  4. If no ring of that difficulty exists yet, one is created at the right
 *     spot on the ramp — after every easier ring, before every harder one, and
 *     always before the closing recap.
 */
export function placeQuestionAtLevel(
  chapter: Chapter,
  slots: RingSlot[],
  questionId: string,
  level: PathLevel,
): PlacementResult {
  const index = chapterQuestionIndex(chapter);
  const next = slots.map((slot) =>
    slot.kind === "normal" ? { ...slot, questionIds: [...(slot.questionIds ?? [])] } : { ...slot },
  );

  let targetIndex = -1;
  for (let i = 0; i < next.length; i++) {
    const slot = next[i]!;
    if (slot.kind !== "normal") continue;
    if (slotLevel(slot, index) === level) targetIndex = i;
  }

  const positionOf = (slotIndex: number): number =>
    next.slice(0, slotIndex + 1).filter((s) => s.kind === "normal").length;

  if (targetIndex !== -1) {
    const target = next[targetIndex]!;
    const ids = target.questionIds ?? [];
    if (ids.length < RING_MAX_OVERFLOW) {
      target.questionIds = [...ids, questionId];
      return {
        slots: next,
        slotIndex: targetIndex,
        position: positionOf(targetIndex),
        createdRing: false,
      };
    }
    // Saturated — start the next ring of the same difficulty right after it.
    const insertAt = Math.min(targetIndex + 1, lastRecapIndex(next));
    next.splice(insertAt, 0, { kind: "normal", questionIds: [questionId], targetLevel: level });
    return { slots: next, slotIndex: insertAt, position: positionOf(insertAt), createdRing: true };
  }

  // No ring of this difficulty yet: slot one in at the right point on the ramp.
  const rank = levelRank(level);
  let insertAt = lastRecapIndex(next);
  for (let i = 0; i < next.length; i++) {
    const slot = next[i]!;
    if (slot.kind !== "normal") continue;
    if (levelRank(slotLevel(slot, index)) > rank) {
      insertAt = i;
      break;
    }
  }
  insertAt = Math.min(insertAt, lastRecapIndex(next));
  next.splice(insertAt, 0, { kind: "normal", questionIds: [questionId], targetLevel: level });
  return { slots: next, slotIndex: insertAt, position: positionOf(insertAt), createdRing: true };
}

/** Appends an empty ring of the given difficulty, just before the closing recap. */
export function addEmptyRing(slots: RingSlot[], level: PathLevel): RingSlot[] {
  const next = [...slots];
  next.splice(lastRecapIndex(next), 0, { kind: "normal", questionIds: [], targetLevel: level });
  return next;
}

/** Retargets an empty (or any) ring to another difficulty. */
export function setRingTargetLevel(slots: RingSlot[], slotIndex: number, level: PathLevel): RingSlot[] {
  return slots.map((slot, i) => (i === slotIndex ? { ...slot, targetLevel: level } : slot));
}

/**
 * Deletes a ring. Its questions are handed to the nearest ring of the same
 * difficulty, else the previous normal ring, else the next one — they are never
 * dropped. Refuses to remove the last remaining recap.
 */
export function removeRing(
  chapter: Chapter,
  slots: RingSlot[],
  slotIndex: number,
): { slots: RingSlot[]; error?: string } {
  const victim = slots[slotIndex];
  if (!victim) return { slots };
  if (victim.kind === "recap") {
    if (slots.filter((s) => s.kind === "recap").length <= 1) {
      return { slots, error: "Chaque sous-chapitre garde au moins un récap de fin." };
    }
    return { slots: slots.filter((_, i) => i !== slotIndex) };
  }

  const orphans = victim.questionIds ?? [];
  const index = chapterQuestionIndex(chapter);
  const victimLevel = slotLevel(victim, index);
  const next = slots.map((slot) =>
    slot.kind === "normal" ? { ...slot, questionIds: [...(slot.questionIds ?? [])] } : { ...slot },
  );

  let host = -1;
  for (let i = slotIndex - 1; i >= 0; i--) {
    const slot = next[i]!;
    if (slot.kind === "normal" && slotLevel(slot, index) === victimLevel) { host = i; break; }
  }
  if (host === -1) {
    for (let i = slotIndex - 1; i >= 0; i--) {
      if (next[i]!.kind === "normal") { host = i; break; }
    }
  }
  if (host === -1) {
    for (let i = slotIndex + 1; i < next.length; i++) {
      if (next[i]!.kind === "normal") { host = i; break; }
    }
  }
  if (host === -1 && orphans.length > 0) {
    // Nowhere to put them — keep the ring rather than lose its questions.
    return { slots, error: "Ce rond est le seul du sous-chapitre : il ne peut pas être supprimé." };
  }
  if (host !== -1) {
    next[host]!.questionIds = [...(next[host]!.questionIds ?? []), ...orphans];
  }
  return { slots: next.filter((_, i) => i !== slotIndex) };
}

/** Moves one question into a specific ring, keeping it out of every other. */
export function moveQuestionToRing(
  slots: RingSlot[],
  questionId: string,
  targetSlotIndex: number,
): RingSlot[] {
  const cleaned = removeQuestionFromSlots(slots, questionId);
  return cleaned.map((slot, i) =>
    i === targetSlotIndex && slot.kind === "normal"
      ? { ...slot, questionIds: [...(slot.questionIds ?? []), questionId] }
      : slot,
  );
}

// MARK: - Creating questions

/** Ids are positional in the legacy catalog, so hand-made ones get their own
 * namespace — guaranteed unique and obvious in the moderation queue. */
export function newQuestionId(chapterId: string, level: PathLevel): string {
  const stamp = Date.now().toString(36);
  const salt = Math.floor(Math.random() * 1296).toString(36).padStart(2, "0");
  return `man_${chapterId}_${level.slice(0, 1)}_${stamp}${salt}`;
}

export type DraftQuestion = {
  type: QuestionType;
  prompt: string;
  answer: string;
  options: string[];
  explanation: string;
  familiarity: Familiarity;
  level: PathLevel;
};

export const EMPTY_DRAFT: DraftQuestion = {
  type: "multipleChoice",
  prompt: "",
  answer: "",
  options: ["", "", "", ""],
  explanation: "",
  familiarity: "moyen",
  level: "facile",
};

/** Validation shared by the manual form and the AI import preview. */
export function validateDraft(draft: DraftQuestion, chapter: Chapter): string | null {
  const prompt = draft.prompt.trim();
  const answer = draft.answer.trim();
  if (prompt.length < 8) return "L'énoncé est trop court.";
  if (answer.length === 0) return "La réponse est vide.";
  if (draft.explanation.trim().length < 5) return "L'explication est trop courte.";

  if (draft.type === "trueFalse") {
    if (!["Vrai", "Faux"].includes(answer)) return "Une question vrai/faux attend « Vrai » ou « Faux ».";
  } else if (draft.type === "anagram") {
    if (answer.includes(" ")) return "Une anagramme doit tenir en un seul mot.";
  } else {
    const options = draft.options.map((o) => o.trim()).filter(Boolean);
    if (options.length < 2) return "Il faut au moins deux propositions.";
    if (new Set(options.map((o) => o.toLowerCase())).size !== options.length) {
      return "Deux propositions sont identiques.";
    }
    if (!options.some((o) => o.toLowerCase() === answer.toLowerCase())) {
      return "La bonne réponse doit figurer parmi les propositions.";
    }
  }

  const needle = prompt.toLowerCase();
  for (const entry of chapterQuestionIndex(chapter).values()) {
    if (entry.question.prompt.trim().toLowerCase() === needle) {
      return "Cet énoncé existe déjà dans ce sous-chapitre.";
    }
  }
  return null;
}

/** Turns a validated draft into a catalog question, pending moderation. */
export function buildQuestion(draft: DraftQuestion, chapterId: string): Question {
  const needsOptions = draft.type === "multipleChoice" || draft.type === "fillBlank";
  return {
    id: newQuestionId(chapterId, draft.level),
    type: draft.type,
    prompt: draft.prompt.trim(),
    answer: draft.answer.trim(),
    options: needsOptions ? draft.options.map((o) => o.trim()).filter(Boolean) : undefined,
    explanation: draft.explanation.trim(),
    familiarity: draft.familiarity,
    moderationStatus: "pending",
  };
}

export function refFor(disciplineId: string, chapter: Chapter, level: PathLevel): QuestionRef {
  // Legacy chapters keep their flat array; everything else is level-filed.
  const isLegacy = !chapter.levels && Array.isArray(chapter.questions);
  return { disciplineId, chapterId: chapter.id, level: isLegacy ? "legacy" : level };
}

/** The level bucket a question currently sits in, for building its source ref. */
export function levelOfQuestion(chapter: Chapter, questionId: string): PathLevel {
  return chapterQuestionIndex(chapter).get(questionId)?.level ?? "facile";
}

/** Human-readable summary of a chapter's difficulty spread. */
export function levelBreakdown(counts: Record<PathLevel, number>): string {
  const parts: string[] = [];
  for (const level of LEVEL_ORDER) {
    const n = counts[level];
    if (n > 0) parts.push(`${n} ${level === "facile" ? "faciles" : level}`);
  }
  return parts.join(" · ");
}

/** Rough count of how many full rings a set of questions would fill. */
export function ringsNeeded(questionCount: number): number {
  return Math.max(1, Math.ceil(questionCount / RING_SIZE));
}
