import SwiftUI

/// Renders the current question with the input control matching its format.
struct QuestionContentView: View {
    @Environment(AppModel.self) private var model
    @Bindable var session: LessonSession

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

struct ChoiceRowView: View {
    enum Style: Equatable {
        case normal
        case selected
        case correct
        case wrong
        case dimmed
    }

    let text: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if style == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                }
                if style == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14).fill(fillColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 2))
            .opacity(style == .dimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: style)
    }

    private var fillColor: Color {
        switch style {
        case .selected: return Theme.primary.opacity(0.1)
        case .correct: return Theme.success.opacity(0.12)
        case .wrong: return Theme.danger.opacity(0.1)
        case .normal, .dimmed: return Theme.card
        }
    }

    private var borderColor: Color {
        switch style {
        case .selected: return Theme.primary
        case .correct: return Theme.success
        case .wrong: return Theme.danger
        case .normal, .dimmed: return Theme.line
        }
    }

    private var textColor: Color {
        switch style {
        case .correct: return Theme.success.mix(with: .black, by: 0.25)
        case .wrong: return Theme.danger.mix(with: .black, by: 0.15)
        default: return Theme.ink
        }
    }
}
