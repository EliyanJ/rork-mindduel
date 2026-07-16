import Foundation
import Observation

/// Drives the optional onboarding diagnostic: a lightweight quiz that records
/// spaced-repetition answers but does NOT award XP, count toward quotas, or
/// record chapter progress. Purely a measurement tool.
@Observable
final class DiagnosticSession {
    enum Phase: Equatable {
        case answering
        case feedback(correct: Bool)
        case completed
    }

    let items: [LessonItem]
    private let store: ProgressStore

    private(set) var index: Int = 0
    private(set) var phase: Phase = .answering
    var selection: String = ""
    private(set) var currentOptions: [String] = []
    private(set) var anagramLetters: [Character] = []
    private(set) var correctCount: Int = 0
    private(set) var wasCorrect: [Bool] = []

    init(items: [LessonItem], store: ProgressStore) {
        self.items = items
        self.store = store
        prepareQuestion()
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
            Haptics.success()
        } else {
            Haptics.error()
        }
        wasCorrect.append(correct)
        // Record in spaced repetition but skip XP, activity, and quotas.
        store.recordAnswer(questionId: question.id, disciplineId: current.disciplineId, correct: correct)
        phase = .feedback(correct: correct)
    }

    func advance() {
        guard case .feedback = phase else { return }
        if isLast {
            phase = .completed
            Haptics.medium()
        } else {
            index += 1
            selection = ""
            phase = .answering
            prepareQuestion()
        }
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
