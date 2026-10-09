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
        VStack(alignment: .leading, spacing: 22) {
            Text(instruction)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(alignment: .center, spacing: 10) {
                Image(mascotName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(isFeedback ? 1.06 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isFeedback)
                    .accessibilityHidden(true)
                PromptBubble(text: displayPrompt)
            }

            switch question.type {
            case .multipleChoice, .trueFalse, .fillBlank:
                VStack(spacing: 12) {
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

    private var instruction: String {
        switch question.type {
        case .multipleChoice: return "Trouve la bonne réponse"
        case .trueFalse: return "Vrai ou faux ?"
        case .fillBlank: return "Complète la phrase"
        case .anagram: return "Remets les lettres dans l'ordre"
        }
    }

    /// Mascot pose reacting to the answer once it is checked.
    private var mascotName: String {
        if case .feedback(let correct) = session.phase {
            return correct ? "MascotCheer" : "MascotShrug"
        }
        return "MascotStudy"
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
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30)
                .padding(.horizontal, 44)
                .padding(.vertical, 16)
                .overlay(alignment: .trailing) {
                    if style == .correct || style == .wrong {
                        Image(systemName: style == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(style == .correct ? Theme.success : Theme.danger)
                            .padding(.trailing, 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(fillColor))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(borderColor, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 18).fill(borderColor).offset(y: 4))
                .padding(.bottom, 4)
                .opacity(style == .dimmed ? 0.55 : 1)
        }
        .buttonStyle(ChoicePressStyle())
        .animation(.easeOut(duration: 0.15), value: style)
    }

    private var fillColor: Color {
        switch style {
        case .selected: return Theme.link.opacity(0.12)
        case .correct: return Theme.success.opacity(0.12)
        case .wrong: return Theme.danger.opacity(0.1)
        case .normal, .dimmed: return Theme.card
        }
    }

    private var borderColor: Color {
        switch style {
        case .selected: return Theme.link
        case .correct: return Theme.success
        case .wrong: return Theme.danger
        case .normal, .dimmed: return Theme.line
        }
    }

    private var textColor: Color {
        switch style {
        case .correct: return Theme.success.mix(with: .black, by: 0.25)
        case .wrong: return Theme.danger.mix(with: .black, by: 0.15)
        case .selected: return Theme.link
        default: return Theme.ink
        }
    }
}

/// Sinks the 3D answer card while pressed.
private struct ChoicePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// The question, said by the mascot: a rounded bubble with a tail on the left.
private struct PromptBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 2))
            .overlay(alignment: .leading) {
                PromptTail()
                    .fill(Theme.card)
                    .overlay(PromptTail().stroke(Theme.line, lineWidth: 2).mask(Rectangle().padding(.trailing, 2)))
                    .frame(width: 12, height: 18)
                    .offset(x: -10)
            }
            .contentTransition(.opacity)
    }
}

private struct PromptTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
