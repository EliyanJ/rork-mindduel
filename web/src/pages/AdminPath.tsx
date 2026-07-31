import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowDown,
  ArrowUp,
  ChevronDown,
  CircleDashed,
  Crown,
  Globe,
  Loader2,
  Plus,
  RefreshCw,
  RotateCcw,
  Shuffle,
  Sparkles,
  Target,
  Trash2,
  Upload,
} from "lucide-react";

import {
  type Chapter,
  type Content,
  type Discipline,
  type DisciplineKind,
  type Question,
  fetchContent,
  isLegacyChapter,
} from "@/lib/generator";
import { insertQuestion, moveQuestion } from "@/lib/moderation";
import { difficultyPatch, LEVEL_MIDPOINT_SCORE, normalizeLevel } from "@/lib/difficulty";
import {
  type PathLayout,
  type PathLevel,
  type PreviewRing,
  type RingSlot,
  chapterLevelCounts,
  defaultLayout,
  DEFAULT_CHAPTER_ORDER,
  disciplineRings,
  effectiveDisciplineKind,
  fetchPathLayout,
  LEVEL_ORDER,
  mixedRings,
  moveItem,
  orderedChapters,
  orderedDisciplines,
  PATH_LEVEL_LABEL,
  publishPathLayout,
  RING_SIZE,
  slotsFor,
  TIER_LABEL,
  buildRings,
} from "@/lib/pathLayout";
import {
  type DraftQuestion,
  addEmptyRing,
  buildQuestion,
  levelBreakdown,
  levelOfQuestion,
  materializeSlots,
  moveQuestionToRing,
  placeQuestionAtLevel,
  refFor,
  removeQuestionFromSlots,
  removeRing,
  setRingTargetLevel,
} from "@/lib/pathEditor";
import {
  type PendingChange,
  fetchReviewState,
  publishPendingChanges,
  replayChanges,
} from "@/lib/reviewSync";
import { usePendingChanges } from "@/hooks/usePendingChanges";
import PathImportDialog from "@/components/PathImportDialog";
import PathQuestionForm from "@/components/PathQuestionForm";

type LogLevel = "info" | "success" | "warn" | "error";
type LogEntry = { time: string; level: LogLevel; message: string };

/** Where a question just landed, so an edit is never invisible. */
type Highlight = { questionId: string; message: string };

/**
 * Admin "Parcours" tool: the learning path editor.
 *
 * Two stores are edited side by side and published together:
 *  - the **layout** (theme/chapter/ring order, ring membership, theme kind),
 *    which never contains question text and so can't lose content;
 *  - the **catalog**, through the shared pending-decision queue used by
 *    Modération and Calibrage, so a difficulty change here and a moderation
 *    decision there can't overwrite each other.
 *
 * Ring maths lives in `lib/pathLayout.ts` (read) and `lib/pathEditor.ts`
 * (write), the TypeScript twins of the Swift `RingBuilder` — what is previewed
 * here is what ships.
 */
