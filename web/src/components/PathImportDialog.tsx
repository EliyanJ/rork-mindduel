import { useCallback, useMemo, useRef, useState } from "react";
import { AlertTriangle, Copy, FileUp, Loader2, Sparkles, X } from "lucide-react";

import type { Chapter, Familiarity } from "@/lib/generator";
import { FAMILIARITY_LABEL } from "@/lib/generator";
import { AI_MODELS } from "@/lib/moderation";
import type { AiConfig } from "@/lib/aiReview";
import { convertSource, type ImportRow } from "@/lib/aiImport";
import { chapterQuestionIndex, LEVEL_ORDER, PATH_LEVEL_LABEL, type PathLevel } from "@/lib/pathLayout";
import type { DraftQuestion } from "@/lib/pathEditor";

const FAMILIARITIES: Familiarity[] = ["commun", "moyen", "pointu"];

/**
 * Bulk import: paste (or drop) a free-form question file, let the model
 * reformat it, then review every row before anything enters the catalog.
 *
 * The model is explicitly a *converter*, not an author — see `aiImport.ts`.
 * Nothing is imported until the admin ticks rows and confirms, and duplicates
 * are unticked by default.
 */
const PathImportDialog = ({
  chapter,
  disciplineName,
  onClose,
  onImport,
}: {
  chapter: Chapter;
  disciplineName: string;
  onClose: () => void;
  onImport: (drafts: DraftQuestion[]) => void;
}) => {
  const [source, setSource] = useState<string>("");
  const [rows, setRows] = useState<ImportRow[] | null>(null);
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [progress, setProgress] = useState<{ done: number; total: number }>({ done: 0, total: 0 });
  const [errors, setErrors] = useState<string[]>([]);
  const [apiKey, setApiKey] = useState<string>("");
  const [modelId, setModelId] = useState<string>(AI_MODELS[0]?.id ?? "");
  const fileInput = useRef<HTMLInputElement | null>(null);

  const existingPrompts = useMemo(() => {
    const set = new Set<string>();
    for (const entry of chapterQuestionIndex(chapter).values()) {
      set.add(entry.question.prompt.trim().toLowerCase());
    }
    return set;
  }, [chapter]);

  const run = useCallback(async () => {
    const model = AI_MODELS.find((m) => m.id === modelId);
    if (!model || apiKey.trim().length === 0 || source.trim().length === 0) return;
    const config: AiConfig = { provider: model.provider, model: model.model, apiKey };

    setIsRunning(true);
    setErrors([]);
    setRows(null);
    setProgress({ done: 0, total: 0 });

    const collectedErrors: string[] = [];
    try {
      const converted = await convertSource(
        source,
        config,
        { chapterTitle: chapter.title, disciplineName },
        (done, total, error) => {
          setProgress({ done, total });
          if (error) collectedErrors.push(error);
        },
      );
      const seen = new Set<string>();
      setRows(
        converted.map((row) => {
          const needle = row.prompt.trim().toLowerCase();
          const isDuplicate = existingPrompts.has(needle) || seen.has(needle);
          seen.add(needle);
          return { ...row, isDuplicate, selected: !isDuplicate };
        }),
      );
      setErrors(collectedErrors);
    } catch (err) {
      setErrors([err instanceof Error ? err.message : String(err)]);
    } finally {
      setIsRunning(false);
    }
  }, [apiKey, chapter.title, disciplineName, existingPrompts, modelId, source]);

  const patchRow = (key: string, patch: Partial<ImportRow>) => {
    setRows((cur) => cur?.map((row) => (row.key === key ? { ...row, ...patch } : row)) ?? cur);
  };

  const selected = rows?.filter((r) => r.selected) ?? [];

  const readFile = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => setSource(String(reader.result ?? ""));
    reader.readAsText(file);
  };

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 p-4 backdrop-blur-sm">
      <div className="flex max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-2xl border border-white/10 bg-[#12141c] text-white shadow-2xl">
        <header className="flex items-center justify-between gap-3 border-b border-white/10 px-5 py-3.5">
          <div>
            <h2 className="flex items-center gap-2 text-sm font-extrabold">
              <Sparkles className="h-4 w-4 text-indigo-300" />
              Import assisté par IA
            </h2>
            <p className="mt-0.5 text-[11px] font-semibold text-white/40">
              {chapter.title} · l'IA reformate, elle n'invente rien
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1 text-white/40 transition hover:bg-white/10 hover:text-white"
            aria-label="Fermer"
          >
            <X className="h-4 w-4" />
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">
          {!rows && (
            <div className="space-y-3">
              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={modelId}
                  onChange={(e) => setModelId(e.target.value)}
                  className="rounded-lg border border-white/10 bg-[#161923] px-2 py-1.5 text-[11px] font-bold text-white/80 outline-none"
                >
                  {AI_MODELS.map((m) => (
                    <option key={m.id} value={m.id}>{m.label}</option>
                  ))}
                </select>
                <input
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  type="password"
                  placeholder="Clé API (jamais enregistrée)"
                  className="min-w-[220px] flex-1 rounded-lg border border-white/10 bg-black/25 px-2.5 py-1.5 text-[11px] text-white/80 outline-none placeholder:text-white/25 focus:border-indigo-400/50"
                />
                <button
                  type="button"
                  onClick={() => fileInput.current?.click()}
                  className="flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-[11px] font-bold text-white/55 transition hover:bg-white/[0.06] hover:text-white"
                >
                  <FileUp className="h-3.5 w-3.5" />
                  Charger un fichier
                </button>
                <input
                  ref={fileInput}
                  type="file"
                  accept=".md,.txt,.csv,.json,text/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) readFile(file);
                  }}
                />
              </div>

              <textarea
                value={source}
                onChange={(e) => setSource(e.target.value)}
                onDrop={(e) => {
                  const file = e.dataTransfer.files?.[0];
                  if (file) {
                    e.preventDefault();
                    readFile(file);
                  }
                }}
                rows={14}
                placeholder={"Colle ici tes questions dans n'importe quel format.\n\nExemple :\n1. Quelle est la capitale de l'Australie ?\n   a) Sydney  b) Canberra  c) Melbourne\n   Réponse : Canberra\n\n2. Vrai ou faux : le Nil est le plus long fleuve du monde.\n   Réponse : Vrai"}
                className="w-full resize-y rounded-xl border border-white/10 bg-black/25 px-3 py-2.5 font-mono text-[11px] leading-relaxed text-white/80 outline-none placeholder:text-white/20 focus:border-indigo-400/50"
              />

              {errors.length > 0 && (
                <div className="space-y-1 rounded-lg border border-rose-400/25 bg-rose-500/[0.07] px-3 py-2">
                  {errors.map((error, i) => (
                    <p key={i} className="text-[11px] font-semibold text-rose-200/90">{error}</p>
                  ))}
                </div>
              )}
            </div>
          )}

          {rows && (
            <div className="space-y-2">
              <div className="flex flex-wrap items-center justify-between gap-2 pb-1">
                <p className="text-[11px] font-bold text-white/50">
                  {rows.length} question{rows.length > 1 ? "s" : ""} détectée{rows.length > 1 ? "s" : ""} ·{" "}
                  {selected.length} sélectionnée{selected.length > 1 ? "s" : ""}
                  {rows.some((r) => r.isDuplicate) && " · doublons décochés d'office"}
                </p>
                <div className="flex gap-1.5">
                  <button
                    type="button"
                    onClick={() => setRows((cur) => cur?.map((r) => ({ ...r, selected: !r.isDuplicate })) ?? cur)}
                    className="rounded-md border border-white/10 px-2 py-1 text-[10px] font-bold text-white/50 transition hover:text-white"
                  >
                    Tout sauf doublons
                  </button>
                  <button
                    type="button"
                    onClick={() => setRows(null)}
                    className="rounded-md border border-white/10 px-2 py-1 text-[10px] font-bold text-white/50 transition hover:text-white"
                  >
                    Recommencer
                  </button>
                </div>
              </div>

              {errors.map((error, i) => (
                <p key={i} className="rounded-md bg-rose-500/10 px-2 py-1 text-[10px] font-semibold text-rose-200/80">
                  {error}
                </p>
              ))}

              {rows.map((row) => (
                <div
                  key={row.key}
                  className={`rounded-lg border px-2.5 py-2 ${
                    row.selected ? "border-indigo-400/30 bg-indigo-500/[0.05]" : "border-white/10 bg-white/[0.02]"
                  }`}
                >
                  <div className="flex items-start gap-2">
                    <input
                      type="checkbox"
                      checked={row.selected}
                      onChange={(e) => patchRow(row.key, { selected: e.target.checked })}
                      className="mt-1 h-3.5 w-3.5 shrink-0 accent-indigo-500"
                    />
                    <div className="min-w-0 flex-1 space-y-1.5">
                      <textarea
                        value={row.prompt}
                        onChange={(e) => patchRow(row.key, { prompt: e.target.value })}
                        rows={2}
                        className="w-full resize-y rounded-md border border-white/10 bg-black/25 px-2 py-1 text-[11px] text-white/85 outline-none focus:border-indigo-400/50"
                      />
                      <div className="flex flex-wrap items-center gap-1.5">
                        <input
                          value={row.answer}
                          onChange={(e) => patchRow(row.key, { answer: e.target.value })}
                          className="min-w-[140px] flex-1 rounded-md border border-emerald-400/25 bg-black/25 px-2 py-1 text-[10px] font-semibold text-emerald-200/90 outline-none focus:border-emerald-400/60"
                        />
                        <select
                          value={row.level}
                          onChange={(e) => patchRow(row.key, { level: e.target.value as PathLevel })}
                          className="rounded-md border border-white/10 bg-[#161923] px-1.5 py-1 text-[10px] font-bold text-white/75 outline-none"
                        >
                          {LEVEL_ORDER.map((level) => (
                            <option key={level} value={level}>{PATH_LEVEL_LABEL[level]}</option>
                          ))}
                        </select>
                        <select
                          value={row.familiarity}
                          onChange={(e) => patchRow(row.key, { familiarity: e.target.value as Familiarity })}
                          className="rounded-md border border-white/10 bg-[#161923] px-1.5 py-1 text-[10px] font-bold text-white/75 outline-none"
                        >
                          {FAMILIARITIES.map((f) => (
                            <option key={f} value={f}>{FAMILIARITY_LABEL[f]}</option>
                          ))}
                        </select>
                        <span className="rounded bg-white/[0.06] px-1.5 py-0.5 text-[9px] font-bold uppercase text-white/40">
                          {row.type}
                        </span>
                      </div>
                      {row.options.filter(Boolean).length > 0 && (
                        <p className="text-[10px] font-medium text-white/35">
                          {row.options.filter(Boolean).join("  ·  ")}
                        </p>
                      )}
                      {row.warning && (
                        <p className="flex items-start gap-1 text-[10px] font-semibold text-amber-300/80">
                          <AlertTriangle className="mt-px h-3 w-3 shrink-0" />
                          {row.warning}
                        </p>
                      )}
                      {row.isDuplicate && (
                        <p className="flex items-center gap-1 text-[10px] font-semibold text-rose-300/80">
                          <Copy className="h-3 w-3" />
                          Cet énoncé existe déjà dans ce sous-chapitre.
                        </p>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <footer className="flex items-center justify-between gap-3 border-t border-white/10 px-5 py-3">
          <p className="text-[11px] font-semibold text-white/35">
            {isRunning
              ? `Conversion ${progress.done}/${progress.total} lot${progress.total > 1 ? "s" : ""}…`
              : "Les questions importées entrent en attente de modération."}
          </p>
          {!rows ? (
            <button
              type="button"
              onClick={() => void run()}
              disabled={isRunning || source.trim().length === 0 || apiKey.trim().length === 0}
              className="flex items-center gap-1.5 rounded-lg bg-indigo-500 px-4 py-2 text-[11px] font-extrabold text-white transition hover:bg-indigo-400 disabled:cursor-not-allowed disabled:opacity-35"
            >
              {isRunning ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Sparkles className="h-3.5 w-3.5" />}
              Convertir
            </button>
          ) : (
            <button
              type="button"
              onClick={() =>
                onImport(
                  selected.map((row) => ({
                    type: row.type,
                    prompt: row.prompt,
                    answer: row.answer,
                    options: row.options,
                    explanation: row.explanation,
                    familiarity: row.familiarity,
                    level: row.level,
                  })),
                )
              }
              disabled={selected.length === 0}
              className="rounded-lg bg-emerald-500 px-4 py-2 text-[11px] font-extrabold text-white transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-35"
            >
              Importer {selected.length} question{selected.length > 1 ? "s" : ""}
            </button>
          )}
        </footer>
      </div>
    </div>
  );
};

export default PathImportDialog;
