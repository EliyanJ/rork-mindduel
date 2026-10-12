import Foundation
import Observation
import SwiftUI

/// Real online 1v1 (ranked or free unranked): joins the matchmaking queue (HTTP polling),
/// then connects to the match room over WebSocket. The server drives the
/// rounds; both players derive the same questions from the shared seed.
@Observable
final class OnlineDuelSession {
    enum Phase: Equatable {
        case searching
        case found
        /// Both players pick one of four themes before the first question.
        case draft
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
    /// Bonus granted for a win (empty on a loss or draw).
    private(set) var winRewards: [Reward] = []
    private(set) var searchSeconds: Int = 0
    private(set) var isPreviewing: Bool = false
    private(set) var showScoreboard: Bool = false
    private(set) var lastPlayerAnswerText: String?
    private(set) var lastOpponentAnswerText: String?
    private(set) var leaderboardEntries: [QuizLeaderboardEntry] = []
    private(set) var answeredCount: Int = 0
    private(set) var wasFastestCorrect: Bool = false
    private(set) var floatingEmotes: [FloatingEmote] = []
    /// Theme draft: the four offered themes, the player's pick and the outcome.
    private(set) var draftThemes: [String] = []
    private(set) var draftEndsAt: Date?
    private(set) var myPick: String?
    private(set) var opponentPicked: Bool = false
    private(set) var opponentPick: String?
    private(set) var chosenThemes: [String] = []
    /// Set while the opponent's connection dropped: when their grace period ends.
    private(set) var opponentAwayUntil: Date?
    /// The player's own connection dropped and the app is trying to rejoin.
    private(set) var isReconnecting: Bool = false
    private var reconnectAttempts: Int = 0

    static let totalVoters: Int = 2
    static let readingBeat: Double = 4.5

    /// Seconds left to answer once the choices are visible.
    var answerWindow: Double { max(1, roundDuration - Self.readingBeat) }

    private var previousRanks: [String: Int] = [:]
    private var scoreboardTask: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var queueTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var leaveTask: Task<Void, Never>?
    private var roundStartedAt: Date?
    private var playerAnswerTime: Double?
    private var finishedHandled = false

    private let disciplineId: String?
    /// Ranked = Premium ladder match; unranked = free 1v1 that costs one duel bolt.
    let isRanked: Bool

    init(catalog: ContentCatalog, store: ProgressStore, online: OnlineModel, disciplineId: String? = nil, isRanked: Bool = true) {
        self.isRanked = isRanked
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

    /// Catalog entry for a drafted theme id (name, colour, illustration).
    func discipline(for id: String) -> Discipline? {
        catalog.disciplines.first { $0.id == id }
    }

    var opponent: PlayerProfile? { ticket?.opponent }
    var you: PlayerProfile? { ticket?.you }
    var playerHasAnswered: Bool { playerAnswer != nil }

    /// Human-readable theme readout for the leaderboard header — falls back
    /// to a generic label for mixed/unset theme tickets.
    var themeName: String {
        let ids = chosenThemes.isEmpty ? (ticket?.themes ?? []) : chosenThemes
        guard !ids.isEmpty, ids != ["all"] else { return "Tous thèmes" }
        let names = ids.compactMap { id in catalog.disciplines.first { $0.id == id }?.name }
        return names.isEmpty ? "Tous thèmes" : names.joined(separator: " · ")
    }

    var currentQuestion: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    // MARK: lifecycle

    /// Safe to call again after a lifecycle `cancel()` (SwiftUI can briefly
    /// tear the screen down while presentations settle): the search resumes,
    /// or the match socket reconnects, instead of surfacing an error.
    func start() {
        guard queueTask == nil else { return }
        if let ticket {
            guard socket == nil else { return }
            switch phase {
            case .found, .draft, .countdown, .question, .reveal:
                queueTask = Task { await reconnect(ticket: ticket) }
            default:
                break
            }
            return
        }
        guard phase == .searching else { return }
        Analytics.capture("duel_started", ["mode": "classe"])
        queueTask = Task { await runQueue() }
    }

    private func reconnect(ticket matchTicket: MatchTicket) async {
        defer { queueTask = nil }
        guard let token = await online.auth.validAccessToken() else { return }
        guard !Task.isCancelled else { return }
        openSocket(ticket: matchTicket, service: MultiplayerService(token: token))
    }

    private var isMatchActive: Bool {
        switch phase {
        case .found, .draft, .countdown, .question, .reveal: return true
        default: return false
        }
    }

    /// The server keeps the seat for 10 s: a few quick retries bring the
    /// player back into the same match.
    private func handleSocketDrop() {
        socket = nil
        guard isMatchActive, let ticket else { return }
        reconnectAttempts += 1
        guard reconnectAttempts <= 4 else {
            isReconnecting = false
            timerTask?.cancel()
            SoundManager.shared.stopAmbience()
            phase = .cancelled("Connexion perdue. Faute de reconnexion à temps, la partie revient à ton adversaire.")
            return
        }
        isReconnecting = true
        let delay = reconnectAttempts == 1 ? 0.6 : 2
        queueTask?.cancel()
        queueTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            await self.reconnect(ticket: ticket)
        }
    }


