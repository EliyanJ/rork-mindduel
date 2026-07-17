import Foundation
import Observation

/// Real online ranked duel: joins the matchmaking queue (HTTP polling),
/// then connects to the match room over WebSocket. The server drives the
/// rounds; both players derive the same questions from the shared seed.
@Observable
final class OnlineDuelSession {
    enum Phase: Equatable {
        case searching
        case found
        case countdown
        case question
        case reveal
        case finished
        case cancelled(String)
        case failed(String)
    }

    struct RoundResult: Identifiable {
        let id: String
        let question: Question
        let playerAnswer: String?
        let playerCorrect: Bool
        let playerPoints: Int
        let playerTime: Double?
        let opponentCorrect: Bool
        let opponentPoints: Int
        let opponentTime: Double
    }

    private let catalog: ContentCatalog
    private let store: ProgressStore
    private let online: OnlineModel
    private let questionDiscipline: [String: String]

    private(set) var phase: Phase = .searching
    private(set) var ticket: MatchTicket?
    private(set) var questions: [Question] = []
    private(set) var roundDuration: Double = 15
    private(set) var currentIndex: Int = 0
    private(set) var currentOptions: [String] = []
    private(set) var timeRemaining: Double = 15
    private(set) var playerScore: Int = 0
    private(set) var opponentScore: Int = 0
    private(set) var playerAnswer: String?
    private(set) var opponentHasAnswered: Bool = false
    private(set) var lastPlayerPoints: Int = 0
    private(set) var lastOpponentPoints: Int = 0
    private(set) var results: [RoundResult] = []
    private(set) var eloChange: Int = 0
    private(set) var newElo: Int?
    private(set) var wonByForfeit: Bool = false
    private(set) var searchSeconds: Int = 0

    private var socket: URLSessionWebSocketTask?
    private var queueTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var roundStartedAt: Date?
    private var playerAnswerTime: Double?
    private var finishedHandled = false

    private let disciplineId: String?

    init(catalog: ContentCatalog, store: ProgressStore, online: OnlineModel, disciplineId: String? = nil) {
        self.catalog = catalog
        self.store = store
        self.online = online
        self.disciplineId = disciplineId
        var map: [String: String] = [:]
        for discipline in catalog.disciplines {
            for chapter in discipline.chapters {
                for question in chapter.allQuestions {
                    map[question.id] = discipline.id
                }
            }
        }
        self.questionDiscipline = map
    }

    var opponent: PlayerProfile? { ticket?.opponent }
    var you: PlayerProfile? { ticket?.you }
    var playerHasAnswered: Bool { playerAnswer != nil }

    var currentQuestion: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    // MARK: lifecycle

    func start() {
        guard queueTask == nil else { return }
        queueTask = Task { await runQueue() }
    }

    func cancel() {
        queueTask?.cancel()
        receiveTask?.cancel()
        timerTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        Task { [online] in
            guard let token = await online.auth.validAccessToken() else { return }
            try? await MultiplayerService(token: token).leaveQueue()
        }
    }

    // MARK: matchmaking

    private func runQueue() async {
        guard let token = await online.auth.validAccessToken() else {
            phase = .failed("Connecte-toi pour jouer en classé")
            return
        }
        let service = MultiplayerService(token: token)
        do {
            var status = try await service.joinQueue(disciplineId: disciplineId)
            let startedAt = Date()
            while case .searching = status {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(1500))
                searchSeconds = Int(Date().timeIntervalSince(startedAt))
                status = try await service.pollQueue()
            }
            if case .matched(let matchTicket) = status {
                await beginMatch(ticket: matchTicket, service: service)
            } else {
                phase = .failed("File d'attente interrompue — réessaie")
            }
        } catch is CancellationError {
            // user cancelled
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func beginMatch(ticket matchTicket: MatchTicket, service: MultiplayerService) async {
        ticket = matchTicket
        roundDuration = matchTicket.roundDuration
        let averageElo = (matchTicket.you.elo + matchTicket.opponent.elo) / 2
        questions = MatchQuestionPicker.questions(
            from: catalog,
            seed: matchTicket.seed,
            count: matchTicket.questionCount,
            themes: matchTicket.themes ?? disciplineId.map { [$0] },
            averageElo: averageElo
        )
        phase = .found
        Haptics.success()

        do {
            let request = try service.matchSocketRequest(ticket: matchTicket)
            let task = URLSession.shared.webSocketTask(with: request)
            socket = task
            task.resume()
            receiveTask = Task { await receiveLoop(task) }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: websocket

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                guard case .string(let text) = message,
                      let data = text.data(using: .utf8) else { continue }
                handleServerMessage(data)
            } catch {
                if !Task.isCancelled && phase != .finished {
                    if case .cancelled = phase { return }
                    if case .failed = phase { return }
                    phase = .failed("Connexion au match perdue")
                }
                return
            }
        }
    }

