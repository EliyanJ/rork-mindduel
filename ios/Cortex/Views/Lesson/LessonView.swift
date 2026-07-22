import SwiftUI

struct LessonLaunch: Identifiable {
    let id: UUID = UUID()
    let title: String
    let chapterId: String?
    let items: [LessonItem]
    var disciplineId: String? = nil
    var level: DifficultyLevel? = nil
    var chapterIdRaw: String? = nil
    /// Pre-lesson snapshot used to detect newly-unlocked content once the
    /// lesson completes successfully. Nil for mixed/themed path stages.
    var unlockSnapshot: UnlockSnapshot? = nil
}

/// Captures what was locked right before starting a chapter-level lesson,
/// so the completion flow can tell whether this lesson just unlocked the
/// next chapter or the next difficulty tier.
struct UnlockSnapshot {
    let disciplineId: String
    let chapterId: String
    let level: DifficultyLevel
    let nextChapterTitle: String?
    let nextChapterWasLocked: Bool
    let nextLevelWasLocked: Bool

    /// Compares this snapshot against the current store state to decide
    /// whether a chapter or a difficulty tier just got unlocked.
    func resolveUnlockKind(model: AppModel) -> UnlockCelebrationView.Kind? {
        guard let discipline = model.discipline(withId: disciplineId) else { return nil }
        if nextChapterWasLocked, let nextChapterTitle {
            let newBest = model.store.chapterProgress(
                disciplineId: disciplineId, chapterId: chapterId, level: .facile
            )?.bestScore ?? 0
            if newBest >= 0.6 {
                return .chapter(title: nextChapterTitle)
            }
        }
        if nextLevelWasLocked, let nextLevel = level.next, model.store.isLevelUnlocked(nextLevel, for: discipline) {
            return .level(nextLevel, disciplineName: discipline.name)
        }
        return nil
    }
}

