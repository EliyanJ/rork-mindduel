// moderation.ts — helpers for the admin question-review tool: flattening the
// nested content.json structure into a flat list, and applying immutable
// per-question moderation updates (approve/reject/edit/delete) back into it.

import type { Chapter, Content, ModeratedBy, ModerationStatus, Question } from "./generator";

export type QuestionRef = {
  disciplineId: string;
  chapterId: string;
  level: string; // "legacy" for flat (non-leveled) chapters
};

export type FlatQuestion = {
  question: Question;
  disciplineId: string;
  disciplineName: string;
  disciplineColor: string;
  chapterId: string;
  chapterTitle: string;
  level: string;
};

/** Flattens every question across every discipline/chapter/level into one list. */
export function flattenQuestions(content: Content | null): FlatQuestion[] {
  if (!content) return [];
  const out: FlatQuestion[] = [];
  for (const disc of content.disciplines) {
    for (const ch of disc.chapters) {
      if (ch.questions) {
        for (const q of ch.questions) {
          out.push({
            question: q,
            disciplineId: disc.id,
            disciplineName: disc.name,
            disciplineColor: disc.colorHex,
            chapterId: ch.id,
            chapterTitle: ch.title,
            level: "legacy",
          });
        }
      }
      if (ch.levels) {
        for (const [levelName, lvl] of Object.entries(ch.levels)) {
          for (const q of lvl.questions) {
            out.push({
              question: q,
              disciplineId: disc.id,
              disciplineName: disc.name,
              disciplineColor: disc.colorHex,
              chapterId: ch.id,
              chapterTitle: ch.title,
              level: levelName,
            });
          }
        }
      }
    }
  }
  return out;
}

export function questionStatus(q: Question): ModerationStatus {
  return q.moderationStatus ?? "pending";
}

function findChapter(content: Content, ref: QuestionRef): Chapter | undefined {
  const disc = content.disciplines.find((d) => d.id === ref.disciplineId);
  return disc?.chapters.find((c) => c.id === ref.chapterId);
}

function getQuestionArray(ch: Chapter, level: string): Question[] | undefined {
  if (level === "legacy") return ch.questions;
  return ch.levels?.[level]?.questions;
}

/** Immutably applies `updater` to a single question anywhere in the tree. */
export function updateQuestion(
  content: Content,
  ref: QuestionRef,
  questionId: string,
  updater: (q: Question) => Question,
): Content {
  const clone: Content = JSON.parse(JSON.stringify(content));
  const ch = findChapter(clone, ref);
  if (!ch) return content;
  const arr = getQuestionArray(ch, ref.level);
  if (!arr) return content;
  const idx = arr.findIndex((q) => q.id === questionId);
  if (idx === -1) return content;
  arr[idx] = updater(arr[idx]);
  return clone;
}

/** Permanently removes a question — used for irrecoverable rejected entries. */
export function deleteQuestion(content: Content, ref: QuestionRef, questionId: string): Content {
  const clone: Content = JSON.parse(JSON.stringify(content));
  const ch = findChapter(clone, ref);
  if (!ch) return content;
  const arr = getQuestionArray(ch, ref.level);
  if (!arr) return content;
  const idx = arr.findIndex((q) => q.id === questionId);
  if (idx === -1) return content;
  arr.splice(idx, 1);
  return clone;
}

export function markStatus(q: Question, status: ModerationStatus, by: ModeratedBy): Question {
  return { ...q, moderationStatus: status, moderatedBy: by, moderatedAt: Date.now() };
}

export const LEVEL_LABEL: Record<string, string> = {
  facile: "Facile",
  intermediaire: "Intermédiaire",
  difficile: "Difficile",
  maitre: "Maître",
  legende: "Légende",
  legacy: "—",
};

export type AiModelOption = {
  id: string;
  label: string;
  provider: "anthropic" | "openai" | "google";
  model: string;
};

/** Curated model shortlist — the exact model string can still be overridden
 * in the UI if a provider renames/retires an alias. */
export const AI_MODELS: AiModelOption[] = [
  { id: "claude-sonnet", label: "Claude Sonnet 3.5", provider: "anthropic", model: "claude-3-5-sonnet-latest" },
  { id: "claude-opus", label: "Claude Opus 3", provider: "anthropic", model: "claude-3-opus-latest" },
  { id: "gpt-4o", label: "GPT-4o", provider: "openai", model: "gpt-4o" },
  { id: "gpt-4o-mini", label: "GPT-4o mini", provider: "openai", model: "gpt-4o-mini" },
  { id: "gemini-pro", label: "Gemini 1.5 Pro", provider: "google", model: "gemini-1.5-pro-latest" },
  { id: "gemini-flash", label: "Gemini 1.5 Flash", provider: "google", model: "gemini-1.5-flash-latest" },
];
