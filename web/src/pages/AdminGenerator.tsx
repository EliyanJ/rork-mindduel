import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowLeft,
  Brain,
  CheckCircle2,
  Download,
  Flame,
  Loader2,
  Lock,
  Pause,
  Play,
  RefreshCw,
  Sparkles,
  Trash2,
  Zap,
  AlertTriangle,
  XCircle,
  Copy,
  Wand2,
  ListChecks,
  X,
} from "lucide-react";
import { Link } from "react-router-dom";

import {
  type Content,
  type GenTarget,
  type LogEntry,
  countQuestions,
  detectIncomplete,
  downloadJson,
  estimateCost,
  fetchContent,
  generateForTarget,
  getExistingQuestions,
  isLegacyChapter,
  mergeQuestions,
  planBulkTargets,
  FAMILIARITY_LABEL,
  MODEL_ID,
  COST_PER_QUESTION_USD,
  TARGET_PER_LEVEL,
} from "@/lib/generator";

const ADMIN_PASSWORD = "minduel-admin";

type RunState = "idle" | "running" | "paused" | "error";
type LeftTab = "bulk" | "auto" | "manual";

type QueueItem = {
  target: GenTarget;
  status: "pending" | "running" | "done" | "failed";
  questionCount: number;
  error?: string;
};

type BulkGoal = { goal: number; generated: number };

