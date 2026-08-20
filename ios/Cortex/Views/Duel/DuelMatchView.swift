import SwiftUI

struct DuelMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: DuelSession

    init(catalog: ContentCatalog, store: ProgressStore, disciplineId: String? = nil) {
        _session = State(initialValue: DuelSession(catalog: catalog, store: store, disciplineId: disciplineId))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .matchmaking, .found:
                MatchmakingStage(session: session) { dismiss() }
            case .countdown(let count):
                countdownStage(count)
            case .preview, .question, .reveal:
                DuelQuestionStage(session: session)
            case .finished:
                DuelResultsView(session: session) { dismiss() }
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

    private func countdownStage(_ count: Int) -> some View {
        VStack(spacing: 16) {
            Text("Prêt ?")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.quizInkMuted)
            CountdownDigits(value: count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
    }
}

private struct MatchmakingStage: View {
    let session: DuelSession
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
                Text(isFound ? session.opponent.emoji : "🧠")
                    .font(.system(size: 56))
                    .frame(width: 110, height: 110)
                    .background(Circle().fill(Theme.quizCanvas))
            }
            VStack(spacing: 8) {
                Text(isFound ? "Adversaire trouvé !" : "Recherche d'un adversaire…")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                if isFound {
                    Text("\(session.opponent.name) · ELO \(session.opponent.elo)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.duelAccent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Matchmaking basé sur ton ELO")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.quizInkMuted)
                }
            }
            .animation(.spring(duration: 0.4), value: isFound)
            Spacer()
            if !isFound {
                Button("Annuler") {
                    onCancel()
                }
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

private struct DuelQuestionStage: View {
    let session: DuelSession

    private var isReveal: Bool { session.phase == .reveal }
    private var isPreview: Bool { session.phase == .preview }

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
                    QuestionRevealBeat(duration: DuelSession.readingBeat)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if isReveal {
                                QuestionVoteBars(options: session.currentOptions, counts: session.voteCounts, correctAnswer: question.answer)
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
            voteCounter
            statusBanner
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.quizBackground)
        .animation(.spring(duration: 0.4), value: isPreview)
    }

    private var scoreHeader: some View {
        HStack {
            playerBadge(emoji: "🧠", name: "Toi", score: session.playerScore, points: session.lastPlayerPoints, alignment: .leading)
            Spacer()
            if !isPreview {
                QuizTimerRing(remaining: session.timeRemaining, total: DuelSession.roundDuration)
            } else {
                Text("VS")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInkMuted)
            }
            Spacer()
            playerBadge(
                emoji: session.opponent.emoji,
                name: session.opponent.name,
                score: session.botScore,
                points: session.lastBotPoints,
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

    @ViewBuilder
    private var statusBanner: some View {
        Group {
            if isPreview {
                Text("La réponse va bientôt s'ouvrir…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else if isReveal {
                Text(session.lastPlayerPoints > 0 ? "+\(session.lastPlayerPoints) points ! 🔥" : "Raté… la bonne réponse est en vert")
                    .foregroundStyle(session.lastPlayerPoints > 0 ? Theme.primary : Theme.quizInkMuted)
            } else if session.playerHasAnswered {
                Text("Réponse verrouillée 🔒 En attente de \(session.opponent.name)…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else if session.botHasAnswered {
                Text("\(session.opponent.emoji) \(session.opponent.name) a répondu !")
                    .foregroundStyle(Theme.primary)
            } else {
                Text("\(session.opponent.emoji) \(session.opponent.name) réfléchit…")
                    .foregroundStyle(Theme.quizInkMuted)
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.quizCanvas))
        .animation(.easeOut(duration: 0.2), value: session.botHasAnswered)
        .animation(.easeOut(duration: 0.2), value: session.playerHasAnswered)
    }

    @ViewBuilder
    private var voteCounter: some View {
        if !isPreview, !isReveal {
            LiveVoteCounter(answered: session.answeredCount, total: DuelSession.totalVoters)
        }
    }
}
