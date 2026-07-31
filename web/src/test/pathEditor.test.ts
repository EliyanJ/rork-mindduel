import type { Chapter, Question } from "@/lib/generator";
import {
  addEmptyRing,
  materializeSlots,
  moveQuestionToRing,
  placeQuestionAtLevel,
  removeQuestionFromSlots,
  removeRing,
} from "@/lib/pathEditor";
import {
  buildRings,
  defaultLayout,
  RING_MAX_OVERFLOW,
  RING_SIZE,
  type PathLevel,
  type PathLayout,
  type RingSlot,
} from "@/lib/pathLayout";

function question(id: string): Question {
  return {
    id,
    type: "multipleChoice",
    prompt: `Question ${id} ?`,
    options: ["A", "B", "C", "D"],
    answer: "A",
    explanation: "Parce que.",
    familiarity: "moyen",
  };
}

/** Chapter with `counts[level]` questions in each difficulty bucket. */
function chapter(counts: Partial<Record<PathLevel, number>>, id = "ch"): Chapter {
  const levels: Chapter["levels"] = {};
  for (const [level, n] of Object.entries(counts)) {
    levels[level] = {
      questions: Array.from({ length: n as number }, (_, i) => question(`${level}_${i}`)),
    };
  }
  return { id, title: "Chapitre test", levels };
}

function layoutWith(chapterId: string, slots: RingSlot[]): PathLayout {
  return { ...defaultLayout(), ringLayout: { [chapterId]: slots } };
}

/** Every question id currently reachable through the timeline. */
function idsInSlots(slots: RingSlot[]): string[] {
  return slots.flatMap((s) => (s.kind === "normal" ? s.questionIds ?? [] : []));
}

/** One ring per difficulty bucket — a precise fixture that doesn't depend on
 * how the auto-chunker happens to merge trailing groups. */
function oneRingPerLevel(ch: Chapter, order: PathLevel[]): RingSlot[] {
  const slots: RingSlot[] = order.map((level) => ({
    kind: "normal" as const,
    questionIds: (ch.levels?.[level]?.questions ?? []).map((q) => q.id),
    targetLevel: level,
  }));
  slots.push({ kind: "recap" });
  return slots;
}

/** Re-levels a question then files it, the way the admin tool does. */
function reLevel(
  before: Chapter,
  slots: RingSlot[],
  questionId: string,
  from: PathLevel,
  to: PathLevel,
) {
  const moved = { ...before, levels: { ...before.levels } };
  const source = (moved.levels![from]?.questions ?? []).filter((q) => q.id !== questionId);
  const target = [...(moved.levels![to]?.questions ?? []), question(questionId)];
  moved.levels![from] = { questions: source };
  moved.levels![to] = { questions: target };
  const cleaned = removeQuestionFromSlots(slots, questionId);
  return { chapter: moved, ...placeQuestionAtLevel(moved, cleaned, questionId, to) };
}

describe("materializeSlots", () => {
  it("freezes the auto layout without changing what is shown", () => {
    const ch = chapter({ facile: 32 });
    const layout = defaultLayout();
    const before = buildRings(ch, "d", layout);
    const frozen = materializeSlots(ch, layout);
    const after = buildRings(ch, "d", frozen);

    expect(after.map((r) => r.questions.map((q) => q.id))).toEqual(
      before.map((r) => r.questions.map((q) => q.id)),
    );
  });

  it("keeps every question reachable", () => {
    const ch = chapter({ facile: 47 });
    expect(idsInSlots(materializeSlots(ch, defaultLayout())).sort()).toEqual(
      Object.values(ch.levels!).flatMap((l) => l.questions.map((q) => q.id)).sort(),
    );
  });
});

