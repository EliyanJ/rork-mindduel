import SwiftUI

/// Full-screen ranked match flow: queue → found → countdown → rounds → results.
struct OnlineMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: OnlineDuelSession

    init(catalog: ContentCatalog, store: ProgressStore, online: OnlineModel, disciplineId: String? = nil) {
        _session = State(initialValue: OnlineDuelSession(catalog: catalog, store: store, online: online, disciplineId: disciplineId))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .searching, .found:
                OnlineSearchStage(session: session) {
                    session.cancel()
                    dismiss()
                }
            case .countdown:
                OnlineCountdownStage()
            case .question, .reveal:
                OnlineQuestionStage(session: session)
            case .finished:
                OnlineResultsView(session: session) {
                    session.cancel()
                    dismiss()
                }
            case .cancelled(let reason), .failed(let reason):
                OnlineErrorStage(message: reason) {
                    session.cancel()
                    dismiss()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .overlay {
            if session.showScoreboard {
                QuizLeaderboardOverlay(
                    entries: session.leaderboardEntries,
                    subtitle: "Question \(session.currentIndex + 1)/\(session.questions.count)",
                    autoDismissAfter: nil,
                    onDismiss: nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: session.showScoreboard)
        .task { session.start() }
        .onDisappear { session.cancel() }
    }
}

private struct OnlineSearchStage: View {
    let session: OnlineDuelSession
    let onCancel: () -> Void

    @State private var isPulsing: Bool = false

    private var isFound: Bool { session.phase == .found }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Theme.duelAccent.opacity(0.3), lineWidth: 3)
                    .frame(width: 200, height: 200)
                    .scaleEffect(isPulsing ? 1.12 : 0.9)
                    .opacity(isPulsing ? 0.2 : 0.8)
                Circle()
                    .stroke(Theme.duelAccent.opacity(0.5), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(isPulsing ? 1.06 : 0.94)
                Text(isFound ? (session.opponent?.emoji ?? "🎯") : "🌍")
                    .font(.system(size: 56))
                    .frame(width: 110, height: 110)
                    .background(Circle().fill(Theme.quizCanvas))
            }
            VStack(spacing: 8) {
                Text(isFound ? "Adversaire trouvé !" : "Recherche mondiale…")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                if isFound, let opponent = session.opponent {
                    Text("\(opponent.name) · ELO \(opponent.elo)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.duelAccent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 4) {
                        Text("Matchmaking ELO avec de vrais joueurs")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.quizInkMuted)
                        if session.searchSeconds > 3 {
                            Text("En attente depuis \(session.searchSeconds) s")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.quizInkMuted.opacity(0.7))
                                .contentTransition(.numericText())
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.4), value: isFound)
            Spacer()
            if !isFound {
                Button("Annuler", action: onCancel)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.quizInkMuted)
                    .padding(.bottom, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct OnlineCountdownStage: View {
    @State private var count: Int = 3

    var body: some View {
        VStack(spacing: 16) {
            Text("Prêt ?")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.quizInkMuted)
            CountdownDigits(value: count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .task {
            for value in [2, 1] {
                try? await Task.sleep(for: .seconds(1))
                count = value
            }
        }
    }
}

private struct OnlineErrorStage: View {
    let message: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("😕")
                .font(.system(size: 60))
            Text(message)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Retour", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
                .padding(.bottom, 24)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
    }
}

private struct OnlineQuestionStage: View {
    let session: OnlineDuelSession

    private var isReveal: Bool { session.phase == .reveal }
    private var isPreview: Bool { session.isPreviewing }

    var body: some View {
        VStack(spacing: 16) {
            scoreHeader
            if let question = session.currentQuestion {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Question \(session.currentIndex + 1)/\(session.questions.count)")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInkMuted)
                    Text(question.prompt)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isPreview {
                    QuestionRevealBeat(duration: OnlineDuelSession.readingBeat)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if isReveal {
                                QuestionVoteBars(
                                    options: session.currentOptions,
                                    counts: voteCounts(question: question),
                                    correctAnswer: question.answer
                                )
                            }
                            VStack(spacing: 10) {
                                ForEach(Array(session.currentOptions.enumerated()), id: \.element) { index, option in
                                    KahootOptionButton(
                                        index: index,
                                        text: option,
                                        isCorrect: option.comparisonKey == question.answer.comparisonKey,
                                        isPicked: option == session.playerAnswer,
                                        isReveal: isReveal,
                                        isDisabled: session.playerHasAnswered || isReveal
                                    ) {
                                        session.answer(option)
                                    }
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            if !isPreview, !isReveal {
                LiveVoteCounter(answered: session.answeredCount, total: OnlineDuelSession.totalVoters)
            }
            statusBanner
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.quizBackground)
        .animation(.spring(duration: 0.4), value: isPreview)
    }

    private var scoreHeader: some View {
        HStack {
            playerBadge(
                emoji: session.you?.emoji ?? "🧠",
                name: "Toi",
                score: session.playerScore,
                points: session.lastPlayerPoints,
                alignment: .leading
            )
            Spacer()
            if !isPreview {
                QuizTimerRing(remaining: session.timeRemaining, total: max(1, session.roundDuration))
            } else {
                Text("VS")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInkMuted)
            }
            Spacer()
            playerBadge(
                emoji: session.opponent?.emoji ?? "🎯",
                name: session.opponent?.name ?? "Adversaire",
                score: session.opponentScore,
                points: session.lastOpponentPoints,
                alignment: .trailing
            )
        }
    }

    private func playerBadge(emoji: String, name: String, score: Int, points: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            HStack(spacing: 6) {
                if alignment == .trailing, isReveal, points > 0 {
                    AnimatedPointsBadge(points: points)
                }
                Text(emoji).font(.system(size: 26))
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                    .lineLimit(1)
                if alignment == .leading, isReveal, points > 0 {
                    AnimatedPointsBadge(points: points)
                }
            }
            Text("\(score)")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.5), value: score)
        }
    }

    /// The server only tells each client its own answer text plus the
    /// opponent's — exact for a 1v1, unlike the bigger party rooms.
    private func voteCounts(question: Question) -> [Int] {
        session.currentOptions.map { option in
            let mine = session.lastPlayerAnswerText == option ? 1 : 0
            let theirs = session.lastOpponentAnswerText == option ? 1 : 0
            return mine + theirs
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        let opponentName = session.opponent?.name ?? "Adversaire"
        let opponentEmoji = session.opponent?.emoji ?? "🎯"
        Group {
            if isPreview {
                Text("La réponse va bientôt s'ouvrir…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else if isReveal {
                Text(session.lastPlayerPoints > 0 ? "+\(session.lastPlayerPoints) points ! 🔥" : "Raté… la bonne réponse est en vert")
                    .foregroundStyle(session.lastPlayerPoints > 0 ? Theme.primary : Theme.quizInkMuted)
            } else if session.playerHasAnswered {
                Text("Réponse verrouillée 🔒 En attente de \(opponentName)…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else if session.opponentHasAnswered {
                Text("\(opponentEmoji) \(opponentName) a répondu !")
                    .foregroundStyle(Theme.primary)
            } else {
                Text("\(opponentEmoji) \(opponentName) réfléchit…")
                    .foregroundStyle(Theme.quizInkMuted)
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.quizCanvas))
        .animation(.easeOut(duration: 0.2), value: session.opponentHasAnswered)
        .animation(.easeOut(duration: 0.2), value: session.playerHasAnswered)
    }
}
