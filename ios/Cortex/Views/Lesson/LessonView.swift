import SwiftUI

struct LessonLaunch: Identifiable {
    let id: UUID = UUID()
    let title: String
    let chapterId: String?
    let items: [LessonItem]
    var disciplineId: String? = nil
    var level: DifficultyLevel? = nil
    var chapterIdRaw: String? = nil
}

struct LessonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: LessonSession
    private let title: String

    init(launch: LessonLaunch, store: ProgressStore) {
        self.title = launch.title
        _session = State(initialValue: LessonSession(
            items: launch.items,
            chapterId: launch.chapterId,
            store: store,
            disciplineId: launch.disciplineId,
            level: launch.level,
            chapterIdRaw: launch.chapterIdRaw
        ))
    }

    var body: some View {
        Group {
            if session.phase == .completed {
                LessonCompleteView(
                    xp: session.xpEarned,
                    accuracy: session.accuracy,
                    streak: session.streakAfterCompletion
                ) {
                    dismiss()
                }
            } else {
                lessonContent
            }
        }
        .background(Theme.background)
    }

    private var lessonContent: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                QuestionContentView(session: session)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .id(session.current.id)
            }
            footer
        }
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
                    if session.progressValue > 0 {
                        Capsule()
                            .fill(Theme.success)
                            .frame(width: max(14, geo.size.width * session.progressValue))
                    }
                }
            }
            .frame(height: 12)
            .animation(.spring(duration: 0.4), value: session.progressValue)
            Text("\(session.index + 1)/\(session.items.count)")
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
            FeedbackPanel(
                correct: correct,
                question: session.current.question,
                isLast: session.isLast
            ) {
                withAnimation(.spring(duration: 0.35)) {
                    session.advance()
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .completed:
            EmptyView()
        }
    }
}

private struct FeedbackPanel: View {
    let correct: Bool
    let question: Question
    let isLast: Bool
    let onContinue: () -> Void

    private var tint: Color { correct ? Theme.success : Theme.danger }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(tint)
                Text(correct ? "Excellent !" : "Pas tout à fait…")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(tint.mix(with: .black, by: 0.2))
            }
            if !correct {
                Text("Bonne réponse : \(question.answer)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Explication", systemImage: "lightbulb.fill")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                ScrollView {
                    Text(question.explanation)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 130)
            }
            Button(isLast ? "Terminer" : "Continuer", action: onContinue)
                .buttonStyle(ChunkyButtonStyle(color: tint))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(tint.opacity(0.12))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