const AdminPath = () => {
  const { changes, setChanges, hydrate } = usePendingChanges();

  const [content, setContent] = useState<Content | null>(null);
  const [layout, setLayout] = useState<PathLayout>(defaultLayout());
  const [layoutDirty, setLayoutDirty] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isPublishing, setIsPublishing] = useState<boolean>(false);
  const [selectedDisciplineId, setSelectedDisciplineId] = useState<string>("");
  const [showMixed, setShowMixed] = useState<boolean>(false);
  const [expandedRingId, setExpandedRingId] = useState<string | null>(null);
  const [composing, setComposing] = useState<{ chapterId: string; slotIndex: number } | null>(null);
  const [importing, setImporting] = useState<string | null>(null);
  const [highlight, setHighlight] = useState<Highlight | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);

  const log = useCallback((level: LogLevel, message: string) => {
    setLogs((prev) => [
      { time: new Date().toLocaleTimeString("fr-FR"), level, message },
      ...prev.slice(0, 49),
    ]);
  }, []);

  const loadAll = useCallback(async () => {
    setIsLoading(true);
    try {
      const [serverContent, serverLayout, serverState] = await Promise.all([
        fetchContent(),
        fetchPathLayout(),
        fetchReviewState().catch(() => null),
      ]);
      const queue = serverState?.changes ?? {};
      // Show the catalog as it *will* be once the queue is published, so the
      // rings on screen already reflect unpublished difficulty changes.
      const { merged } = replayChanges(serverContent, queue);
      hydrate(queue);
      setContent(merged);
      setLayout(serverLayout);
      setLayoutDirty(false);
      setSelectedDisciplineId((current) => {
        if (current && merged.disciplines.some((d) => d.id === current)) return current;
        return orderedDisciplines(merged, serverLayout)[0]?.id ?? "";
      });
      log("success", `Catalogue et organisation chargés (${merged.disciplines.length} thèmes).`);
    } catch (err) {
      log("error", `Chargement impossible : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsLoading(false);
    }
  }, [hydrate, log]);

  const loadRequested = useRef(false);
  useEffect(() => {
    if (loadRequested.current) return;
    loadRequested.current = true;
    void loadAll();
  }, [loadAll]);

  // MARK: - Derived data

  const disciplines: Discipline[] = useMemo(
    () => (content ? orderedDisciplines(content, layout) : []),
    [content, layout],
  );

  const selectedDiscipline = useMemo(
    () => disciplines.find((d) => d.id === selectedDisciplineId) ?? disciplines[0],
    [disciplines, selectedDisciplineId],
  );

  const chapters: Chapter[] = useMemo(
    () => (selectedDiscipline ? orderedChapters(selectedDiscipline, layout) : []),
    [selectedDiscipline, layout],
  );

  const previewRings: PreviewRing[] = useMemo(() => {
    if (!content) return [];
    if (showMixed) return mixedRings(content, layout).slice(0, 60);
    return selectedDiscipline ? disciplineRings(selectedDiscipline, layout) : [];
  }, [content, layout, selectedDiscipline, showMixed]);

  const totals = useMemo(() => {
    let questions = 0;
    let rings = 0;
    let recaps = 0;
    for (const discipline of disciplines) {
      for (const chapter of discipline.chapters) {
        const counts = chapterLevelCounts(chapter);
        questions += LEVEL_ORDER.reduce((sum, level) => sum + counts[level], 0);
      }
      for (const ring of disciplineRings(discipline, layout)) {
        rings += 1;
        if (ring.kind === "recap") recaps += 1;
      }
    }
    return { questions, rings, recaps };
  }, [disciplines, layout]);

  const pathChangeCount = useMemo(
    () => Object.values(changes).filter((c) => c.origin === "path").length,
    [changes],
  );
  const totalChangeCount = Object.keys(changes).length;
  const hasPendingWork = layoutDirty || totalChangeCount > 0;

  // MARK: - Layout helpers

  const mutateLayout = useCallback((next: PathLayout) => {
    setLayout(next);
    setLayoutDirty(true);
  }, []);

  const setSlots = useCallback(
    (chapterId: string, slots: RingSlot[]) => {
      mutateLayout({ ...layout, ringLayout: { ...layout.ringLayout, [chapterId]: slots } });
    },
    [layout, mutateLayout],
  );

  const findChapter = useCallback(
    (source: Content, disciplineId: string, chapterId: string): Chapter | undefined =>
      source.disciplines.find((d) => d.id === disciplineId)?.chapters.find((c) => c.id === chapterId),
    [],
  );

  const flash = useCallback((questionId: string, message: string) => {
    setHighlight({ questionId, message });
    window.setTimeout(() => {
      setHighlight((cur) => (cur?.questionId === questionId ? null : cur));
    }, 9000);
  }, []);

  // MARK: - Ordering

  const moveDiscipline = useCallback(
    (index: number, delta: number) => {
      const order = disciplines.map((d) => d.id);
      mutateLayout({ ...layout, disciplineOrder: moveItem(order, index, index + delta) });
    },
    [disciplines, layout, mutateLayout],
  );

  const setDisciplineKind = useCallback(
    (discipline: Discipline, kind: DisciplineKind) => {
      mutateLayout({
        ...layout,
        disciplineKind: { ...layout.disciplineKind, [discipline.id]: kind },
      });
      log(
        "info",
        kind === "specifique"
          ? `« ${discipline.name} » devient un thème spécifique : il sort du parcours mixte et reste choisissable à part.`
          : `« ${discipline.name} » rejoint la culture générale et réintègre le parcours mixte.`,
      );
    },
    [layout, log, mutateLayout],
  );

  const moveChapter = useCallback(
    (index: number, delta: number) => {
      if (!selectedDiscipline) return;
      const order = chapters.map((c) => c.id);
      mutateLayout({
        ...layout,
        chapterOrder: {
          ...layout.chapterOrder,
          [selectedDiscipline.id]: moveItem(order, index, index + delta),
        },
      });
    },
    [chapters, layout, mutateLayout, selectedDiscipline],
  );

  const moveRing = useCallback(
    (chapter: Chapter, slotIndex: number, delta: number) => {
      setSlots(chapter.id, moveItem(slotsFor(chapter, layout), slotIndex, slotIndex + delta));
    },
    [layout, setSlots],
  );

  const addRecapAfter = useCallback(
    (chapter: Chapter, slotIndex: number) => {
      const slots = [...slotsFor(chapter, layout)];
      slots.splice(slotIndex + 1, 0, { kind: "recap" });
      setSlots(chapter.id, slots);
    },
    [layout, setSlots],
  );

  const deleteRing = useCallback(
    (chapter: Chapter, slotIndex: number) => {
      const result = removeRing(chapter, slotsFor(chapter, layout), slotIndex);
      if (result.error) {
        log("warn", result.error);
        return;
      }
      setSlots(chapter.id, result.slots);
      log("info", `Rond supprimé de « ${chapter.title} » — ses questions ont rejoint le rond voisin.`);
    },
    [layout, log, setSlots],
  );

  const addRing = useCallback(
    (chapter: Chapter, level: PathLevel) => {
      setSlots(chapter.id, addEmptyRing(materializeSlots(chapter, layout), level));
      log(
        "info",
        `Rond ${PATH_LEVEL_LABEL[level].toLowerCase()} ajouté à « ${chapter.title} ». Il reste invisible pour les joueurs tant qu'il est vide.`,
      );
    },
    [layout, log, setSlots],
  );

  const retargetRing = useCallback(
    (chapter: Chapter, slotIndex: number, level: PathLevel) => {
      setSlots(chapter.id, setRingTargetLevel(materializeSlots(chapter, layout), slotIndex, level));
    },
    [layout, setSlots],
  );

  const relocateQuestion = useCallback(
    (chapter: Chapter, questionId: string, targetSlotIndex: number) => {
      setSlots(chapter.id, moveQuestionToRing(materializeSlots(chapter, layout), questionId, targetSlotIndex));
      flash(questionId, "Question déplacée dans le rond choisi.");
    },
    [flash, layout, setSlots],
  );

  const resetChapterRings = useCallback(
    (chapter: Chapter) => {
      const next = { ...layout.ringLayout };
      delete next[chapter.id];
      mutateLayout({ ...layout, ringLayout: next });
      log("info", `« ${chapter.title} » repasse au découpage automatique par difficulté.`);
    },
    [layout, log, mutateLayout],
  );

  const resetChapterOrder = useCallback(() => {
    if (!selectedDiscipline) return;
    const fallback = DEFAULT_CHAPTER_ORDER[selectedDiscipline.id] ?? [];
    mutateLayout({
      ...layout,
      chapterOrder: { ...layout.chapterOrder, [selectedDiscipline.id]: [...fallback] },
    });
    log("info", `Ordre des sous-chapitres de ${selectedDiscipline.name} remis par défaut.`);
  }, [layout, log, mutateLayout, selectedDiscipline]);

  // MARK: - Content edits

  /**
   * Re-levels a question and files it into the furthest ring of that
   * difficulty. The chapter is frozen to explicit ring membership first, so
   * this edit can't reshuffle rings the admin didn't touch.
   */
  const changeDifficulty = useCallback(
    (discipline: Discipline, chapter: Chapter, question: Question, level: PathLevel) => {
      if (!content) return;
      const currentLevel = levelOfQuestion(chapter, question.id);
      if (currentLevel === level) return;

      const frozen = removeQuestionFromSlots(materializeSlots(chapter, layout), question.id);
      const fromRef = refFor(discipline.id, chapter, currentLevel);
      const toRef = refFor(discipline.id, chapter, level);
      const patch = difficultyPatch(LEVEL_MIDPOINT_SCORE[normalizeLevel(level)], "human", {
        reason: "Difficulté fixée à la main depuis Parcours",
      });

      const nextContent = moveQuestion(content, fromRef, toRef, question.id, patch);
      if (nextContent === content) {
        log("error", "Question introuvable à son emplacement actuel — rien n'a été modifié.");
        return;
      }
      const nextChapter = findChapter(nextContent, discipline.id, chapter.id);
      if (!nextChapter) return;

      const placement = placeQuestionAtLevel(nextChapter, frozen, question.id, level);
      setContent(nextContent);
      setSlots(chapter.id, placement.slots);

      const existing = changes[question.id];
      const nextChange: PendingChange =
        existing?.isNew && existing.question
          ? { ...existing, ref: toRef, question: { ...existing.question, ...patch } }
          : { ref: fromRef, question: { ...question, ...patch }, moveTo: toRef, origin: "path" };
      setChanges((prev) => ({ ...prev, [question.id]: nextChange }));

      flash(
        question.id,
        `Passée en ${PATH_LEVEL_LABEL[level].toLowerCase()} → rond ${placement.position} de « ${chapter.title} »${
          placement.createdRing ? " (nouveau rond créé)" : ""
        }.`,
      );
      log(
        "success",
        `« ${question.prompt.slice(0, 60)}… » → ${PATH_LEVEL_LABEL[level]}, rond ${placement.position}${
          placement.createdRing ? " (nouveau)" : ""
        }.`,
      );
    },
    [changes, content, findChapter, flash, layout, log, setChanges, setSlots],
  );

  /** Adds one hand-written question straight into a specific ring. */
  const addQuestion = useCallback(
    (discipline: Discipline, chapter: Chapter, slotIndex: number, draft: DraftQuestion) => {
      if (!content) return;
      const question = buildQuestion(draft, chapter.id);
      const ref = refFor(discipline.id, chapter, draft.level);
      const nextContent = insertQuestion(content, ref, question);
      if (nextContent === content) {
        log("error", "Sous-chapitre introuvable — la question n'a pas été ajoutée.");
        return;
      }
      const slots = materializeSlots(chapter, layout).map((slot, i) =>
        i === slotIndex && slot.kind === "normal"
          ? { ...slot, questionIds: [...(slot.questionIds ?? []), question.id] }
          : slot,
      );
      setContent(nextContent);
      setSlots(chapter.id, slots);
      setChanges((prev) => ({ ...prev, [question.id]: { ref, question, origin: "path", isNew: true } }));
      setComposing(null);
      flash(question.id, "Question créée — en attente de modération.");
      log("success", `Question ajoutée à « ${chapter.title} » (${PATH_LEVEL_LABEL[draft.level]}).`);
    },
    [content, flash, layout, log, setChanges, setSlots],
  );

  /** Bulk-imports converted questions, each landing at its own difficulty. */
  const importQuestions = useCallback(
    (discipline: Discipline, chapter: Chapter, drafts: DraftQuestion[]) => {
      if (!content || drafts.length === 0) return;
      let nextContent = content;
      let slots = materializeSlots(chapter, layout);
      const created: Record<string, PendingChange> = {};

      for (const draft of drafts) {
        const question = buildQuestion(draft, chapter.id);
        const ref = refFor(discipline.id, chapter, draft.level);
        const afterInsert = insertQuestion(nextContent, ref, question);
        if (afterInsert === nextContent) continue;
        nextContent = afterInsert;
        const nextChapter = findChapter(nextContent, discipline.id, chapter.id);
        if (!nextChapter) continue;
        slots = placeQuestionAtLevel(nextChapter, slots, question.id, draft.level).slots;
        created[question.id] = { ref, question, origin: "path", isNew: true };
      }

      const count = Object.keys(created).length;
      if (count === 0) {
        log("warn", "Aucune question n'a pu être importée.");
        return;
      }
      setContent(nextContent);
      setSlots(chapter.id, slots);
      setChanges((prev) => ({ ...prev, ...created }));
      setImporting(null);
      log("success", `${count} question(s) importée(s) dans « ${chapter.title} », en attente de modération.`);
    },
    [content, findChapter, layout, log, setChanges, setSlots],
  );

  // MARK: - Publish

  const publish = useCallback(async () => {
    setIsPublishing(true);
    try {
      if (totalChangeCount > 0) {
        log("info", "Publication : fusion des changements de contenu sur la version serveur la plus récente…");
        const result = await publishPendingChanges(changes);
        if (result.skipped > 0) {
          log(
            "warn",
            `${result.skipped} décision(s) introuvables côté serveur — elles restent en attente, rien n'a été effacé.`,
          );
        }
        const kept = new Set(result.skippedIds);
        setChanges((prev) => {
          const next: Record<string, PendingChange> = {};
          for (const [id, change] of Object.entries(prev)) if (kept.has(id)) next[id] = change;
          return next;
        });
        log(
          "success",
          `Contenu publié ✓ v${result.version} — ${result.questionCount} questions en ligne, ${result.applied} changement(s) intégré(s).`,
        );
      }

      const layoutResult = await publishPathLayout(layout);
      setLayoutDirty(false);
      log(
        "success",
        `Organisation publiée ✓ v${layoutResult.version}. L'app la récupère au prochain lancement — aucun nouveau build TestFlight n'est nécessaire.`,
      );
    } catch (err) {
      log("error", `Publication échouée : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsPublishing(false);
    }
  }, [changes, layout, log, setChanges, totalChangeCount]);

  // MARK: - Render

  if (isLoading) {
    return (
      <div className="grid min-h-[70vh] place-items-center text-white/40">
        <div className="flex items-center gap-3">
          <Loader2 className="h-5 w-5 animate-spin" />
          <span className="text-sm font-semibold">Chargement du parcours…</span>
        </div>
      </div>
    );
  }

  const importChapter = importing
    ? chapters.find((c) => c.id === importing) ?? null
    : null;

  return (
    <div className="mx-auto max-w-[1600px] px-4 py-6 text-white">
      <header className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight">Parcours</h1>
          <p className="mt-1 text-sm text-white/50">
            {totals.questions.toLocaleString("fr-FR")} questions · {totals.rings} ronds ·{" "}
            {totals.recaps} récaps · {RING_SIZE} questions par rond
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => void loadAll()}
            className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-xs font-bold text-white/60 transition hover:bg-white/[0.06] hover:text-white"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Recharger
          </button>
          <button
            type="button"
            onClick={() => {
              mutateLayout(defaultLayout());
              log("info", "Organisation complète remise par défaut (non publiée).");
            }}
            className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-xs font-bold text-white/60 transition hover:border-amber-400/40 hover:bg-amber-500/10 hover:text-amber-200"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Tout par défaut
          </button>
          <button
            type="button"
            onClick={() => void publish()}
            disabled={isPublishing || !hasPendingWork}
            className="flex items-center gap-1.5 rounded-lg bg-indigo-500 px-4 py-2 text-xs font-extrabold text-white shadow-[0_8px_22px_-10px_rgba(99,102,241,0.9)] transition hover:bg-indigo-400 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {isPublishing ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Upload className="h-3.5 w-3.5" />}
            {hasPendingWork ? "Publier" : "À jour"}
            {totalChangeCount > 0 && (
              <span className="ml-0.5 rounded-full bg-white/25 px-1.5 py-px text-[10px] font-black">
                {totalChangeCount}
              </span>
            )}
          </button>
        </div>
      </header>

      {hasPendingWork && (
        <div className="mb-4 rounded-xl border border-amber-400/25 bg-amber-500/[0.07] px-4 py-3 text-xs font-semibold text-amber-100/90">
          {layoutDirty && "Organisation modifiée. "}
          {totalChangeCount > 0 &&
            `${totalChangeCount} changement(s) de contenu en attente${pathChangeCount > 0 ? ` (dont ${pathChangeCount} depuis Parcours)` : ""}. `}
          L'application garde la version actuelle tant que tu n'as pas publié. Une sauvegarde de la version
          précédente est prise automatiquement.
        </div>
      )}

      {highlight && (
        <div className="mb-4 flex items-center gap-2 rounded-xl border border-emerald-400/30 bg-emerald-500/[0.08] px-4 py-2.5 text-xs font-bold text-emerald-100">
          <Target className="h-4 w-4 shrink-0" />
          {highlight.message}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_400px]">
        <section className="space-y-5">
          <DisciplineTimeline
            disciplines={disciplines}
            layout={layout}
            selectedId={selectedDiscipline?.id ?? ""}
            onSelect={(id) => {
              setSelectedDisciplineId(id);
              setShowMixed(false);
            }}
            onMove={moveDiscipline}
            onSetKind={setDisciplineKind}
          />

          {selectedDiscipline && (
            <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 className="text-sm font-extrabold tracking-tight">
                  Sous-chapitres de {selectedDiscipline.name}
                </h2>
                <button
                  type="button"
                  onClick={resetChapterOrder}
                  className="flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-[11px] font-bold text-white/50 transition hover:bg-white/[0.06] hover:text-white"
                >
                  <RotateCcw className="h-3 w-3" />
                  Ordre par défaut
                </button>
              </div>

              <div className="space-y-3">
                {chapters.map((chapter, index) => (
                  <ChapterCard
                    key={chapter.id}
                    chapter={chapter}
                    discipline={selectedDiscipline}
                    index={index}
                    total={chapters.length}
                    layout={layout}
                    expandedRingId={expandedRingId}
                    composing={composing}
                    highlightId={highlight?.questionId ?? null}
                    onToggleRing={(id) => setExpandedRingId((cur) => (cur === id ? null : id))}
                    onMoveChapter={moveChapter}
                    onMoveRing={moveRing}
                    onAddRecap={addRecapAfter}
                    onDeleteRing={deleteRing}
                    onAddRing={addRing}
                    onRetargetRing={retargetRing}
                    onResetRings={resetChapterRings}
                    onChangeDifficulty={changeDifficulty}
                    onRelocateQuestion={relocateQuestion}
                    onCompose={setComposing}
                    onAddQuestion={addQuestion}
                    onOpenImport={setImporting}
                  />
                ))}
              </div>
            </div>
          )}
        </section>

        <aside className="space-y-4">
          <PathPreview
            rings={previewRings}
            disciplines={disciplines}
            showMixed={showMixed}
            onToggleMixed={setShowMixed}
            disciplineName={selectedDiscipline?.name ?? ""}
          />
          <LogPanel logs={logs} />
        </aside>
      </div>

      {importChapter && selectedDiscipline && (
        <PathImportDialog
          chapter={importChapter}
          disciplineName={selectedDiscipline.name}
          onClose={() => setImporting(null)}
          onImport={(drafts) => importQuestions(selectedDiscipline, importChapter, drafts)}
        />
      )}
    </div>
  );
};

// MARK: - Discipline timeline

const DisciplineTimeline = ({
  disciplines,
  layout,
  selectedId,
  onSelect,
  onMove,
  onSetKind,
}: {
  disciplines: Discipline[];
  layout: PathLayout;
  selectedId: string;
  onSelect: (id: string) => void;
  onMove: (index: number, delta: number) => void;
  onSetKind: (discipline: Discipline, kind: DisciplineKind) => void;
}) => (
  <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
    <div className="mb-1 flex flex-wrap items-center justify-between gap-2">
      <h2 className="text-sm font-extrabold tracking-tight">Ordre des thèmes</h2>
      <p className="text-[11px] font-semibold text-white/35">
        Les thèmes spécifiques sont exclus du parcours mixte.
      </p>
    </div>
    <div className="mt-3 space-y-1.5">
      {disciplines.map((discipline, index) => {
        const active = discipline.id === selectedId;
        const kind = effectiveDisciplineKind(discipline, layout);
        const isSpecific = kind === "specifique";
        const questionCount = discipline.chapters.reduce((sum, chapter) => {
          const counts = chapterLevelCounts(chapter);
          return sum + LEVEL_ORDER.reduce((s, level) => s + counts[level], 0);
        }, 0);

        return (
          <div
            key={discipline.id}
            className={`flex flex-wrap items-center gap-2 rounded-xl border px-2 py-1.5 transition ${
              active
                ? "border-indigo-400/50 bg-indigo-500/15"
                : "border-white/10 bg-white/[0.03] hover:bg-white/[0.06]"
            }`}
          >
            <div className="flex flex-col">
              <button
                type="button"
                onClick={() => onMove(index, -1)}
                disabled={index === 0}
                className="rounded text-white/35 transition hover:text-white disabled:opacity-20"
                aria-label={`Monter ${discipline.name}`}
              >
                <ArrowUp className="h-3 w-3" />
              </button>
              <button
                type="button"
                onClick={() => onMove(index, 1)}
                disabled={index === disciplines.length - 1}
                className="rounded text-white/35 transition hover:text-white disabled:opacity-20"
                aria-label={`Descendre ${discipline.name}`}
              >
                <ArrowDown className="h-3 w-3" />
              </button>
            </div>

            <button
              type="button"
              onClick={() => onSelect(discipline.id)}
              className="flex min-w-0 flex-1 items-center gap-2 px-1 text-left text-xs font-bold"
            >
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{ backgroundColor: discipline.colorHex }}
              />
              <span className={`truncate ${active ? "text-white" : "text-white/65"}`}>
                {discipline.name}
              </span>
              <span
                className={`shrink-0 rounded px-1.5 py-0.5 text-[9px] font-extrabold uppercase tracking-wide ${
                  isSpecific ? "bg-fuchsia-500/20 text-fuchsia-200" : "bg-sky-500/15 text-sky-200"
                }`}
              >
                {isSpecific ? "Spécifique" : "Commun"}
              </span>
              <span className="shrink-0 text-[10px] font-semibold text-white/30">
                {questionCount.toLocaleString("fr-FR")} q · #{index + 1}
              </span>
            </button>

            <div className="flex shrink-0 overflow-hidden rounded-lg border border-white/10">
              <button
                type="button"
                onClick={() => onSetKind(discipline, "generale")}
                className={`flex items-center gap-1 px-2 py-1 text-[10px] font-bold transition ${
                  !isSpecific ? "bg-sky-500/25 text-sky-100" : "text-white/40 hover:text-white"
                }`}
                title="Inclus dans le parcours mixte"
              >
                <Globe className="h-3 w-3" />
                Commun
              </button>
              <button
                type="button"
                onClick={() => onSetKind(discipline, "specifique")}
                className={`flex items-center gap-1 px-2 py-1 text-[10px] font-bold transition ${
                  isSpecific ? "bg-fuchsia-500/25 text-fuchsia-100" : "text-white/40 hover:text-white"
                }`}
                title="Exclu du parcours mixte, choisissable à part"
              >
                <Target className="h-3 w-3" />
                Spécifique
              </button>
            </div>
          </div>
        );
      })}
    </div>
  </div>
);

// MARK: - Chapter card

const ChapterCard = ({
  chapter,
  discipline,
  index,
  total,
  layout,
  expandedRingId,
  composing,
  highlightId,
  onToggleRing,
  onMoveChapter,
  onMoveRing,
  onAddRecap,
  onDeleteRing,
  onAddRing,
  onRetargetRing,
  onResetRings,
  onChangeDifficulty,
  onRelocateQuestion,
  onCompose,
  onAddQuestion,
  onOpenImport,
}: {
  chapter: Chapter;
  discipline: Discipline;
  index: number;
  total: number;
  layout: PathLayout;
  expandedRingId: string | null;
  composing: { chapterId: string; slotIndex: number } | null;
  highlightId: string | null;
  onToggleRing: (id: string) => void;
  onMoveChapter: (index: number, delta: number) => void;
  onMoveRing: (chapter: Chapter, slotIndex: number, delta: number) => void;
  onAddRecap: (chapter: Chapter, slotIndex: number) => void;
  onDeleteRing: (chapter: Chapter, slotIndex: number) => void;
  onAddRing: (chapter: Chapter, level: PathLevel) => void;
  onRetargetRing: (chapter: Chapter, slotIndex: number, level: PathLevel) => void;
  onResetRings: (chapter: Chapter) => void;
  onChangeDifficulty: (d: Discipline, c: Chapter, q: Question, level: PathLevel) => void;
  onRelocateQuestion: (chapter: Chapter, questionId: string, targetSlotIndex: number) => void;
  onCompose: (target: { chapterId: string; slotIndex: number } | null) => void;
  onAddQuestion: (d: Discipline, c: Chapter, slotIndex: number, draft: DraftQuestion) => void;
  onOpenImport: (chapterId: string) => void;
}) => {
  const [newRingLevel, setNewRingLevel] = useState<PathLevel>("difficile");

  const rings = useMemo(() => buildRings(chapter, discipline.id, layout), [chapter, discipline.id, layout]);
  const counts = useMemo(() => chapterLevelCounts(chapter), [chapter]);
  const questionCount = LEVEL_ORDER.reduce((sum, level) => sum + counts[level], 0);
  const normalRings = rings.filter((r) => r.kind === "normal");
  const isLegacy = isLegacyChapter(chapter);

  /** Destinations offered by the "déplacer vers" picker. */
  const ringOptions = normalRings.map((ring) => ({
    slotIndex: ring.slotIndex,
    label: `Rond ${ring.position} · ${PATH_LEVEL_LABEL[ring.level]}${ring.isEmpty ? " (vide)" : ` · ${ring.questions.length}`}`,
  }));

  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.02]">
      <div className="flex flex-wrap items-center gap-2 border-b border-white/5 px-3 py-2.5">
        <div className="flex flex-col">
          <button
            type="button"
            onClick={() => onMoveChapter(index, -1)}
            disabled={index === 0}
            className="rounded text-white/35 transition hover:text-white disabled:opacity-20"
            aria-label={`Monter ${chapter.title}`}
          >
            <ArrowUp className="h-3 w-3" />
          </button>
          <button
            type="button"
            onClick={() => onMoveChapter(index, 1)}
            disabled={index === total - 1}
            className="rounded text-white/35 transition hover:text-white disabled:opacity-20"
            aria-label={`Descendre ${chapter.title}`}
          >
            <ArrowDown className="h-3 w-3" />
          </button>
        </div>
        <span className="grid h-6 w-6 place-items-center rounded-md bg-white/[0.06] text-[11px] font-extrabold text-white/50">
          {index + 1}
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-bold">{chapter.title}</p>
          <p className="text-[11px] font-semibold text-white/35">
            <span className="text-white/55">{questionCount} questions</span>
            {levelBreakdown(counts) && ` · ${levelBreakdown(counts)}`}
            {" · "}
            {normalRings.length} ronds · {rings.filter((r) => r.kind === "recap").length} récap
          </p>
        </div>
        <button
          type="button"
          onClick={() => onOpenImport(chapter.id)}
          className="flex items-center gap-1 rounded-lg border border-white/10 px-2 py-1 text-[10px] font-bold text-white/45 transition hover:border-indigo-400/40 hover:text-indigo-200"
        >
          <Sparkles className="h-3 w-3" />
          Importer
        </button>
        <button
          type="button"
          onClick={() => onResetRings(chapter)}
          className="rounded-lg border border-white/10 px-2 py-1 text-[10px] font-bold text-white/45 transition hover:bg-white/[0.06] hover:text-white"
        >
          Ronds par défaut
        </button>
      </div>

      <div className="space-y-1.5 p-2.5">
        {rings.map((ring) => (
          <RingRow
            key={ring.id}
            ring={ring}
            chapter={chapter}
            discipline={discipline}
            ringCount={rings.length}
            ringOptions={ringOptions}
            isExpanded={expandedRingId === ring.id}
            isComposing={composing?.chapterId === chapter.id && composing.slotIndex === ring.slotIndex}
            highlightId={highlightId}
            isLegacy={isLegacy}
            onToggle={() => onToggleRing(ring.id)}
            onMove={(delta) => onMoveRing(chapter, ring.slotIndex, delta)}
            onAddRecap={() => onAddRecap(chapter, ring.slotIndex)}
            onDelete={() => onDeleteRing(chapter, ring.slotIndex)}
            onRetarget={(level) => onRetargetRing(chapter, ring.slotIndex, level)}
            onChangeDifficulty={(question, level) => onChangeDifficulty(discipline, chapter, question, level)}
            onRelocate={(questionId, slotIndex) => onRelocateQuestion(chapter, questionId, slotIndex)}
            onCompose={(open) => onCompose(open ? { chapterId: chapter.id, slotIndex: ring.slotIndex } : null)}
            onAddQuestion={(draft) => onAddQuestion(discipline, chapter, ring.slotIndex, draft)}
          />
        ))}

        <div className="flex flex-wrap items-center gap-1.5 pt-1">
          <select
            value={newRingLevel}
            onChange={(e) => setNewRingLevel(e.target.value as PathLevel)}
            className="rounded-md border border-white/10 bg-[#161923] px-2 py-1 text-[10px] font-bold text-white/70 outline-none"
          >
            {LEVEL_ORDER.map((level) => (
              <option key={level} value={level}>{PATH_LEVEL_LABEL[level]}</option>
            ))}
          </select>
          <button
            type="button"
            onClick={() => onAddRing(chapter, newRingLevel)}
            className="flex items-center gap-1 rounded-md border border-dashed border-white/20 px-2.5 py-1 text-[10px] font-bold text-white/45 transition hover:border-indigo-400/50 hover:text-indigo-200"
          >
            <Plus className="h-3 w-3" />
            Ajouter un rond
          </button>
        </div>
      </div>
    </div>
  );
};

// MARK: - Ring row

const RingRow = ({
  ring,
  chapter,
  discipline,
  ringCount,
  ringOptions,
  isExpanded,
  isComposing,
  highlightId,
  isLegacy,
  onToggle,
  onMove,
  onAddRecap,
  onDelete,
  onRetarget,
  onChangeDifficulty,
  onRelocate,
  onCompose,
  onAddQuestion,
}: {
  ring: PreviewRing;
  chapter: Chapter;
  discipline: Discipline;
  ringCount: number;
  ringOptions: { slotIndex: number; label: string }[];
  isExpanded: boolean;
  isComposing: boolean;
  highlightId: string | null;
  isLegacy: boolean;
  onToggle: () => void;
  onMove: (delta: number) => void;
  onAddRecap: () => void;
  onDelete: () => void;
  onRetarget: (level: PathLevel) => void;
  onChangeDifficulty: (question: Question, level: PathLevel) => void;
  onRelocate: (questionId: string, slotIndex: number) => void;
  onCompose: (open: boolean) => void;
  onAddQuestion: (draft: DraftQuestion) => void;
}) => {
  const isRecap = ring.kind === "recap";
  const shown = isRecap ? ring.questions.slice(0, RING_SIZE) : ring.questions;
  const isOverflowing = !isRecap && ring.questions.length > RING_SIZE;

  return (
    <div
      className={`rounded-lg border ${
        isRecap
          ? "border-amber-400/30 bg-amber-500/[0.06]"
          : ring.isEmpty
            ? "border-orange-400/40 bg-orange-500/[0.07]"
            : "border-white/10 bg-white/[0.02]"
      }`}
    >
      <div className="flex flex-wrap items-center gap-2 px-2.5 py-2">
        <div className="flex flex-col">
          <button
            type="button"
            onClick={() => onMove(-1)}
            disabled={ring.slotIndex === 0}
            className="text-white/30 transition hover:text-white disabled:opacity-20"
            aria-label="Monter le rond"
          >
            <ArrowUp className="h-3 w-3" />
          </button>
          <button
            type="button"
            onClick={() => onMove(1)}
            disabled={ring.slotIndex === ringCount - 1}
            className="text-white/30 transition hover:text-white disabled:opacity-20"
            aria-label="Descendre le rond"
          >
            <ArrowDown className="h-3 w-3" />
          </button>
        </div>

        <span
          className={`grid h-7 w-7 shrink-0 place-items-center rounded-full text-[11px] font-extrabold ${
            isRecap
              ? "bg-amber-400 text-black"
              : ring.isEmpty
                ? "bg-orange-400/30 text-orange-100"
                : "bg-indigo-500/80 text-white"
          }`}
        >
          {isRecap ? <Crown className="h-3.5 w-3.5" /> : ring.isEmpty ? <CircleDashed className="h-3.5 w-3.5" /> : ring.position}
        </span>

        <button type="button" onClick={onToggle} className="flex min-w-0 flex-1 items-center gap-2 text-left">
          <span className="truncate text-xs font-bold">
            {isRecap ? "Récap du sous-chapitre" : `Rond ${ring.position}`}
          </span>
          <span
            className={`shrink-0 rounded px-1.5 py-0.5 text-[9px] font-extrabold uppercase ${
              ring.tier === "pointu"
                ? "bg-rose-500/15 text-rose-200"
                : ring.tier === "solide"
                  ? "bg-sky-500/15 text-sky-200"
                  : "bg-emerald-500/15 text-emerald-200"
            }`}
          >
            {TIER_LABEL[ring.tier]}
          </span>
          {!isRecap && (
            <span className="shrink-0 rounded bg-white/[0.06] px-1.5 py-0.5 text-[9px] font-bold text-white/45">
              {PATH_LEVEL_LABEL[ring.level]}
            </span>
          )}
          <span
            className={`shrink-0 text-[10px] font-semibold ${
              isOverflowing ? "text-amber-300/80" : "text-white/35"
            }`}
          >
            {isRecap
              ? `${RING_SIZE} sur ${ring.questions.length} candidates`
              : ring.isEmpty
                ? "vide — invisible pour les joueurs"
                : `${ring.questions.length} questions`}
          </span>
          <ChevronDown
            className={`ml-auto h-3.5 w-3.5 shrink-0 text-white/30 transition ${isExpanded ? "rotate-180" : ""}`}
          />
        </button>

        {!isRecap && (
          <select
            value={ring.level}
            onChange={(e) => onRetarget(e.target.value as PathLevel)}
            className="shrink-0 rounded-md border border-white/10 bg-[#161923] px-1.5 py-1 text-[10px] font-bold text-white/60 outline-none"
            title="Difficulté visée par ce rond"
          >
            {LEVEL_ORDER.map((level) => (
              <option key={level} value={level}>{PATH_LEVEL_LABEL[level]}</option>
            ))}
          </select>
        )}

        {!isRecap && (
          <button
            type="button"
            onClick={onAddRecap}
            className="shrink-0 rounded p-1 text-white/30 transition hover:text-amber-300"
            title="Insérer un récap après ce rond"
            aria-label="Insérer un récap après ce rond"
          >
            <Crown className="h-3.5 w-3.5" />
          </button>
        )}
        <button
          type="button"
          onClick={onDelete}
          className="shrink-0 rounded p-1 text-white/30 transition hover:text-rose-300"
          title={isRecap ? "Supprimer ce récap" : "Supprimer ce rond (ses questions rejoignent le rond voisin)"}
          aria-label="Supprimer ce rond"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>

      {isExpanded && (
        <div className="space-y-1 border-t border-white/5 px-2.5 py-2">
          {isRecap && (
            <p className="mb-1.5 text-[10px] font-semibold text-amber-200/70">
              Le récap est personnalisé : chaque joueur reçoit d'abord ses propres erreurs, complétées par les
              questions les plus dures ci-dessous.
            </p>
          )}
          {isOverflowing && (
            <p className="mb-1.5 text-[10px] font-semibold text-amber-300/80">
              Ce rond dépasse {RING_SIZE} questions : il n'y en avait pas assez pour en former un nouveau
              complet.
            </p>
          )}
          {ring.isEmpty && !isRecap && (
            <p className="mb-1.5 text-[10px] font-semibold text-orange-200/80">
              Rond vide. Ajoute-lui des questions ou déplaces-en depuis un autre rond — tant qu'il est vide,
              les joueurs ne le voient pas.
            </p>
          )}

          {shown.map((question, qIndex) => (
            <QuestionRow
              key={question.id}
              question={question}
              index={qIndex}
              chapter={chapter}
              isRecap={isRecap}
              isLegacy={isLegacy}
              isHighlighted={highlightId === question.id}
              ringOptions={ringOptions}
              currentSlotIndex={ring.slotIndex}
              onChangeDifficulty={(level) => onChangeDifficulty(question, level)}
              onRelocate={(slotIndex) => onRelocate(question.id, slotIndex)}
            />
          ))}

          {!isRecap && (
            <div className="pt-1.5">
              {isComposing ? (
                <PathQuestionForm
                  chapter={chapter}
                  defaultLevel={ring.level}
                  ringLabel={`Rond ${ring.position} · ${discipline.name}`}
                  onCancel={() => onCompose(false)}
                  onSubmit={onAddQuestion}
                />
              ) : (
                <button
                  type="button"
                  onClick={() => onCompose(true)}
                  className="flex w-full items-center justify-center gap-1.5 rounded-md border border-dashed border-white/15 py-1.5 text-[10px] font-bold text-white/40 transition hover:border-indigo-400/50 hover:text-indigo-200"
                >
                  <Plus className="h-3 w-3" />
                  Ajouter une question à ce rond
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

// MARK: - Question row

const QuestionRow = ({
  question,
  index,
  chapter,
  isRecap,
  isLegacy,
  isHighlighted,
  ringOptions,
  currentSlotIndex,
  onChangeDifficulty,
  onRelocate,
}: {
  question: Question;
  index: number;
  chapter: Chapter;
  isRecap: boolean;
  isLegacy: boolean;
  isHighlighted: boolean;
  ringOptions: { slotIndex: number; label: string }[];
  currentSlotIndex: number;
  onChangeDifficulty: (level: PathLevel) => void;
  onRelocate: (slotIndex: number) => void;
}) => {
  const level = levelOfQuestion(chapter, question.id);

  return (
    <div
      className={`flex items-start gap-2 rounded-md px-2 py-1.5 text-[11px] transition ${
        isHighlighted ? "bg-emerald-500/15 ring-1 ring-emerald-400/40" : "bg-black/20"
      }`}
    >
      <span className="mt-0.5 w-4 shrink-0 text-right font-mono text-white/25">{index + 1}</span>
      <div className="min-w-0 flex-1">
        <p className="text-white/80">{question.prompt}</p>
        <p className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[10px] font-semibold">
          <span className="text-emerald-300/80">{question.answer}</span>
          <span className="text-white/25">·</span>
          <span className="text-white/35">{question.familiarity ?? "non classé"}</span>
          <span className="text-white/25">·</span>
          <span className="font-mono text-white/25">{question.id}</span>
          {question.moderationStatus && (
            <span
              className={
                question.moderationStatus === "approved"
                  ? "text-emerald-300/70"
                  : question.moderationStatus === "rejected"
                    ? "text-rose-300/70"
                    : "text-amber-300/70"
              }
            >
              {question.moderationStatus}
            </span>
          )}
          {question.difficultySource === "human" && (
            <span className="rounded bg-emerald-500/15 px-1 py-px text-[9px] text-emerald-200/80">
              difficulté validée
            </span>
          )}
        </p>
      </div>

      {!isRecap && (
        <div className="flex shrink-0 flex-col items-end gap-1">
          <select
            value={level}
            disabled={isLegacy}
            onChange={(e) => onChangeDifficulty(e.target.value as PathLevel)}
            title={
              isLegacy
                ? "Ce sous-chapitre utilise l'ancien format sans niveaux."
                : "Changer la difficulté déplace la question vers le rond correspondant"
            }
            className="rounded border border-white/10 bg-[#161923] px-1.5 py-0.5 text-[10px] font-bold text-white/70 outline-none disabled:opacity-30"
          >
            {LEVEL_ORDER.map((l) => (
              <option key={l} value={l}>{PATH_LEVEL_LABEL[l]}</option>
            ))}
          </select>
          {ringOptions.length > 1 && (
            <select
              value={currentSlotIndex}
              onChange={(e) => onRelocate(Number(e.target.value))}
              title="Déplacer vers un autre rond"
              className="max-w-[170px] rounded border border-white/10 bg-[#161923] px-1.5 py-0.5 text-[10px] font-semibold text-white/50 outline-none"
            >
              {ringOptions.map((option) => (
                <option key={option.slotIndex} value={option.slotIndex}>{option.label}</option>
              ))}
            </select>
          )}
        </div>
      )}
    </div>
  );
};

// MARK: - Player preview

const PathPreview = ({
  rings,
  disciplines,
  showMixed,
  onToggleMixed,
  disciplineName,
}: {
  rings: PreviewRing[];
  disciplines: Discipline[];
  showMixed: boolean;
  onToggleMixed: (value: boolean) => void;
  disciplineName: string;
}) => {
  const colorOf = useCallback(
    (disciplineId: string) => disciplines.find((d) => d.id === disciplineId)?.colorHex ?? "#6366f1",
    [disciplines],
  );

  return (
    <div className="sticky top-16 rounded-2xl border border-white/10 bg-white/[0.02] p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h2 className="text-sm font-extrabold tracking-tight">Aperçu joueur</h2>
        <button
          type="button"
          onClick={() => onToggleMixed(!showMixed)}
          className={`flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-[11px] font-bold transition ${
            showMixed
              ? "border-indigo-400/50 bg-indigo-500/15 text-white"
              : "border-white/10 text-white/50 hover:bg-white/[0.06] hover:text-white"
          }`}
        >
          <Shuffle className="h-3 w-3" />
          Parcours mixte
        </button>
      </div>
      <p className="mb-3 text-[11px] font-semibold text-white/35">
        {showMixed
          ? "Rotation d'un rond par thème commun, 60 premiers ronds. Les thèmes spécifiques en sont exclus."
          : `Chemin de ${disciplineName} tel qu'il apparaît dans l'app.`}
      </p>

      <div className="max-h-[560px] overflow-y-auto pr-1">
        <div className="flex flex-col items-center gap-1.5 py-2">
          {rings.map((ring, index) => {
            const isRecap = ring.kind === "recap";
            const offsets = [0, -34, 0, 34];
            const offset = isRecap ? 0 : offsets[index % offsets.length]!;
            return (
              <div
                key={ring.id}
                className="flex flex-col items-center"
                style={{ transform: `translateX(${offset}px)` }}
              >
                {index > 0 && <span className="my-0.5 h-3 w-[3px] rounded-full bg-white/10" />}
                <div
                  className={`grid place-items-center rounded-full font-extrabold text-white shadow-lg ${
                    isRecap ? "h-14 w-14 text-base" : "h-10 w-10 text-xs"
                  }`}
                  style={{
                    backgroundColor: isRecap ? "#FFB020" : colorOf(ring.disciplineId),
                    boxShadow: isRecap ? "0 6px 20px -6px rgba(255,176,32,0.7)" : undefined,
                  }}
                  title={`${ring.chapterTitle} — ${isRecap ? "Récap" : `Rond ${ring.position}`}`}
                >
                  {isRecap ? <Crown className="h-6 w-6" /> : ring.position}
                </div>
                <span className="mt-0.5 max-w-[150px] truncate text-center text-[9px] font-bold text-white/45">
                  {isRecap ? `Récap · ${ring.chapterTitle}` : ring.chapterTitle}
                </span>
              </div>
            );
          })}
          {rings.length === 0 && (
            <p className="py-8 text-xs font-semibold text-white/30">Aucun rond à afficher.</p>
          )}
        </div>
      </div>
    </div>
  );
};

// MARK: - Logs

const LogPanel = ({ logs }: { logs: LogEntry[] }) => {
  if (logs.length === 0) return null;
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-3">
      <h3 className="mb-2 text-[11px] font-extrabold uppercase tracking-wide text-white/40">Journal</h3>
      <div className="max-h-52 space-y-1 overflow-y-auto">
        {logs.map((entry, index) => (
          <p
            key={`${entry.time}-${index}`}
            className={`text-[11px] font-medium ${
              entry.level === "error"
                ? "text-rose-300"
                : entry.level === "success"
                  ? "text-emerald-300"
                  : entry.level === "warn"
                    ? "text-amber-300"
                    : "text-white/45"
            }`}
          >
            <span className="mr-1.5 font-mono text-white/25">{entry.time}</span>
            {entry.message}
          </p>
        ))}
      </div>
    </div>
  );
};

export default AdminPath;
