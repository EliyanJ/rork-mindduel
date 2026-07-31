import { useMemo, useState } from "react";
import { Loader2, Plus, X } from "lucide-react";

import type { Chapter, Familiarity, QuestionType } from "@/lib/generator";
import { FAMILIARITY_LABEL } from "@/lib/generator";
import { type DraftQuestion, EMPTY_DRAFT, validateDraft } from "@/lib/pathEditor";
import { LEVEL_ORDER, PATH_LEVEL_LABEL, type PathLevel } from "@/lib/pathLayout";

const TYPE_LABEL: Record<QuestionType, string> = {
  multipleChoice: "Choix multiple",
  trueFalse: "Vrai / Faux",
  fillBlank: "Texte à trou",
  anagram: "Anagramme",
};

const FAMILIARITIES: Familiarity[] = ["commun", "moyen", "pointu"];

/**
 * Manual question composer for a single ring. Validation runs live so the
 * "Ajouter" button is only ever enabled on something the app can actually play.
 */
const PathQuestionForm = ({
  chapter,
  defaultLevel,
  ringLabel,
  onCancel,
  onSubmit,
}: {
  chapter: Chapter;
  defaultLevel: PathLevel;
  ringLabel: string;
  onCancel: () => void;
  onSubmit: (draft: DraftQuestion) => void;
}) => {
  const [draft, setDraft] = useState<DraftQuestion>({ ...EMPTY_DRAFT, level: defaultLevel });
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  const needsOptions = draft.type === "multipleChoice" || draft.type === "fillBlank";
  const error = useMemo(() => validateDraft(draft, chapter), [draft, chapter]);

  const patch = (next: Partial<DraftQuestion>) => setDraft((cur) => ({ ...cur, ...next }));

  const setOption = (index: number, value: string) => {
    setDraft((cur) => {
      const options = [...cur.options];
      options[index] = value;
      return { ...cur, options };
    });
  };

  const submit = () => {
    if (error) return;
    setIsSubmitting(true);
    onSubmit(draft);
  };

  return (
    <div className="space-y-2.5 rounded-lg border border-indigo-400/30 bg-indigo-500/[0.06] p-3">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-extrabold text-white/80">Nouvelle question · {ringLabel}</p>
        <button
          type="button"
          onClick={onCancel}
          className="rounded p-0.5 text-white/35 transition hover:text-white"
          aria-label="Annuler"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>

      <div className="flex flex-wrap gap-1.5">
        {(Object.keys(TYPE_LABEL) as QuestionType[]).map((type) => (
          <button
            key={type}
            type="button"
            onClick={() =>
              patch({
                type,
                answer: type === "trueFalse" ? "Vrai" : "",
                options: type === "trueFalse" || type === "anagram" ? ["", "", "", ""] : draft.options,
              })
            }
            className={`rounded-md px-2 py-1 text-[10px] font-bold transition ${
              draft.type === type
                ? "bg-indigo-500 text-white"
                : "bg-white/[0.06] text-white/50 hover:text-white"
            }`}
          >
            {TYPE_LABEL[type]}
          </button>
        ))}
      </div>

      <textarea
        value={draft.prompt}
        onChange={(e) => patch({ prompt: e.target.value })}
        rows={2}
        placeholder={
          draft.type === "fillBlank"
            ? "Énoncé avec ___ à la place du mot manquant"
            : draft.type === "anagram"
              ? "Indice menant au mot à reconstituer"
              : "Énoncé de la question"
        }
        className="w-full resize-y rounded-md border border-white/10 bg-black/25 px-2 py-1.5 text-[11px] text-white/85 outline-none placeholder:text-white/25 focus:border-indigo-400/50"
      />

      {draft.type === "trueFalse" ? (
        <div className="flex gap-1.5">
          {["Vrai", "Faux"].map((value) => (
            <button
              key={value}
              type="button"
              onClick={() => patch({ answer: value })}
              className={`flex-1 rounded-md px-2 py-1.5 text-[11px] font-bold transition ${
                draft.answer === value
                  ? "bg-emerald-500/80 text-white"
                  : "bg-white/[0.06] text-white/50 hover:text-white"
              }`}
            >
              {value}
            </button>
          ))}
        </div>
      ) : (
        <input
          value={draft.answer}
          onChange={(e) => patch({ answer: e.target.value })}
          placeholder={draft.type === "anagram" ? "Mot à reconstituer (un seul mot)" : "Bonne réponse"}
          className="w-full rounded-md border border-emerald-400/25 bg-black/25 px-2 py-1.5 text-[11px] text-emerald-200/90 outline-none placeholder:text-white/25 focus:border-emerald-400/60"
        />
      )}

      {needsOptions && (
        <div className="grid grid-cols-2 gap-1.5">
          {draft.options.map((option, index) => {
            const isAnswer =
              option.trim().length > 0 &&
              option.trim().toLowerCase() === draft.answer.trim().toLowerCase();
            return (
              <input
                key={index}
                value={option}
                onChange={(e) => setOption(index, e.target.value)}
                placeholder={`Proposition ${index + 1}`}
                className={`rounded-md border bg-black/25 px-2 py-1.5 text-[11px] outline-none placeholder:text-white/25 ${
                  isAnswer
                    ? "border-emerald-400/50 text-emerald-200/90"
                    : "border-white/10 text-white/75 focus:border-indigo-400/50"
                }`}
              />
            );
          })}
        </div>
      )}

      <textarea
        value={draft.explanation}
        onChange={(e) => patch({ explanation: e.target.value })}
        rows={2}
        placeholder="Explication affichée après la réponse"
        className="w-full resize-y rounded-md border border-white/10 bg-black/25 px-2 py-1.5 text-[11px] text-white/75 outline-none placeholder:text-white/25 focus:border-indigo-400/50"
      />

      <div className="flex flex-wrap gap-3">
        <label className="flex items-center gap-1.5 text-[10px] font-bold text-white/40">
          Difficulté
          <select
            value={draft.level}
            onChange={(e) => patch({ level: e.target.value as PathLevel })}
            className="rounded-md border border-white/10 bg-[#161923] px-1.5 py-1 text-[10px] font-bold text-white/80 outline-none"
          >
            {LEVEL_ORDER.map((level) => (
              <option key={level} value={level}>{PATH_LEVEL_LABEL[level]}</option>
            ))}
          </select>
        </label>
        <label className="flex items-center gap-1.5 text-[10px] font-bold text-white/40">
          Notoriété
          <select
            value={draft.familiarity}
            onChange={(e) => patch({ familiarity: e.target.value as Familiarity })}
            className="rounded-md border border-white/10 bg-[#161923] px-1.5 py-1 text-[10px] font-bold text-white/80 outline-none"
          >
            {FAMILIARITIES.map((f) => (
              <option key={f} value={f}>{FAMILIARITY_LABEL[f]}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="flex items-center justify-between gap-2 pt-0.5">
        <p className="text-[10px] font-semibold text-amber-300/80">{error ?? ""}</p>
        <button
          type="button"
          onClick={submit}
          disabled={!!error || isSubmitting}
          className="flex shrink-0 items-center gap-1 rounded-md bg-indigo-500 px-2.5 py-1.5 text-[10px] font-extrabold text-white transition hover:bg-indigo-400 disabled:cursor-not-allowed disabled:opacity-35"
        >
          {isSubmitting ? <Loader2 className="h-3 w-3 animate-spin" /> : <Plus className="h-3 w-3" />}
          Ajouter
        </button>
      </div>
    </div>
  );
};

export default PathQuestionForm;
