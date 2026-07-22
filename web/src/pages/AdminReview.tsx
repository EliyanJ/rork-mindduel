import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowLeft,
  Bot,
  CheckCircle2,
  Download,
  Loader2,
  Lock,
  Pencil,
  RefreshCw,
  Search,
  SkipForward,
  Sparkles,
  ThumbsDown,
  ThumbsUp,
  Trash2,
  XCircle,
} from "lucide-react";
import { Link } from "react-router-dom";

import {
  type Content,
  type Question,
  type QuestionType,
  downloadJson,
  fetchContent,
} from "@/lib/generator";
import {
  AI_MODELS,
  LEVEL_LABEL,
  type FlatQuestion,
  type QuestionRef,
  deleteQuestion,
  flattenQuestions,
  markStatus,
  moveQuestion,
  questionStatus,
  updateQuestion,
} from "@/lib/moderation";
import { type AiConfig, type AiReviewResult, reviewQuestionWithAi } from "@/lib/aiReview";
import { PhoneQuestionPreview } from "@/components/PhoneQuestionPreview";

const ADMIN_PASSWORD = "minduel-admin";
const DRAFT_KEY = "minduel-review-draft-v1";
const NOTES_KEY = "minduel-review-ai-notes-v1";
const CHANGES_KEY = "minduel-review-pending-changes-v1";

type Tab = "review" | "rejected" | "all" | "categorize";
type LogLevel = "info" | "success" | "warn" | "error";
type LogEntry = { time: string; level: LogLevel; message: string };

const refOf = (item: FlatQuestion): QuestionRef => ({
  disciplineId: item.disciplineId,
  chapterId: item.chapterId,
  level: item.level,
});

/** A single moderation decision, tracked independently from the full working
 * copy of content.json. `question: null` means "delete this question".
 * `moveTo` (categorization tab) means "re-file this question under a
 * different theme/difficulty" — replayed as a delete-then-insert at publish
 * time. Publishing replays exactly these decisions on top of the freshest
 * server content, so it can never clobber questions generated/published
 * elsewhere in the meantime. */
type PendingChange = { ref: QuestionRef; question: Question | null; moveTo?: QuestionRef };

/** Difficulty levels a question can be manually re-filed under (in order of
 * increasing difficulty) — used by the categorization tab's dropdown. */
const DIFFICULTY_LEVELS = ["facile", "intermediaire", "difficile", "maitre", "legende"];

