import SwiftUI

/// Renders the current diagnostic question with the input control matching its format.
/// Shared UI with QuestionContentView but bound to a DiagnosticSession instead.
struct DiagnosticQuestionContentView: View {
    @Environment(AppModel.self) private var model
    @Bindable var session: DiagnosticSession

    private var question: Question { session.current.question }

    private var discipline: Discipline? {
        model.discipline(withId: session.current.disciplineId)
    }

    private var isFeedback: Bool {
        if case .feedback = session.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Text(question.type.label.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.primary.opacity(0.12)))
                if let discipline {
                    Label(discipline.name, systemImage: discipline.icon)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(discipline.color.mix(with: .black, by: 0.15))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(discipline.color.opacity(0.14)))
                }
                if let familiarity = question.familiarity {
                    Label(familiarity.label, systemImage: familiarity.icon)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.ink.opacity(0.06)))
                }
            }

            Text(displayPrompt)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            switch question.type {
            case .multipleChoice, .trueFalse, .fillBlank:
                VStack(spacing: 10) {
                    ForEach(session.currentOptions, id: \.self) { option in
                        ChoiceRowView(text: option, style: rowStyle(for: option)) {
                            guard !isFeedback else { return }
                            Haptics.tap()
                            session.selection = option
                        }
                    }
                }
            case .anagram:
                AnagramInputView(
                    letters: session.anagramLetters,
                    selection: $session.selection,
                    locked: isFeedback
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayPrompt: String {
        guard question.type == .fillBlank else { return question.prompt }
        let filler = session.selection.isEmpty ? "______" : session.selection
        return question.prompt.replacingOccurrences(of: "___", with: filler)
    }

    private func rowStyle(for option: String) -> ChoiceRowView.Style {
        if isFeedback {
            if option.comparisonKey == question.answer.comparisonKey { return .correct }
            if option == session.selection { return .wrong }
            return .dimmed
        }
        return option == session.selection ? .selected : .normal
    }
}
