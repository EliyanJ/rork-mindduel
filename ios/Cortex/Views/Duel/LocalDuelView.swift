import SwiftUI
import MultipeerConnectivity

/// Local network duel: real device discovery over Multipeer, a lobby that
/// visually fills as nearby players connect (same look as the online
/// lobbies), then everyone plays the exact same seeded question set on
/// their own device and compares scores at the end. No account needed.
struct LocalDuelView: View {
    let catalog: ContentCatalog
    let store: ProgressStore
    let displayName: String
    let displayEmoji: String
    let onExit: () -> Void

    @State private var service: LocalMultiplayerService?
    @State private var phase: Phase = .lobby
    @State private var questions: [Question] = []
    @State private var roundDuration: Double = 6
    @State private var myScore = 0

    private enum Phase: Equatable {
        case lobby
        case playing
        case waitingForOthers
        case finished
    }

    var body: some View {
        ZStack {
            Theme.duelBackground.ignoresSafeArea()
            if let service {
                content(service)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            let s = LocalMultiplayerService(displayName: displayName, emoji: displayEmoji)
            service = s
            s.startDiscovery()
        }
        .onDisappear { service?.disconnect() }
    }

    @ViewBuilder
    private func content(_ service: LocalMultiplayerService) -> some View {
        switch phase {
        case .lobby:
            LocalLobbyBody(service: service, onExit: onExit) { prepare(with: service) }
        case .playing:
            LocalQuizBody(questions: questions, roundDuration: roundDuration) { score in
                myScore = score
                service.reportFinished(score: score)
                phase = .waitingForOthers
            }
        case .waitingForOthers:
            LocalWaitingBody(myScore: myScore)
                .onChange(of: service.finalScores?.count ?? -1) { _, _ in
                    if service.finalScores != nil { phase = .finished }
                }
        case .finished:
            LocalResultsBody(
                scores: service.finalScores ?? [displayName: myScore],
                myName: displayName,
                onDone: onExit
            )
        }
    }

    private func prepare(with service: LocalMultiplayerService) {
        let seed = UUID().uuidString
        let count = 15
        let duration: Double = 6
        service.broadcastStart(seed: seed, questionCount: count, roundDuration: duration)
        startPlaying(seed: seed, count: count, duration: duration)
    }

    private func startPlaying(seed: String, count: Int, duration: Double) {
        questions = MatchQuestionPicker.questions(
            from: catalog,
            seed: seed,
            count: count,
            themes: ["all"],
            averageElo: store.progress.elo
        )
        roundDuration = duration
        phase = .playing
    }
}

// MARK: - Lobby

private struct LocalLobbyBody: View {
    let service: LocalMultiplayerService
    let onExit: () -> Void
    let onPrepare: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button {
                    Haptics.tap()
                    onExit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Text("Duel local")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Recherche d'appareils sur le même réseau…")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text("\(service.connectedPeers.count + 1) connecté\(service.connectedPeers.count > 0 ? "s" : "")")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                avatarSlot(emoji: service.myEmoji, name: "Toi")
                ForEach(service.connectedPeers, id: \.self) { peer in
                    avatarSlot(emoji: "🎮", name: String(peer.displayName.split(separator: "#").first ?? "Ami"))
                }
                ForEach(0..<max(0, 7 - service.connectedPeers.count), id: \.self) { _ in
                    Circle()
                        .fill(Theme.duelCard.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Theme.duelLine, lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Button("Préparer", action: onPrepare)
                    .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                    .disabled(service.connectedPeers.isEmpty)
                    .opacity(service.connectedPeers.isEmpty ? 0.5 : 1)
                Text(service.connectedPeers.isEmpty ? "Ouvrez Minduel sur un autre appareil à proximité" : "Tout le monde jouera le même quiz en simultané")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .animation(.spring(duration: 0.3), value: service.connectedPeers.count)
        .onChange(of: service.startPayload != nil) { _, started in
            if started { onPrepare() }
        }
    }

    private func avatarSlot(emoji: String, name: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.duelCard))
                .overlay(Circle().stroke(Theme.duelAccent.opacity(0.5), lineWidth: 1.5))
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Quiz (independent per device, same seed)

private struct LocalQuizBody: View {
    let questions: [Question]
    let roundDuration: Double
    let onFinished: (Int) -> Void

    @State private var currentIndex = 0
    @State private var currentOptions: [String] = []
    @State private var playerAnswer: String?
    @State private var timeRemaining: Double
    @State private var score = 0
    @State private var lastGain = 0
    @State private var roundStartedAt: Date = .now

    init(questions: [Question], roundDuration: Double, onFinished: @escaping (Int) -> Void) {
        self.questions = questions
        self.roundDuration = roundDuration
        self.onFinished = onFinished
        _timeRemaining = State(initialValue: roundDuration)
    }

    private var question: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(score) pts")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.duelAccent)
                    .contentTransition(.numericText())
                Spacer()
                Text("Question \(currentIndex + 1)/\(questions.count)")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.5))
            }
            GeometryReader { geo in
                let fraction = timeRemaining / roundDuration
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.duelLine)
                    Capsule()
                        .fill(fraction < 0.3 ? Theme.danger : Theme.duelAccent)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 10)

            if let question {
                Text(question.prompt)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 10) {
                    ForEach(currentOptions, id: \.self) { option in
                        optionRow(option, question: question)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .task { setupQuestion() }
    }

    private func setupQuestion() {
        guard let question else {
            onFinished(score)
            return
        }
        currentOptions = question.type == .trueFalse ? ["Vrai", "Faux"] : (question.options ?? []).shuffled()
        playerAnswer = nil
        lastGain = 0
        timeRemaining = roundDuration
        roundStartedAt = .now
        Task {
            var elapsed: Double = 0
            while elapsed < roundDuration && playerAnswer == nil {
                try? await Task.sleep(for: .milliseconds(50))
                elapsed += 0.05
                timeRemaining = max(0, roundDuration - elapsed)
            }
            if playerAnswer == nil { advance() }
        }
    }

    private func optionRow(_ option: String, question: Question) -> some View {
        let isRevealing = playerAnswer != nil
        let isCorrect = option.comparisonKey == question.answer.comparisonKey
        let isPicked = option == playerAnswer
        return Button {
            answer(option, question: question)
        } label: {
            HStack {
                Text(option)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                if isRevealing, isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(isRevealing && isCorrect ? Theme.success.opacity(0.22) : (isPicked ? Theme.duelAccent.opacity(0.16) : Theme.duelCard)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isRevealing && isCorrect ? Theme.success : (isPicked ? Theme.duelAccent : Theme.duelLine), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(isRevealing)
    }

    private func answer(_ option: String, question: Question) {
        guard playerAnswer == nil else { return }
        playerAnswer = option
        let elapsed = Date().timeIntervalSince(roundStartedAt)
        let correct = option.comparisonKey == question.answer.comparisonKey
        let fraction = 1 - min(elapsed, roundDuration) / roundDuration
        let gain = correct ? 100 + Int((fraction * 100).rounded()) : 0
        lastGain = gain
        score += gain
        Haptics.tap()
        advance()
    }

    private func advance() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            currentIndex += 1
            setupQuestion()
        }
    }
}

private struct LocalWaitingBody: View {
    let myScore: Int

    var body: some View {
        VStack(spacing: 18) {
            ProgressView().tint(.white)
            Text("Ton score : \(myScore) pts")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent)
            Text("En attente des autres joueurs…")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct LocalResultsBody: View {
    let scores: [String: Int]
    let myName: String
    let onDone: () -> Void

    private var ranked: [(name: String, score: Int)] {
        scores.map { (name: $0.key, score: $0.value) }.sorted { $0.score > $1.score }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(ranked.first?.name == myName ? "🏆" : "🎉")
                        .font(.system(size: 64))
                    Text("Partie terminée")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(ranked.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(index == 0 ? Theme.gold : .white.opacity(0.5))
                                .frame(width: 34, alignment: .leading)
                            Text(displayName(entry.name))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(entry.name == myName ? Theme.duelAccent : .white.opacity(0.85))
                            Spacer()
                            Text("\(entry.score) pts")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(entry.name == myName ? Theme.duelAccent.opacity(0.12) : Theme.duelCard))
                    }
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Terminer", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.duelBackground.opacity(0.95))
        }
        .background(Theme.duelBackground)
    }

    private func displayName(_ raw: String) -> String {
        raw == myName ? "Toi" : String(raw.split(separator: "#").first ?? Substring(raw))
    }
}