    /// Lifecycle cleanup is never reported as a voluntary forfeit.
    func cancel(voluntary: Bool = false) {
        queueTask?.cancel()
        queueTask = nil
        receiveTask?.cancel()
        timerTask?.cancel()
        scoreboardTask?.cancel()
        let closingSocket = socket
        socket = nil
        if voluntary, let closingSocket, phase == .question || phase == .reveal || phase == .countdown || phase == .draft {
            closingSocket.send(.string("{\"type\":\"leave\"}")) { _ in
                closingSocket.cancel(with: .normalClosure, reason: nil)
            }
        } else {
            closingSocket?.cancel(with: .goingAway, reason: nil)
        }
        guard ticket == nil else { return }
        leaveTask = Task { [online] in
            guard let token = await online.auth.validAccessToken() else { return }
            try? await MultiplayerService(token: token).leaveQueue()
        }
    }

    // MARK: matchmaking

    private func runQueue() async {
        guard let token = await online.auth.validAccessToken() else {
            phase = .failed("Connecte-toi pour jouer en ligne")
            return
        }
        let service = MultiplayerService(token: token)
        // A resumed search must not race the previous "leave" request.
        await leaveTask?.value
        leaveTask = nil
        do {
            try Task.checkCancellation()
            var status = try await service.joinQueue(disciplineId: disciplineId, ranked: isRanked)
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
        } catch let error as URLError where error.code == .cancelled {
            // Request torn down with the screen — not a real failure.
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(Self.friendlyMessage(for: error))
        }
    }

