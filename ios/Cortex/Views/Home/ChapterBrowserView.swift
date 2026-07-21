import SwiftUI

/// Duolingo-style zigzag path for multi-level disciplines.
/// Each node is a chapter; the five small dots below it are the difficulty
/// checkpoints (F → I → D → M → L). Tapping a chapter launches the next
/// unlocked, non-completed level for that chapter.
struct ChapterBrowserView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    let onSelectItems: ([LessonItem], String, String, DifficultyLevel) -> Void

    @State private var pathWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            if let discipline = model.selectedDiscipline {
                ForEach(Array(discipline.chapters.enumerated()), id: \.element.id) { index, chapter in
                    if index > 0 {
                        connector
                    }
                    ChapterNodeView(
                        chapter: chapter,
                        discipline: discipline,
                        index: index,
                        state: state(for: chapter, discipline: discipline)
                    ) { level in
                        startLevel(chapter: chapter, discipline: discipline, level: level)
                    }
                    .offset(x: horizontalOffset(for: index, width: pathWidth))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            pathWidth = newWidth
        }
    }

    private var connector: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Theme.line)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 10)
    }

    private func horizontalOffset(for index: Int, width: CGFloat) -> CGFloat {
        let step = min(width * 0.22, 72)
        let pattern: [CGFloat] = [0, -step, 0, step]
        return pattern[index % pattern.count]
    }

    private func state(for chapter: Chapter, discipline: Discipline) -> ChapterState {
        // Chapter-by-chapter sequential gate: the first chapter is always
        // available, the next one only unlocks once the previous chapter
        // was cleared on its Facile level (same 60%/80% thresholds as the
        // mixed path in AppModel.state(of:)).
        guard isChapterUnlocked(chapter, in: discipline) else { return .locked }

        // Once the chapter itself is reachable, isLevelUnlocked still
        // governs unlocking Intermédiaire/Difficile/etc. within it.
        let hasAnyUnlocked = chapter.availableLevels.contains { level in
            model.store.isLevelUnlocked(level, for: discipline) && !model.store.isChapterLevelCompleted(disciplineId: discipline.id, chapterId: chapter.id, level: level)
        }
        if hasAnyUnlocked {
            return chapter.availableLevels.allSatisfy { level in
                model.store.isChapterLevelCompleted(disciplineId: discipline.id, chapterId: chapter.id, level: level)
            } ? .mastered : .available
        }
        let allCompleted = chapter.availableLevels.allSatisfy { level in
            model.store.isChapterLevelCompleted(disciplineId: discipline.id, chapterId: chapter.id, level: level)
        }
        return allCompleted ? .mastered : .available
    }

    /// A chapter unlocks sequentially: the first one is free, the next ones
    /// require the previous chapter's Facile level to be cleared at >= 60%
    /// best score (same unlock threshold used by the mixed path).
    private func isChapterUnlocked(_ chapter: Chapter, in discipline: Discipline) -> Bool {
        let idx = index(of: chapter, in: discipline)
        guard idx > 0 else { return true }
        let previous = discipline.chapters[idx - 1]
        let previousBestScore = model.store.chapterProgress(
            disciplineId: discipline.id, chapterId: previous.id, level: .facile
        )?.bestScore ?? 0
        return previousBestScore >= 0.6
    }

    private func index(of chapter: Chapter, in discipline: Discipline) -> Int {
        discipline.chapters.firstIndex(where: { $0.id == chapter.id }) ?? 0
    }

    private func startLevel(chapter: Chapter, discipline: Discipline, level: DifficultyLevel) {
        let questions = chapter.questionsAtLevel(level)
        let seenIds = model.store.seenQuestionIds(
            disciplineId: discipline.id, chapterId: chapter.id, level: level
        )
        let unseen = questions.filter { q in !seenIds.contains(q.id) }
        let sessionQuestions = Array(unseen.prefix(10))
        let items = sessionQuestions.map { LessonItem(question: $0, disciplineId: discipline.id) }
        onSelectItems(items, discipline.id, chapter.id, level)
    }
}

struct ChapterNodeView: View {
    @Environment(AppModel.self) private var model
    let chapter: Chapter
    let discipline: Discipline
    let index: Int
    let state: ChapterState
    let action: (DifficultyLevel) -> Void

    @State private var isPulsing: Bool = false

    var body: some View {
        let nextLevel = nextPlayableLevel()
        Button {
            guard let nextLevel else { return }
            Haptics.medium()
            action(nextLevel)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if state == .available {
                        Circle()
                            .stroke(discipline.color.opacity(0.35), lineWidth: 4)
                            .frame(width: 96, height: 96)
                            .scaleEffect(isPulsing ? 1.05 : 0.94)
                    }
                    Circle()
                        .fill(fillColor.mix(with: .black, by: 0.25))
                        .frame(width: 78, height: 78)
                        .offset(y: 5)
                    Circle()
                        .fill(fillColor)
                        .frame(width: 78, height: 78)
                    Image(systemName: iconName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(height: 96)

                Text(chapter.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(state == .locked ? Theme.inkMuted : Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(width: 160)

                levelCheckpoints

                if let nextLevel {
                    Text(nextLevel.displayName)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(discipline.color)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .locked || nextLevel == nil)
        .onAppear {
            guard state == .available else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var levelCheckpoints: some View {
        HStack(spacing: 6) {
            ForEach(chapter.availableLevels, id: \.self) { level in
                let completed = isLevelCompleted(level)
                let unlocked = isLevelUnlocked(level)
                Text(level.shortLabel)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(completed ? .white : (unlocked ? Theme.ink : Theme.inkMuted))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(completed ? Theme.gold : (unlocked ? discipline.color.opacity(0.22) : Theme.lockedFill))
                    )
                    .overlay(
                        Circle()
                            .stroke(completed ? Theme.gold : (unlocked ? discipline.color.opacity(0.5) : Theme.line), lineWidth: 1.5)
                    )
            }
        }
        .opacity(state == .locked ? 0.6 : 1)
    }

    private func isLevelUnlocked(_ level: DifficultyLevel) -> Bool {
        model.store.isLevelUnlocked(level, for: discipline)
    }

    private func isLevelCompleted(_ level: DifficultyLevel) -> Bool {
        model.store.isChapterLevelCompleted(disciplineId: discipline.id, chapterId: chapter.id, level: level)
    }

    private func nextPlayableLevel() -> DifficultyLevel? {
        chapter.availableLevels.first { level in
            isLevelUnlocked(level) && !isLevelCompleted(level)
        }
    }

    private var fillColor: Color {
        switch state {
        case .locked: return Theme.lockedFill
        case .available, .completed: return discipline.color
        case .mastered: return Theme.gold
        }
    }

    private var iconName: String {
        switch state {
        case .locked: return "lock.fill"
        case .available: return "star.fill"
        case .completed: return "book.fill"
        case .mastered: return "crown.fill"
        }
    }

    private var iconColor: Color {
        state == .locked ? Theme.inkMuted : .white
    }
}