const AdminGenerator = () => {
  const [authed, setAuthed] = useState<boolean>(false);
  const [passwordInput, setPasswordInput] = useState<string>("");
  const [authError, setAuthError] = useState<string>("");

  const [content, setContent] = useState<Content | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [runState, setRunState] = useState<RunState>("idle");
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [queueIndex, setQueueIndex] = useState<number>(0);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [totalGenerated, setTotalGenerated] = useState<number>(0);
  const [totalCost, setTotalCost] = useState<number>(0);
  const [bulkGoal, setBulkGoal] = useState<BulkGoal | null>(null);
  const [leftTab, setLeftTab] = useState<LeftTab>("bulk");

  // Manual generation form state
  const [selDiscipline, setSelDiscipline] = useState<string>("");
  const [selChapter, setSelChapter] = useState<string>("");
  const [selLevel, setSelLevel] = useState<string>("facile");
  const [selCount, setSelCount] = useState<number>(20);

  // Bulk generation form state
  const [bulkCount, setBulkCount] = useState<number>(600);

  const logEndRef = useRef<HTMLDivElement | null>(null);
  const runningRef = useRef<boolean>(false);
  const queueRef = useRef<QueueItem[]>([]);
  const idxRef = useRef<number>(0);
  const bulkGoalRef = useRef<BulkGoal | null>(null);

  // Auto-scroll log to bottom
  useEffect(() => {
    if (logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [logs]);

  const addLog = useCallback((level: LogEntry["level"], message: string) => {
    const entry: LogEntry = {
      time: new Date().toLocaleTimeString("fr-FR"),
      level,
      message,
    };
    setLogs((prev) => [...prev.slice(-300), entry]);
  }, []);

  /** Keep the ref (source of truth for the running loop) and the render state in sync. */
  const updateQueue = useCallback((updater: (prev: QueueItem[]) => QueueItem[]) => {
    queueRef.current = updater(queueRef.current);
    setQueue(queueRef.current);
  }, []);

  // Load content on auth
  const loadContent = useCallback(async () => {
    setLoading(true);
    try {
      const c = await fetchContent();
      setContent(c);
      addLog("info", `content.json chargé : ${c.disciplines.length} disciplines`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      addLog("error", `Erreur chargement content.json : ${msg}`);
    } finally {
      setLoading(false);
    }
  }, [addLog]);

  const handleAuth = (e: React.FormEvent) => {
    e.preventDefault();
    if (passwordInput === ADMIN_PASSWORD) {
      setAuthed(true);
      setAuthError("");
      addLog("info", "Accès autorisé");
    } else {
      setAuthError("Mot de passe incorrect");
    }
  };

  useEffect(() => {
    if (authed && !content) {
      loadContent();
    }
  }, [authed, content, loadContent]);

  const disciplines = content?.disciplines ?? [];
  const selectedDiscipline = disciplines.find((d) => d.id === selDiscipline);
  const selectedChapter = selectedDiscipline?.chapters.find((c) => c.id === selChapter);

  const incompleteTargets = useMemo<GenTarget[]>(() => {
    if (!content) return [];
    return detectIncomplete(content);
  }, [content]);

  const incompleteNeeded = useMemo(
    () => incompleteTargets.reduce((sum, t) => sum + t.count, 0),
    [incompleteTargets],
  );

  const summary = useMemo(() => {
    if (!content) return { total: 0, complete: 0, incomplete: 0, totalQuestions: 0 };
    let total = 0;
    let complete = 0;
    let incomplete = 0;
    let totalQuestions = 0;
    for (const disc of content.disciplines) {
      for (const ch of disc.chapters) {
        if (isLegacyChapter(ch)) {
          total += 1;
          const q = ch.questions?.length ?? 0;
          totalQuestions += q;
          if (q >= TARGET_PER_LEVEL) complete += 1;
          else incomplete += 1;
        } else if (ch.levels) {
          for (const lvl of Object.values(ch.levels)) {
            total += 1;
            totalQuestions += lvl.questions.length;
            if (lvl.questions.length >= TARGET_PER_LEVEL) complete += 1;
            else incomplete += 1;
          }
        }
      }
    }
    return { total, complete, incomplete, totalQuestions };
  }, [content]);

  /**
   * Core generation loop. Reads/writes exclusively through refs so it can run
   * for a long time (hundreds of calls) without stale-closure bugs, and so a
   * bulk goal can transparently extend the queue mid-run instead of stopping.
   */
  const runLoop = useCallback(async () => {
    if (runningRef.current || !content) return;
    runningRef.current = true;
    setRunState("running");
    addLog("info", `Démarrage — ${queueRef.current.length - idxRef.current} tâche(s) en file`);

    let currentContent = content;
    let stoppedForCredits = false;

    while (runningRef.current) {
      // If we're in bulk mode and the queue is exhausted but the goal isn't
      // reached yet, plan more batches from the freshest content and keep going.
      if (idxRef.current >= queueRef.current.length && bulkGoalRef.current) {
        const remaining = bulkGoalRef.current.goal - bulkGoalRef.current.generated;
        if (remaining > 0) {
          const more = planBulkTargets(currentContent, remaining, 8);
          if (more.length > 0) {
            updateQueue((prev) => [...prev, ...more.map((t) => ({ target: t, status: "pending" as const, questionCount: 0 }))]);
            addLog("info", `Rafale : ${more.length} tâche(s) de plus planifiées (${remaining} question(s) restantes)`);
          } else {
            addLog("warn", "Rafale : plus aucun chapitre disponible, arrêt anticipé");
            bulkGoalRef.current = null;
            setBulkGoal(null);
          }
        } else {
          addLog("success", `Objectif rafale atteint : ${bulkGoalRef.current.generated} questions générées`);
          bulkGoalRef.current = null;
          setBulkGoal(null);
        }
      }

      if (idxRef.current >= queueRef.current.length) break;

      const idx = idxRef.current;
      const item = queueRef.current[idx];
      updateQueue((prev) => prev.map((q, i) => (i === idx ? { ...q, status: "running" } : q)));
      addLog("info", `→ [${idx + 1}] ${item.target.chapterTitle} (${item.target.level}) — ${item.target.count} Q`);

      try {
        const existing = getExistingQuestions(currentContent, item.target);
        const result = await generateForTarget(item.target, existing);

        if (!result.ok) {
          addLog("error", `✗ ${item.target.chapterTitle} : ${result.error}`);
          updateQueue((prev) => prev.map((q, i) => (i === idx ? { ...q, status: "failed", error: result.error } : q)));
          if (result.error?.includes("Crédits insuffisants")) {
            setRunState("error");
            addLog("error", "Arrêt : crédits insuffisants");
            stoppedForCredits = true;
            break;
          }
        } else {
          currentContent = mergeQuestions(currentContent, item.target, result.questions);
          setContent(currentContent);
          setTotalGenerated((prev) => prev + result.questions.length);
          setTotalCost((prev) => prev + estimateCost(result.questions.length));
          if (bulkGoalRef.current) {
            bulkGoalRef.current = { ...bulkGoalRef.current, generated: bulkGoalRef.current.generated + result.questions.length };
            setBulkGoal(bulkGoalRef.current);
          }
          const cost = estimateCost(result.questions.length);
          const famCounts: Record<string, number> = {};
          for (const q of result.questions) {
            const key = q.familiarity ?? "?";
            famCounts[key] = (famCounts[key] ?? 0) + 1;
          }
          const famSummary = Object.entries(famCounts)
            .map(([k, n]) => `${n} ${FAMILIARITY_LABEL[k as keyof typeof FAMILIARITY_LABEL] ?? k}`)
            .join(", ");
          addLog("success", `✓ ${item.target.chapterTitle} : +${result.questions.length} Q (${famSummary}) (~$${cost.toFixed(4)})`);
          if (result.rejectedReasons && result.rejectedReasons.length > 0) {
            addLog("warn", `  ⚠ ${result.rejectedReasons.length} rejetée(s) : ${result.rejectedReasons.slice(0, 2).join(" | ")}`);
          }
          updateQueue((prev) => prev.map((q, i) => (i === idx ? { ...q, status: "done", questionCount: result.questions.length } : q)));
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        addLog("error", `Exception : ${msg}`);
        updateQueue((prev) => prev.map((q, i) => (i === idx ? { ...q, status: "failed", error: msg } : q)));
      }

      idxRef.current += 1;
      setQueueIndex(idxRef.current);
      await new Promise((r) => setTimeout(r, 250));
    }

    runningRef.current = false;
    if (stoppedForCredits) {
      // state already set to "error" above
    } else if (idxRef.current >= queueRef.current.length && !bulkGoalRef.current) {
      setRunState("idle");
      addLog("success", "Boucle terminée");
    } else {
      setRunState("paused");
      addLog("info", "Boucle en pause");
    }
  }, [content, addLog, updateQueue]);

  const toggleRun = () => {
    if (runState === "running") {
      runningRef.current = false;
      setRunState("paused");
      addLog("info", "Pause demandée");
    } else {
      runLoop();
    }
  };

  const buildAutoQueue = () => {
    if (incompleteTargets.length === 0) {
      addLog("info", "Aucun chapitre incomplet détecté — tout est complet !");
      return;
    }
    bulkGoalRef.current = null;
    setBulkGoal(null);
    idxRef.current = 0;
    setQueueIndex(0);
    updateQueue(() => incompleteTargets.map((t) => ({ target: t, status: "pending" as const, questionCount: 0 })));
    setRunState("idle");
    addLog("info", `Auto-détection : ${incompleteTargets.length} tâche(s) ajoutée(s) (${incompleteNeeded} questions au total)`);
  };

  const addManualTarget = () => {
    if (!selDiscipline || !selChapter || selCount < 1) return;
    const disc = disciplines.find((d) => d.id === selDiscipline);
    const ch = disc?.chapters.find((c) => c.id === selChapter);
    if (!disc || !ch) return;
    const level = isLegacyChapter(ch) ? "facile" : selLevel;

    // Split large manual requests into reliable batches of 8.
    const batchSize = 8;
    let left = selCount;
    const newItems: QueueItem[] = [];
    while (left > 0) {
      const count = Math.min(batchSize, left);
      const target: GenTarget = {
        disciplineId: disc.id,
        disciplineName: disc.name,
        chapterId: ch.id,
        chapterTitle: ch.title,
        level,
        count,
      };
      newItems.push({ target, status: "pending", questionCount: 0 });
      left -= count;
    }
    updateQueue((prev) => [...prev, ...newItems]);
    addLog("info", `Tâche manuelle ajoutée : ${ch.title} (${level}) × ${selCount}, en ${newItems.length} lot(s)`);
  };

  const startBulk = () => {
    if (!content || bulkCount < 1) return;
    const targets = planBulkTargets(content, bulkCount, 8);
    bulkGoalRef.current = { goal: bulkCount, generated: 0 };
    setBulkGoal(bulkGoalRef.current);
    idxRef.current = 0;
    setQueueIndex(0);
    updateQueue(() => targets.map((t) => ({ target: t, status: "pending" as const, questionCount: 0 })));
    addLog("info", `Mode Rafale : objectif ${bulkCount} questions, ${targets.length} tâche(s) planifiée(s). Ne s'arrêtera pas avant d'atteindre l'objectif.`);
    runLoop();
  };

  const stopBulkOnly = () => {
    bulkGoalRef.current = null;
    setBulkGoal(null);
    addLog("info", "Objectif rafale annulé — la file en cours ira jusqu'au bout puis s'arrêtera");
  };

  const clearQueue = () => {
    runningRef.current = false;
    bulkGoalRef.current = null;
    setBulkGoal(null);
    idxRef.current = 0;
    setQueueIndex(0);
    updateQueue(() => []);
    setRunState("idle");
  };

  const handleDownload = () => {
    if (!content) return;
    downloadJson(content);
    addLog("success", "content.json téléchargé");
  };

  const [publishing, setPublishing] = useState<boolean>(false);
  const [publishedInfo, setPublishedInfo] = useState<{ version: number; questionCount: number } | null>(null);

  const handlePublish = async () => {
    if (!content) return;
    setPublishing(true);
    const fnUrl = import.meta.env.VITE_RORK_FUNCTIONS_URL
      ?? import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL
      ?? "https://mindduel-kqfozex-backend.rork.app";
    const maxAttempts = 3;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        if (attempt > 1) {
          addLog("warn", `Nouvelle tentative de publication (${attempt}/${maxAttempts})…`);
          await new Promise((r) => setTimeout(r, 1000 * attempt));
        }
        const res = await fetch(`${fnUrl}/api/content/publish`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ content, password: "minduel-admin" }),
        });
        if (!res.ok) {
          const err = await res.json().catch(() => ({}));
          addLog("error", `Publication échouée : ${(err as { error?: string }).error ?? res.status}`);
          break;
        }
        const data = (await res.json()) as { version: number; questionCount: number };
        setPublishedInfo(data);
        addLog("success", `Publié sur le backend ✓ v${data.version} — ${data.questionCount} questions en ligne. L'app iOS les récupérera au prochain démarrage.`);
        break;
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        if (attempt >= maxAttempts) {
          addLog("error", `Publication échouée après ${maxAttempts} tentatives : ${msg}. Vérifie ta connexion et réessaie.`);
        } else {
          addLog("warn", `Tentative ${attempt} échouée (${msg}), nouvel essai…`);
        }
      }
    }
    setPublishing(false);
  };

  const handleCopyJson = async () => {
    if (!content) return;
    try {
      await navigator.clipboard.writeText(JSON.stringify(content, null, 2));
      addLog("success", "JSON copié dans le presse-papier");
    } catch {
      addLog("error", "Impossible de copier le JSON");
    }
  };

  const availableLevels = selectedChapter?.levels ? Object.keys(selectedChapter.levels) : ["facile"];
  const bulkProgressPct = bulkGoal ? Math.min(100, Math.round((bulkGoal.generated / bulkGoal.goal) * 100)) : 0;

  // --- Login gate ---
  if (!authed) {
    return (
      <div className="min-h-screen bg-[#0b0f1a] text-white flex items-center justify-center px-6">
        <div className="w-full max-w-sm">
          <Link to="/" className="mb-6 inline-flex items-center gap-2 text-sm text-white/50 hover:text-white">
            <ArrowLeft className="h-4 w-4" />
            Retour au site
          </Link>
          <div className="rounded-3xl border border-white/10 bg-white/[0.03] p-8">
            <div className="mb-6 flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-400 to-orange-500">
                <Lock className="h-6 w-6 text-[#0b0f1a]" />
              </div>
              <div>
                <h1 className="text-lg font-bold">Admin Generator</h1>
                <p className="text-xs text-white/50">Accès réservé à l'équipe</p>
              </div>
            </div>
            <form onSubmit={handleAuth} className="space-y-4">
              <input
                type="password"
                value={passwordInput}
                onChange={(e) => setPasswordInput(e.target.value)}
                placeholder="Mot de passe"
                autoFocus
                className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/30 focus:border-amber-500/50 focus:outline-none focus:ring-1 focus:ring-amber-500/30"
              />
              {authError && <p className="text-sm text-red-400">{authError}</p>}
              <button
                type="submit"
                className="w-full rounded-xl bg-gradient-to-r from-amber-400 to-orange-500 px-4 py-3 text-sm font-bold text-[#0b0f1a] transition hover:brightness-105 active:scale-[0.98]"
              >
                Se connecter
              </button>
            </form>
          </div>
        </div>
      </div>
    );
  }

  // --- Main dashboard ---
  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      {/* Top bar */}
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#0b0f1a]/90 backdrop-blur-lg">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-3">
          <div className="flex items-center gap-3">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-white/50 hover:text-white">
              <ArrowLeft className="h-4 w-4" />
              Accueil
            </Link>
            <span className="text-white/20">|</span>
            <span className="text-sm font-bold">Generator Admin</span>
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={loadContent}
              disabled={loading}
              className="inline-flex items-center gap-2 rounded-lg border border-white/10 px-3 py-1.5 text-xs font-medium text-white/70 transition hover:bg-white/5 disabled:opacity-50"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
              Recharger
            </button>
            <button
              type="button"
              onClick={handleDownload}
              disabled={!content}
              className="inline-flex items-center gap-2 rounded-lg border border-white/10 px-3 py-1.5 text-xs font-medium text-white/70 transition hover:bg-white/5 disabled:opacity-50"
            >
              <Download className="h-3.5 w-3.5" />
              content.json
            </button>
            <button
              type="button"
              onClick={handlePublish}
              disabled={!content || publishing}
              className="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r from-emerald-500 to-teal-500 px-3 py-1.5 text-xs font-bold text-white transition hover:brightness-105 disabled:opacity-50"
            >
              {publishing ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
              Publier
            </button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 py-8">
        <p className="mb-6 max-w-2xl text-sm text-white/40">
          Génère automatiquement des questions de culture G au format Minduel avec l'IA, les valide, les corrige, et les fusionne dans le contenu.
          Utilise <span className="text-white/60">Mode Rafale</span> pour lancer un gros volume d'un coup — la boucle ne s'arrêtera pas tant que l'objectif n'est pas atteint.
          Clique sur <span className="text-emerald-400">Publier</span> pour envoyer le contenu sur le backend — l'app iOS le récupérera automatiquement au prochain démarrage, sans mise à jour App Store.
        </p>

        {publishedInfo && (
          <div className="mb-6 flex items-center gap-3 rounded-xl border border-emerald-500/20 bg-emerald-500/[0.06] px-4 py-3 text-sm">
            <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-400" />
            <span className="text-emerald-300">
              Contenu publié ✓ — v{publishedInfo.version} · {publishedInfo.questionCount} questions en ligne.
              L'app iOS récupérera cette version automatiquement.
            </span>
          </div>
        )}

        {/* Bulk progress bar (shown only during a bulk run) */}
        {bulkGoal && (
          <div className="mb-6 rounded-2xl border border-amber-500/30 bg-amber-500/[0.06] p-4">
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="inline-flex items-center gap-2 font-bold text-amber-300">
                <Flame className="h-4 w-4" />
                Rafale en cours — {bulkGoal.generated} / {bulkGoal.goal} questions ({bulkProgressPct}%)
              </span>
              <button
                type="button"
                onClick={stopBulkOnly}
                className="inline-flex items-center gap-1 rounded-lg border border-white/10 px-2 py-1 text-xs text-white/60 hover:bg-white/5"
              >
                <X className="h-3 w-3" />
                Annuler l'objectif
              </button>
            </div>
            <div className="h-2.5 w-full overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-gradient-to-r from-amber-400 to-orange-500 transition-all duration-500"
                style={{ width: `${bulkProgressPct}%` }}
              />
            </div>
          </div>
        )}

        {/* Status cards */}
        <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <StatCard icon={<Brain className="h-5 w-5" />} label="Questions totales" value={summary.totalQuestions.toString()} accent="text-amber-400" />
          <StatCard icon={<CheckCircle2 className="h-5 w-5" />} label="Chapitres complets" value={`${summary.complete}/${summary.total}`} accent="text-emerald-400" />
          <StatCard icon={<Sparkles className="h-5 w-5" />} label="Générées (session)" value={totalGenerated.toString()} accent="text-sky-400" />
          <StatCard icon={<Zap className="h-5 w-5" />} label="Coût (session)" value={`$${totalCost.toFixed(4)}`} accent="text-orange-400" />
          <StatCard icon={<AlertTriangle className="h-5 w-5" />} label="À compléter" value={summary.incomplete.toString()} accent="text-red-400" />
        </div>

        <div className="grid gap-6 lg:grid-cols-[360px_1fr_1fr]">
          {/* LEFT: Controls */}
          <div className="space-y-4">
            {/* Main toggle — always visible regardless of tab */}
            <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
              <div className="mb-4 flex items-center justify-between">
                <h2 className="text-sm font-bold uppercase tracking-wider text-white/60">Boucle</h2>
                <span
                  className={`rounded-full px-2 py-0.5 text-xs font-bold ${
                    runState === "running"
                      ? "bg-emerald-500/20 text-emerald-400"
                      : runState === "paused"
                        ? "bg-amber-500/20 text-amber-400"
                        : runState === "error"
                          ? "bg-red-500/20 text-red-400"
                          : "bg-white/10 text-white/50"
                  }`}
                >
                  {runState === "running" ? "EN COURS" : runState === "paused" ? "PAUSE" : runState === "error" ? "ERREUR" : "ARRÊT"}
                </span>
              </div>
              <button
                type="button"
                onClick={toggleRun}
                disabled={queue.length === 0 || runState === "error"}
                className={`flex w-full items-center justify-center gap-2 rounded-xl px-4 py-3 text-sm font-bold transition disabled:opacity-40 ${
                  runState === "running" ? "bg-amber-500/20 text-amber-400 hover:bg-amber-500/30" : "bg-gradient-to-r from-amber-400 to-orange-500 text-[#0b0f1a] hover:brightness-105"
                }`}
              >
                {runState === "running" ? (
                  <>
                    <Pause className="h-4 w-4" /> Pause
                  </>
                ) : (
                  <>
                    <Play className="h-4 w-4" /> {queue.length === 0 ? "File vide" : "Démarrer"}
                  </>
                )}
              </button>
              {queue.length > 0 && (
                <button
                  type="button"
                  onClick={clearQueue}
                  className="mt-2 flex w-full items-center justify-center gap-2 rounded-lg border border-white/10 px-3 py-2 text-xs font-medium text-red-400/70 transition hover:bg-red-500/10"
                >
                  <Trash2 className="h-3.5 w-3.5" />
                  Vider la file
                </button>
              )}
            </div>

            {/* Tab switcher */}
            <div className="flex gap-1 rounded-xl border border-white/10 bg-white/[0.02] p-1">
              <TabButton active={leftTab === "bulk"} onClick={() => setLeftTab("bulk")} icon={<Flame className="h-3.5 w-3.5" />} label="Rafale" />
              <TabButton active={leftTab === "auto"} onClick={() => setLeftTab("auto")} icon={<Wand2 className="h-3.5 w-3.5" />} label="Auto" />
              <TabButton active={leftTab === "manual"} onClick={() => setLeftTab("manual")} icon={<ListChecks className="h-3.5 w-3.5" />} label="Manuel" />
            </div>

            {leftTab === "bulk" && (
              <div className="rounded-2xl border border-amber-500/20 bg-white/[0.03] p-5">
                <h2 className="mb-1 text-sm font-bold uppercase tracking-wider text-white/60">Mode Rafale</h2>
                <p className="mb-4 text-xs text-white/40">
                  Génère un gros volume d'un coup. La boucle enchaîne les lots automatiquement et ne s'arrête que si l'objectif est atteint ou si les crédits sont épuisés.
                </p>
                <label className="mb-1 block text-xs text-white/50">Nombre de questions à générer</label>
                <input
                  type="number"
                  min={1}
                  step={10}
                  value={bulkCount}
                  onChange={(e) => setBulkCount(Number(e.target.value) || 0)}
                  className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-amber-500/50 focus:outline-none"
                />
                <div className="mb-4 flex flex-wrap gap-2">
                  {[100, 300, 600, 1000].map((n) => (
                    <button
                      key={n}
                      type="button"
                      onClick={() => setBulkCount(n)}
                      className={`rounded-full px-3 py-1 text-xs font-medium transition ${bulkCount === n ? "bg-amber-500/20 text-amber-300" : "border border-white/10 text-white/50 hover:bg-white/5"}`}
                    >
                      {n}
                    </button>
                  ))}
                </div>
                <p className="mb-4 text-xs text-white/40">
                  Priorité aux {incompleteTargets.length > 0 ? `${summary.incomplete} niveau(x) incomplet(s)` : "chapitres incomplets"}, puis complète au-delà si besoin. Coût estimé : ~${estimateCost(bulkCount).toFixed(2)}.
                </p>
                <button
                  type="button"
                  onClick={startBulk}
                  disabled={!content || bulkCount < 1 || runState === "running"}
                  className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-amber-400 to-orange-500 px-4 py-3 text-sm font-bold text-[#0b0f1a] transition hover:brightness-105 disabled:opacity-40"
                >
                  <Flame className="h-4 w-4" />
                  Lancer {bulkCount} questions
                </button>
              </div>
            )}

            {leftTab === "auto" && (
              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <h2 className="mb-1 text-sm font-bold uppercase tracking-wider text-white/60">Auto-détection</h2>
                <p className="mb-4 text-xs text-white/40">
                  Scanne tous les chapitres et complète uniquement ceux qui ont moins de {TARGET_PER_LEVEL} questions par niveau.
                </p>
                <div className="mb-4 rounded-lg border border-white/5 bg-white/[0.02] p-3 text-xs">
                  <div className="flex justify-between text-white/50">
                    <span>Niveaux incomplets</span>
                    <span className="font-mono text-white/80">{summary.incomplete}</span>
                  </div>
                  <div className="flex justify-between text-white/50">
                    <span>Questions manquantes</span>
                    <span className="font-mono text-white/80">{incompleteNeeded}</span>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={buildAutoQueue}
                  disabled={!content}
                  className="w-full rounded-lg border border-white/10 px-3 py-2 text-sm font-bold text-white/80 transition hover:bg-white/5 disabled:opacity-40"
                >
                  Remplir la file automatiquement
                </button>
              </div>
            )}

            {leftTab === "manual" && (
              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <h2 className="mb-1 text-sm font-bold uppercase tracking-wider text-white/60">Génération manuelle</h2>
                <p className="mb-4 text-xs text-white/40">Choisis un chapitre et un niveau précis à compléter.</p>
                <div className="space-y-3">
                  <div>
                    <label className="mb-1 block text-xs text-white/50">Discipline</label>
                    <select
                      value={selDiscipline}
                      onChange={(e) => {
                        setSelDiscipline(e.target.value);
                        setSelChapter("");
                      }}
                      className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-amber-500/50 focus:outline-none"
                    >
                      <option value="">Choisir…</option>
                      {disciplines.map((d) => (
                        <option key={d.id} value={d.id} className="bg-[#0b0f1a]">
                          {d.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="mb-1 block text-xs text-white/50">Chapitre</label>
                    <select
                      value={selChapter}
                      onChange={(e) => setSelChapter(e.target.value)}
                      disabled={!selDiscipline}
                      className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-amber-500/50 focus:outline-none disabled:opacity-40"
                    >
                      <option value="">Choisir…</option>
                      {selectedDiscipline?.chapters.map((c) => {
                        const q = countQuestions(c);
                        return (
                          <option key={c.id} value={c.id} className="bg-[#0b0f1a]">
                            {c.title} ({q} Q)
                          </option>
                        );
                      })}
                    </select>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="mb-1 block text-xs text-white/50">Niveau</label>
                      <select
                        value={selLevel}
                        onChange={(e) => setSelLevel(e.target.value)}
                        disabled={!selChapter || (selectedChapter ? isLegacyChapter(selectedChapter) : true)}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-amber-500/50 focus:outline-none disabled:opacity-40"
                      >
                        {(availableLevels.length > 0 ? availableLevels : ["facile"]).map((l) => (
                          <option key={l} value={l} className="bg-[#0b0f1a]">
                            {l}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="mb-1 block text-xs text-white/50">Nombre</label>
                      <input
                        type="number"
                        min={1}
                        max={200}
                        value={selCount}
                        onChange={(e) => setSelCount(Number(e.target.value) || 1)}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-amber-500/50 focus:outline-none"
                      />
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={addManualTarget}
                    disabled={!selChapter}
                    className="w-full rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs font-bold text-amber-400 transition hover:bg-amber-500/20 disabled:opacity-40"
                  >
                    + Ajouter à la file
                  </button>
                </div>
              </div>
            )}

            {/* Model info */}
            <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
              <h2 className="mb-3 text-sm font-bold uppercase tracking-wider text-white/60">Configuration</h2>
              <dl className="space-y-2 text-xs">
                <div className="flex justify-between">
                  <dt className="text-white/50">Modèle</dt>
                  <dd className="font-mono text-white/80">{MODEL_ID}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-white/50">Coût/Q</dt>
                  <dd className="font-mono text-white/80">~${COST_PER_QUESTION_USD.toFixed(4)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-white/50">Cible/niveau</dt>
                  <dd className="font-mono text-white/80">{TARGET_PER_LEVEL} Q</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-white/50">Taille de lot</dt>
                  <dd className="font-mono text-white/80">8 Q/appel</dd>
                </div>
              </dl>
            </div>
          </div>

          {/* CENTER: Queue */}
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-sm font-bold uppercase tracking-wider text-white/60">File de génération ({queue.length})</h2>
              {queueIndex > 0 && queueIndex < queue.length && <span className="text-xs text-white/40">{queueIndex}/{queue.length}</span>}
            </div>
            <div className="max-h-[600px] space-y-2 overflow-y-auto pr-1">
              {queue.length === 0 ? (
                <div className="flex h-32 flex-col items-center justify-center gap-2 text-center text-sm text-white/30">
                  <span>File vide</span>
                  <span className="text-xs">Choisis Rafale, Auto ou Manuel à gauche pour commencer</span>
                </div>
              ) : (
                queue.map((item, i) => (
                  <div
                    key={`${item.target.chapterId}-${item.target.level}-${i}`}
                    className={`flex items-center gap-3 rounded-xl border p-3 text-sm transition ${
                      item.status === "running"
                        ? "border-amber-500/40 bg-amber-500/10"
                        : item.status === "done"
                          ? "border-emerald-500/20 bg-emerald-500/5"
                          : item.status === "failed"
                            ? "border-red-500/30 bg-red-500/5"
                            : i < queueIndex
                              ? "border-white/5 bg-white/[0.02] opacity-50"
                              : "border-white/10 bg-white/[0.02]"
                    }`}
                  >
                    <div className="shrink-0">
                      {item.status === "running" ? (
                        <Loader2 className="h-4 w-4 animate-spin text-amber-400" />
                      ) : item.status === "done" ? (
                        <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                      ) : item.status === "failed" ? (
                        <XCircle className="h-4 w-4 text-red-400" />
                      ) : (
                        <div className="h-4 w-4 rounded-full border-2 border-white/20" />
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium text-white/90">{item.target.chapterTitle}</p>
                      <p className="text-xs text-white/40">
                        {item.target.disciplineName} · {item.target.level} · {item.target.count} Q
                        {item.status === "done" && item.questionCount > 0 && ` · ✓ ${item.questionCount}`}
                        {item.status === "failed" && item.error && ` · ✗ ${item.error.slice(0, 60)}`}
                      </p>
                    </div>
                  </div>
                ))
              )}
            </div>
            {content && (
              <div className="mt-4 flex gap-2 border-t border-white/5 pt-4">
                <button
                  type="button"
                  onClick={handleCopyJson}
                  className="flex-1 inline-flex items-center justify-center gap-2 rounded-lg border border-white/10 px-3 py-2 text-xs font-medium text-white/70 transition hover:bg-white/5"
                >
                  <Copy className="h-3.5 w-3.5" />
                  Copier JSON
                </button>
              </div>
            )}
          </div>

          {/* RIGHT: Live log */}
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
            <h2 className="mb-4 text-sm font-bold uppercase tracking-wider text-white/60">Log en direct</h2>
            <div className="max-h-[600px] overflow-y-auto rounded-xl bg-black/40 p-3 font-mono text-xs leading-relaxed">
              {logs.length === 0 ? (
                <p className="text-white/30">En attente d'activité…</p>
              ) : (
                logs.map((log, i) => (
                  <div key={i} className="flex gap-2 py-0.5">
                    <span className="shrink-0 text-white/30">{log.time}</span>
                    <span
                      className={
                        log.level === "success"
                          ? "text-emerald-400"
                          : log.level === "error"
                            ? "text-red-400"
                            : log.level === "warn"
                              ? "text-amber-400"
                              : "text-white/60"
                      }
                    >
                      {log.message}
                    </span>
                  </div>
                ))
              )}
              <div ref={logEndRef} />
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

type StatCardProps = {
  icon: React.ReactNode;
  label: string;
  value: string;
  accent: string;
};

const StatCard = ({ icon, label, value, accent }: StatCardProps) => (
  <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
    <div className={`mb-2 ${accent}`}>{icon}</div>
    <p className="text-2xl font-extrabold text-white">{value}</p>
    <p className="mt-0.5 text-xs uppercase tracking-wider text-white/40">{label}</p>
  </div>
);

type TabButtonProps = {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
};

const TabButton = ({ active, onClick, icon, label }: TabButtonProps) => (
  <button
    type="button"
    onClick={onClick}
    className={`flex flex-1 items-center justify-center gap-1.5 rounded-lg px-2 py-2 text-xs font-bold transition ${
      active ? "bg-amber-500/20 text-amber-300" : "text-white/40 hover:bg-white/5 hover:text-white/70"
    }`}
  >
    {icon}
    {label}
  </button>
);

export default AdminGenerator;
