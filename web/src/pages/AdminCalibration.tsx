import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  BarChart3,
  Bot,
  Check,
  Gauge,
  Loader2,
  RefreshCw,
  Scale,
  ShieldAlert,
  Sparkles,
  Upload,
  X,
} from "lucide-react";

import { type Content, type Question, fetchContent } from "@/lib/generator";
import { flattenQuestions, type FlatQuestion, type QuestionRef } from "@/lib/moderation";
import {
  ADMIN_PASSWORD,
  type PendingChange,
  fetchReviewState,
  publishPendingChanges,
  pushReviewState,
  replayChanges,
} from "@/lib/reviewSync";
import { usePendingChanges } from "@/hooks/usePendingChanges";
import {
  DIFFICULTY_LEVELS,
  DIFFICULTY_LEVEL_LABEL,
  LEVEL_MIDPOINT_SCORE,
  MIN_ATTEMPTS_TO_SUGGEST,
  type DifficultyLevel,
  type QuestionStat,
  type Recalibration,
  type Suspicion,
  SOURCE_LABEL,
  SUSPICION_LABEL,
  TARGET_ANCHORS,
  applyPairwiseJudgements,
  clampScore,
  collectAnchors,
  computeRecalibrations,
  detectSuspiciousQuestions,
  difficultyPatch,
  effectiveScore,
  fetchQuestionStats,
  migrateContentDifficulty,
  scoreToExpectedSuccessPercent,
  scoreToLevel,
  selectAnchorsForPrompt,
  summarizeAnchors,
} from "@/lib/difficulty";
import { AI_MODELS } from "@/lib/moderation";
import type { AiConfig } from "@/lib/aiReview";
import { type AiDifficultyResult, comparePairWithAi, estimateDifficultyWithAi } from "@/lib/aiDifficulty";

type Tab = "dashboard" | "manual" | "pairwise" | "ai" | "empirical" | "suspicious";
type LogLevel = "info" | "success" | "warn" | "error";
type LogEntry = { time: string; level: LogLevel; message: string };

/** An AI difficulty proposal awaiting human approval. Never auto-applied. */
type Proposal = {
  item: FlatQuestion;
  result: AiDifficultyResult;
};

const refOf = (item: FlatQuestion): QuestionRef => ({
  disciplineId: item.disciplineId,
  chapterId: item.chapterId,
  level: item.level,
});

const LEVEL_COLOR: Record<DifficultyLevel, string> = {
  facile: "bg-emerald-500",
  intermediaire: "bg-sky-500",
  difficile: "bg-amber-500",
  maitre: "bg-rose-500",
};

const LEVEL_TEXT: Record<DifficultyLevel, string> = {
  facile: "text-emerald-300",
  intermediaire: "text-sky-300",
  difficile: "text-amber-300",
  maitre: "text-rose-300",
};