const AdminReview = () => {
  const [authed, setAuthed] = useState(false);
  const [passwordInput, setPasswordInput] = useState("");
  const [authError, setAuthError] = useState("");

  const [content, setContent] = useState<Content | null>(null);
  const [loading, setLoading] = useState(false);
  const [tab, setTab] = useState<Tab>("review");
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [publishedInfo, setPublishedInfo] = useState<{ version: number; questionCount: number } | null>(null);
  const [hasDraft, setHasDraft] = useState(false);

  // filters (shared across tabs)
  const [search, setSearch] = useState("");
  const [disciplineFilter, setDisciplineFilter] = useState("all");
  const [levelFilter, setLevelFilter] = useState("all");
  const [sourceFilter, setSourceFilter] = useState<"all" | "human" | "ai">("all");
  const [allStatusFilter, setAllStatusFilter] = useState<"all" | "pending" | "approved" | "rejected">("all");

  // review queue order (question ids), independent from array order so "skip" can push to the back
  const [orderIds, setOrderIds] = useState<string[]>([]);

  // AI review notes, keyed by question id — ephemeral, never written into content.json
  const [aiNotes, setAiNotes] = useState<Record<string, AiReviewResult>>({});

  // AI config — apiKey lives ONLY in this component's memory for the session, never persisted
  const [aiModelId, setAiModelId] = useState(AI_MODELS[0].id);
  const [aiApiKey, setAiApiKey] = useState("");
  const [aiBatchSize, setAiBatchSize] = useState(50);
  const [aiAutoApply, setAiAutoApply] = useState(false);
  const [aiConfidenceThreshold, setAiConfidenceThreshold] = useState(80);
  const [aiRunning, setAiRunning] = useState(false);
  const [aiProgress, setAiProgress] = useState({ done: 0, total: 0 });

  // Moderation decisions, keyed by question id — the source of truth used at
  // publish time (see handlePublish). Kept separate from `content` so publishing
  // never has to trust that the full local working copy is still up to date.
  const [pendingChanges, setPendingChanges] = useState<Record<string, PendingChange>>({});
  const [lastBatchSummary, setLastBatchSummary] = useState<{
    autoApproved: number;
    autoRejected: number;
    suggested: number;
    errored: number;
  } | null>(null);
  const aiRunningRef = useRef(false);

  // edit modal
  const [editingItem, setEditingItem] = useState<FlatQuestion | null>(null);
  const [editPrompt, setEditPrompt] = useState("");
  const [editOptionsText, setEditOptionsText] = useState("");
  const [editAnswer, setEditAnswer] = useState("");
  const [editExplanation, setEditExplanation] = useState("");

  const addLog = useCallback((level: LogLevel, message: string) => {
    setLogs((prev) => [...prev.slice(-200), { time: new Date().toLocaleTimeString("fr-FR"), level, message }]);
  }, []);

  const handleAuth = (e: React.FormEvent) => {
    e.preventDefault();
    if (passwordInput === ADMIN_PASSWORD) {
      setAuthed(true);
      setAuthError("");
    } else {
      setAuthError("Mot de passe incorrect");
    }
  };

  const loadFromServer = useCallback(async () => {
    setLoading(true);
    try {
      const c = await fetchContent();
      setContent(c);
      localStorage.removeItem(DRAFT_KEY);
      setHasDraft(false);
      addLog("info", `content.json rechargé depuis le serveur : ${c.disciplines.length} disciplines`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      addLog("error", `Erreur chargement content.json : ${msg}`);
    } finally {
      setLoading(false);
    }
  }, [addLog]);

  const loadInitial = useCallback(async () => {
    setLoading(true);
    try {
      const draftRaw = localStorage.getItem(DRAFT_KEY);
      if (draftRaw) {
        const draft = JSON.parse(draftRaw) as { content: Content; savedAt: number };
        setContent(draft.content);
        setHasDraft(true);
        addLog("info", `Brouillon local restauré (sauvegardé le ${new Date(draft.savedAt).toLocaleString("fr-FR")})`);
      } else {
        const c = await fetchContent();
        setContent(c);
        addLog("info", `content.json chargé : ${c.disciplines.length} disciplines`);
      }
      const notesRaw = localStorage.getItem(NOTES_KEY);
      if (notesRaw) setAiNotes(JSON.parse(notesRaw));
      const changesRaw = localStorage.getItem(CHANGES_KEY);
      if (changesRaw) setPendingChanges(JSON.parse(changesRaw));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      addLog("error", `Erreur chargement : ${msg}`);
    } finally {
      setLoading(false);
    }
  }, [addLog]);

  useEffect(() => {
    if (authed && !content && !loading) {
      loadInitial();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authed]);

  // Autosave the working content to localStorage so a closed tab never loses progress.
  useEffect(() => {
    if (!content) return;
    const t = setTimeout(() => {
      try {
        localStorage.setItem(DRAFT_KEY, JSON.stringify({ content, savedAt: Date.now() }));
        setHasDraft(true);
      } catch {
        // storage full — silently skip, publish/download still work
      }
    }, 800);
    return () => clearTimeout(t);
  }, [content]);

  // Persist AI notes too (small, and never includes the API key).
  useEffect(() => {
    const t = setTimeout(() => {
      try {
        localStorage.setItem(NOTES_KEY, JSON.stringify(aiNotes));
      } catch {
        // ignore
      }
    }, 500);
    return () => clearTimeout(t);
  }, [aiNotes]);

  // Persist moderation decisions independently — this is what publish replays
  // onto the latest server content, so it survives page reloads too.
  useEffect(() => {
    const t = setTimeout(() => {
      try {
        localStorage.setItem(CHANGES_KEY, JSON.stringify(pendingChanges));
      } catch {
        // ignore
      }
    }, 500);
    return () => clearTimeout(t);
  }, [pendingChanges]);

  const recordChange = useCallback((ref: QuestionRef, questionId: string, question: Question | null) => {
    setPendingChanges((prev) => ({ ...prev, [questionId]: { ref, question } }));
  }, []);

  const recordMove = useCallback((ref: QuestionRef, moveTo: QuestionRef, questionId: string, question: Question) => {
    setPendingChanges((prev) => ({ ...prev, [questionId]: { ref, question, moveTo } }));
  }, []);

  const flatQuestions = useMemo(() => flattenQuestions(content), [content]);

  const disciplineOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const f of flatQuestions) map.set(f.disciplineId, f.disciplineName);
    return Array.from(map.entries());
  }, [flatQuestions]);

  const levelOptions = useMemo(() => {
    const set = new Set<string>();
    for (const f of flatQuestions) set.add(f.level);
    return Array.from(set);
  }, [flatQuestions]);

  const matchesFilters = useCallback(
    (item: FlatQuestion) => {
      if (disciplineFilter !== "all" && item.disciplineId !== disciplineFilter) return false;
      if (levelFilter !== "all" && item.level !== levelFilter) return false;
      if (sourceFilter !== "all" && item.question.moderatedBy !== sourceFilter) return false;
      if (search.trim()) {
        const s = search.trim().toLowerCase();
        if (!item.question.prompt.toLowerCase().includes(s) && !item.question.answer.toLowerCase().includes(s)) return false;
      }
      return true;
    },
    [disciplineFilter, levelFilter, sourceFilter, search],
  );

  // Discipline -> chapters lookup for the categorization tab's dropdowns.
  const chaptersByDiscipline = useMemo(() => {
    const map = new Map<string, { id: string; title: string }[]>();
    if (!content) return map;
    for (const disc of content.disciplines) {
      map.set(disc.id, disc.chapters.map((c) => ({ id: c.id, title: c.title })));
    }
    return map;
  }, [content]);

  // Local (not-yet-applied) selection per question row in the categorization
  // tab — defaults to the question's current location until you pick something else.
  const [categorizeSelection, setCategorizeSelection] = useState<Record<string, QuestionRef>>({});

  const categorizeItems = useMemo(() => flatQuestions.filter(matchesFilters), [flatQuestions, matchesFilters]);

  const stats = useMemo(() => {
    let approved = 0;
    let rejected = 0;
    for (const f of flatQuestions) {
      const s = questionStatus(f.question);
      if (s === "approved") approved += 1;
      else if (s === "rejected") rejected += 1;
    }
    const total = flatQuestions.length;
    return { total, approved, rejected, pending: total - approved - rejected };
  }, [flatQuestions]);

  // Questions still officially "pending" but that the IA has already reviewed
  // and given a decision for (kept as a suggestion, not yet applied). You trust
  // the AI's call, so these should count as "already assessed" for a realistic
  // sense of what's truly left to look at from scratch — even though the
  // official approved/rejected counters only move once a decision is applied.
  const aiAssessedPendingCount = useMemo(
    () => flatQuestions.reduce((n, f) => (questionStatus(f.question) === "pending" && aiNotes[f.question.id] ? n + 1 : n), 0),
    [flatQuestions, aiNotes],
  );

  // Combined tally: officially applied (human or AI) + AI suggestions still
  // awaiting your click. This is the "add manual + AI together" number asked
  // for — a realistic view of what's genuinely untouched.
  const assessedTotal = stats.approved + stats.rejected + aiAssessedPendingCount;
  const trulyUntouched = stats.total - assessedTotal;
  const progressPct = stats.total > 0 ? Math.round((assessedTotal / stats.total) * 100) : 0;

  const pendingItems = useMemo(
    () => flatQuestions.filter((f) => questionStatus(f.question) === "pending" && matchesFilters(f)),
    [flatQuestions, matchesFilters],
  );

  const rejectedItems = useMemo(
    () => flatQuestions.filter((f) => questionStatus(f.question) === "rejected" && matchesFilters(f)),
    [flatQuestions, matchesFilters],
  );

  const allItems = useMemo(
    () =>
      flatQuestions.filter((f) => {
        if (allStatusFilter !== "all" && questionStatus(f.question) !== allStatusFilter) return false;
        return matchesFilters(f);
      }),
    [flatQuestions, matchesFilters, allStatusFilter],
  );

  // Keep the review queue order stable across re-renders: newly-pending items
  // are appended, resolved items drop out automatically, and "skip" reorders
  // without touching moderation status.
  useEffect(() => {
    setOrderIds((prev) => {
      const pendingIds = pendingItems.map((f) => f.question.id);
      const pendingSet = new Set(pendingIds);
      const keep = prev.filter((id) => pendingSet.has(id));
      const keepSet = new Set(keep);
      const added = pendingIds.filter((id) => !keepSet.has(id));
      return [...keep, ...added];
    });
  }, [pendingItems]);

  const currentItem = useMemo(() => {
    if (orderIds.length === 0) return null;
    return flatQuestions.find((f) => f.question.id === orderIds[0]) ?? null;
  }, [orderIds, flatQuestions]);

  const applyUpdate = useCallback((ref: QuestionRef, questionId: string, updater: (q: Question) => Question) => {
    setContent((prev) => (prev ? updateQuestion(prev, ref, questionId, updater) : prev));
  }, []);

  const handleApprove = useCallback(
    (item: FlatQuestion, by: "human" | "ai" = "human") => {
      const ref = refOf(item);
      const next = markStatus(item.question, "approved", by);
      applyUpdate(ref, item.question.id, () => next);
      recordChange(ref, item.question.id, next);
      addLog("success", `✓ Validée : ${item.question.prompt.slice(0, 60)}`);
    },
    [applyUpdate, recordChange, addLog],
  );

  const handleReject = useCallback(
    (item: FlatQuestion, by: "human" | "ai" = "human") => {
      const ref = refOf(item);
      const next = markStatus(item.question, "rejected", by);
      applyUpdate(ref, item.question.id, () => next);
      recordChange(ref, item.question.id, next);
      addLog("warn", `✗ Rejetée : ${item.question.prompt.slice(0, 60)}`);
    },
    [applyUpdate, recordChange, addLog],
  );

  const handleSkip = useCallback(() => {
    setOrderIds((ids) => (ids.length > 1 ? [...ids.slice(1), ids[0]] : ids));
  }, []);

  const handleDelete = useCallback(
    (item: FlatQuestion) => {
      if (!window.confirm("Supprimer définitivement cette question ? Cette action est irréversible.")) return;
      const ref = refOf(item);
      setContent((prev) => (prev ? deleteQuestion(prev, ref, item.question.id) : prev));
      recordChange(ref, item.question.id, null);
      addLog("warn", `🗑 Supprimée définitivement : ${item.question.prompt.slice(0, 60)}`);
    },
    [addLog, recordChange],
  );

  /** Manually re-files a question under a different discipline/chapter/difficulty
   * — used by the "Catégorisation" tab to fix miscategorized questions before
   * publishing. Moves are tracked like any other moderation decision, so
   * publishing can replay them safely on top of the freshest server content. */
  const handleMove = useCallback(
    (item: FlatQuestion, to: QuestionRef) => {
      const from = refOf(item);
      if (from.disciplineId === to.disciplineId && from.chapterId === to.chapterId && from.level === to.level) return;
      setContent((prev) => (prev ? moveQuestion(prev, from, to, item.question.id) : prev));
      recordMove(from, to, item.question.id, item.question);
      addLog("success", `⇆ Recatégorisée : "${item.question.prompt.slice(0, 50)}" → ${to.chapterId} / ${LEVEL_LABEL[to.level] ?? to.level}`);
    },
    [addLog, recordMove],
  );

  const openEdit = useCallback((item: FlatQuestion) => {
    setEditingItem(item);
    setEditPrompt(item.question.prompt);
    setEditOptionsText((item.question.options ?? []).join("\n"));
    setEditAnswer(item.question.answer);
    setEditExplanation(item.question.explanation);
  }, []);

  const closeEdit = () => setEditingItem(null);

  const saveEdit = () => {
    if (!editingItem) return;
    const type: QuestionType = editingItem.question.type;
    const options =
      type === "multipleChoice" || type === "fillBlank"
        ? editOptionsText.split("\n").map((s) => s.trim()).filter(Boolean)
        : undefined;
    const ref = refOf(editingItem);
    const next = markStatus(
      {
        ...editingItem.question,
        prompt: editPrompt.trim(),
        options,
        answer: editAnswer.trim(),
        explanation: editExplanation.trim(),
      },
      "approved",
      "human",
    );
    applyUpdate(ref, editingItem.question.id, () => next);
    recordChange(ref, editingItem.question.id, next);
    addLog("success", `✎ Corrigée et validée : ${editPrompt.slice(0, 60)}`);
    closeEdit();
  };

  // Keyboard shortcuts — only active in the review tab, and never while
  // typing in a field or with the edit modal open.
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (tab !== "review" || editingItem || !currentItem) return;
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) return;
      const key = e.key.toLowerCase();
      if (key === "v") {
        e.preventDefault();
        handleApprove(currentItem);
      } else if (key === "r") {
        e.preventDefault();
        handleReject(currentItem);
      } else if (key === "e") {
        e.preventDefault();
        openEdit(currentItem);
      } else if (key === "s" || key === "arrowright" || e.key === " ") {
        e.preventDefault();
        handleSkip();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [tab, editingItem, currentItem, handleApprove, handleReject, handleSkip, openEdit]);

  const applyAiSuggestion = (item: FlatQuestion, result: AiReviewResult) => {
    const ref = refOf(item);
    if (result.decision === "reject") {
      handleReject(item, "ai");
    } else if (result.decision === "approve") {
      handleApprove(item, "ai");
    } else if (result.decision === "edit" && result.correctedQuestion) {
      const next = markStatus(
        {
          ...item.question,
          prompt: result.correctedQuestion?.prompt ?? item.question.prompt,
          options: result.correctedQuestion?.options ?? item.question.options,
          answer: result.correctedQuestion?.answer ?? item.question.answer,
          explanation: result.correctedQuestion?.explanation ?? item.question.explanation,
        },
        "approved",
        "ai",
      );
      applyUpdate(ref, item.question.id, () => next);
      recordChange(ref, item.question.id, next);
    }
    setAiNotes((prev) => {
      const next = { ...prev };
      delete next[item.question.id];
      return next;
    });
  };

  const dismissAiSuggestion = (item: FlatQuestion) => {
    setAiNotes((prev) => {
      const next = { ...prev };
      delete next[item.question.id];
      return next;
    });
  };

  const runAiBatch = useCallback(async () => {
    if (!content || aiRunningRef.current) return;
    if (!aiApiKey.trim()) {
      addLog("error", "Renseigne une clé API avant de lancer l'IA");
      return;
    }
    const modelCfg = AI_MODELS.find((m) => m.id === aiModelId);
    if (!modelCfg) return;
    const targets = flatQuestions
      .filter((f) => questionStatus(f.question) === "pending" && matchesFilters(f))
      .slice(0, Math.max(1, aiBatchSize));
    if (targets.length === 0) {
      addLog("info", "Aucune question en attente à confier à l'IA (selon les filtres actuels)");
      return;
    }
    aiRunningRef.current = true;
    setAiRunning(true);
    setAiProgress({ done: 0, total: targets.length });
    setLastBatchSummary(null);
    addLog("info", `IA (${modelCfg.label}) : traitement de ${targets.length} question(s) en parallèle de ta revue manuelle…`);
    if (!aiAutoApply) {
      addLog("info", "Application automatique désactivée — chaque résultat restera « en attente » et te sera proposé en suggestion à valider toi-même.");
    }

    const config: AiConfig = { provider: modelCfg.provider, model: modelCfg.model, apiKey: aiApiKey };
    let autoApproved = 0;
    let autoRejected = 0;
    let suggested = 0;
    let errored = 0;

    for (const item of targets) {
      if (!aiRunningRef.current) break;
      try {
        const result = await reviewQuestionWithAi(item, config);
        setAiNotes((prev) => ({ ...prev, [item.question.id]: result }));
        const lowConfidence = result.confidence < aiConfidenceThreshold;
        if (aiAutoApply && !lowConfidence) {
          applyAiSuggestion(item, result);
          if (result.decision === "reject") autoRejected += 1;
          else autoApproved += 1;
          addLog("success", `IA ✓ "${item.question.prompt.slice(0, 50)}" → ${result.decision} (confiance ${result.confidence}%) — appliquée automatiquement, ne compte plus dans les restantes`);
        } else {
          suggested += 1;
          addLog(
            lowConfidence ? "warn" : "info",
            `IA a une suggestion pour "${item.question.prompt.slice(0, 50)}" (confiance ${result.confidence}%) — reste « en attente » tant que tu ne la valides pas toi-même`,
          );
        }
      } catch (err) {
        errored += 1;
        const msg = err instanceof Error ? err.message : String(err);
        addLog("error", `IA erreur sur "${item.question.prompt.slice(0, 40)}" : ${msg} — reste « en attente »`);
      }
      setAiProgress((p) => ({ ...p, done: p.done + 1 }));
      await new Promise((r) => setTimeout(r, 150));
    }
    aiRunningRef.current = false;
    setAiRunning(false);
    setLastBatchSummary({ autoApproved, autoRejected, suggested, errored });
    addLog(
      "success",
      `Résumé du lot — ${autoApproved} validée(s) auto, ${autoRejected} rejetée(s) auto, ${suggested} suggestion(s) en attente de ta revue, ${errored} erreur(s) (restées en attente).`,
    );
    addLog("success", "Lot IA terminé");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [content, aiApiKey, aiModelId, aiBatchSize, aiAutoApply, aiConfidenceThreshold, flatQuestions, matchesFilters, addLog]);

  const stopAiBatch = () => {
    aiRunningRef.current = false;
    setAiRunning(false);
    addLog("info", "Lot IA interrompu");
  };

  const handlePublish = async () => {
    if (!content) return;
    setPublishing(true);
    const fnUrl = import.meta.env.VITE_RORK_FUNCTIONS_URL
      ?? import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL
      ?? "https://mindduel-kqfozex-backend.rork.app";
    try {
      // Never publish the local working copy as-is: someone else (or the
      // Generator tool) may have published new questions to the server since
      // this page loaded its snapshot. Instead, fetch the freshest server
      // content and replay only the moderation decisions made in this page on
      // top of it — this can never erase newly generated questions, and it
      // can never silently un-publish a decision made from another tab.
      addLog("info", "Publication : récupération de la version la plus récente du serveur avant fusion…");
      const freshContent = await fetchContent();
      let merged = freshContent;
      let appliedCount = 0;
      let skippedCount = 0;
      for (const [questionId, change] of Object.entries(pendingChanges)) {
        const before = merged;
        if (change.question === null) {
          merged = deleteQuestion(merged, change.ref, questionId);
        } else if (change.moveTo) {
          merged = moveQuestion(merged, change.ref, change.moveTo, questionId, change.question);
        } else {
          merged = updateQuestion(merged, change.ref, questionId, () => change.question as Question);
        }
        if (merged === before) skippedCount += 1;
        else appliedCount += 1;
      }
      if (skippedCount > 0) {
        addLog("warn", `${skippedCount} décision(s) locale(s) n'ont pas pu être retrouvées dans la version serveur (question déjà supprimée/déplacée ailleurs) — ignorée(s) sans risque.`);
      }
      addLog("info", `${appliedCount} décision(s) de modération réappliquée(s) sur la version fraîche du serveur.`);

      const res = await fetch(`${fnUrl}/api/content/publish`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content: merged, password: ADMIN_PASSWORD }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        addLog("error", `Publication échouée : ${(err as { error?: string }).error ?? res.status}`);
      } else {
        const data = (await res.json()) as { version: number; questionCount: number };
        setPublishedInfo(data);
        // Reflect the true published state locally (includes anything generated
        // elsewhere), and clear the replayed decisions since they're now live.
        setContent(merged);
        setPendingChanges({});
        localStorage.removeItem(CHANGES_KEY);
        localStorage.setItem(DRAFT_KEY, JSON.stringify({ content: merged, savedAt: Date.now() }));
        addLog("success", `Publié sur le backend ✓ v${data.version} — ${data.questionCount} questions en ligne.`);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      addLog("error", `Publication échouée : ${msg}`);
    } finally {
      setPublishing(false);
    }
  };

  const handleDownload = () => {
    if (!content) return;
    downloadJson(content);
    addLog("success", "content.json téléchargé");
  };

  // --- Login gate ---
  if (!authed) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0b0f1a] px-6 text-white">
        <div className="w-full max-w-sm">
          <Link to="/" className="mb-6 inline-flex items-center gap-2 text-sm text-white/50 hover:text-white">
            <ArrowLeft className="h-4 w-4" />
            Retour au site
          </Link>
          <div className="rounded-3xl border border-white/10 bg-white/[0.03] p-8">
            <div className="mb-6 flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-sky-400 to-indigo-500">
                <Lock className="h-6 w-6 text-[#0b0f1a]" />
              </div>
              <div>
                <h1 className="text-lg font-bold">Modération des questions</h1>
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
                className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-white/30 focus:border-sky-500/50 focus:outline-none focus:ring-1 focus:ring-sky-500/30"
              />
              {authError && <p className="text-sm text-red-400">{authError}</p>}
              <button
                type="submit"
                className="w-full rounded-xl bg-gradient-to-r from-sky-400 to-indigo-500 px-4 py-3 text-sm font-bold text-[#0b0f1a] transition hover:brightness-105 active:scale-[0.98]"
              >
                Se connecter
              </button>
            </form>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0f1a] text-white">
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#0b0f1a]/90 backdrop-blur-lg">
        <div className="mx-auto flex max-w-[1600px] items-center justify-between px-6 py-3">
          <div className="flex items-center gap-3">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-white/50 hover:text-white">
              <ArrowLeft className="h-4 w-4" />
              Accueil
            </Link>
            <span className="text-white/20">|</span>
            <span className="text-sm font-bold">Modération des questions</span>
            <span className="text-white/20">|</span>
            <Link
              to="/admin-generator"
              className="inline-flex items-center gap-1.5 rounded-lg border border-amber-500/30 bg-amber-500/10 px-2.5 py-1 text-xs font-bold text-amber-300 transition hover:bg-amber-500/20"
            >
              Generator Admin →
            </Link>
            {hasDraft && <span className="rounded-full bg-amber-500/15 px-2 py-0.5 text-[10px] font-bold text-amber-300">BROUILLON LOCAL</span>}
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={loadFromServer}
              disabled={loading}
              className="inline-flex items-center gap-2 rounded-lg border border-white/10 px-3 py-1.5 text-xs font-medium text-white/70 transition hover:bg-white/5 disabled:opacity-50"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
              Recharger depuis le serveur
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

      <main className="mx-auto max-w-[1600px] px-6 py-6">
        {publishedInfo && (
          <div className="mb-4 flex items-center gap-3 rounded-xl border border-emerald-500/20 bg-emerald-500/[0.06] px-4 py-3 text-sm">
            <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-400" />
            <span className="text-emerald-300">
              Contenu publié ✓ — v{publishedInfo.version} · {publishedInfo.questionCount} questions en ligne.
            </span>
          </div>
        )}

        {/* Progress banner */}
        <div className="mb-6 rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <div className="mb-2 flex items-center justify-between text-sm">
            <span className="font-bold text-white/80">
              Progression (humain + IA) — {assessedTotal} / {stats.total} évaluées ({progressPct}%)
            </span>
            <div className="flex gap-4 text-xs">
              <span className="text-white/50">Total <b className="text-white/80">{stats.total}</b></span>
              <span className="text-emerald-400">Validées <b>{stats.approved}</b></span>
              <span className="text-red-400">Rejetées <b>{stats.rejected}</b></span>
              <span className="text-sky-400">Vues par l'IA (en attente de clic) <b>{aiAssessedPendingCount}</b></span>
              <span className="text-amber-400">Vraiment intouchées <b>{trulyUntouched}</b></span>
            </div>
          </div>
          <div className="h-2.5 w-full overflow-hidden rounded-full bg-white/10">
            <div className="flex h-full w-full overflow-hidden rounded-full">
              <div
                className="h-full bg-gradient-to-r from-emerald-400 to-teal-500 transition-all duration-500"
                style={{ width: `${stats.total > 0 ? ((stats.approved + stats.rejected) / stats.total) * 100 : 0}%` }}
              />
              <div
                className="h-full bg-gradient-to-r from-sky-400 to-indigo-500 transition-all duration-500"
                style={{ width: `${stats.total > 0 ? (aiAssessedPendingCount / stats.total) * 100 : 0}%` }}
              />
            </div>
          </div>
          <p className="mt-2 text-[11px] text-white/30">
            Restantes (compteur officiel, ce qui détermine la file de révision) : <b className="text-white/50">{stats.pending}</b> — dont {aiAssessedPendingCount} déjà commentée(s) par l'IA, il ne reste plus qu'à cliquer « Appliquer la suggestion » pour les faire sortir de la file.
          </p>
        </div>

        {/* Filters */}
        <div className="mb-6 flex flex-wrap items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.03] p-3">
          <div className="relative flex-1 min-w-[220px]">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-white/30" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Rechercher un mot-clé…"
              className="w-full rounded-lg border border-white/10 bg-white/5 py-2 pl-9 pr-3 text-sm text-white placeholder:text-white/30 focus:border-sky-500/50 focus:outline-none"
            />
          </div>
          <select
            value={disciplineFilter}
            onChange={(e) => setDisciplineFilter(e.target.value)}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white focus:border-sky-500/50 focus:outline-none"
          >
            <option value="all" className="bg-[#0b0f1a]">Toutes disciplines</option>
            {disciplineOptions.map(([id, name]) => (
              <option key={id} value={id} className="bg-[#0b0f1a]">{name}</option>
            ))}
          </select>
          <select
            value={levelFilter}
            onChange={(e) => setLevelFilter(e.target.value)}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white focus:border-sky-500/50 focus:outline-none"
          >
            <option value="all" className="bg-[#0b0f1a]">Toutes difficultés</option>
            {levelOptions.map((l) => (
              <option key={l} value={l} className="bg-[#0b0f1a]">{LEVEL_LABEL[l] ?? l}</option>
            ))}
          </select>
          <select
            value={sourceFilter}
            onChange={(e) => setSourceFilter(e.target.value as "all" | "human" | "ai")}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white focus:border-sky-500/50 focus:outline-none"
          >
            <option value="all" className="bg-[#0b0f1a]">Toute origine</option>
            <option value="human" className="bg-[#0b0f1a]">Moi</option>
            <option value="ai" className="bg-[#0b0f1a]">IA</option>
          </select>
          {tab === "all" && (
            <select
              value={allStatusFilter}
              onChange={(e) => setAllStatusFilter(e.target.value as typeof allStatusFilter)}
              className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white focus:border-sky-500/50 focus:outline-none"
            >
              <option value="all" className="bg-[#0b0f1a]">Tout statut</option>
              <option value="pending" className="bg-[#0b0f1a]">En attente</option>
              <option value="approved" className="bg-[#0b0f1a]">Validées</option>
              <option value="rejected" className="bg-[#0b0f1a]">Rejetées</option>
            </select>
          )}
        </div>

        {/* Tabs */}
        <div className="mb-6 flex gap-1 rounded-xl border border-white/10 bg-white/[0.02] p-1">
          <TabButton active={tab === "review"} onClick={() => setTab("review")} label={`File de révision (${pendingItems.length})`} />
          <TabButton active={tab === "rejected"} onClick={() => setTab("rejected")} label={`Rejetées (${rejectedItems.length})`} />
          <TabButton active={tab === "all"} onClick={() => setTab("all")} label={`Toutes (${allItems.length})`} />
          <TabButton active={tab === "categorize"} onClick={() => setTab("categorize")} label={`Catégorisation (${categorizeItems.length})`} />
        </div>

        {tab === "review" && (
          <div className="grid gap-6 lg:grid-cols-[400px_1fr_340px]">
            <div className="flex flex-col items-center gap-4">
              {currentItem ? (
                <PhoneQuestionPreview
                  question={currentItem.question}
                  disciplineName={currentItem.disciplineName}
                  disciplineColor={`#${currentItem.disciplineColor.replace("#", "")}`}
                  position={stats.approved + stats.rejected + 1}
                  total={stats.total}
                />
              ) : (
                <div className="flex h-[700px] w-[360px] items-center justify-center rounded-[3rem] border-4 border-dashed border-white/10 text-center text-sm text-white/30">
                  {loading ? "Chargement…" : "🎉 Tout est traité pour ces filtres !"}
                </div>
              )}
            </div>

            <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
              {currentItem ? (
                <>
                  <h2 className="mb-3 text-sm font-bold uppercase tracking-wider text-white/60">Détails</h2>
                  <dl className="mb-4 space-y-2 text-xs">
                    <Row label="Discipline" value={currentItem.disciplineName} />
                    <Row label="Chapitre" value={currentItem.chapterTitle} />
                    <Row label="Niveau" value={LEVEL_LABEL[currentItem.level] ?? currentItem.level} />
                    <Row label="Familiarité" value={currentItem.question.familiarity ?? "—"} />
                    <Row label="ID" value={currentItem.question.id} mono />
                  </dl>
                  <div className="mb-4 rounded-xl border border-white/10 bg-white/[0.02] p-3 text-xs text-white/70">
                    <p className="mb-1 font-bold text-white/50">Explication</p>
                    <p>{currentItem.question.explanation}</p>
                  </div>

                  {aiNotes[currentItem.question.id] && (
                    <div className="mb-4 rounded-xl border border-sky-500/30 bg-sky-500/[0.06] p-3 text-xs">
                      <div className="mb-1 flex items-center justify-between">
                        <span className="inline-flex items-center gap-1.5 font-bold text-sky-300">
                          <Bot className="h-3.5 w-3.5" />
                          Avis de l'IA
                        </span>
                        <span className="rounded-full bg-white/10 px-2 py-0.5 font-bold text-white/70">
                          {aiNotes[currentItem.question.id].confidence}% confiance
                        </span>
                      </div>
                      <p className="mb-2 text-white/70">{aiNotes[currentItem.question.id].notes}</p>
                      <p className="mb-2 font-bold text-white/50">
                        Décision suggérée : {aiNotes[currentItem.question.id].decision === "approve" ? "Valider" : aiNotes[currentItem.question.id].decision === "reject" ? "Rejeter" : "Corriger"}
                      </p>
                      {aiNotes[currentItem.question.id].correctedQuestion && (
                        <div className="mb-2 rounded-lg bg-black/30 p-2 text-white/60">
                          <p className="font-mono text-[11px]">{aiNotes[currentItem.question.id].correctedQuestion?.prompt}</p>
                        </div>
                      )}
                      <div className="flex gap-2">
                        <button
                          type="button"
                          onClick={() => applyAiSuggestion(currentItem, aiNotes[currentItem.question.id])}
                          className="flex-1 rounded-lg bg-sky-500/20 px-2 py-1.5 text-[11px] font-bold text-sky-300 hover:bg-sky-500/30"
                        >
                          Appliquer la suggestion
                        </button>
                        <button
                          type="button"
                          onClick={() => dismissAiSuggestion(currentItem)}
                          className="flex-1 rounded-lg border border-white/10 px-2 py-1.5 text-[11px] font-bold text-white/60 hover:bg-white/5"
                        >
                          Ignorer
                        </button>
                      </div>
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-2">
                    <ActionButton onClick={() => handleApprove(currentItem)} icon={<ThumbsUp className="h-4 w-4" />} label="Valider" shortcut="V" color="emerald" />
                    <ActionButton onClick={() => handleReject(currentItem)} icon={<ThumbsDown className="h-4 w-4" />} label="Rejeter" shortcut="R" color="red" />
                    <ActionButton onClick={() => openEdit(currentItem)} icon={<Pencil className="h-4 w-4" />} label="Éditer" shortcut="E" color="sky" />
                    <ActionButton onClick={handleSkip} icon={<SkipForward className="h-4 w-4" />} label="Passer" shortcut="S" color="white" />
                  </div>
                  <p className="mt-3 text-center text-[11px] text-white/30">
                    Raccourcis clavier : V (valider) · R (rejeter) · E (éditer) · S / Espace (passer)
                  </p>
                </>
              ) : (
                <p className="text-sm text-white/40">Aucune question à afficher.</p>
              )}
            </div>

            {/* AI assistance panel */}
            <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
              <h2 className="mb-1 flex items-center gap-2 text-sm font-bold uppercase tracking-wider text-white/60">
                <Sparkles className="h-4 w-4 text-sky-400" />
                Assistance IA
              </h2>
              <p className="mb-4 text-xs text-white/40">
                Confie un lot de questions à un modèle IA pendant que tu continues à valider les tiennes en parallèle.
              </p>

              <label className="mb-1 block text-xs text-white/50">Modèle</label>
              <select
                value={aiModelId}
                onChange={(e) => setAiModelId(e.target.value)}
                disabled={aiRunning}
                className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none disabled:opacity-50"
              >
                {AI_MODELS.map((m) => (
                  <option key={m.id} value={m.id} className="bg-[#0b0f1a]">{m.label}</option>
                ))}
              </select>

              <label className="mb-1 block text-xs text-white/50">Clé API (jamais stockée, session uniquement)</label>
              <input
                type="password"
                name="minduel-ai-review-api-key"
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="off"
                spellCheck={false}
                data-lpignore="true"
                data-1p-ignore="true"
                data-bwignore="true"
                value={aiApiKey}
                onChange={(e) => setAiApiKey(e.target.value)}
                disabled={aiRunning}
                placeholder="sk-… / clé du fournisseur"
                className="mb-1 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder:text-white/30 focus:border-sky-500/50 focus:outline-none disabled:opacity-50"
              />
              {aiApiKey.trim().length > 0 && (
                <p className="mb-3 text-[11px] text-white/30">
                  Clé détectée : {aiApiKey.trim().length} caractères, se termine par « …{aiApiKey.trim().slice(-4)} »
                </p>
              )}
              {aiApiKey.trim().length === 0 && <div className="mb-3" />}

              <label className="mb-1 block text-xs text-white/50">Nombre de questions à lui confier</label>
              <input
                type="number"
                min={1}
                max={500}
                value={aiBatchSize}
                onChange={(e) => setAiBatchSize(Number(e.target.value) || 1)}
                disabled={aiRunning}
                className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none disabled:opacity-50"
              />

              <label className="mb-1 block text-xs text-white/50">Seuil de confiance pour auto-appliquer (%)</label>
              <input
                type="number"
                min={0}
                max={100}
                value={aiConfidenceThreshold}
                onChange={(e) => setAiConfidenceThreshold(Number(e.target.value) || 0)}
                disabled={aiRunning || !aiAutoApply}
                className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none disabled:opacity-50"
              />

              <label className="mb-4 flex items-center gap-2 text-xs text-white/60">
                <input
                  type="checkbox"
                  checked={aiAutoApply}
                  onChange={(e) => setAiAutoApply(e.target.checked)}
                  disabled={aiRunning}
                  className="h-4 w-4 rounded border-white/20 bg-white/5"
                />
                Appliquer automatiquement les décisions à confiance élevée (sinon, toujours proposer en suggestion)
              </label>

              {aiRunning ? (
                <>
                  <div className="mb-2 h-2 w-full overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-sky-400 to-indigo-500 transition-all"
                      style={{ width: `${aiProgress.total ? (aiProgress.done / aiProgress.total) * 100 : 0}%` }}
                    />
                  </div>
                  <p className="mb-3 text-center text-xs text-white/50">{aiProgress.done} / {aiProgress.total} traitées</p>
                  <button
                    type="button"
                    onClick={stopAiBatch}
                    className="w-full rounded-xl border border-white/10 px-4 py-3 text-sm font-bold text-white/70 transition hover:bg-white/5"
                  >
                    Arrêter le lot IA
                  </button>
                </>
              ) : lastBatchSummary ? (
                <div className="mb-3 rounded-xl border border-white/10 bg-white/[0.03] p-3 text-xs">
                  <p className="mb-2 font-bold text-white/70">Résumé du dernier lot</p>
                  <div className="grid grid-cols-2 gap-y-1">
                    <span className="text-emerald-400">Auto-validées <b>{lastBatchSummary.autoApproved}</b></span>
                    <span className="text-red-400">Auto-rejetées <b>{lastBatchSummary.autoRejected}</b></span>
                    <span className="text-amber-400">Suggestions en attente <b>{lastBatchSummary.suggested}</b></span>
                    <span className="text-white/50">Erreurs <b>{lastBatchSummary.errored}</b></span>
                  </div>
                  {lastBatchSummary.suggested + lastBatchSummary.errored > 0 && (
                    <p className="mt-2 text-white/40">
                      Les {lastBatchSummary.suggested + lastBatchSummary.errored} question(s) non appliquées automatiquement comptent toujours dans « Restantes » — valide-les toi-même dans la file de révision.
                    </p>
                  )}
                </div>
              ) : null}
              {!aiRunning && (
                <button
                  type="button"
                  onClick={runAiBatch}
                  disabled={!content}
                  className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-sky-400 to-indigo-500 px-4 py-3 text-sm font-bold text-[#0b0f1a] transition hover:brightness-105 disabled:opacity-40"
                >
                  <Bot className="h-4 w-4" />
                  Lancer l'IA sur {Math.min(aiBatchSize, pendingItems.length)} question(s)
                </button>
              )}

              <div className="mt-4 max-h-[220px] overflow-y-auto rounded-xl bg-black/40 p-3 font-mono text-[11px] leading-relaxed">
                {logs.length === 0 ? (
                  <p className="text-white/30">En attente d'activité…</p>
                ) : (
                  logs.slice(-40).map((log, i) => (
                    <div key={i} className="flex gap-2 py-0.5">
                      <span className="shrink-0 text-white/30">{log.time}</span>
                      <span
                        className={
                          log.level === "success" ? "text-emerald-400" : log.level === "error" ? "text-red-400" : log.level === "warn" ? "text-amber-400" : "text-white/60"
                        }
                      >
                        {log.message}
                      </span>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        )}

        {tab === "rejected" && (
          <div className="space-y-2">
            {rejectedItems.length === 0 ? (
              <p className="py-12 text-center text-sm text-white/30">Aucune question rejetée pour ces filtres.</p>
            ) : (
              rejectedItems.map((item) => (
                <div key={item.question.id} className="flex items-center gap-3 rounded-xl border border-red-500/20 bg-red-500/[0.04] p-3 text-sm">
                  <XCircle className="h-4 w-4 shrink-0 text-red-400" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-white/90">{item.question.prompt}</p>
                    <p className="text-xs text-white/40">
                      {item.disciplineName} · {LEVEL_LABEL[item.level] ?? item.level} · par {item.question.moderatedBy === "ai" ? "IA" : "moi"}
                      {item.question.moderatedAt && ` · ${new Date(item.question.moderatedAt).toLocaleString("fr-FR")}`}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => openEdit(item)}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-xs font-bold text-white/70 transition hover:bg-white/5"
                  >
                    <Pencil className="h-3.5 w-3.5" />
                    Éditer et revalider
                  </button>
                  <button
                    type="button"
                    onClick={() => handleApprove(item)}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-2.5 py-1.5 text-xs font-bold text-emerald-400 transition hover:bg-emerald-500/20"
                  >
                    <ThumbsUp className="h-3.5 w-3.5" />
                    Revalider telle quelle
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(item)}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-red-500/30 bg-red-500/10 px-2.5 py-1.5 text-xs font-bold text-red-400 transition hover:bg-red-500/20"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    Supprimer
                  </button>
                </div>
              ))
            )}
          </div>
        )}

        {tab === "categorize" && (
          <div className="space-y-3">
            <p className="rounded-xl border border-sky-500/20 bg-sky-500/[0.06] px-4 py-3 text-xs text-sky-200">
              Recatégorise manuellement une question par thème (discipline/chapitre) et par difficulté. Chaque changement est appliqué immédiatement à ton brouillon local et sera repris tel quel à la publication — même si le serveur a évolué entre-temps.
            </p>
            {categorizeItems.length === 0 ? (
              <p className="py-12 text-center text-sm text-white/30">Aucune question pour ces filtres.</p>
            ) : (
              <div className="overflow-hidden rounded-2xl border border-white/10">
                <table className="w-full text-sm">
                  <thead className="bg-white/[0.03] text-left text-xs uppercase tracking-wider text-white/40">
                    <tr>
                      <th className="px-4 py-2.5">Question</th>
                      <th className="px-4 py-2.5">Actuel</th>
                      <th className="px-4 py-2.5">Nouvelle discipline</th>
                      <th className="px-4 py-2.5">Nouveau chapitre</th>
                      <th className="px-4 py-2.5">Nouvelle difficulté</th>
                      <th className="px-4 py-2.5"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {categorizeItems.slice(0, 300).map((item) => {
                      const currentRef = refOf(item);
                      const sel = categorizeSelection[item.question.id] ?? currentRef;
                      const chapters = chaptersByDiscipline.get(sel.disciplineId) ?? [];
                      const changed = sel.disciplineId !== currentRef.disciplineId || sel.chapterId !== currentRef.chapterId || sel.level !== currentRef.level;
                      const setSel = (patch: Partial<QuestionRef>) => {
                        setCategorizeSelection((prev) => {
                          const base = prev[item.question.id] ?? currentRef;
                          const next = { ...base, ...patch };
                          // Switching discipline invalidates the chapter choice — fall back to its first chapter.
                          if (patch.disciplineId && patch.disciplineId !== base.disciplineId) {
                            next.chapterId = chaptersByDiscipline.get(patch.disciplineId)?.[0]?.id ?? "";
                          }
                          return { ...prev, [item.question.id]: next };
                        });
                      };
                      return (
                        <tr key={item.question.id} className="hover:bg-white/[0.02]">
                          <td className="max-w-xs truncate px-4 py-2.5 text-white/80">{item.question.prompt}</td>
                          <td className="px-4 py-2.5 text-xs text-white/40">
                            {item.disciplineName}
                            <br />
                            {item.chapterTitle} · {LEVEL_LABEL[item.level] ?? item.level}
                          </td>
                          <td className="px-4 py-2.5">
                            <select
                              value={sel.disciplineId}
                              onChange={(e) => setSel({ disciplineId: e.target.value })}
                              className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white focus:border-sky-500/50 focus:outline-none"
                            >
                              {disciplineOptions.map(([id, name]) => (
                                <option key={id} value={id} className="bg-[#0b0f1a]">{name}</option>
                              ))}
                            </select>
                          </td>
                          <td className="px-4 py-2.5">
                            <select
                              value={sel.chapterId}
                              onChange={(e) => setSel({ chapterId: e.target.value })}
                              className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white focus:border-sky-500/50 focus:outline-none"
                            >
                              {chapters.map((c) => (
                                <option key={c.id} value={c.id} className="bg-[#0b0f1a]">{c.title}</option>
                              ))}
                            </select>
                          </td>
                          <td className="px-4 py-2.5">
                            <select
                              value={sel.level === "legacy" ? "facile" : sel.level}
                              onChange={(e) => setSel({ level: e.target.value })}
                              className="rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 text-xs text-white focus:border-sky-500/50 focus:outline-none"
                            >
                              {DIFFICULTY_LEVELS.map((l) => (
                                <option key={l} value={l} className="bg-[#0b0f1a]">{LEVEL_LABEL[l] ?? l}</option>
                              ))}
                            </select>
                          </td>
                          <td className="px-4 py-2.5">
                            <button
                              type="button"
                              disabled={!changed}
                              onClick={() => {
                                handleMove(item, sel);
                                setCategorizeSelection((prev) => {
                                  const next = { ...prev };
                                  delete next[item.question.id];
                                  return next;
                                });
                              }}
                              className="inline-flex items-center gap-1.5 rounded-lg border border-sky-500/30 bg-sky-500/10 px-2.5 py-1.5 text-xs font-bold text-sky-300 transition hover:bg-sky-500/20 disabled:cursor-not-allowed disabled:opacity-30"
                            >
                              Recatégoriser
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
                {categorizeItems.length > 300 && (
                  <p className="border-t border-white/5 px-4 py-2 text-center text-xs text-white/30">
                    {categorizeItems.length - 300} question(s) de plus — affine la recherche/les filtres pour les voir.
                  </p>
                )}
              </div>
            )}
          </div>
        )}

        {tab === "all" && (
          <div className="overflow-hidden rounded-2xl border border-white/10">
            <table className="w-full text-sm">
              <thead className="bg-white/[0.03] text-left text-xs uppercase tracking-wider text-white/40">
                <tr>
                  <th className="px-4 py-2.5">Statut</th>
                  <th className="px-4 py-2.5">Question</th>
                  <th className="px-4 py-2.5">Discipline</th>
                  <th className="px-4 py-2.5">Niveau</th>
                  <th className="px-4 py-2.5">Origine</th>
                  <th className="px-4 py-2.5"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {allItems.slice(0, 500).map((item) => {
                  const status = questionStatus(item.question);
                  return (
                    <tr key={item.question.id} className="hover:bg-white/[0.02]">
                      <td className="px-4 py-2.5">
                        <span
                          className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${
                            status === "approved"
                              ? "bg-emerald-500/15 text-emerald-400"
                              : status === "rejected"
                                ? "bg-red-500/15 text-red-400"
                                : "bg-white/10 text-white/50"
                          }`}
                        >
                          {status === "approved" ? "Validée" : status === "rejected" ? "Rejetée" : "En attente"}
                        </span>
                      </td>
                      <td className="max-w-md truncate px-4 py-2.5 text-white/80">{item.question.prompt}</td>
                      <td className="px-4 py-2.5 text-white/50">{item.disciplineName}</td>
                      <td className="px-4 py-2.5 text-white/50">{LEVEL_LABEL[item.level] ?? item.level}</td>
                      <td className="px-4 py-2.5 text-white/50">{item.question.moderatedBy === "ai" ? "IA" : item.question.moderatedBy === "human" ? "Moi" : "—"}</td>
                      <td className="px-4 py-2.5">
                        <button
                          type="button"
                          onClick={() => openEdit(item)}
                          className="rounded-lg border border-white/10 px-2 py-1 text-[11px] font-bold text-white/60 hover:bg-white/5"
                        >
                          Éditer
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {allItems.length > 500 && (
              <p className="border-t border-white/5 px-4 py-2 text-center text-xs text-white/30">
                {allItems.length - 500} question(s) de plus — affine les filtres pour les voir.
              </p>
            )}
          </div>
        )}
      </main>

      {/* Edit modal */}
      {editingItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-6" onClick={closeEdit}>
          <div
            className="w-full max-w-lg rounded-2xl border border-white/10 bg-[#0f1424] p-6"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="mb-4 text-sm font-bold uppercase tracking-wider text-white/60">Éditer la question</h3>
            <label className="mb-1 block text-xs text-white/50">Question</label>
            <textarea
              value={editPrompt}
              onChange={(e) => setEditPrompt(e.target.value)}
              rows={3}
              className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none"
            />
            {(editingItem.question.type === "multipleChoice" || editingItem.question.type === "fillBlank") && (
              <>
                <label className="mb-1 block text-xs text-white/50">Options (une par ligne)</label>
                <textarea
                  value={editOptionsText}
                  onChange={(e) => setEditOptionsText(e.target.value)}
                  rows={4}
                  className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none"
                />
              </>
            )}
            <label className="mb-1 block text-xs text-white/50">Bonne réponse</label>
            {editingItem.question.type === "trueFalse" ? (
              <select
                value={editAnswer}
                onChange={(e) => setEditAnswer(e.target.value)}
                className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none"
              >
                <option value="Vrai" className="bg-[#0b0f1a]">Vrai</option>
                <option value="Faux" className="bg-[#0b0f1a]">Faux</option>
              </select>
            ) : (
              <input
                type="text"
                value={editAnswer}
                onChange={(e) => setEditAnswer(e.target.value)}
                className="mb-3 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none"
              />
            )}
            <label className="mb-1 block text-xs text-white/50">Explication</label>
            <textarea
              value={editExplanation}
              onChange={(e) => setEditExplanation(e.target.value)}
              rows={2}
              className="mb-4 w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white focus:border-sky-500/50 focus:outline-none"
            />
            <div className="flex gap-2">
              <button
                type="button"
                onClick={saveEdit}
                className="flex-1 rounded-xl bg-gradient-to-r from-sky-400 to-indigo-500 px-4 py-2.5 text-sm font-bold text-[#0b0f1a] transition hover:brightness-105"
              >
                Enregistrer et valider
              </button>
              <button
                type="button"
                onClick={closeEdit}
                className="rounded-xl border border-white/10 px-4 py-2.5 text-sm font-bold text-white/60 transition hover:bg-white/5"
              >
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const TabButton = ({ active, onClick, label }: { active: boolean; onClick: () => void; label: string }) => (
  <button
    type="button"
    onClick={onClick}
    className={`flex-1 rounded-lg px-3 py-2 text-xs font-bold transition ${
      active ? "bg-sky-500/20 text-sky-300" : "text-white/40 hover:bg-white/5 hover:text-white/70"
    }`}
  >
    {label}
  </button>
);

const Row = ({ label, value, mono }: { label: string; value: string; mono?: boolean }) => (
  <div className="flex justify-between gap-3">
    <dt className="text-white/40">{label}</dt>
    <dd className={`truncate text-right text-white/80 ${mono ? "font-mono text-[10px]" : ""}`}>{value}</dd>
  </div>
);

const COLOR_MAP: Record<string, string> = {
  emerald: "border-emerald-500/30 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20",
  red: "border-red-500/30 bg-red-500/10 text-red-400 hover:bg-red-500/20",
  sky: "border-sky-500/30 bg-sky-500/10 text-sky-400 hover:bg-sky-500/20",
  white: "border-white/10 bg-white/5 text-white/70 hover:bg-white/10",
};

const ActionButton = ({
  onClick,
  icon,
  label,
  shortcut,
  color,
}: {
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  shortcut: string;
  color: keyof typeof COLOR_MAP;
}) => (
  <button
    type="button"
    onClick={onClick}
    className={`flex items-center justify-between gap-2 rounded-xl border px-3 py-2.5 text-sm font-bold transition ${COLOR_MAP[color]}`}
  >
    <span className="flex items-center gap-2">
      {icon}
      {label}
    </span>
    <span className="rounded bg-black/20 px-1.5 py-0.5 text-[10px] font-mono">{shortcut}</span>
  </button>
);

export default AdminReview;
