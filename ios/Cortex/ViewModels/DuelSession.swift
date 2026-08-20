import Foundation
import Observation
import SwiftUI

/// Real-time PvP duel engine (Kahoot-style) against a simulated opponent:
/// simultaneous questions, locked buzzers, speed bonus and ELO update.
@Observable
final class DuelSession {
    enum Phase: Equatable {
        case matchmaking
        case found
        case countdown(Int)
        case preview
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
    let themeName: String
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
    private(set) var showScoreboard: Bool = false
    private(set) var botAnswer: String?
    private(set) var voteCounts: [Int] = []
    private(set) var leaderboardEntries: [QuizLeaderboardEntry] = []
    private(set) var answeredCount: Int = 0
    private(set) var wasFastestCorrect: Bool = false
    private(set) var floatingEmotes: [FloatingEmote] = []

    static let totalVoters: Int = 2
    static let readingBeat: Double = 8

    private var playerAnswerTime: Double?
    private var runTask: Task<Void, Never>?
    private var previousRanks: [String: Int] = [:]
    private var emoteTask: Task<Void, Never>?

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
        self.themeName = disciplineId.flatMap { id in catalog.disciplines.first { $0.id == id }?.name } ?? "Tous thèmes"
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = .countdown(count) }
                Haptics.tap()
                try await Task.sleep(for: .seconds(1.0))
            }
            SoundManager.shared.startAmbience()
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
        botAnswer = nil
        answeredCount = 0

        // A short "read the question first" beat, Kahoot-style: the answers
        // stay fully hidden while the question sinks in before unlocking.
        phase = .preview
        try await Task.sleep(for: .seconds(Self.readingBeat))

        timeRemaining = Self.roundDuration
        let botTime = Double.random(in: 2.5...12.5)
        let botCorrect = Double.random(in: 0...1) < 0.6
        botAnswer = botCorrect
            ? question.answer
            : (currentOptions.first { $0.comparisonKey != question.answer.comparisonKey } ?? question.answer)
        phase = .question

        var elapsed: Double = 0
        while elapsed < Self.roundDuration {
            try await Task.sleep(for: .milliseconds(50))
            elapsed += 0.05
            timeRemaining = max(0, Self.roundDuration - elapsed)
            SoundManager.shared.pulseTension(fraction: timeRemaining / Self.roundDuration)
            if !botHasAnswered && elapsed >= botTime {
                botHasAnswered = true
            }
            answeredCount = (playerAnswer != nil ? 1 : 0) + (botHasAnswered ? 1 : 0)
            if playerAnswer != nil && botHasAnswered {
                break
            }
        }
        botHasAnswered = true
        answeredCount = Self.totalVoters
        SoundManager.shared.resetTension()

        let playerCorrect = playerAnswer.map { $0.comparisonKey == question.answer.comparisonKey } ?? false
        let answerTime = playerAnswerTime ?? Self.roundDuration
        let playerPoints = playerCorrect ? 100 + Int((1 - answerTime / Self.roundDuration) * 100) : 0
        let effectiveBotTime = min(botTime, Self.roundDuration)
        let botPoints = botCorrect ? 100 + Int((1 - effectiveBotTime / Self.roundDuration) * 100) : 0
        wasFastestCorrect = playerCorrect && (playerAnswerTime ?? Self.roundDuration) < effectiveBotTime

        // Snapshot the rank order before this round's points land, so the
        // leaderboard page can show who just overtook whom.
        previousRanks = [
            "you": playerScore >= botScore ? 1 : 2,
            "bot": botScore >= playerScore ? 1 : 2
        ]

        lastPlayerPoints = playerPoints
        lastBotPoints = botPoints
        playerScore += playerPoints
        botScore += botPoints
        if playerCorrect { Haptics.success(); SoundManager.shared.playCorrect() } else { Haptics.error(); SoundManager.shared.playWrong() }

        voteCounts = currentOptions.map { option in
            (playerAnswer == option ? 1 : 0) + (botAnswer == option ? 1 : 0)
        }

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
        AnswerTelemetry.shared.record(AnswerTelemetry.Event(
            questionId: question.id,
            correct: playerCorrect,
            timeMs: Int(answerTime * 1000),
            selected: playerAnswer,
            timedOut: playerAnswer == nil,
            disciplineId: questionDiscipline[question.id] ?? "",
            level: nil
        ))

        phase = .reveal
        try await Task.sleep(for: .seconds(4.0))

        if (index + 1) % 2 == 0, index < questions.count - 1 {
            leaderboardEntries = [
                QuizLeaderboardEntry(id: "you", name: "Toi", emoji: "\u{1F9E0}", score: playerScore, isYou: true, previousRank: previousRanks["you"]),
                QuizLeaderboardEntry(id: "bot", name: opponent.name, emoji: opponent.emoji, score: botScore, isYou: false, previousRank: previousRanks["bot"])
            ]
            SoundManager.shared.startLeaderboardMusic()
            withAnimation(.spring(duration: 0.7)) { showScoreboard = true }
            try await Task.sleep(for: .seconds(7.0))
            showScoreboard = false
            SoundManager.shared.stopLeaderboardMusic()
        }
    }

    // MARK: - Emotes

    /// Sends the player's own reaction, then — for fun and to make the bot
    /// feel alive — sometimes has it emote back a moment later.
    func sendEmote(_ emote: QuizEmote) {
        pushFloatingEmote(FloatingEmote(senderName: "Toi", emote: emote))
        guard Double.random(in: 0...1) < 0.45 else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(.random(in: 400...1100)))
            guard let self else { return }
            let reply = QuizEmote.allCases.randomElement() ?? emote
            self.pushFloatingEmote(FloatingEmote(senderName: self.opponent.name, emote: reply))
        }
    }

    private func pushFloatingEmote(_ item: FloatingEmote) {
        floatingEmotes.append(item)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            self?.floatingEmotes.removeAll { $0.id == item.id }
        }
    }

    private func finish() {
        AnswerTelemetry.shared.flush()
        SoundManager.shared.stopAmbience()
        SoundManager.shared.stopLeaderboardMusic()
        let won = playerScore > botScore
        let draw = playerScore == botScore
        eloChange = draw ? 4 : (won ? 18 : -12)
        store.finalizeDuel(won: won, draw: draw, score: playerScore, eloChange: eloChange)
        store.registerBotMatchPlayed()
        phase = .finished
        if won { Haptics.success() }
    }
}
