import Foundation
import Observation

/// Drives one party game end-to-end: HTTP-polls the lobby until it is full
/// (real players trickling in, then bots after 15s server-side), opens the
/// party room over WebSocket, and plays through 3 rounds of 20 questions.
/// The server is authoritative on timing and scores — this session mirrors
/// its state for the UI and derives the shared question list from the seed,
/// exactly like `OnlineDuelSession` does for ranked 1v1 duels.
@Observable
final class PartySession {
    enum Phase: Equatable {
        case queued
        case connecting
        case countdown
        case question
        case reveal
        case finished
        case cancelled(String)
        case failed(String)
    }

    struct BoardEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let emoji: String
        let score: Int
        let team: String?
        let isYou: Bool
    }

    struct Surge: Identifiable, Equatable {
        let id: String
        let name: String
        let points: Int
    }

    struct FinalEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let emoji: String
        let score: Int
        let team: String?
        let rank: Int
        let isYou: Bool
    }

    private let catalog: ContentCatalog
    private let store: ProgressStore
    private let online: OnlineModel

    private(set) var phase: Phase = .queued
    private(set) var mode: PartyMode = .solo
    private(set) var lobby: PartyLobbyState?
    private(set) var ticket: PartyTicket?
    private(set) var questions: [Question] = []
    private(set) var roundDuration: Double = 10
    private(set) var totalQuestions: Int = 60
    private(set) var currentGlobalIndex: Int = 0
    private(set) var currentOptions: [String] = []
    private(set) var timeRemaining: Double = 10
    private(set) var playerAnswer: String?
    private(set) var lastPlayerCorrect: Bool = false
    private(set) var lastPlayerPoints: Int = 0
    private(set) var scores: [String: Int] = [:]
    private(set) var teamScores: (a: Int, b: Int)?
    private(set) var topBoard: [BoardEntry] = []
    private(set) var showLeaderboard: Bool = false
    private(set) var surge: Surge?
    private(set) var finalEntries: [FinalEntry] = []
    private(set) var pointsDelta: Int = 0
    private(set) var reputationDelta: Int = 0
    private(set) var winningTeam: String?

    private var scoresAtRoundStart: [String: Int] = [:]
    private var socket: URLSessionWebSocketTask?
    private var queueTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var surgeTask: Task<Void, Never>?
    private var roundStartedAt: Date?
    private var playerAnswerTime: Double?
    private var finishedHandled = false
    private var leftBeforeStart = false
    private let questionDiscipline: [String: String]

    init(catalog: ContentCatalog, store: ProgressStore, online: OnlineModel, mode: PartyMode) {
        self.catalog = catalog
        self.store = store
        self.online = online
        self.mode = mode
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

    var you: PartyPlayer? { ticket?.you }
    var currentQuestion: Question? {
        questions.indices.contains(currentGlobalIndex) ? questions[currentGlobalIndex] : nil
    }
    var currentRound: Int { ticket.map { currentGlobalIndex / $0.questionsPerRound } ?? 0 }
    var currentQuestionInRound: Int { ticket.map { currentGlobalIndex % $0.questionsPerRound } ?? 0 }
    var myScore: Int { you.map { scores[$0.id] ?? 0 } ?? 0 }
    var myRank: Int {
        let sorted = scores.sorted { $0.value > $1.value }
        return (sorted.firstIndex { $0.key == you?.id } ?? 0) + 1
    }

    // MARK: lifecycle

    func start() {
        guard queueTask == nil else { return }
        queueTask = Task { await runLobby() }
    }

    /// Leaves the lobby (before start) or disconnects mid-game — the server
    /// applies the matching reputation penalty either way.
    func cancel() {
        queueTask?.cancel()
        receiveTask?.cancel()
        timerTask?.cancel()
        surgeTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        guard !leftBeforeStart, ticket == nil else { return }
        leftBeforeStart = true
        Task { [online] in
            guard let token = await online.auth.validAccessToken() else { return }
            try? await MultiplayerService(token: token).leavePartyQueue()
        }
    }

    // MARK: lobby

    private func runLobby() async {
        guard let token = await online.auth.validAccessToken() else {
            phase = .failed("Connecte-toi pour jouer en multijoueur")
            return
        }
        let service = MultiplayerService(token: token)
        do {
            var status = try await service.joinPartyQueue(mode: mode)
            while true {
                try Task.checkCancellation()
                switch status {
                case .matched(let ticket):
                    await beginGame(ticket: ticket, service: service)
                    return
                case .waiting(let state):
                    lobby = state
                case .idle:
                    break
                }
                try await Task.sleep(for: .milliseconds(1200))
                status = try await service.pollPartyQueue()
            }
        } catch is CancellationError {
            // user cancelled
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func beginGame(ticket partyTicket: PartyTicket, service: MultiplayerService) async {
        ticket = partyTicket
        roundDuration = partyTicket.roundDuration
        totalQuestions = partyTicket.totalQuestions
        let averageElo = partyTicket.players.reduce(0) { $0 + $1.elo } / max(partyTicket.players.count, 1)
        questions = MatchQuestionPicker.questions(
            from: catalog,
            seed: partyTicket.seed,
            count: partyTicket.totalQuestions,
            themes: ["all"],
            averageElo: averageElo
        )
        scores = Dictionary(uniqueKeysWithValues: partyTicket.players.map { ($0.id, 0) })
        phase = .connecting
        Haptics.success()

        do {
            let request = try service.partySocketRequest(ticket: partyTicket)
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
                guard case .string(let text) = message, let data = text.data(using: .utf8) else { continue }
                handleServerMessage(data)
            } catch {
                if !Task.isCancelled {
                    switch phase {
                    case .finished, .cancelled, .failed: return
                    default: phase = .failed("Connexion à la partie perdue")
                    }
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
            guard let index = raw["globalIndex"] as? Int else { return }
            startRound(index: index, durationMs: raw["durationMs"] as? Double ?? roundDuration * 1000)
        case "reveal":
            handleReveal(raw)
        case "finish":
            handleFinish(raw)
        case "cancelled":
            phase = .cancelled("La partie a été annulée")
            socket?.cancel(with: .goingAway, reason: nil)
        default:
            break
        }
    }

    private func startRound(index: Int, durationMs: Double) {
        currentGlobalIndex = index
        scoresAtRoundStart = scores
        guard let question = currentQuestion else { return }
        currentOptions = question.type == .trueFalse ? ["Vrai", "Faux"] : (question.options ?? []).shuffled()
        playerAnswer = nil
        playerAnswerTime = nil
        roundStartedAt = .now
        timeRemaining = durationMs / 1000
        surge = nil
        showLeaderboard = false
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
        lastPlayerCorrect = correct
        Haptics.tap()
        send([
            "type": "answer",
            "index": currentGlobalIndex,
            "correct": correct,
            "timeMs": Int(min(elapsed, roundDuration) * 1000)
        ])
    }

    private func handleReveal(_ raw: [String: Any]) {
        guard let index = raw["globalIndex"] as? Int, questions.indices.contains(index) else { return }
        timerTask?.cancel()
        let question = questions[index]

        if let serverScores = raw["scores"] as? [String: Int] {
            scores = serverScores
        }
        if let teams = raw["teamScores"] as? [String: Int] {
            teamScores = (a: teams["A"] ?? 0, b: teams["B"] ?? 0)
        }
        if let youId = you?.id {
            lastPlayerPoints = (scores[youId] ?? 0) - (scoresAtRoundStart[youId] ?? 0)
        }

        store.recordAnswer(
            questionId: question.id,
            disciplineId: questionDiscipline[question.id] ?? "",
            correct: lastPlayerCorrect
        )
        AnswerTelemetry.shared.record(AnswerTelemetry.Event(
            questionId: question.id,
            correct: lastPlayerCorrect,
            timeMs: Int((playerAnswerTime ?? roundDuration) * 1000),
            selected: playerAnswer,
            timedOut: playerAnswer == nil,
            disciplineId: questionDiscipline[question.id] ?? "",
            level: nil
        ))
        if lastPlayerCorrect { Haptics.success() } else { Haptics.error() }

        updateLeaderboard(revealIndex: index)
        phase = .reveal
    }

    /// Recomputes the top 5 every 2 questions, and fires the "surge" callout
    /// when someone outside the top 5 just posted the biggest gain this round.
    private func updateLeaderboard(revealIndex: Int) {
        guard let ticket else { return }
        let ranked = ticket.players
            .map { player -> BoardEntry in
                BoardEntry(
                    id: player.id,
                    name: player.name,
                    emoji: player.emoji,
                    score: scores[player.id] ?? 0,
                    team: player.team,
                    isYou: player.id == you?.id
                )
            }
            .sorted { $0.score > $1.score }

        let top5Ids = Set(ranked.prefix(5).map(\.id))
        let biggestOutsider = ticket.players
            .filter { !top5Ids.contains($0.id) }
            .map { player -> (PartyPlayer, Int) in
                (player, (scores[player.id] ?? 0) - (scoresAtRoundStart[player.id] ?? 0))
            }
            .max { $0.1 < $1.1 }

        if let (player, gained) = biggestOutsider, gained >= 150 {
            let surgeEvent = Surge(id: "\(player.id)-\(revealIndex)", name: player.name, points: gained)
            surge = surgeEvent
            surgeTask?.cancel()
            surgeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.4))
                if self?.surge?.id == surgeEvent.id { self?.surge = nil }
            }
        }

        if (revealIndex + 1) % 2 == 0 {
            topBoard = Array(ranked.prefix(5))
            showLeaderboard = true
        }
    }

    private func handleFinish(_ raw: [String: Any]) {
        guard !finishedHandled, let ticket else {
            phase = .finished
            return
        }
        finishedHandled = true
        timerTask?.cancel()
        surgeTask?.cancel()
        AnswerTelemetry.shared.flush()

        if let serverScores = raw["scores"] as? [String: Int] {
            scores = serverScores
        }
        if let teams = raw["teamScores"] as? [String: Int] {
            teamScores = (a: teams["A"] ?? 0, b: teams["B"] ?? 0)
        }
        if let changes = raw["pointsChanges"] as? [String: Int], let youId = you?.id {
            pointsDelta = changes[youId] ?? 0
        }
        if let repChanges = raw["reputationChanges"] as? [String: Int], let youId = you?.id {
            reputationDelta = repChanges[youId] ?? 0
        }

        let ranked = ticket.players
            .map { player -> FinalEntry in
                FinalEntry(
                    id: player.id, name: player.name, emoji: player.emoji,
                    score: scores[player.id] ?? 0, team: player.team, rank: 0,
                    isYou: player.id == you?.id
                )
            }
            .sorted { $0.score > $1.score }
            .enumerated()
            .map { index, entry in
                FinalEntry(
                    id: entry.id, name: entry.name, emoji: entry.emoji,
                    score: entry.score, team: entry.team, rank: index + 1, isYou: entry.isYou
                )
            }
        finalEntries = ranked

        if let teamScores {
            winningTeam = teamScores.a == teamScores.b ? nil : (teamScores.a > teamScores.b ? "A" : "B")
        }

        store.registerRankedDuelPlayed()
        online.applyPartyResult(pointsDelta: pointsDelta, reputationDelta: reputationDelta)
        phase = .finished
        let won = mode == .team10 ? (winningTeam != nil && winningTeam == you?.team) : myRank <= 3
        if won { Haptics.success() }
    }

    private func send(_ payload: [String: Any]) {
        guard let socket,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { error in
            if let error {
                print("party ws send failed: \(error.localizedDescription)")
            }
        }
    }
}
