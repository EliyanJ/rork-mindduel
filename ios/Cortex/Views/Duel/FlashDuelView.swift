import SwiftUI

/// "Flash" mode: answer as many different questions as fast as possible to
/// rack up points. Fully local (no matchmaking needed) — the visual lobby
/// fills with a handful of rival avatars for atmosphere, then it is a solo
/// race against the clock, ranked against those rivals' simulated scores.
struct FlashDuelView: View {
    let catalog: ContentCatalog
    let store: ProgressStore
    let isTeamFlavor: Bool
    let onExit: () -> Void

    @State private var session: FlashSession?

    private var capacity: Int { isTeamFlavor ? 4 : 8 }

    var body: some View {
        ZStack {
            Theme.duelBackground.ignoresSafeArea()
            if let session {
                content(session)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            let s = FlashSession(catalog: catalog, store: store, capacity: capacity)
            session = s
        }
    }

    @ViewBuilder
    private func content(_ session: FlashSession) -> some View {
        switch session.phase {
        case .filling:
            FlashLobbyBody(session: session, isTeamFlavor: isTeamFlavor, onExit: onExit)
        case .countdown:
            FlashCountdownBody(session: session)
        case .question:
            FlashQuestionBody(session: session)
        case .finished:
            FlashResultsBody(session: session, isTeamFlavor: isTeamFlavor, onDone: onExit)
        }
    }
}

// MARK: - Session

@Observable
private final class FlashSession {
    enum Phase: Equatable {
        case filling
        case countdown
        case question
        case finished
    }

    struct Rival: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
    }

    struct FinalEntry: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let score: Int
        let isYou: Bool
    }

    static let questionCount = 18
    static let roundDuration: Double = 4

    let capacity: Int
    private(set) var phase: Phase = .filling
    private(set) var rivals: [Rival] = []
    private(set) var countdown = 3
    private(set) var questions: [Question] = []
    private(set) var currentIndex = 0
    private(set) var currentOptions: [String] = []
    private(set) var playerAnswer: String?
    private(set) var timeRemaining: Double = FlashSession.roundDuration
    private(set) var score = 0
    private(set) var lastGain = 0
    private(set) var finalEntries: [FinalEntry] = []

    private let store: ProgressStore
    private let questionDiscipline: [String: String]
    private var timerTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var roundStartedAt: Date?

    var currentQuestion: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    init(catalog: ContentCatalog, store: ProgressStore, capacity: Int) {
        self.store = store
        self.capacity = capacity
        var map: [String: String] = [:]
        for discipline in catalog.disciplines {
            for chapter in discipline.chapters {
                for question in chapter.allQuestions {
                    map[question.id] = discipline.id
                }
            }
        }
        self.questionDiscipline = map
        self.questions = MatchQuestionPicker.questions(
            from: catalog,
            seed: UUID().uuidString,
            count: Self.questionCount,
            themes: ["all"],
            averageElo: store.progress.elo
        )
        fillLobby()
    }

    private func fillLobby() {
        Task { [weak self] in
            guard let self else { return }
            for _ in 0..<(capacity - 1) {
                try? await Task.sleep(for: .milliseconds(.random(in: 220...420)))
                await MainActor.run {
                    self.rivals.append(Rival(name: Self.randomName(), emoji: Self.randomEmoji()))
                }
            }
        }
    }

    func prepare() {
        guard phase == .filling else { return }
        phase = .countdown
        Haptics.medium()
        Task { [weak self] in
            guard let self else { return }
            for value in stride(from: 3, through: 1, by: -1) {
                await MainActor.run { withAnimation(.spring(duration: 0.3)) { self.countdown = value } }
                Haptics.tap()
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { self.startQuestion(0) }
        }
    }

    private func startQuestion(_ index: Int) {
        guard questions.indices.contains(index) else {
            finish()
            return
        }
        currentIndex = index
        let question = questions[index]
        currentOptions = question.type == .trueFalse ? ["Vrai", "Faux"] : (question.options ?? []).shuffled()
        playerAnswer = nil
        lastGain = 0
        timeRemaining = Self.roundDuration
        roundStartedAt = .now
        phase = .question
        runTimer()
    }

    private func runTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            var elapsed: Double = 0
            while elapsed < Self.roundDuration && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                elapsed += 0.05
                await MainActor.run {
                    guard self.phase == .question else { return }
                    self.timeRemaining = max(0, Self.roundDuration - elapsed)
                }
                if elapsed >= Self.roundDuration {
                    await MainActor.run { self.timeout() }
                }
            }
        }
    }

    private func timeout() {
        guard phase == .question, playerAnswer == nil else { return }
        playerAnswer = ""
        advanceSoon()
    }

    func answer(_ option: String) {
        guard phase == .question, playerAnswer == nil, let question = currentQuestion else { return }
        playerAnswer = option
        timerTask?.cancel()
        let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.roundDuration
        let correct = option.comparisonKey == question.answer.comparisonKey
        let fraction = 1 - min(elapsed, Self.roundDuration) / Self.roundDuration
        let gain = correct ? 100 + Int((fraction * 100).rounded()) : 0
        lastGain = gain
        score += gain
        Haptics.tap()
        store.recordAnswer(
            questionId: question.id,
            disciplineId: questionDiscipline[question.id] ?? "",
            correct: correct
        )
        if correct { Haptics.success() } else { Haptics.error() }
        advanceSoon()
    }

    private func advanceSoon() {
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run {
                guard let self else { return }
                self.startQuestion(self.currentIndex + 1)
            }
        }
    }

    private func finish() {
        timerTask?.cancel()
        revealTask?.cancel()
        var entries = rivals.map { rival in
            FinalEntry(name: rival.name, emoji: rival.emoji, score: simulatedRivalScore(), isYou: false)
        }
        entries.append(FinalEntry(name: "Toi", emoji: "🧠", score: score, isYou: true))
        finalEntries = entries.sorted { $0.score > $1.score }
        phase = .finished
        store.registerRankedDuelPlayed()
        if finalEntries.first?.isYou == true { Haptics.success() }
    }

    /// Rivals score somewhere around the player's own performance, so the
    /// result always feels close and earned rather than arbitrary.
    private func simulatedRivalScore() -> Int {
        let base = max(score, 400)
        let jitter = Double.random(in: 0.55...1.25)
        return max(0, Int(Double(base) * jitter))
    }

    private static func randomName() -> String {
        let names = ["Léa", "Hugo", "Emma", "Nolan", "Chloé", "Liam", "Zoé", "Adam", "Lina", "Noah", "Mila", "Sacha"]
        return names.randomElement() ?? "Joueur"
    }

    private static func randomEmoji() -> String {
        ["🦊", "🦉", "🐼", "🐸", "🐨", "🐯", "🦁", "🐙", "🦄", "🐺"].randomElement() ?? "🧠"
    }
}