    private func handleServerMessage(_ data: Data) {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = raw["type"] as? String else { return }

        switch type {
        case "start":
            phase = .countdown
            Haptics.medium()
        case "round":
            guard let index = raw["index"] as? Int else { return }
            startRound(index: index, durationMs: raw["durationMs"] as? Double ?? roundDuration * 1000)
        case "opponent_answered":
            if (raw["index"] as? Int) == currentIndex {
                opponentHasAnswered = true
            }
        case "reveal":
            handleReveal(raw)
        case "finish":
            handleFinish(raw)
        case "cancelled":
            phase = .cancelled("Ton adversaire a quitté avant le début")
            socket?.cancel(with: .goingAway, reason: nil)
        default:
            break
        }
    }

    private func startRound(index: Int, durationMs: Double) {
        currentIndex = index
        guard let question = currentQuestion else { return }
        currentOptions = question.type == .trueFalse
            ? ["Vrai", "Faux"]
            : (question.options ?? []).shuffled()
        playerAnswer = nil
        playerAnswerTime = nil
        opponentHasAnswered = false
        roundStartedAt = .now
        timeRemaining = durationMs / 1000
        phase = .question
        runLocalTimer(total: durationMs / 1000)
    }

    private func runLocalTimer(total: Double) {
        timerTask?.cancel()
        timerTask = Task {
            var elapsed: Double = 0
            while elapsed < total && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                elapsed += 0.05
                if phase == .question {
                    timeRemaining = max(0, total - elapsed)
                } else {
                    return
                }
            }
        }
    }

    func answer(_ option: String) {
        guard phase == .question, playerAnswer == nil, let question = currentQuestion else { return }
        playerAnswer = option
        let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? roundDuration
        playerAnswerTime = min(elapsed, roundDuration)
        let correct = option.comparisonKey == question.answer.comparisonKey
        Haptics.tap()
        send([
            "type": "answer",
            "index": currentIndex,
            "answer": option,
            "correct": correct,
            "timeMs": Int(min(elapsed, roundDuration) * 1000)
        ])
    }

    private func handleReveal(_ raw: [String: Any]) {
        guard let index = raw["index"] as? Int,
              questions.indices.contains(index),
              let you = ticket?.you,
              let opp = ticket?.opponent,
              let answers = raw["answers"] as? [String: [String: Any]] else { return }
        timerTask?.cancel()

        let question = questions[index]
        let mine = answers[you.id]
        let theirs = answers[opp.id]

        let myPoints = mine?["points"] as? Int ?? 0
        let theirPoints = theirs?["points"] as? Int ?? 0
        let myCorrect = mine?["correct"] as? Bool ?? false
        let theirCorrect = theirs?["correct"] as? Bool ?? false
        let theirTimeMs = theirs?["timeMs"] as? Double ?? roundDuration * 1000

        lastPlayerPoints = myPoints
        lastOpponentPoints = theirPoints

        if let scores = raw["scores"] as? [String: Int] {
            playerScore = scores[you.id] ?? playerScore
            opponentScore = scores[opp.id] ?? opponentScore
        }

        results.append(RoundResult(
            id: question.id,
            question: question,
            playerAnswer: playerAnswer,
            playerCorrect: myCorrect,
            playerPoints: myPoints,
            playerTime: playerAnswerTime,
            opponentCorrect: theirCorrect,
            opponentPoints: theirPoints,
            opponentTime: theirTimeMs / 1000
        ))
        store.recordAnswer(
            questionId: question.id,
            disciplineId: questionDiscipline[question.id] ?? "",
            correct: myCorrect
        )
        if myCorrect { Haptics.success() } else { Haptics.error() }
        phase = .reveal
    }

    private func handleFinish(_ raw: [String: Any]) {
        guard !finishedHandled, let you = ticket?.you, let opp = ticket?.opponent else {
            phase = .finished
            return
        }
        finishedHandled = true
        timerTask?.cancel()

        if let scores = raw["scores"] as? [String: Int] {
            playerScore = scores[you.id] ?? playerScore
            opponentScore = scores[opp.id] ?? opponentScore
        }
        if let changes = raw["eloChanges"] as? [String: Int] {
            eloChange = changes[you.id] ?? 0
        }
        if let elos = raw["newElos"] as? [String: Int] {
            newElo = elos[you.id]
        }
        if let forfeitBy = raw["forfeitBy"] as? String, forfeitBy == opp.id {
            wonByForfeit = true
        }

        let won = wonByForfeit || playerScore > opponentScore
        let draw = !wonByForfeit && playerScore == opponentScore
        // Local stats & XP; ranked ELO lives on the server profile.
        store.finalizeDuel(won: won, draw: draw, score: playerScore, eloChange: 0)
        store.registerRankedDuelPlayed()
        online.applyRankedResult(newElo: newElo, won: won, draw: draw)

        phase = .finished
        if won { Haptics.success() }
    }

    private func send(_ payload: [String: Any]) {
        guard let socket,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { error in
            if let error {
                print("ws send failed: \(error.localizedDescription)")
            }
        }
    }
}