const AdminCalibration = () => {
  const [content, setContent] = useState<Content | null>(null);
  const [stats, setStats] = useState<Map<string, QuestionStat>>(new Map());
  const [loading, setLoading] = useState(false);
  const [tab, setTab] = useState<Tab>("dashboard");
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [publishing, setPublishing] = useState(false);

  // One decision queue shared with the moderation page — same counter
  // everywhere, one publish path, no more "8 shown, 53 published" surprises.
  const {
    changes: pendingChanges,
    setChanges: setPendingChanges,
    hydrate,
    syncState,
    breakdownLabel,
  } = usePendingChanges();

  // filters
  const [disciplineFilter, setDisciplineFilter] = useState("all");
  const [levelFilter, setLevelFilter] = useState<"all" | DifficultyLevel>("all");
  const [search, setSearch] = useState("");
  const [onlyUncalibrated, setOnlyUncalibrated] = useState(true);

  // manual scoring
  const [manualIndex, setManualIndex] = useState(0);
  const [sliderScore, setSliderScore] = useState(50);

  // pairwise
  const [pair, setPair] = useState<[FlatQuestion, FlatQuestion] | null>(null);
  const [pairCount, setPairCount] = useState(0);

  // AI
  const [aiModelId, setAiModelId] = useState(AI_MODELS[0].id);
  const [aiApiKey, setAiApiKey] = useState("");
  const [aiBatchSize, setAiBatchSize] = useState(25);
  const [aiClassifyTheme, setAiClassifyTheme] = useState(false);
  const [aiRunning, setAiRunning] = useState(false);
  const [aiProgress, setAiProgress] = useState({ done: 0, total: 0 });
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const aiRunningRef = useRef(false);

  const addLog = useCallback((level: LogLevel, message: string) => {
    setLogs((prev) => [
      ...prev.slice(-200),
      { time: new Date().toLocaleTimeString("fr-FR"), level, message },
    ]);
  }, []);

  /**
   * Loads live content, the shared decision store and the play telemetry, then
   * replays pending decisions so the page always reopens where you left off.
   */
  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      const [serverContent, serverState, statMap] = await Promise.all([
        fetchContent(),
        fetchReviewState().catch((err: unknown) => {
          addLog("warn", `Décisions serveur indisponibles (${String(err)}).`);
          return null;
        }),
        fetchQuestionStats(ADMIN_PASSWORD).catch((err: unknown) => {
          addLog("warn", `Statistiques de jeu indisponibles (${String(err)}).`);
          return new Map<string, QuestionStat>();
        }),
      ]);
      const changes = serverState?.changes ?? {};
      const { merged, applied } = replayChanges(serverContent, changes);
      hydrate(changes);
      setContent(merged);
      setStats(statMap);
      addLog(
        "info",
        `Chargé : ${flattenQuestions(merged).length} questions · ${Object.keys(changes).length} décision(s) non publiée(s)${applied > 0 ? ` (${applied} rejouée(s))` : ""} · ${statMap.size} question(s) avec des stats de jeu.`,
      );
    } catch (err) {
      addLog("error", `Erreur chargement : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setLoading(false);
    }
  }, [addLog, hydrate]);

  // Access is granted by the admin layout, so everything loads on mount.
  const loadRequestedRef = useRef(false);
  useEffect(() => {
    if (loadRequestedRef.current) return;
    loadRequestedRef.current = true;
    void loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Live server sync of decisions is handled by the shared PendingChangesProvider.

  const flat = useMemo(() => flattenQuestions(content), [content]);

  const disciplineOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const f of flat) map.set(f.disciplineId, f.disciplineName);
    return Array.from(map.entries());
  }, [flat]);

  const anchors = useMemo(() => collectAnchors(content), [content]);
  const anchorSummary = useMemo(() => summarizeAnchors(anchors), [anchors]);

  const recalibrations = useMemo(() => computeRecalibrations(content, stats), [content, stats]);
  const suspicions = useMemo(() => detectSuspiciousQuestions(content, stats), [content, stats]);

  /** Distribution of the effective tier across the whole catalogue. */
  const distribution = useMemo(() => {
    const counts: Record<DifficultyLevel, number> = {
      facile: 0,
      intermediaire: 0,
      difficile: 0,
      maitre: 0,
    };
    let explicit = 0;
    let withEnoughData = 0;
    for (const item of flat) {
      const eff = effectiveScore(item.question, item.level);
      counts[eff.level] += 1;
      if (eff.isExplicit && eff.source === "human") explicit += 1;
      const stat = stats.get(item.question.id);
      if (stat && stat.attempts >= MIN_ATTEMPTS_TO_SUGGEST) withEnoughData += 1;
    }
    return { counts, explicit, withEnoughData, total: flat.length };
  }, [flat, stats]);

  const filtered = useMemo(() => {
    const s = search.trim().toLowerCase();
    return flat.filter((item) => {
      if (disciplineFilter !== "all" && item.disciplineId !== disciplineFilter) return false;
      const eff = effectiveScore(item.question, item.level);
      if (levelFilter !== "all" && eff.level !== levelFilter) return false;
      if (onlyUncalibrated && item.question.difficultySource === "human") return false;
      if (s && !item.question.prompt.toLowerCase().includes(s)) return false;
      return true;
    });
  }, [flat, disciplineFilter, levelFilter, onlyUncalibrated, search]);

  const manualItem = filtered[Math.min(manualIndex, Math.max(filtered.length - 1, 0))] ?? null;

  // Keep the slider in step with whichever question is on screen.
  useEffect(() => {
    if (!manualItem) return;
    setSliderScore(effectiveScore(manualItem.question, manualItem.level).score);
  }, [manualItem?.question.id]);

  useEffect(() => {
    if (manualIndex > filtered.length - 1) setManualIndex(Math.max(0, filtered.length - 1));
  }, [filtered.length, manualIndex]);

  /**
   * Records a difficulty decision. When the tier changes the question is
   * re-filed into the matching folder, so the app keeps serving it at the right
   * level; otherwise only the score is patched in place.
   */
  const applyScore = useCallback(
    (
      item: FlatQuestion,
      score: number,
      source: "human" | "ai" | "empirical",
      options?: { confidence?: number; reason?: string },
    ) => {
      const patch = difficultyPatch(score, source, options);
      const updated: Question = { ...item.question, ...patch };
      const targetLevel = scoreToLevel(clampScore(score));
      const from = refOf(item);
      setPendingChanges((prev) => {
        const next = { ...prev };
        if (item.level !== "legacy" && item.level !== targetLevel) {
          next[item.question.id] = {
            ref: from,
            question: updated,
            moveTo: { ...from, level: targetLevel },
            origin: "calibration",
          };
        } else {
          next[item.question.id] = { ref: from, question: updated, origin: "calibration" };
        }
        return next;
      });
      // Mirror the decision into the working copy so counters and lists update
      // immediately rather than waiting for a reload.
      setContent((prev) => {
        if (!prev) return prev;
        const clone: Content = JSON.parse(JSON.stringify(prev));
        for (const disc of clone.disciplines) {
          for (const ch of disc.chapters) {
            const buckets = [
              ...(ch.questions ? [{ key: "legacy", arr: ch.questions }] : []),
              ...Object.entries(ch.levels ?? {}).map(([key, lvl]) => ({ key, arr: lvl.questions })),
            ];
            for (const bucket of buckets) {
              const idx = bucket.arr.findIndex((q) => q.id === item.question.id);
              if (idx === -1) continue;
              if (bucket.key !== "legacy" && bucket.key !== targetLevel && ch.levels) {
                bucket.arr.splice(idx, 1);
                const dest = ch.levels[targetLevel] ?? { questions: [] };
                dest.questions = [...dest.questions, updated];
                ch.levels[targetLevel] = dest;
              } else {
                bucket.arr[idx] = updated;
              }
              return clone;
            }
          }
        }
        return clone;
      });
    },
    [],
  );

  const handleManualSave = useCallback(() => {
    if (!manualItem) return;
    applyScore(manualItem, sliderScore, "human");
    addLog(
      "success",
      `Référence enregistrée : ${scoreToExpectedSuccessPercent(sliderScore)}/100 réussissent → ${DIFFICULTY_LEVEL_LABEL[scoreToLevel(sliderScore)]}.`,
    );
    setManualIndex((i) => Math.min(i + 1, Math.max(filtered.length - 1, 0)));
  }, [manualItem, sliderScore, applyScore, addLog, filtered.length]);

  // MARK: pairwise

  /** Draws two comparable questions — different enough to be informative. */
  const drawPair = useCallback(() => {
    const pool = filtered.length >= 2 ? filtered : flat;
    if (pool.length < 2) {
      setPair(null);
      return;
    }
    const a = pool[Math.floor(Math.random() * pool.length)]!;
    let b = pool[Math.floor(Math.random() * pool.length)]!;
    for (let i = 0; i < 8 && b.question.id === a.question.id; i += 1) {
      b = pool[Math.floor(Math.random() * pool.length)]!;
    }
    if (a.question.id === b.question.id) {
      setPair(null);
      return;
    }
    setPair([a, b]);
  }, [filtered, flat]);

  useEffect(() => {
    if (tab === "pairwise" && !pair) drawPair();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, pair]);

  /** Turns one "this one is harder" verdict into two updated scores. */
  const judgePair = useCallback(
    (harder: FlatQuestion, easier: FlatQuestion) => {
      const initial = new Map<string, number>([
        [harder.question.id, effectiveScore(harder.question, harder.level).score],
        [easier.question.id, effectiveScore(easier.question, easier.level).score],
      ]);
      const updated = applyPairwiseJudgements(initial, [
        { harderId: harder.question.id, easierId: easier.question.id },
      ]);
      applyScore(harder, updated.get(harder.question.id) ?? 50, "human");
      applyScore(easier, updated.get(easier.question.id) ?? 50, "human");
      setPairCount((n) => n + 1);
      setPair(null);
    },
    [applyScore],
  );

  // MARK: AI

  const aiConfig = useMemo<AiConfig | null>(() => {
    const model = AI_MODELS.find((m) => m.id === aiModelId);
    if (!model || !aiApiKey.trim()) return null;
    return { provider: model.provider, model: model.model, apiKey: aiApiKey.trim() };
  }, [aiModelId, aiApiKey]);

  const themeOptions = useMemo(() => {
    const set = new Set<string>();
    for (const item of flat) set.add(`${item.disciplineName} / ${item.chapterTitle}`);
    return Array.from(set);
  }, [flat]);

  const runAiBatch = useCallback(async () => {
    if (!aiConfig) {
      addLog("error", "Renseigne une clé API et choisis un modèle.");
      return;
    }
    const queue = filtered
      .filter((item) => item.question.difficultySource !== "human")
      .slice(0, aiBatchSize);
    if (queue.length === 0) {
      addLog("warn", "Aucune question à calibrer avec ces filtres.");
      return;
    }
    if (!anchorSummary.isReady) {
      addLog(
        "warn",
        `Seulement ${anchorSummary.total} question(s) de référence : l'IA sera moins fiable. Calibre-en au moins 12 à la main, réparties sur les 4 paliers.`,
      );
    }
    setAiRunning(true);
    aiRunningRef.current = true;
    setAiProgress({ done: 0, total: queue.length });
    let errored = 0;
    const collected: Proposal[] = [];

    for (const item of queue) {
      if (!aiRunningRef.current) break;
      try {
        const promptAnchors = selectAnchorsForPrompt(anchors, item.disciplineId);
        const result = await estimateDifficultyWithAi(item, promptAnchors, aiConfig, {
          classifyTheme: aiClassifyTheme,
          availableThemes: aiClassifyTheme ? themeOptions : undefined,
        });
        collected.push({ item, result });
      } catch (err) {
        errored += 1;
        addLog(
          "error",
          `« ${item.question.prompt.slice(0, 48)}… » : ${err instanceof Error ? err.message : String(err)}`,
        );
      }
      setAiProgress((p) => ({ ...p, done: p.done + 1 }));
    }

    setProposals((prev) => {
      const byId = new Map(prev.map((p) => [p.item.question.id, p] as const));
      for (const p of collected) byId.set(p.item.question.id, p);
      return Array.from(byId.values());
    });
    setAiRunning(false);
    aiRunningRef.current = false;
    addLog(
      "success",
      `${collected.length} proposition(s) prête(s) à valider${errored > 0 ? ` · ${errored} erreur(s)` : ""}.`,
    );
  }, [aiConfig, filtered, aiBatchSize, anchors, anchorSummary, aiClassifyTheme, themeOptions, addLog]);

  const acceptProposal = useCallback(
    (proposal: Proposal) => {
      applyScore(proposal.item, proposal.result.score, "ai", {
        confidence: proposal.result.confidence / 100,
        reason: proposal.result.reason,
      });
      setProposals((prev) => prev.filter((p) => p.item.question.id !== proposal.item.question.id));
    },
    [applyScore],
  );

  const acceptAllProposals = useCallback(() => {
    for (const proposal of proposals) {
      applyScore(proposal.item, proposal.result.score, "ai", {
        confidence: proposal.result.confidence / 100,
        reason: proposal.result.reason,
      });
    }
    addLog("success", `${proposals.length} proposition(s) appliquée(s).`);
    setProposals([]);
  }, [proposals, applyScore, addLog]);

  const runAiPairwise = useCallback(async () => {
    if (!aiConfig || !pair) return;
    try {
      const { harderId, reason } = await comparePairWithAi(pair[0], pair[1], aiConfig);
      const harder = pair.find((p) => p.question.id === harderId) ?? pair[0];
      const easier = pair.find((p) => p.question.id !== harderId) ?? pair[1];
      addLog("info", `IA : « ${harder.question.prompt.slice(0, 40)}… » est la plus dure. ${reason}`);
    } catch (err) {
      addLog("error", `Comparaison IA échouée : ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [aiConfig, pair, addLog]);

  // MARK: empirical

  const acceptRecalibration = useCallback(
    (rec: Recalibration) => {
      applyScore(rec.item, rec.blendedScore, "empirical", {
        confidence: rec.confidence,
        reason: `${Math.round(rec.stat.successRate * 100)}% de réussite sur ${rec.stat.attempts} réponses`,
      });
      addLog(
        "success",
        `« ${rec.item.question.prompt.slice(0, 40)}… » → ${DIFFICULTY_LEVEL_LABEL[rec.suggestedLevel]}.`,
      );
    },
    [applyScore, addLog],
  );

  // MARK: migration + publish

  const runMigration = useCallback(() => {
    if (!content) return;
    const { content: migrated, movedFromLegende, seededScores } = migrateContentDifficulty(content);
    if (movedFromLegende === 0 && seededScores === 0) {
      addLog("info", "Rien à migrer : tout est déjà au bon format.");
      return;
    }
    // Every touched question becomes a pending decision so the migration is
    // published through the same reviewed path as any other change.
    const changes: Record<string, PendingChange> = {};
    for (const item of flattenQuestions(migrated)) {
      changes[item.question.id] = {
        ref: { disciplineId: item.disciplineId, chapterId: item.chapterId, level: item.level },
        question: item.question,
        origin: "migration",
      };
    }
    setContent(migrated);
    setPendingChanges((prev) => ({ ...prev, ...changes }));
    addLog(
      "success",
      `Migration prête : ${movedFromLegende} question(s) « Légende » déplacée(s) vers « Maître », ${seededScores} score(s) initial(aux) posé(s). Publie pour appliquer.`,
    );
  }, [content, addLog]);

  const handlePublish = useCallback(async () => {
    if (Object.keys(pendingChanges).length === 0) {
      addLog("warn", "Aucune décision à publier.");
      return;
    }
    setPublishing(true);
    const snapshot = pendingChanges;
    try {
      const res = await publishPendingChanges(snapshot);
      addLog(
        "success",
        `Publié : version ${res.version} · ${res.questionCount} questions · ${res.applied} décision(s) intégrée(s)${res.skipped > 0 ? ` · ${res.skipped} conservée(s) en attente (introuvables sur la version serveur)` : ""}.`,
      );
      // Only decisions that actually landed leave the queue; skipped ones stay
      // pending, and anything added from another tab meanwhile is untouched.
      const kept = new Set(res.skippedIds);
      setPendingChanges((prev) => {
        const next: Record<string, PendingChange> = {};
        for (const [id, ch] of Object.entries(prev)) {
          if (kept.has(id) || !(id in snapshot)) next[id] = ch;
        }
        return next;
      });
      // Remove the published decisions server-side BEFORE reloading, so the
      // reload can't resurrect them into the queue.
      try {
        await pushReviewState(
          [],
          res.appliedIds.map((id) => ({ kind: "change" as const, questionId: id })),
          "calibration-publish",
        );
      } catch {
        addLog("warn", "Publication OK, mais le nettoyage de la file a échoué.");
      }
      await loadAll();
    } catch (err) {
      addLog("error", `Publication échouée : ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setPublishing(false);
    }
  }, [pendingChanges, addLog, loadAll]);

  const refreshStats = useCallback(async () => {
    try {
      const statMap = await fetchQuestionStats(ADMIN_PASSWORD);
      setStats(statMap);
      addLog("info", `Statistiques rafraîchies : ${statMap.size} question(s) jouée(s).`);
    } catch (err) {
      addLog("error", `Stats indisponibles : ${err instanceof Error ? err.message : String(err)}`);
    }
  }, [addLog]);

  const pendingCount = Object.keys(pendingChanges).length;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <header className="sticky top-[52px] z-20 border-b border-white/10 bg-slate-950/90 backdrop-blur">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center gap-3 px-4 py-3">
          <div className="flex items-center gap-2">
            <Gauge className="h-5 w-5 text-indigo-400" />
            <h1 className="text-sm font-semibold">Calibrage de la difficulté</h1>
          </div>
          <div className="ml-auto flex items-center gap-2 text-xs">
            <span
              className={
                syncState === "error"
                  ? "text-rose-400"
                  : syncState === "saving"
                    ? "text-amber-300"
                    : "text-emerald-400"
              }
            >
              {syncState === "error"
                ? "Sauvegarde serveur en erreur"
                : syncState === "saving"
                  ? "Sauvegarde…"
                  : "Sauvegardé"}
            </span>
            <button
              onClick={refreshStats}
              className="flex items-center gap-1 rounded-lg border border-white/10 px-3 py-2 hover:bg-white/5"
            >
              <RefreshCw className="h-3 w-3" /> Stats
            </button>
            <button
              onClick={loadAll}
              disabled={loading}
              className="flex items-center gap-1 rounded-lg border border-white/10 px-3 py-2 hover:bg-white/5 disabled:opacity-50"
            >
              {loading ? <Loader2 className="h-3 w-3 animate-spin" /> : <RefreshCw className="h-3 w-3" />}
              Recharger
            </button>
            {breakdownLabel && (
              <span
                className="hidden rounded-lg border border-indigo-400/30 bg-indigo-500/10 px-2 py-1 font-medium text-indigo-200 sm:inline"
                title="La file de décisions est commune aux pages Modération et Calibrage."
              >
                File commune : {breakdownLabel}
              </span>
            )}
            <button
              onClick={handlePublish}
              disabled={publishing || pendingCount === 0}
              title="Publie TOUTES les décisions en attente, y compris celles faites sur la page Modération — la file est commune."
              className="flex items-center gap-1 rounded-lg bg-indigo-500 px-3 py-2 font-semibold text-white hover:bg-indigo-400 disabled:opacity-40"
            >
              {publishing ? <Loader2 className="h-3 w-3 animate-spin" /> : <Upload className="h-3 w-3" />}
              Publier ({pendingCount})
            </button>
          </div>
        </div>
        <nav className="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-4 pb-2 text-xs">
          {([
            ["dashboard", "Tableau de bord", BarChart3],
            ["manual", "Calibrer à la main", Gauge],
            ["pairwise", "Comparaison", Scale],
            ["ai", "Calibrage IA", Bot],
            ["empirical", "Ajustements réels", Sparkles],
            ["suspicious", "Questions suspectes", ShieldAlert],
          ] as const).map(([key, label, Icon]) => (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-2 ${
                tab === key ? "bg-indigo-500/20 text-indigo-200" : "text-slate-400 hover:bg-white/5"
              }`}
            >
              <Icon className="h-3.5 w-3.5" />
              {label}
              {key === "empirical" && recalibrations.filter((r) => r.levelChanges).length > 0 && (
                <span className="rounded-full bg-amber-500/20 px-1.5 text-[10px] text-amber-300">
                  {recalibrations.filter((r) => r.levelChanges).length}
                </span>
              )}
              {key === "suspicious" && suspicions.length > 0 && (
                <span className="rounded-full bg-rose-500/20 px-1.5 text-[10px] text-rose-300">
                  {suspicions.length}
                </span>
              )}
              {key === "ai" && proposals.length > 0 && (
                <span className="rounded-full bg-emerald-500/20 px-1.5 text-[10px] text-emerald-300">
                  {proposals.length}
                </span>
              )}
            </button>
          ))}
        </nav>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-6">
        {/* Filters shared by the working tabs. */}
        {tab !== "dashboard" && tab !== "suspicious" && tab !== "empirical" && (
          <div className="mb-5 flex flex-wrap items-center gap-2 rounded-xl border border-white/10 bg-slate-900/50 p-3 text-xs">
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Rechercher…"
              className="min-w-[180px] flex-1 rounded-lg border border-white/10 bg-slate-950 px-3 py-2 outline-none focus:border-indigo-400"
            />
            <select
              value={disciplineFilter}
              onChange={(e) => setDisciplineFilter(e.target.value)}
              className="rounded-lg border border-white/10 bg-slate-950 px-3 py-2"
            >
              <option value="all">Tous les thèmes</option>
              {disciplineOptions.map(([id, name]) => (
                <option key={id} value={id}>
                  {name}
                </option>
              ))}
            </select>
            <select
              value={levelFilter}
              onChange={(e) => setLevelFilter(e.target.value as "all" | DifficultyLevel)}
              className="rounded-lg border border-white/10 bg-slate-950 px-3 py-2"
            >
              <option value="all">Tous les paliers</option>
              {DIFFICULTY_LEVELS.map((lvl) => (
                <option key={lvl} value={lvl}>
                  {DIFFICULTY_LEVEL_LABEL[lvl]}
                </option>
              ))}
            </select>
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={onlyUncalibrated}
                onChange={(e) => setOnlyUncalibrated(e.target.checked)}
              />
              Masquer celles déjà validées à la main
            </label>
            <span className="ml-auto text-slate-400">{filtered.length} question(s)</span>
          </div>
        )}

        {tab === "dashboard" && (
          <div className="space-y-5">
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <StatCard
                label="Questions au total"
                value={distribution.total.toLocaleString("fr-FR")}
                hint={`${pendingCount} décision(s) non publiée(s)`}
              />
              <StatCard
                label="Références à la main"
                value={`${anchorSummary.total} / ${TARGET_ANCHORS}`}
                hint={
                  anchorSummary.isReady
                    ? "L'IA est correctement ancrée"
                    : `Paliers à compléter : ${anchorSummary.missingLevels.map((l) => DIFFICULTY_LEVEL_LABEL[l]).join(", ") || "—"}`
                }
                tone={anchorSummary.isReady ? "good" : "warn"}
              />
              <StatCard
                label="Assez de données de jeu"
                value={distribution.withEnoughData.toLocaleString("fr-FR")}
                hint={`≥ ${MIN_ATTEMPTS_TO_SUGGEST} réponses enregistrées`}
              />
              <StatCard
                label="Questions suspectes"
                value={suspicions.length.toLocaleString("fr-FR")}
                hint="Détectées par les réponses des joueurs"
                tone={suspicions.length > 0 ? "warn" : "good"}
              />
            </div>

            <section className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
              <h2 className="mb-1 text-sm font-semibold">Répartition par palier</h2>
              <p className="mb-4 text-xs text-slate-400">
                Le palier est déduit du score : Facile ≤ 25, Intermédiaire ≤ 50, Difficile ≤ 75,
                Maître au-delà. Un score de S signifie que {"(100 - S)"}% des joueurs réussissent.
              </p>
              <div className="space-y-3">
                {DIFFICULTY_LEVELS.map((lvl) => {
                  const count = distribution.counts[lvl];
                  const pct = distribution.total > 0 ? (count / distribution.total) * 100 : 0;
                  return (
                    <div key={lvl}>
                      <div className="mb-1 flex justify-between text-xs">
                        <span className={LEVEL_TEXT[lvl]}>{DIFFICULTY_LEVEL_LABEL[lvl]}</span>
                        <span className="text-slate-400">
                          {count} · {pct.toFixed(1)}%
                        </span>
                      </div>
                      <div className="h-2 overflow-hidden rounded-full bg-white/5">
                        <div
                          className={`h-full rounded-full ${LEVEL_COLOR[lvl]}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>

            <section className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
              <h2 className="mb-1 text-sm font-semibold">Migration du format</h2>
              <p className="mb-3 text-xs text-slate-400">
                Fusionne l'ancien palier « Légende » dans « Maître » et pose un score initial sur
                les questions qui n'en ont pas, déduit de leur palier d'origine. À lancer une seule
                fois, puis publier.
              </p>
              <button
                onClick={runMigration}
                disabled={!content}
                className="rounded-lg border border-white/10 px-4 py-2 text-xs hover:bg-white/5 disabled:opacity-50"
              >
                Préparer la migration
              </button>
            </section>

            {recalibrations.length > 0 && (
              <section className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
                <h2 className="mb-3 text-sm font-semibold">Plus gros écarts mesurés</h2>
                <div className="space-y-2">
                  {recalibrations.slice(0, 8).map((rec) => (
                    <div
                      key={rec.item.question.id}
                      className="flex flex-wrap items-center gap-2 rounded-lg bg-slate-950/60 p-3 text-xs"
                    >
                      <span className="flex-1 truncate">{rec.item.question.prompt}</span>
                      <span className={LEVEL_TEXT[rec.currentLevel]}>
                        {DIFFICULTY_LEVEL_LABEL[rec.currentLevel]} ({rec.currentScore})
                      </span>
                      <span className="text-slate-500">→</span>
                      <span className={LEVEL_TEXT[rec.suggestedLevel]}>
                        {DIFFICULTY_LEVEL_LABEL[rec.suggestedLevel]} ({rec.blendedScore})
                      </span>
                      <span className="text-slate-400">
                        {Math.round(rec.stat.successRate * 100)}% / {rec.stat.attempts} rép.
                      </span>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </div>
        )}

        {tab === "manual" && (
          <div className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
            <section className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
              {manualItem ? (
                <>
                  <div className="mb-3 flex items-center gap-2 text-xs text-slate-400">
                    <span>
                      {manualIndex + 1} / {filtered.length}
                    </span>
                    <span>·</span>
                    <span>
                      {manualItem.disciplineName} / {manualItem.chapterTitle}
                    </span>
                    {manualItem.question.difficultySource && (
                      <span className="rounded-full bg-white/5 px-2 py-0.5">
                        {SOURCE_LABEL[manualItem.question.difficultySource]}
                      </span>
                    )}
                  </div>
                  <p className="mb-3 text-base font-medium leading-relaxed">
                    {manualItem.question.prompt}
                  </p>
                  <div className="mb-4 space-y-1.5 text-sm">
                    {(manualItem.question.type === "trueFalse"
                      ? ["Vrai", "Faux"]
                      : (manualItem.question.options ?? [])
                    ).map((opt) => (
                      <div
                        key={opt}
                        className={`rounded-lg border px-3 py-2 ${
                          opt.trim().toLowerCase() === manualItem.question.answer.trim().toLowerCase()
                            ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-200"
                            : "border-white/10 bg-slate-950/50"
                        }`}
                      >
                        {opt}
                      </div>
                    ))}
                  </div>

                  <div className="rounded-xl bg-slate-950/60 p-4">
                    <label className="mb-2 block text-xs text-slate-400">
                      Sur 100 adultes au hasard, combien répondraient juste ?
                    </label>
                    <div className="mb-2 flex items-baseline gap-3">
                      <span className="text-3xl font-bold text-white">
                        {scoreToExpectedSuccessPercent(sliderScore)}
                      </span>
                      <span className="text-xs text-slate-400">/ 100 réussissent</span>
                      <span
                        className={`ml-auto rounded-full px-3 py-1 text-xs font-semibold ${LEVEL_TEXT[scoreToLevel(sliderScore)]} bg-white/5`}
                      >
                        {DIFFICULTY_LEVEL_LABEL[scoreToLevel(sliderScore)]} · score {sliderScore}
                      </span>
                    </div>
                    <input
                      type="range"
                      min={0}
                      max={100}
                      value={scoreToExpectedSuccessPercent(sliderScore)}
                      onChange={(e) => setSliderScore(clampScore(100 - Number(e.target.value)))}
                      className="w-full accent-indigo-500"
                    />
                    <div className="mt-1 flex justify-between text-[10px] text-slate-500">
                      <span>Personne ne sait (Maître)</span>
                      <span>Tout le monde sait (Facile)</span>
                    </div>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {DIFFICULTY_LEVELS.map((lvl) => (
                        <button
                          key={lvl}
                          onClick={() => setSliderScore(LEVEL_MIDPOINT_SCORE[lvl])}
                          className="rounded-lg border border-white/10 px-3 py-1.5 text-xs hover:bg-white/5"
                        >
                          {DIFFICULTY_LEVEL_LABEL[lvl]}
                        </button>
                      ))}
                    </div>
                    <div className="mt-4 flex gap-2">
                      <button
                        onClick={handleManualSave}
                        className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-indigo-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-400"
                      >
                        <Check className="h-4 w-4" /> Valider comme référence
                      </button>
                      <button
                        onClick={() =>
                          setManualIndex((i) => Math.min(i + 1, Math.max(filtered.length - 1, 0)))
                        }
                        className="rounded-lg border border-white/10 px-4 py-2.5 text-sm hover:bg-white/5"
                      >
                        Passer
                      </button>
                    </div>
                  </div>
                </>
              ) : (
                <p className="text-sm text-slate-400">
                  Aucune question avec ces filtres. Décoche « masquer celles déjà validées » pour
                  revoir tes références.
                </p>
              )}
            </section>

            <aside className="space-y-4">
              <div className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
                <h3 className="mb-3 text-sm font-semibold">Tes références</h3>
                <p className="mb-3 text-xs text-slate-400">
                  Ces questions servent d'échelle à l'IA. L'objectif est d'en avoir au moins{" "}
                  {TARGET_ANCHORS}, réparties sur les 4 paliers.
                </p>
                <div className="space-y-2">
                  {DIFFICULTY_LEVELS.map((lvl) => (
                    <div key={lvl} className="flex items-center justify-between text-xs">
                      <span className={LEVEL_TEXT[lvl]}>{DIFFICULTY_LEVEL_LABEL[lvl]}</span>
                      <span className="text-slate-300">{anchorSummary.byLevel[lvl]}</span>
                    </div>
                  ))}
                </div>
                {!anchorSummary.isReady && (
                  <p className="mt-3 rounded-lg bg-amber-500/10 p-2 text-[11px] text-amber-300">
                    Il manque encore des exemples sur :{" "}
                    {anchorSummary.missingLevels.map((l) => DIFFICULTY_LEVEL_LABEL[l]).join(", ")}.
                  </p>
                )}
              </div>
              <LogPanel logs={logs} />
            </aside>
          </div>
        )}

        {tab === "pairwise" && (
          <div className="space-y-4">
            <div className="rounded-xl border border-white/10 bg-slate-900/50 p-4 text-xs text-slate-400">
              Choisis simplement la question la plus difficile. Comparer est bien plus fiable que
              noter dans le vide, et chaque verdict écarte les deux scores l'un de l'autre.
              <span className="ml-2 text-slate-300">{pairCount} comparaison(s) faite(s)</span>
            </div>
            {pair ? (
              <div className="grid gap-4 md:grid-cols-2">
                {pair.map((item, idx) => {
                  const other = pair[idx === 0 ? 1 : 0];
                  const eff = effectiveScore(item.question, item.level);
                  return (
                    <div
                      key={item.question.id}
                      className="flex flex-col rounded-xl border border-white/10 bg-slate-900/50 p-5"
                    >
                      <div className="mb-2 text-xs text-slate-400">{item.disciplineName}</div>
                      <p className="mb-3 flex-1 text-sm font-medium leading-relaxed">
                        {item.question.prompt}
                      </p>
                      <p className="mb-3 text-xs text-emerald-300">→ {item.question.answer}</p>
                      <div className="mb-3 text-xs text-slate-500">
                        Actuel : {DIFFICULTY_LEVEL_LABEL[eff.level]} (score {eff.score})
                      </div>
                      <button
                        onClick={() => judgePair(item, other)}
                        className="rounded-lg bg-indigo-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-400"
                      >
                        Celle-ci est plus dure
                      </button>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-slate-400">Pas assez de questions pour comparer.</p>
            )}
            <div className="flex gap-2">
              <button
                onClick={drawPair}
                className="rounded-lg border border-white/10 px-4 py-2 text-xs hover:bg-white/5"
              >
                Autre paire
              </button>
              {aiConfig && (
                <button
                  onClick={runAiPairwise}
                  className="rounded-lg border border-white/10 px-4 py-2 text-xs hover:bg-white/5"
                >
                  Demander l'avis de l'IA
                </button>
              )}
            </div>
            <LogPanel logs={logs} />
          </div>
        )}

        {tab === "ai" && (
          <div className="space-y-5">
            <section className="rounded-xl border border-white/10 bg-slate-900/50 p-5">
              <h2 className="mb-1 text-sm font-semibold">Lancer le calibrage IA</h2>
              <p className="mb-4 text-xs text-slate-400">
                L'IA estime combien d'adultes sur 100 répondraient juste, en se comparant à tes{" "}
                {anchorSummary.total} question(s) de référence. Rien n'est appliqué sans ta
                validation.
              </p>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <select
                  value={aiModelId}
                  onChange={(e) => setAiModelId(e.target.value)}
                  className="rounded-lg border border-white/10 bg-slate-950 px-3 py-2 text-xs"
                >
                  {AI_MODELS.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.label}
                    </option>
                  ))}
                </select>
                <input
                  type="password"
                  value={aiApiKey}
                  onChange={(e) => setAiApiKey(e.target.value)}
                  placeholder="Clé API (jamais stockée)"
                  className="rounded-lg border border-white/10 bg-slate-950 px-3 py-2 text-xs"
                />
                <input
                  type="number"
                  min={1}
                  max={200}
                  value={aiBatchSize}
                  onChange={(e) => setAiBatchSize(Number(e.target.value))}
                  className="rounded-lg border border-white/10 bg-slate-950 px-3 py-2 text-xs"
                />
                <label className="flex items-center gap-2 text-xs text-slate-300">
                  <input
                    type="checkbox"
                    checked={aiClassifyTheme}
                    onChange={(e) => setAiClassifyTheme(e.target.checked)}
                  />
                  Proposer aussi le thème
                </label>
              </div>
              <div className="mt-4 flex flex-wrap items-center gap-2">
                <button
                  onClick={runAiBatch}
                  disabled={aiRunning || !aiConfig}
                  className="flex items-center gap-2 rounded-lg bg-indigo-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-400 disabled:opacity-40"
                >
                  {aiRunning ? <Loader2 className="h-4 w-4 animate-spin" /> : <Bot className="h-4 w-4" />}
                  Calibrer {Math.min(aiBatchSize, filtered.length)} question(s)
                </button>
                {aiRunning && (
                  <button
                    onClick={() => {
                      aiRunningRef.current = false;
                    }}
                    className="rounded-lg border border-white/10 px-4 py-2.5 text-sm hover:bg-white/5"
                  >
                    Arrêter
                  </button>
                )}
                {aiProgress.total > 0 && (
                  <span className="text-xs text-slate-400">
                    {aiProgress.done} / {aiProgress.total}
                  </span>
                )}
                {proposals.length > 0 && (
                  <button
                    onClick={acceptAllProposals}
                    className="ml-auto rounded-lg bg-emerald-500/20 px-4 py-2.5 text-sm font-semibold text-emerald-200 hover:bg-emerald-500/30"
                  >
                    Tout accepter ({proposals.length})
                  </button>
                )}
              </div>
            </section>

            {proposals.length > 0 && (
              <section className="space-y-2">
                {proposals.map((proposal) => {
                  const current = effectiveScore(proposal.item.question, proposal.item.level);
                  return (
                    <div
                      key={proposal.item.question.id}
                      className="rounded-xl border border-white/10 bg-slate-900/50 p-4"
                    >
                      <div className="mb-2 flex flex-wrap items-center gap-2 text-xs">
                        <span className="text-slate-400">{proposal.item.disciplineName}</span>
                        <span className={LEVEL_TEXT[current.level]}>
                          {DIFFICULTY_LEVEL_LABEL[current.level]}
                        </span>
                        <span className="text-slate-500">→</span>
                        <span className={`font-semibold ${LEVEL_TEXT[proposal.result.level]}`}>
                          {DIFFICULTY_LEVEL_LABEL[proposal.result.level]}
                        </span>
                        <span className="text-slate-400">
                          {proposal.result.percentCorrect}/100 réussiraient
                        </span>
                        <span className="text-slate-500">
                          confiance {proposal.result.confidence}%
                        </span>
                      </div>
                      <p className="mb-1 text-sm">{proposal.item.question.prompt}</p>
                      <p className="mb-3 text-xs italic text-slate-400">{proposal.result.reason}</p>
                      {proposal.result.suggestedDisciplineName && (
                        <p className="mb-3 text-xs text-amber-300">
                          Thème plus probable : {proposal.result.suggestedDisciplineName}
                          {proposal.result.suggestedChapterTitle
                            ? ` / ${proposal.result.suggestedChapterTitle}`
                            : ""}
                        </p>
                      )}
                      <div className="flex gap-2">
                        <button
                          onClick={() => acceptProposal(proposal)}
                          className="flex items-center gap-1.5 rounded-lg bg-emerald-500/20 px-3 py-2 text-xs font-semibold text-emerald-200 hover:bg-emerald-500/30"
                        >
                          <Check className="h-3.5 w-3.5" /> Accepter
                        </button>
                        <button
                          onClick={() =>
                            setProposals((prev) =>
                              prev.filter((p) => p.item.question.id !== proposal.item.question.id),
                            )
                          }
                          className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-xs hover:bg-white/5"
                        >
                          <X className="h-3.5 w-3.5" /> Ignorer
                        </button>
                      </div>
                    </div>
                  );
                })}
              </section>
            )}
            <LogPanel logs={logs} />
          </div>
        )}

        {tab === "empirical" && (
          <div className="space-y-4">
            <div className="rounded-xl border border-white/10 bg-slate-900/50 p-4 text-xs text-slate-400">
              Ces propositions viennent des vraies parties : taux de réussite pondéré par le niveau
              des joueurs, plus le temps de réponse. Il faut au moins {MIN_ATTEMPTS_TO_SUGGEST}{" "}
              réponses pour qu'une question apparaisse ici. Les questions validées à la main sont
              signalées et jamais modifiées sans toi.
            </div>
            {recalibrations.filter((r) => r.levelChanges).length === 0 ? (
              <p className="text-sm text-slate-400">
                Aucun changement de palier à proposer pour l'instant. Les données arrivent au fur et
                à mesure des parties.
              </p>
            ) : (
              recalibrations
                .filter((r) => r.levelChanges)
                .map((rec) => (
                  <div
                    key={rec.item.question.id}
                    className="rounded-xl border border-white/10 bg-slate-900/50 p-4"
                  >
                    <div className="mb-2 flex flex-wrap items-center gap-2 text-xs">
                      <span className={LEVEL_TEXT[rec.currentLevel]}>
                        {DIFFICULTY_LEVEL_LABEL[rec.currentLevel]} ({rec.currentScore})
                      </span>
                      <span className="text-slate-500">→</span>
                      <span className={`font-semibold ${LEVEL_TEXT[rec.suggestedLevel]}`}>
                        {DIFFICULTY_LEVEL_LABEL[rec.suggestedLevel]} ({rec.blendedScore})
                      </span>
                      <span className="text-slate-400">
                        {Math.round(rec.stat.successRate * 100)}% de réussite sur {rec.stat.attempts}{" "}
                        réponses
                      </span>
                      {rec.humanLocked && (
                        <span className="rounded-full bg-amber-500/20 px-2 py-0.5 text-amber-300">
                          Validée à la main
                        </span>
                      )}
                    </div>
                    <p className="mb-3 text-sm">{rec.item.question.prompt}</p>
                    <button
                      onClick={() => acceptRecalibration(rec)}
                      className="flex items-center gap-1.5 rounded-lg bg-emerald-500/20 px-3 py-2 text-xs font-semibold text-emerald-200 hover:bg-emerald-500/30"
                    >
                      <Check className="h-3.5 w-3.5" /> Appliquer le nouveau palier
                    </button>
                  </div>
                ))
            )}
            <LogPanel logs={logs} />
          </div>
        )}

        {tab === "suspicious" && (
          <div className="space-y-4">
            <div className="rounded-xl border border-white/10 bg-slate-900/50 p-4 text-xs text-slate-400">
              Détecté à partir de ce que les joueurs ont réellement choisi — plus fiable qu'une
              relecture par IA. Corrige ces questions dans l'outil de modération.
            </div>
            {suspicions.length === 0 ? (
              <p className="text-sm text-slate-400">Rien de suspect pour l'instant.</p>
            ) : (
              suspicions.map((s: Suspicion) => (
                <div
                  key={s.item.question.id}
                  className="rounded-xl border border-white/10 bg-slate-900/50 p-4"
                >
                  <div className="mb-2 flex flex-wrap gap-1.5">
                    {s.kinds.map((kind) => (
                      <span
                        key={kind}
                        className="rounded-full bg-rose-500/15 px-2 py-0.5 text-[11px] text-rose-300"
                      >
                        {SUSPICION_LABEL[kind]}
                      </span>
                    ))}
                  </div>
                  <p className="mb-1 text-sm">{s.item.question.prompt}</p>
                  <p className="mb-2 text-xs text-emerald-300">
                    Réponse officielle : {s.item.question.answer}
                  </p>
                  <ul className="space-y-1 text-xs text-slate-400">
                    {s.reasons.map((reason) => (
                      <li key={reason}>• {reason}</li>
                    ))}
                  </ul>
                </div>
              ))
            )}
            <LogPanel logs={logs} />
          </div>
        )}
      </main>
    </div>
  );
};

const StatCard = ({
  label,
  value,
  hint,
  tone = "neutral",
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "neutral" | "good" | "warn";
}) => (
  <div className="rounded-xl border border-white/10 bg-slate-900/50 p-4">
    <p className="text-xs text-slate-400">{label}</p>
    <p
      className={`mt-1 text-2xl font-bold ${
        tone === "good" ? "text-emerald-300" : tone === "warn" ? "text-amber-300" : "text-white"
      }`}
    >
      {value}
    </p>
    {hint && <p className="mt-1 text-[11px] text-slate-500">{hint}</p>}
  </div>
);

const LogPanel = ({ logs }: { logs: LogEntry[] }) => (
  <div className="rounded-xl border border-white/10 bg-slate-950/80 p-4">
    <h3 className="mb-2 text-xs font-semibold text-slate-300">Journal</h3>
    <div className="max-h-64 space-y-1 overflow-y-auto font-mono text-[11px]">
      {logs.length === 0 && <p className="text-slate-600">Aucune action pour l'instant.</p>}
      {logs
        .slice()
        .reverse()
        .map((log, i) => (
          <p
            key={`${log.time}-${i}`}
            className={
              log.level === "error"
                ? "text-rose-400"
                : log.level === "warn"
                  ? "text-amber-300"
                  : log.level === "success"
                    ? "text-emerald-400"
                    : "text-slate-400"
            }
          >
            <span className="text-slate-600">{log.time}</span> {log.message}
          </p>
        ))}
    </div>
  </div>
);

export default AdminCalibration;