    static func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "Pas de connexion internet. Vérifie ton réseau et réessaie."
            case .timedOut:
                return "Le serveur met trop de temps à répondre. Réessaie."
            default:
                return "Connexion au serveur impossible. Réessaie dans un instant."
            }
        }
        return error.localizedDescription
    }

    private func beginMatch(ticket matchTicket: MatchTicket, service: MultiplayerService) async {
        ticket = matchTicket
        if isRanked {
            store.recordRankedStarted()
        } else {
            store.consumeDuelPoint()
        }
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
        openSocket(ticket: matchTicket, service: service)
    }

    private func openSocket(ticket matchTicket: MatchTicket, service: MultiplayerService) {
        do {
            let request = try service.matchSocketRequest(ticket: matchTicket)
            let task = URLSession.shared.webSocketTask(with: request)
            socket = task
            task.resume()
            receiveTask = Task { await receiveLoop(task) }
        } catch {
            phase = .failed(Self.friendlyMessage(for: error))
        }
    }

    // MARK: websocket

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                if isReconnecting {
                    isReconnecting = false
                    reconnectAttempts = 0
                }
                guard case .string(let text) = message,
                      let data = text.data(using: .utf8) else { continue }
                handleServerMessage(data)
            } catch {
                guard socket === task else { return }
                if !Task.isCancelled && phase != .finished {
                    if case .cancelled = phase { return }
                    if case .failed = phase { return }
                    handleSocketDrop()
                }
                return
            }
        }
    }

    private func handleServerMessage(_ data: Data) {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = raw["type"] as? String else { return }

        switch type {
        case "draft":
            handleDraft(raw)
        case "opponent_picked":
            withAnimation(.spring(duration: 0.4)) { opponentPicked = true }
        case "draft_result":
            handleDraftResult(raw)
        case "opponent_disconnected":
            let grace = (raw["graceMs"] as? Double ?? 10_000) / 1000
            withAnimation(.spring(duration: 0.4)) { opponentAwayUntil = Date().addingTimeInterval(grace) }
        case "opponent_reconnected":
            withAnimation(.spring(duration: 0.4)) { opponentAwayUntil = nil }
        case "start":
            if let payload = raw["questions"],
               let encoded = try? JSONSerialization.data(withJSONObject: payload),
               let authoritative = try? JSONDecoder().decode([Question].self, from: encoded),
               authoritative.count == ticket?.questionCount {
                questions = authoritative
            }
            if let themes = raw["themes"] as? [String], !themes.isEmpty {
                chosenThemes = themes
            }
            if raw["resumed"] as? Bool == true {
                if let scores = raw["scores"] as? [String: Int], let you, let opp = opponent {
                    playerScore = scores[you.id] ?? playerScore
                    opponentScore = scores[opp.id] ?? opponentScore
                }
                if phase != .question && phase != .reveal { phase = .reveal }
                return
            }
            phase = .countdown
            Haptics.medium()
            SoundManager.shared.startAmbience()
        case "round":
            guard let index = raw["index"] as? Int else { return }
            startRound(index: index, durationMs: raw["durationMs"] as? Double ?? roundDuration * 1000)
        case "opponent_answered":
            if (raw["index"] as? Int) == currentIndex {
                opponentHasAnswered = true
                answeredCount = (playerAnswer != nil ? 1 : 0) + 1
            }
        case "reveal":
            handleReveal(raw)
        case "finish":
            handleFinish(raw)
        case "cancelled":
            isReconnecting = false
            opponentAwayUntil = nil
            phase = .cancelled(raw["noResult"] as? Bool == true
                ? "Partie interrompue sans résultat. Aucun point perdu ni pénalité."
                : "Ton adversaire a quitté avant le début")
            timerTask?.cancel()
            showScoreboard = false
            SoundManager.shared.stopAmbience()
            SoundManager.shared.stopLeaderboardMusic()
            socket?.cancel(with: .goingAway, reason: nil)
        case "emote":
            if let raw = raw["emote"] as? String, let emote = QuizEmote(rawValue: raw) {
                pushFloatingEmote(FloatingEmote(senderName: ticket?.opponent.name ?? "Adversaire", emote: emote))
            }
        default:
            break
        }
    }

    // MARK: theme draft

    private func handleDraft(_ raw: [String: Any]) {
        guard let themes = raw["themes"] as? [String], !themes.isEmpty else { return }
        draftThemes = themes
        let duration = (raw["durationMs"] as? Double ?? 10_000) / 1000
        draftEndsAt = Date().addingTimeInterval(duration)
        if let picked = raw["picked"] as? String { myPick = picked }
        if phase != .draft {
            withAnimation(.spring(duration: 0.5)) { phase = .draft }
            Haptics.medium()
        }
    }

    /// Picks one of the four offered themes (once).
    func pick(_ themeId: String) {
        guard phase == .draft, myPick == nil, chosenThemes.isEmpty, draftThemes.contains(themeId) else { return }
        Haptics.medium()
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { myPick = themeId }
        send(["type": "pick", "theme": themeId])
    }

    private func handleDraftResult(_ raw: [String: Any]) {
        guard let themes = raw["themes"] as? [String] else { return }
        let picks = raw["picks"] as? [String: String] ?? [:]
        if let you { myPick = picks[you.id] ?? myPick }
        if let opp = opponent { opponentPick = picks[opp.id] }
        opponentPicked = true
        Haptics.success()
        withAnimation(.spring(duration: 0.6, bounce: 0.3)) { chosenThemes = themes }
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
        answeredCount = 0
        roundStartedAt = .now
        timeRemaining = durationMs / 1000
        phase = .question
        runLocalTimer(total: durationMs / 1000)

        // Cosmetic "read the question first" beat — the server's timer keeps
        // running underneath, so this stays purely a client-side reveal delay.
        isPreviewing = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.readingBeat))
            guard let self, self.currentIndex == index else { return }
            self.isPreviewing = false
        }
    }

    private func runLocalTimer(total: Double) {
        timerTask?.cancel()
        SoundManager.shared.resetTension()
        timerTask = Task {
            var elapsed: Double = 0
            while elapsed < total && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                elapsed += 0.05
                if phase == .question {
                    timeRemaining = max(0, total - elapsed)
                    if !isPreviewing {
                        SoundManager.shared.pulseTension(fraction: timeRemaining / total)
                    }
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
        answeredCount = (opponentHasAnswered ? 1 : 0) + 1
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
        lastPlayerAnswerText = mine?["answer"] as? String
        lastOpponentAnswerText = theirs?["answer"] as? String
        wasFastestCorrect = myCorrect && (playerAnswerTime ?? roundDuration) * 1000 < theirTimeMs

        // Snapshot the rank order before this round's points land, so the
        // leaderboard page can show who just overtook whom.
        previousRanks = [
            "you": playerScore >= opponentScore ? 1 : 2,
            "opp": opponentScore >= playerScore ? 1 : 2
        ]

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
            correct: myCorrect,
            responseTime: playerAnswerTime
        )
        // The server is authoritative on correctness here, so the telemetry uses
        // its verdict rather than re-deriving it on the client.
        AnswerTelemetry.shared.record(AnswerTelemetry.Event(
            questionId: question.id,
            correct: myCorrect,
            timeMs: Int((playerAnswerTime ?? roundDuration) * 1000),
            selected: playerAnswer,
            timedOut: playerAnswer == nil,
            disciplineId: questionDiscipline[question.id] ?? "",
            level: nil
        ))
        if myCorrect { Haptics.success(); SoundManager.shared.playCorrect() } else { Haptics.error(); SoundManager.shared.playWrong() }
        phase = .reveal
    }

    // MARK: - Emotes

    /// Broadcasts the player's own reaction to the opponent over the match
    /// socket, and displays anything the opponent sends back.
    func sendEmote(_ emote: QuizEmote) {
        pushFloatingEmote(FloatingEmote(senderName: "Toi", emote: emote))
        send(["type": "emote", "emote": emote.rawValue])
    }

    private func pushFloatingEmote(_ item: FloatingEmote) {
        floatingEmotes.append(item)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            self?.floatingEmotes.removeAll { $0.id == item.id }
        }
    }

    private func handleFinish(_ raw: [String: Any]) {
        opponentAwayUntil = nil
        isReconnecting = false
        if raw["noResult"] as? Bool == true {
            phase = .cancelled("Partie sans résultat. Aucun point perdu ni pénalité.")
            return
        }
        guard !finishedHandled, let you = ticket?.you, let opp = ticket?.opponent else {
            phase = .finished
            return
        }
        finishedHandled = true
        timerTask?.cancel()
        SoundManager.shared.stopAmbience()
        SoundManager.shared.stopLeaderboardMusic()
        // A ranked duel is shorter than one telemetry batch, so without an
        // explicit flush the whole match's answers would sit in memory and be
        // lost when the app is closed.
        AnswerTelemetry.shared.flush()

        if let scores = raw["scores"] as? [String: Int] {
            playerScore = scores[you.id] ?? playerScore
            opponentScore = scores[opp.id] ?? opponentScore
        }
        if isRanked, let changes = raw["eloChanges"] as? [String: Int] {
            eloChange = changes[you.id] ?? 0
        }
        if isRanked, let elos = raw["newElos"] as? [String: Int] {
            newElo = elos[you.id]
        }
        if let forfeitBy = raw["forfeitBy"] as? String, forfeitBy == opp.id {
            wonByForfeit = true
        }

        let won = wonByForfeit || playerScore > opponentScore
        let draw = !wonByForfeit && playerScore == opponentScore
        // Local stats & XP; ranked ELO lives on the server profile.
        store.finalizeDuel(won: won, draw: draw, score: playerScore, eloChange: 0)
        if isRanked {
            online.applyRankedResult(newElo: newElo, won: won, draw: draw)
        }
        if won {
            winRewards = store.grantDuelWin(xp: max(5, playerScore / 10), rankPoints: isRanked ? eloChange : nil)
            if online.friends.contains(where: { $0.id == opp.id }) { store.setBadgeFlag(.friendWin) }
        }
        if isRanked, let newElo, newElo >= RankLeague.maitre.range.lowerBound {
            store.setBadgeFlag(.masterLeague)
        }

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
