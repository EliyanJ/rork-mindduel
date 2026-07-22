// PhoneQuestionPreview.tsx — renders a question inside a phone-shaped frame
// using the exact color tokens from the iOS app's Theme.swift, so the admin
// sees questions the way a real player would. The correct answer is
// highlighted (a deliberate deviation from the live app) since spotting a
// wrong "correct answer" is the whole point of this moderation tool.

import type { Question } from "@/lib/generator";

const THEME = {
  background: "#FDF8EF",
  card: "#FFFFFF",
  line: "#EAE0D0",
  ink: "#3B2E28",
  inkMuted: "#9B8A7C",
  success: "#58B412",
} as const;

const TYPE_LABEL: Record<Question["type"], string> = {
  multipleChoice: "Choix multiple",
  trueFalse: "Vrai ou Faux",
  fillBlank: "Texte à trous",
  anagram: "Anagramme",
};

type Props = {
  question: Question;
  disciplineName: string;
  disciplineColor: string;
  position: number;
  total: number;
};

export const PhoneQuestionPreview = ({ question, disciplineName, disciplineColor, position, total }: Props) => {
  const options = question.type === "trueFalse" ? ["Vrai", "Faux"] : (question.options ?? []);
  const progressPct = total > 0 ? Math.min(100, Math.round((position / total) * 100)) : 0;

  return (
    <div className="relative mx-auto h-[700px] w-[360px] shrink-0 rounded-[3rem] border-[10px] border-black bg-black shadow-2xl">
      <div className="absolute left-1/2 top-0 z-10 h-6 w-32 -translate-x-1/2 rounded-b-2xl bg-black" />
      <div className="flex h-full w-full flex-col overflow-hidden rounded-[2.3rem]" style={{ backgroundColor: THEME.background }}>
        <div className="flex items-center justify-between px-6 pb-1 pt-3 text-[11px] font-semibold" style={{ color: THEME.ink }}>
          <span>9:41</span>
          <span className="tracking-widest">●●●● 🔋</span>
        </div>

        <div className="px-5 pt-2">
          <div className="h-2 w-full overflow-hidden rounded-full" style={{ backgroundColor: THEME.line }}>
            <div
              className="h-full rounded-full transition-all duration-300"
              style={{ width: `${progressPct}%`, backgroundColor: disciplineColor }}
            />
          </div>
          <div className="mt-2 flex items-center gap-2 text-[11px] font-bold" style={{ color: THEME.inkMuted }}>
            <span className="rounded-full px-2 py-0.5" style={{ backgroundColor: `${disciplineColor}22`, color: disciplineColor }}>
              {disciplineName}
            </span>
            <span>· {TYPE_LABEL[question.type]}</span>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          <p className="text-[19px] font-extrabold leading-snug" style={{ color: THEME.ink }}>
            {question.prompt}
          </p>
          <div className="mt-5 space-y-2.5">
            {options.map((opt, i) => {
              const isCorrect = opt.trim().toLowerCase() === question.answer.trim().toLowerCase();
              return (
                <div
                  key={`${opt}-${i}`}
                  className="rounded-2xl border-2 px-4 py-3 text-[14px] font-bold"
                  style={{
                    borderColor: isCorrect ? THEME.success : THEME.line,
                    backgroundColor: isCorrect ? `${THEME.success}15` : THEME.card,
                    color: isCorrect ? THEME.success : THEME.ink,
                  }}
                >
                  <span className="flex items-center justify-between gap-2">
                    <span>{opt}</span>
                    {isCorrect && <span className="shrink-0 text-[11px]">✓ Bonne réponse</span>}
                  </span>
                </div>
              );
            })}
            {question.type === "anagram" && (
              <div
                className="rounded-2xl border-2 px-4 py-3 text-center text-[14px] font-bold"
                style={{ borderColor: THEME.success, backgroundColor: `${THEME.success}15`, color: THEME.success }}
              >
                Réponse : {question.answer}
              </div>
            )}
            {options.length === 0 && question.type !== "anagram" && (
              <p className="text-sm italic" style={{ color: THEME.inkMuted }}>
                (aucune option — question mal formée)
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
