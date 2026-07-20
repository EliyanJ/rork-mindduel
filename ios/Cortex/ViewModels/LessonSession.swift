import Foundation
import Observation

struct LessonItem: Identifiable, Hashable {
    let question: Question
    let disciplineId: String
    var id: String { question.id }
}

/// Drives a lesson or a review session: question flow, answer checking,
/// feedback, XP and spaced-repetition recording.
@Observable
final class LessonSession {
    enum Phase: Equatable {
        case answering
        case feedback(correct: Bool)
        case completed
    }

    let items: [LessonItem]
    let chapterId: String?
    let disciplineId: String?
    let level: DifficultyLevel?
    let chapterIdRaw: String?
    /// 1-based index of the current manche within a multi-session chapter level.
    let sessionNumber: Int
    /// Total manches needed to validate a chapter level (2 = 20 questions / 10 per session).
    /// 1 for non-level lessons (mixed/themed path stages, reviews).
    let totalSessions: Int
    private let store: ProgressStore

    private(set) var index: Int = 0
    private(set) var phase: Phase = .answering
    var selection: String = ""
    private(set) var currentOptions: [String] = []
    private(set) var anagramLetters: [Character] = []
    private(set) var correctCount: Int = 0
    private(set) var xpEarned: Int = 0
    private(set) var streakAfterCompletion: Int = 0
    private(set) var wrongAnswers: [WrongAnswer] = []

    struct WrongAnswer: Identifiable, Hashable {
        let id = UUID()
        let question: Question
        let selectedAnswer: String
        let disciplineId: String
    }

    init(items: [LessonItem], chapterId: String?, store: ProgressStore,
         disciplineId: String? = nil, level: DifficultyLevel? = nil, chapterIdRaw: String? = nil) {
        self.items = items
        self.chapterId = chapterId
        self.store = store
        self.disciplineId = disciplineId
        self.level = level
        self.chapterIdRaw = chapterIdRaw
        // A chapter level is played over 2 manches of 10 questions (20 total).
        // Other lessons (mixed/themed path stages, reviews) are single-session.
        if disciplineId != nil, level != nil, chapterIdRaw != nil {
            let prior = store.chapterProgress(
                disciplineId: disciplineId!, chapterId: chapterIdRaw!, level: level!
            )?.sessionsDone ?? 0
            self.sessionNumber = prior + 1
            self.totalSessions = 2
        } else {
            self.sessionNumber = 1
            self.totalSessions = 1
        }
        prepareQuestion()
    }

    /// True when this lesson is one manche of a 2-session chapter level.
    var isMultiSessionLevel: Bool { totalSessions > 1 }

    /// After completion, true if the chapter level still needs another manche
    /// (i.e. this was session 1/2 and the level isn't evaluated yet).
    var needsAnotherSession: Bool {
        guard phase == .completed, isMultiSessionLevel,
              let disciplineId, let level, let chapterIdRaw,
              let cp = store.chapterProgress(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level) else {
            return false
        }
        return !cp.isCompleted
    }

    /// After completion, true if this manche just validated the level (>=80%).
    var levelJustValidated: Bool {
        guard phase == .completed, isMultiSessionLevel,
              let disciplineId, let level, let chapterIdRaw,
              let cp = store.chapterProgress(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level) else {
            return false
        }
        return cp.isCompleted && cp.passed
    }

    var current: LessonItem { items[min(index, max(items.count - 1, 0))] }
    var progressValue: Double { items.isEmpty ? 0 : Double(index) / Double(items.count) }
    var isLast: Bool { index >= items.count - 1 }
    var accuracy: Double { items.isEmpty ? 0 : Double(correctCount) / Double(items.count) }

    func submit() {
        guard phase == .answering, !selection.isEmpty, !items.isEmpty else { return }
        let question = current.question
        let correct = selection.comparisonKey == question.answer.comparisonKey
        if correct {
            correctCount += 1
            xpEarned += 10
            Haptics.success()
        } else {
            Haptics.error()
            wrongAnswers.append(WrongAnswer(
                question: question,
                selectedAnswer: selection,
                disciplineId: current.disciplineId
            ))
        }
        store.recordAnswer(questionId: question.id, disciplineId: current.disciplineId, correct: correct)
        phase = .feedback(correct: correct)
    }

    func advance() {
        guard case .feedback = phase else { return }
        if isLast {
            complete()
        } else {
            index += 1
            selection = ""
            phase = .answering
            prepareQuestion()
        }
    }

    private func complete() {
        if correctCount == items.count { xpEarned += 20 }
        store.addXP(xpEarned)
        store.registerActivity()
        if let chapterId {
            store.recordChapterResult(chapterId: chapterId, score: accuracy)
        }
        // Record multi-level progress for v2 chapters
        if let disciplineId, let level, let chapterIdRaw {
            let seenIds = items.map { $0.question.id }
            store.recordChapterLevelSession(
                disciplineId: disciplineId,
                chapterId: chapterIdRaw,
                level: level,
                correct: correctCount,
                answered: items.count,
                seenIds: seenIds
            )
            // If the chapter level is now completed but failed (<80%), mark it as failed
            // so the retry cooldown and empty-pool prevention kick in.
            if let cp = store.chapterProgress(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level),
               cp.isCompleted, !cp.passed {
                store.markChapterLevelFailed(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level)
            }
        }
        streakAfterCompletion = store.currentStreak
        phase = .completed
        Haptics.medium()
    }

    /// Convenience: a level is "failed" when it was just completed and scored <80%.
    var isLevelFailed: Bool {
        guard phase == .completed,
              let disciplineId, let level, let chapterIdRaw,
              let cp = store.chapterProgress(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level) else {
            return false
        }
        return cp.isCompleted && !cp.passed
    }

    private func prepareQuestion() {
        guard !items.isEmpty else { return }
        let question = current.question
        switch question.type {
        case .trueFalse:
            currentOptions = ["Vrai", "Faux"]
            anagramLetters = []
        case .anagram:
            currentOptions = []
            var letters = Array(question.answer)
            if letters.count > 1 {
                repeat { letters.shuffle() } while String(letters) == question.answer
            }
            anagramLetters = letters
        case .multipleChoice, .fillBlank:
            currentOptions = (question.options ?? []).shuffled()
            anagramLetters = []
        }
    }
}
