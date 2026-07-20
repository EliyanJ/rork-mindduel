import Foundation
import Observation

/// Real-time PvP duel engine (Kahoot-style) against a simulated opponent:
/// simultaneous questions, locked buzzers, speed bonus and ELO update.
@Observable
final class DuelSession {
    enum Phase: Equatable {
        case matchmaking
        case found
        case countdown(Int)
        case question
        case reveal
        case finished
    }

    struct Opponent {
        let name: String
        let emoji: String
        let elo: Int
    }

    struct RoundResult: Identifiable {
        let id: String
        let question: Question
        let playerAnswer: String?
        let playerCorrect: Bool
        let playerPoints: Int
        let playerTime: Double?
        let botCorrect: Bool
        let botPoints: Int
        let botTime: Double
    }

    static let roundDuration: Double = 15
    static let questionCount: Int = 15

    let questions: [Question]
    let opponent: Opponent
    private let store: ProgressStore
    private let questionDiscipline: [String: String]

    private(set) var phase: Phase = .matchmaking
    private(set) var currentIndex: Int = 0
    private(set) var currentOptions: [String] = []
    private(set) var timeRemaining: Double = DuelSession.roundDuration
    private(set) var playerScore: Int = 0
    private(set) var botScore: Int = 0
    private(set) var playerAnswer: String?
    private(set) var botHasAnswered: Bool = false
    private(set) var lastPlayerPoints: Int = 0
    private(set) var lastBotPoints: Int = 0
    private(set) var results: [RoundResult] = []
    private(set) var eloChange: Int = 0

    private var playerAnswerTime: Double?
    private var runTask: Task<Void, Never>?

    init(catalog: ContentCatalog, store: ProgressStore, disciplineId: String? = nil) {
        self.store = store
        var disciplineMap: [String: String] = [:]
        var pool: [Question] = []
        for discipline in catalog.disciplines {
            if let disciplineId, discipline.id != disciplineId { continue }
            for chapter in discipline.chapters {
                for question in chapter.allQuestions where question.type != .anagram {
                    pool.append(question)
                    disciplineMap[question.id] = discipline.id
                }
            }
        }
        self.questionDiscipline = disciplineMap
        self.questions = Array(pool.shuffled().prefix(Self.questionCount))
        let candidates: [(String, String)] = [
            ("Léa", "🦊"), ("Hugo", "🦉"), ("Emma", "🐼"),
            ("Nathan", "🐸"), ("Sofia", "🐨"), ("Tom", "🐯")
        ]
        let pick = candidates.randomElement() ?? ("Léa", "🦊")
        self.opponent = Opponent(name: pick.0, emoji: pick.1, elo: store.progress.elo + Int.random(in: -80...80))
    }

    var currentQuestion: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var playerHasAnswered: Bool { playerAnswer != nil }

    func start() {
        guard runTask == nil else { return }
        runTask = Task { await run() }
    }

    func cancel() {
        runTask?.cancel()
    }

    func answer(_ option: String) {
        guard phase == .question, playerAnswer == nil else { return }
        playerAnswer = option
        playerAnswerTime = Self.roundDuration - timeRemaining
        Haptics.tap()
    }

    private func run() async {
        do {
            try await Task.sleep(for: .seconds(2.4))
            phase = .found
            try await Task.sleep(for: .seconds(1.8))
            for count in [3, 2, 1] {
                phase = .countdown(count)
                try await Task.sleep(for: .seconds(0.8))
            }
            for index in questions.indices {
                try await playRound(index: index)
            }
            finish()
        } catch {
            // Duel cancelled by user.
        }
    }

    private func playRound(index: Int) async throws {
        currentIndex = index
        let question = questions[index]
        currentOptions = question.type == .trueFalse ? ["Vrai", "Faux"] : (question.options ?? []).shuffled()
        playerAnswer = nil
        playerAnswerTime = nil
        botHasAnswered = false
        timeRemaining = Self.roundDuration
        let botTime = Double.random(in: 2.5...12.5)
        let botCorrect = Double.random(in: 0...1) < 0.6
        phase = .question

        var elapsed: Double = 0
        while elapsed < Self.roundDuration {
            try await Task.sleep(for: .milliseconds(50))
            elapsed += 0.05
            timeRemaining = max(0, Self.roundDuration - elapsed)
            if !botHasAnswered && elapsed >= botTime {
                botHasAnswered = true
            }
            if playerAnswer != nil && botHasAnswered {
                break
            }
        }
        botHasAnswered = true

        let playerCorrect = playerAnswer.map { $0.comparisonKey == question.answer.comparisonKey } ?? false
        let answerTime = playerAnswerTime ?? Self.roundDuration
        let playerPoints = playerCorrect ? 100 + Int((1 - answerTime / Self.roundDuration) * 100) : 0
        let effectiveBotTime = min(botTime, Self.roundDuration)
        let botPoints = botCorrect ? 100 + Int((1 - effectiveBotTime / Self.roundDuration) * 100) : 0

        lastPlayerPoints = playerPoints
        lastBotPoints = botPoints
        playerScore += playerPoints
        botScore += botPoints
        if playerCorrect { Haptics.success() } else { Haptics.error() }

        results.append(RoundResult(
            id: question.id,
            question: question,
            playerAnswer: playerAnswer,
            playerCorrect: playerCorrect,
            playerPoints: playerPoints,
            playerTime: playerAnswerTime,
            botCorrect: botCorrect,
            botPoints: botPoints,
            botTime: effectiveBotTime
        ))
        store.recordAnswer(
            questionId: question.id,
            disciplineId: questionDiscipline[question.id] ?? "",
            correct: playerCorrect
        )

        phase = .reveal
        try await Task.sleep(for: .seconds(2.4))
    }

    private func finish() {
        let won = playerScore > botScore
        let draw = playerScore == botScore
        eloChange = draw ? 4 : (won ? 18 : -12)
        store.finalizeDuel(won: won, draw: draw, score: playerScore, eloChange: eloChange)
        store.registerBotMatchPlayed()
        phase = .finished
        if won { Haptics.success() }
    }
}