describe("placeQuestionAtLevel", () => {
  it("sends a promoted question to the LAST ring of that difficulty", () => {
    // Two difficult rings (30 difficult questions) + easy ones before them.
    const ch = chapter({ facile: 15, difficile: 30 });
    const slots = materializeSlots(ch, defaultLayout());
    const result = reLevel(ch, slots, "facile_0", "facile", "difficile");

    const rings = buildRings(result.chapter, "d", result.slots).filter((r) => r.kind === "normal");
    const difficultRings = rings.filter((r) => r.level === "difficile");
    expect(difficultRings.length).toBeGreaterThanOrEqual(2);
    // It must land in the furthest difficult ring, not the first one.
    const last = difficultRings[difficultRings.length - 1]!;
    expect(last.questions.map((q) => q.id)).toContain("facile_0");
  });

  it("overflows a full ring up to the cap, then opens a new one", () => {
    const ch = chapter({ facile: 20, difficile: RING_SIZE });
    let slots = oneRingPerLevel(ch, ["facile", "difficile"]);
    let current = ch;

    // Fill the difficult ring from 15 up to the 20 cap — no new ring yet.
    for (let i = 0; i < RING_MAX_OVERFLOW - RING_SIZE; i++) {
      const step = reLevel(current, slots, `facile_${i}`, "facile", "difficile");
      expect(step.createdRing).toBe(false);
      current = step.chapter;
      slots = step.slots;
    }
    let difficultRings = buildRings(current, "d", slots)
      .filter((r) => r.kind === "normal" && r.level === "difficile");
    expect(difficultRings).toHaveLength(1);
    expect(difficultRings[0]!.questions).toHaveLength(RING_MAX_OVERFLOW);

    // The next one is saturated, so it spawns a second difficult ring.
    const overflow = reLevel(current, slots, "facile_9", "facile", "difficile");
    expect(overflow.createdRing).toBe(true);
    difficultRings = buildRings(overflow.chapter, "d", overflow.slots)
      .filter((r) => r.kind === "normal" && r.level === "difficile");
    expect(difficultRings).toHaveLength(2);
    expect(difficultRings[1]!.questions.map((q) => q.id)).toEqual(["facile_9"]);
  });

  it("tops up an existing difficult ring that still has room", () => {
    const ch = chapter({ facile: 20, difficile: 10 });
    const slots = oneRingPerLevel(ch, ["facile", "difficile"]);
    const result = reLevel(ch, slots, "facile_0", "facile", "difficile");

    expect(result.createdRing).toBe(false);
    const difficultRings = buildRings(result.chapter, "d", result.slots)
      .filter((r) => r.kind === "normal" && r.level === "difficile");
    expect(difficultRings).toHaveLength(1);
    expect(difficultRings[0]!.questions).toHaveLength(11);
  });

  it("opens the first ring of a difficulty on the ramp, before the recap", () => {
    const ch = chapter({ facile: 30 });
    const slots = materializeSlots(ch, defaultLayout());
    const result = reLevel(ch, slots, "facile_0", "facile", "maitre");

    expect(result.createdRing).toBe(true);
    const rings = buildRings(result.chapter, "d", result.slots);
    const hard = rings.findIndex((r) => r.kind === "normal" && r.level === "maitre");
    const recap = rings.findIndex((r) => r.kind === "recap");
    expect(hard).toBeGreaterThan(0);
    expect(hard).toBeLessThan(recap); // never after the closing recap
  });

  it("never loses a question while re-levelling", () => {
    const ch = chapter({ facile: 40 });
    const result = reLevel(ch, materializeSlots(ch, defaultLayout()), "facile_7", "facile", "difficile");
    const ids = idsInSlots(result.slots);
    expect(ids).toHaveLength(40);
    expect(new Set(ids).size).toBe(40);
    expect(ids).toContain("facile_7");
  });
});

describe("ring management", () => {
  it("hides an empty ring from players but keeps it editable", () => {
    const ch = chapter({ facile: 20 });
    const slots = addEmptyRing(materializeSlots(ch, defaultLayout()), "difficile");

    // The editor sees it...
    expect(buildRings(ch, "d", slots).some((r) => r.isEmpty)).toBe(true);
    // ...the path served to players does not.
    const layout = layoutWith("ch", slots);
    const served = buildRings(ch, "d", layout).filter((r) => !r.isEmpty);
    expect(served.every((r) => r.questions.length > 0)).toBe(true);
  });

  it("hands a deleted ring's questions to a neighbour rather than dropping them", () => {
    const ch = chapter({ facile: 40 });
    const slots = materializeSlots(ch, defaultLayout());
    const victim = slots.findIndex((s) => s.kind === "normal");
    const result = removeRing(ch, slots, victim);

    expect(result.error).toBeUndefined();
    expect(idsInSlots(result.slots).sort()).toEqual(idsInSlots(slots).sort());
  });

  it("refuses to remove the only recap", () => {
    const ch = chapter({ facile: 20 });
    const slots = materializeSlots(ch, defaultLayout());
    const recap = slots.findIndex((s) => s.kind === "recap");
    expect(removeRing(ch, slots, recap).error).toBeTruthy();
  });

  it("moves a question to another ring exactly once", () => {
    const ch = chapter({ facile: 40 });
    const slots = materializeSlots(ch, defaultLayout());
    const target = slots.map((s) => s.kind).lastIndexOf("normal");
    const next = moveQuestionToRing(slots, "facile_0", target);

    expect(next[target]!.questionIds).toContain("facile_0");
    expect(idsInSlots(next).filter((id) => id === "facile_0")).toHaveLength(1);
  });
});

describe("normalisation safety net", () => {
  it("re-files a question that no ring claims", () => {
    const ch = chapter({ facile: 20 });
    // A stale layout that forgot half the chapter.
    const stale: RingSlot[] = [
      { kind: "normal", questionIds: ["facile_0", "facile_1"] },
      { kind: "recap" },
    ];
    const rings = buildRings(ch, "d", layoutWith("ch", stale));
    const served = rings.filter((r) => r.kind === "normal").flatMap((r) => r.questions.map((q) => q.id));
    expect(served).toHaveLength(20);
  });

  it("ignores ids that no longer exist", () => {
    const ch = chapter({ facile: 5 });
    const stale: RingSlot[] = [
      { kind: "normal", questionIds: ["facile_0", "supprimee_99"] },
      { kind: "recap" },
    ];
    const rings = buildRings(ch, "d", layoutWith("ch", stale));
    const served = rings.filter((r) => r.kind === "normal").flatMap((r) => r.questions.map((q) => q.id));
    expect(served).not.toContain("supprimee_99");
    expect(served).toHaveLength(5);
  });
});