// MARK: - Lobby

private struct FlashLobbyBody: View {
    let session: FlashSession
    let isTeamFlavor: Bool
    let onExit: () -> Void

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
                Text(isTeamFlavor ? "Flash 2 vs 2" : "Flash")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Réponds le plus vite possible !")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text("\(session.rivals.count + 1) / \(session.capacity)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                avatarSlot(emoji: "🧠", name: "Toi", filled: true)
                ForEach(0..<(session.capacity - 1), id: \.self) { index in
                    if index < session.rivals.count {
                        avatarSlot(emoji: session.rivals[index].emoji, name: session.rivals[index].name, filled: true)
                    } else {
                        avatarSlot(emoji: "", name: "", filled: false)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 8)

            Button("Préparer") {
                session.prepare()
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .disabled(session.rivals.count < session.capacity - 1)
            .opacity(session.rivals.count < session.capacity - 1 ? 0.5 : 1)
        }
        .animation(.spring(duration: 0.3), value: session.rivals.count)
    }

    private func avatarSlot(emoji: String, name: String, filled: Bool) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Circle().fill(filled ? Theme.duelCard : Theme.duelCard.opacity(0.4)))
                .overlay(Circle().stroke(filled ? Theme.duelAccent.opacity(0.5) : Theme.duelLine, lineWidth: filled ? 1.5 : 1))
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct FlashCountdownBody: View {
    let session: FlashSession

    var body: some View {
        VStack(spacing: 12) {
            Text("La partie commence")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(session.countdown)")
                .font(.system(size: 90, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())
                .id(session.countdown)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Question

private struct FlashQuestionBody: View {
    let session: FlashSession

    private var isRevealing: Bool { session.playerAnswer != nil }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session.score) pts")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.duelAccent)
                        .contentTransition(.numericText())
                    Text("Question \(session.currentIndex + 1)/\(FlashSession.questionCount)")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if isRevealing, session.lastGain > 0 {
                    Text("+\(session.lastGain)")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.gold)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            GeometryReader { geo in
                let fraction = session.timeRemaining / FlashSession.roundDuration
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.duelLine)
                    Capsule()
                        .fill(fraction < 0.3 ? Theme.danger : Theme.duelAccent)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 10)

            if let question = session.currentQuestion {
                Text(question.prompt)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(session.currentOptions, id: \.self) { option in
                        optionRow(option, question: question)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .animation(.easeOut(duration: 0.15), value: session.currentIndex)
    }

    private func optionRow(_ option: String, question: Question) -> some View {
        let isCorrect = option.comparisonKey == question.answer.comparisonKey
        let isPicked = option == session.playerAnswer
        return Button {
            session.answer(option)
        } label: {
            HStack {
                Text(option)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isRevealing, isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                }
                if isRevealing, isPicked, !isCorrect {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isRevealing && isCorrect ? Theme.success.opacity(0.22) : (isPicked ? Theme.duelAccent.opacity(0.16) : Theme.duelCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isRevealing && isCorrect ? Theme.success : (isPicked ? Theme.duelAccent : Theme.duelLine), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRevealing)
    }
}

// MARK: - Results

private struct FlashResultsBody: View {
    let session: FlashSession
    let isTeamFlavor: Bool
    let onDone: () -> Void

    private var myRank: Int {
        (session.finalEntries.firstIndex { $0.isYou } ?? 0) + 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(myRank == 1 ? "🏆" : "⚡️")
                        .font(.system(size: 64))
                    Text(myRank == 1 ? "Tu es le plus rapide !" : "Partie terminée")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("\(session.score) points marqués")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.duelAccent)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Classement")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                    ForEach(Array(session.finalEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            Text(rankLabel(index + 1))
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .frame(width: 34, alignment: .leading)
                                .foregroundStyle(index < 3 ? Theme.gold : .white.opacity(0.5))
                            Text(entry.emoji).font(.system(size: 20))
                            Text(entry.name)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(entry.isYou ? Theme.duelAccent : .white.opacity(0.85))
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.score) pts")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(entry.isYou ? Theme.duelAccent.opacity(0.12) : Theme.duelCard))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
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

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}