struct LessonView: View {
    let launch: LessonLaunch
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreViewModel.self) private var store
    @Environment(AppModel.self) private var model
    @State private var session: LessonSession
    @State private var isWatchingAd = false
    @State private var postScreenQueue: [PostLessonScreen] = []
    @State private var currentPostScreen: PostLessonScreen?
    private let title: String
    private let onRetry: (LessonLaunch) -> Void

    init(launch: LessonLaunch, store: ProgressStore, onRetry: @escaping (LessonLaunch) -> Void = { _ in }) {
        self.launch = launch
        self.onRetry = onRetry
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
        ZStack {
            Group {
                if session.phase == .completed {
                    if session.isLevelFailed {
                        LessonFailureView(
                            score: session.correctCount,
                            maxScore: session.items.count,
                            requiredAccuracy: 0.8,
                            wrongAnswers: session.wrongAnswers,
                            isPremium: store.isPremium,
                            onRetry: retryNow,
                            onLater: { dismiss() }
                        )
                    } else if let screen = currentPostScreen {
                        postScreenView(screen)
                    } else {
                        LessonCompleteView(
                            xp: session.xpEarned,
                            accuracy: session.accuracy,
                            streak: session.streakAfterCompletion,
                            masteredCount: session.correctCount,
                            toReinforceCount: session.wrongAnswers.count,
                            onDone: advancePostLesson,
                            sessionLabel: completionSessionLabel,
                            needsAnotherSession: session.needsAnotherSession,
                            levelJustValidated: session.levelJustValidated
                        )
                    }
                } else {
                    lessonContent
                }
            }
            .background(Theme.background)

            if isWatchingAd {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
            }
        }
        .alert("Erreur", isPresented: .init(
            get: { AdsManager.shared.lastError != nil },
            set: { if !$0 { AdsManager.shared.lastError = nil } }
        )) {
            Button("OK") { AdsManager.shared.lastError = nil }
        } message: {
            Text(AdsManager.shared.lastError ?? "")
        }
        .onChange(of: session.phase) { _, newPhase in
            guard newPhase == .completed, !session.isLevelFailed else { return }
            buildPostLessonQueueIfNeeded()
        }
    }

    /// A screen shown after `LessonCompleteView`, before the player is
    /// finally released back to the app: streak celebration, then any
    /// content-unlock celebration.
    private enum PostLessonScreen {
        case streak
        case unlock(UnlockCelebrationView.Kind)
    }

    @ViewBuilder
    private func postScreenView(_ screen: PostLessonScreen) -> some View {
        switch screen {
        case .streak:
            StreakCelebrationView(
                streak: session.streakAfterCompletion,
                week: session.weekActivity,
                onContinue: advancePostLesson
            )
        case .unlock(let kind):
            UnlockCelebrationView(kind: kind, onClaim: advancePostLesson)
        }
    }

    private func advancePostLesson() {
        if postScreenQueue.isEmpty {
            dismiss()
        } else {
            currentPostScreen = postScreenQueue.removeFirst()
        }
    }

    private func buildPostLessonQueueIfNeeded() {
        guard postScreenQueue.isEmpty, currentPostScreen == nil else { return }
        var queue: [PostLessonScreen] = []
        if session.isFirstLessonToday {
            queue.append(.streak)
        }
        if let snapshot = launch.unlockSnapshot, let kind = snapshot.resolveUnlockKind(model: model) {
            queue.append(.unlock(kind))
        }
        postScreenQueue = queue
    }

    private func retryNow() {
        if store.isPremium {
            Haptics.success()
            onRetry(retryLaunch)
            return
        }
        Haptics.medium()
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            if rewarded {
                onRetry(retryLaunch)
            }
        }
    }

    private var retryLaunch: LessonLaunch {
        LessonLaunch(
            title: title,
            chapterId: launch.chapterId,
            items: launch.items,
            disciplineId: launch.disciplineId,
            level: launch.level,
            chapterIdRaw: launch.chapterIdRaw
        )
    }

    /// Short label shown on the completion screen for multi-session levels.
    private var completionSessionLabel: String? {
        guard session.isMultiSessionLevel else { return nil }
        if session.needsAnotherSession {
            return "Manche \(session.sessionNumber)/\(session.totalSessions)"
        } else if session.levelJustValidated {
            return "Niveau validé"
        } else {
            return "Manche \(session.sessionNumber)/\(session.totalSessions)"
        }
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
        VStack(spacing: 6) {
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
            if session.isMultiSessionLevel {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 11, weight: .bold))
                    Text("Manche \(session.sessionNumber)/\(session.totalSessions) · \(title)")
                        .lineLimit(1)
                }
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
            } else if isMixedLesson {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 11, weight: .bold))
                    Text("Plusieurs thèmes mélangés")
                        .lineLimit(1)
                }
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
            } else if let disciplineName = singleDisciplineName {
                HStack(spacing: 6) {
                    Image(systemName: singleDisciplineIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(disciplineName)
                        .lineLimit(1)
                }
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// A path-stage lesson (no discipline/level) is "mixed" when it features
    /// more than one discipline, "single-theme" otherwise. Chapter-level and
    /// review lessons are handled by their own branches above.
    private var isMixedLesson: Bool {
        launch.disciplineId == nil && launch.level == nil
            && Set(launch.items.map { $0.disciplineId }).count > 1
    }

    private var singleDisciplineName: String? {
        guard launch.disciplineId == nil, launch.level == nil else { return nil }
        let ids = launch.items.map { $0.disciplineId }
        guard let only = ids.first, ids.allSatisfy({ $0 == only }) else { return nil }
        return storeDisciplineName(only)
    }

    private var singleDisciplineIcon: String {
        let ids = launch.items.map { $0.disciplineId }
        if let only = ids.first, ids.allSatisfy({ $0 == only }),
           let store = storeDiscipline(only) {
            return store.icon
        }
        return "book.fill"
    }

    private func storeDiscipline(_ id: String) -> Discipline? {
        model.catalog.disciplines.first { $0.id == id }
    }

    private func storeDisciplineName(_ id: String) -> String {
        storeDiscipline(id)?.name ?? "Thème"
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
