import SwiftUI

/// Diagnostic quiz step: fast-paced feedback-only question flow.
/// No explanations, no XP, no daily quota impact.
struct OnboardingDiagnosticQuizStep: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let items: [LessonItem]
    let onCompleted: (DiagnosticSession) -> Void

    @State private var session: DiagnosticSession
    @State private var indexDisplay = 0

    init(items: [LessonItem], store: ProgressStore, onCompleted: @escaping (DiagnosticSession) -> Void) {
        self.items = items
        self.onCompleted = onCompleted
        _session = State(initialValue: DiagnosticSession(items: items, store: store))
    }

    var body: some View {
        Group {
            if case .completed = session.phase {
                Color.clear
                    .task {
                        onCompleted(session)
                    }
            } else {
                quizContent
            }
        }
        .background(Theme.background)
    }

    private var quizContent: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                DiagnosticQuestionContentView(session: session)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .id(session.current.id)
            }
            footer
        }
        .onChange(of: session.phase) { _, new in
            if case .feedback = new {
                indexDisplay = session.index + 1
            } else {
                indexDisplay = session.index
            }
        }
    }

    private var isRevealed: Bool {
        if case .feedback = session.phase { return true }
        return false
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 40, height: 40)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule()
                        .fill(Theme.primary)
                        .frame(width: max(14, geo.size.width * session.progressValue))
                        .animation(.easeOut(duration: 0.4), value: session.progressValue)
                }
            }
            .frame(height: 12)

            Text("\(indexDisplay + 1)/\(session.items.count)")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
                .lineLimit(1)
                .frame(minWidth: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var footer: some View {
        switch session.phase {
        case .answering:
            Button("Vérifier") {
                withAnimation(.spring(duration: 0.35)) {
                    session.submit()
                }
            }
            .buttonStyle(ChunkyButtonStyle(
                color: session.selection.isEmpty ? Theme.line : Theme.success,
                textColor: session.selection.isEmpty ? Theme.inkMuted : .white
            ))
            .disabled(session.selection.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        case .feedback(let correct):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(correct ? Theme.success : Theme.danger)
                    Text(correct ? "Bien joué !" : "Pas cette fois…")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(correct ? Theme.success : Theme.danger)
                    Spacer()
                }
                if !correct {
                    Text("Bonne réponse : \(session.current.question.answer)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
                Button(session.isLast ? "Voir mon résultat" : "Continuer") {
                    withAnimation(.spring(duration: 0.35)) {
                        session.advance()
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: correct ? Theme.success : Theme.danger))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                    .fill((correct ? Theme.success : Theme.danger).opacity(0.12))
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .completed:
            EmptyView()
        }
    }
}

#Preview {
    OnboardingDiagnosticQuizStep(
        items: MiniQuizContent.questions.map { LessonItem(question: $0, disciplineId: "hist") },
        store: ProgressStore(),
        onCompleted: { _ in }
    )
}
