import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowDown,
  ArrowUp,
  ChevronDown,
  Crown,
  Loader2,
  Plus,
  RefreshCw,
  RotateCcw,
  Shuffle,
  Trash2,
  Upload,
} from "lucide-react";

import { type Chapter, type Content, type Discipline, fetchContent } from "@/lib/generator";
import {
  type PathLayout,
  type PreviewRing,
  type RingSlot,
  TIER_LABEL,
  buildRings,
  defaultLayout,
  DEFAULT_CHAPTER_ORDER,
  disciplineRings,
  fetchPathLayout,
  mixedRings,
  moveItem,
  normalizeSlots,
  orderedChapters,
  orderedDisciplines,
  publishPathLayout,
  RING_SIZE,
} from "@/lib/pathLayout";

type LogLevel = "info" | "success" | "warn" | "error";
type LogEntry = { time: string; level: LogLevel; message: string };

/**
 * Admin "Parcours" tool: reorder the learning path (disciplines, sub-chapters,
 * rings) and preview it exactly as players will see it.
 *
 * The ring maths lives in `lib/pathLayout.ts`, which is the TypeScript twin of
 * the Swift `RingBuilder` — so what is previewed here is what ships.
 */
const AdminPath = () => {
  const [content, setContent] = useState<Content | null>(null);
  const [layout, setLayout] = useState<PathLayout>(defaultLayout());
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isPublishing, setIsPublishing] = useState<boolean>(false);
  const [isDirty, setIsDirty] = useState<boolean>(false);
  const [selectedDisciplineId, setSelectedDisciplineId] = useState<string>("");
  const [showMixed, setShowMixed] = useState<boolean>(false);
  const [expandedRingId, setExpandedRingId] = useState<string | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);

  const log = useCallback((level: LogLevel, message: string) => {
    setLogs((prev) => [
      { time: new Date().toLocaleTimeString("fr-FR"), level, message },
      ...prev.slice(0, 39),
    ]);
  }, []);

  const loadAll = useCallback(async () => {
    setIsLoading(true);
    try {
      const [loadedContent, loadedLayout] = await Promise.all([fetchContent(), fetchPathLayout()]);
      setContent(loadedContent);
      setLayout(loadedLayout);
      setIsDirty(false);
      setSelectedDisciplineId((current) => {
        if (current && loadedContent.disciplines.some((d) => d.id === current)) return current;
        return orderedDisciplines(loadedContent, loadedLayout)[0]?.id ?? "";
      });
      log("success", `Catalogue et organisation chargés (${loadedContent.disciplines.length} thèmes)`);
    } catch (err) {
      log("error", `Chargement impossible : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsLoading(false);
    }
  }, [log]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

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
    if (!content) return { rings: 0, recaps: 0, questions: 0 };
    let rings = 0;
    let recaps = 0;
    let questions = 0;
    for (const discipline of disciplines) {
      for (const ring of disciplineRings(discipline, layout)) {
        rings += 1;
        if (ring.kind === "recap") recaps += 1;
        else questions += ring.questions.length;
      }
    }
    return { rings, recaps, questions };
  }, [content, disciplines, layout]);

  // MARK: - Layout mutations

  const mutate = useCallback((next: PathLayout) => {
    setLayout(next);
    setIsDirty(true);
  }, []);

  const moveDiscipline = useCallback(
    (index: number, delta: number) => {
      const order = disciplines.map((d) => d.id);
      mutate({ ...layout, disciplineOrder: moveItem(order, index, index + delta) });
    },
    [disciplines, layout, mutate],
  );

  const moveChapter = useCallback(
    (index: number, delta: number) => {
      if (!selectedDiscipline) return;
      const order = chapters.map((c) => c.id);
      mutate({
        ...layout,
        chapterOrder: {
          ...layout.chapterOrder,
          [selectedDiscipline.id]: moveItem(order, index, index + delta),
        },
      });
    },
    [chapters, layout, mutate, selectedDiscipline],
  );

  /** Current (normalized) slot timeline of a chapter. */
  const slotsOf = useCallback(
    (chapter: Chapter): RingSlot[] => {
      if (!selectedDiscipline) return [];
      const normalCount = buildRings(chapter, selectedDiscipline.id, undefined).filter(
        (r) => r.kind === "normal",
      ).length;
      return normalizeSlots(layout.ringLayout[chapter.id], normalCount);
    },
    [layout.ringLayout, selectedDiscipline],
  );

  const setSlots = useCallback(
    (chapterId: string, slots: RingSlot[]) => {
      mutate({ ...layout, ringLayout: { ...layout.ringLayout, [chapterId]: slots } });
    },
    [layout, mutate],
  );

  const moveRing = useCallback(
    (chapter: Chapter, index: number, delta: number) => {
      setSlots(chapter.id, moveItem(slotsOf(chapter), index, index + delta));
    },
    [setSlots, slotsOf],
  );

  const addRecapAfter = useCallback(
    (chapter: Chapter, index: number) => {
      const slots = [...slotsOf(chapter)];
      slots.splice(index + 1, 0, { kind: "recap" });
      setSlots(chapter.id, slots);
    },
    [setSlots, slotsOf],
  );

  const removeRecap = useCallback(
    (chapter: Chapter, index: number) => {
      const slots = slotsOf(chapter);
      if (slots.filter((s) => s.kind === "recap").length <= 1) {
        log("warn", "Chaque sous-chapitre garde au moins un récap de fin.");
        return;
      }
      setSlots(chapter.id, slots.filter((_, i) => i !== index));
    },
    [log, setSlots, slotsOf],
  );

  const resetChapterRings = useCallback(
    (chapter: Chapter) => {
      const next = { ...layout.ringLayout };
      delete next[chapter.id];
      mutate({ ...layout, ringLayout: next });
      log("info", `Ronds de « ${chapter.title} » remis par défaut.`);
    },
    [layout, log, mutate],
  );

  const resetDisciplineOrder = useCallback(() => {
    if (!selectedDiscipline) return;
    const fallback = DEFAULT_CHAPTER_ORDER[selectedDiscipline.id] ?? [];
    mutate({
      ...layout,
      chapterOrder: { ...layout.chapterOrder, [selectedDiscipline.id]: [...fallback] },
    });
    log("info", `Ordre des sous-chapitres de ${selectedDiscipline.name} remis par défaut.`);
  }, [layout, log, mutate, selectedDiscipline]);

  const resetEverything = useCallback(() => {
    mutate(defaultLayout());
    log("info", "Organisation complète remise par défaut (non publiée).");
  }, [log, mutate]);

  const publish = useCallback(async () => {
    setIsPublishing(true);
    try {
      const result = await publishPathLayout(layout);
      setIsDirty(false);
      log("success", `Organisation publiée (version ${result.version}). L'app la prendra au prochain lancement.`);
    } catch (err) {
      log("error", `Publication échouée : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsPublishing(false);
    }
  }, [layout, log]);

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

  return (
    <div className="mx-auto max-w-[1600px] px-4 py-6 text-white">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight">Parcours</h1>
          <p className="mt-1 text-sm text-white/50">
            Organise l'ordre des thèmes, des sous-chapitres et des ronds. {totals.rings} ronds au total
            {" · "}
            {totals.recaps} récaps · {RING_SIZE} questions par rond.
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
            onClick={resetEverything}
            className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-xs font-bold text-white/60 transition hover:border-amber-400/40 hover:bg-amber-500/10 hover:text-amber-200"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Tout par défaut
          </button>
          <button
            type="button"
            onClick={() => void publish()}
            disabled={isPublishing || !isDirty}
            className="flex items-center gap-1.5 rounded-lg bg-indigo-500 px-4 py-2 text-xs font-extrabold text-white shadow-[0_8px_22px_-10px_rgba(99,102,241,0.9)] transition hover:bg-indigo-400 disabled:cursor-not-allowed disabled:opacity-40"
            title="Publie uniquement l'organisation du parcours. Le contenu des questions passe par Modération / Calibrage."
          >
            {isPublishing ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Upload className="h-3.5 w-3.5" />}
            {isDirty ? "Publier l'organisation" : "À jour"}
          </button>
        </div>
      </header>

      {isDirty && (
        <div className="mb-5 rounded-xl border border-amber-400/25 bg-amber-500/[0.07] px-4 py-3 text-xs font-semibold text-amber-100/90">
          Modifications non publiées. L'application garde l'organisation actuelle tant que tu n'as pas cliqué sur
          « Publier l'organisation ». Une sauvegarde de la version précédente est prise automatiquement.
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_400px]">
        <section className="space-y-5">
          <DisciplineTimeline
            disciplines={disciplines}
            selectedId={selectedDiscipline?.id ?? ""}
            onSelect={(id) => {
              setSelectedDisciplineId(id);
              setShowMixed(false);
            }}
            onMove={moveDiscipline}
          />

          {selectedDiscipline && (
            <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 className="text-sm font-extrabold tracking-tight">
                  Sous-chapitres de {selectedDiscipline.name}
                </h2>
                <button
                  type="button"
                  onClick={resetDisciplineOrder}
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
                    disciplineId={selectedDiscipline.id}
                    index={index}
                    total={chapters.length}
                    slots={slotsOf(chapter)}
                    layout={layout}
                    expandedRingId={expandedRingId}
                    onToggleRing={(id) => setExpandedRingId((cur) => (cur === id ? null : id))}
                    onMoveChapter={moveChapter}
                    onMoveRing={moveRing}
                    onAddRecap={addRecapAfter}
                    onRemoveRecap={removeRecap}
                    onResetRings={resetChapterRings}
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
    </div>
  );
};

// MARK: - Discipline timeline

const DisciplineTimeline = ({
  disciplines,
  selectedId,
  onSelect,
  onMove,
}: {
  disciplines: Discipline[];
  selectedId: string;
  onSelect: (id: string) => void;
  onMove: (index: number, delta: number) => void;
}) => (
  <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
    <h2 className="mb-3 text-sm font-extrabold tracking-tight">Ordre des thèmes</h2>
    <div className="flex flex-wrap gap-2">
      {disciplines.map((discipline, index) => {
        const active = discipline.id === selectedId;
        return (
          <div
            key={discipline.id}
            className={`flex items-center gap-1 rounded-xl border px-2 py-1.5 transition ${
              active
                ? "border-indigo-400/50 bg-indigo-500/15"
                : "border-white/10 bg-white/[0.03] hover:bg-white/[0.06]"
            }`}
          >
            <button
              type="button"
              onClick={() => onMove(index, -1)}
              disabled={index === 0}
              className="rounded p-0.5 text-white/35 transition hover:text-white disabled:opacity-20"
              aria-label={`Monter ${discipline.name}`}
            >
              <ArrowUp className="h-3 w-3" />
            </button>
            <button
              type="button"
              onClick={() => onSelect(discipline.id)}
              className="flex items-center gap-2 px-1.5 text-xs font-bold"
            >
              <span
                className="h-2.5 w-2.5 rounded-full"
                style={{ backgroundColor: discipline.colorHex }}
              />
              <span className={active ? "text-white" : "text-white/65"}>{discipline.name}</span>
              <span className="text-[10px] font-semibold text-white/30">{index + 1}</span>
            </button>
            <button
              type="button"
              onClick={() => onMove(index, 1)}
              disabled={index === disciplines.length - 1}
              className="rounded p-0.5 text-white/35 transition hover:text-white disabled:opacity-20"
              aria-label={`Descendre ${discipline.name}`}
            >
              <ArrowDown className="h-3 w-3" />
            </button>
          </div>
        );
      })}
    </div>
  </div>
);

// MARK: - Chapter card

const ChapterCard = ({
  chapter,
  disciplineId,
  index,
  total,
  slots,
  layout,
  expandedRingId,
  onToggleRing,
  onMoveChapter,
  onMoveRing,
  onAddRecap,
  onRemoveRecap,
  onResetRings,
}: {
  chapter: Chapter;
  disciplineId: string;
  index: number;
  total: number;
  slots: RingSlot[];
  layout: PathLayout;
  expandedRingId: string | null;
  onToggleRing: (id: string) => void;
  onMoveChapter: (index: number, delta: number) => void;
  onMoveRing: (chapter: Chapter, index: number, delta: number) => void;
  onAddRecap: (chapter: Chapter, index: number) => void;
  onRemoveRecap: (chapter: Chapter, index: number) => void;
  onResetRings: (chapter: Chapter) => void;
}) => {
  const rings = useMemo(
    () => buildRings(chapter, disciplineId, layout.ringLayout[chapter.id]),
    [chapter, disciplineId, layout.ringLayout],
  );
  const questionCount = rings
    .filter((r) => r.kind === "normal")
    .reduce((sum, r) => sum + r.questions.length, 0);

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
            {rings.filter((r) => r.kind === "normal").length} ronds ·{" "}
            {rings.filter((r) => r.kind === "recap").length} récap · {questionCount} questions
          </p>
        </div>
        <button
          type="button"
          onClick={() => onResetRings(chapter)}
          className="rounded-lg border border-white/10 px-2 py-1 text-[10px] font-bold text-white/45 transition hover:bg-white/[0.06] hover:text-white"
        >
          Ronds par défaut
        </button>
      </div>

      <div className="space-y-1.5 p-2.5">
        {rings.map((ring, ringIndex) => (
          <RingRow
            key={ring.id}
            ring={ring}
            index={ringIndex}
            total={slots.length}
            isExpanded={expandedRingId === ring.id}
            onToggle={() => onToggleRing(ring.id)}
            onMove={(delta) => onMoveRing(chapter, ringIndex, delta)}
            onAddRecap={() => onAddRecap(chapter, ringIndex)}
            onRemoveRecap={() => onRemoveRecap(chapter, ringIndex)}
          />
        ))}
      </div>
    </div>
  );
};

// MARK: - Ring row

const RingRow = ({
  ring,
  index,
  total,
  isExpanded,
  onToggle,
  onMove,
  onAddRecap,
  onRemoveRecap,
}: {
  ring: PreviewRing;
  index: number;
  total: number;
  isExpanded: boolean;
  onToggle: () => void;
  onMove: (delta: number) => void;
  onAddRecap: () => void;
  onRemoveRecap: () => void;
}) => {
  const isRecap = ring.kind === "recap";
  const shown = isRecap ? ring.questions.slice(0, RING_SIZE) : ring.questions;

  return (
    <div
      className={`rounded-lg border ${
        isRecap ? "border-amber-400/30 bg-amber-500/[0.06]" : "border-white/10 bg-white/[0.02]"
      }`}
    >
      <div className="flex items-center gap-2 px-2.5 py-2">
        <div className="flex flex-col">
          <button
            type="button"
            onClick={() => onMove(-1)}
            disabled={index === 0}
            className="text-white/30 transition hover:text-white disabled:opacity-20"
            aria-label="Monter le rond"
          >
            <ArrowUp className="h-3 w-3" />
          </button>
          <button
            type="button"
            onClick={() => onMove(1)}
            disabled={index === total - 1}
            className="text-white/30 transition hover:text-white disabled:opacity-20"
            aria-label="Descendre le rond"
          >
            <ArrowDown className="h-3 w-3" />
          </button>
        </div>

        <span
          className={`grid h-7 w-7 shrink-0 place-items-center rounded-full text-[11px] font-extrabold ${
            isRecap ? "bg-amber-400 text-black" : "bg-indigo-500/80 text-white"
          }`}
        >
          {isRecap ? <Crown className="h-3.5 w-3.5" /> : ring.position}
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
          <span className="shrink-0 text-[10px] font-semibold text-white/35">
            {isRecap ? `${RING_SIZE} sur ${ring.questions.length} candidates` : `${ring.questions.length} questions`}
          </span>
          <ChevronDown
            className={`ml-auto h-3.5 w-3.5 shrink-0 text-white/30 transition ${isExpanded ? "rotate-180" : ""}`}
          />
        </button>

        {isRecap ? (
          <button
            type="button"
            onClick={onRemoveRecap}
            className="shrink-0 rounded p-1 text-white/30 transition hover:text-rose-300"
            aria-label="Supprimer ce récap"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        ) : (
          <button
            type="button"
            onClick={onAddRecap}
            className="shrink-0 rounded p-1 text-white/30 transition hover:text-amber-300"
            title="Insérer un récap après ce rond"
            aria-label="Insérer un récap après ce rond"
          >
            <Plus className="h-3.5 w-3.5" />
          </button>
        )}
      </div>

      {isExpanded && (
        <div className="space-y-1 border-t border-white/5 px-2.5 py-2">
          {isRecap && (
            <p className="mb-1.5 text-[10px] font-semibold text-amber-200/70">
              Le récap est personnalisé : chaque joueur reçoit d'abord ses propres erreurs, complétées par les
              questions les plus dures ci-dessous.
            </p>
          )}
          {shown.map((question, qIndex) => (
            <div
              key={question.id}
              className="flex items-start gap-2 rounded-md bg-black/20 px-2 py-1.5 text-[11px]"
            >
              <span className="mt-0.5 w-4 shrink-0 text-right font-mono text-white/25">{qIndex + 1}</span>
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
                </p>
              </div>
            </div>
          ))}
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
          ? "Rotation d'un rond par thème, 60 premiers ronds. Les favoris de l'onboarding reviennent plus souvent chez le joueur."
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
      <div className="max-h-40 space-y-1 overflow-y-auto">
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
