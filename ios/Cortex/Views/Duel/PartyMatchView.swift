import SwiftUI

/// In-game screen for a party match: question, 10s timer, reveal, a top-5
/// leaderboard every 2 questions, and the "surge" callout for a big scorer
/// still outside the top 5. Hands off to `PartyResultsView` on finish.
struct PartyMatchView: View {
    let session: PartySession
    let mode: PartyMode
    let onExit: () -> Void

    private var isReveal: Bool { session.phase == .reveal }

    var body: some View {
        ZStack {
            switch session.phase {
            case .question, .reveal:
                questionBody
            case .finished:
                PartyResultsView(session: session, mode: mode, onDone: onExit)
            default:
                ProgressView().tint(Theme.duelAccent)
            }

            if let surge = session.surge {
                surgeBanner(surge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .sheet(isPresented: Binding(
            get: { session.showLeaderboard },
            set: { _ in }
        )) {
            QuizLeaderboardOverlay(
                entries: session.topBoard.map {
                    QuizLeaderboardEntry(id: $0.id, name: $0.name, emoji: $0.emoji, score: $0.score, isYou: $0.isYou)
                },
                title: "Classement"
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .animation(.spring(duration: 0.35), value: session.surge)
    }

    private var questionBody: some View {
        VStack(spacing: 16) {
            scoreHeader
            if let question = session.currentQuestion {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Manche \(session.currentRound + 1)/3 · Question \(session.currentQuestionInRound + 1)/20")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInkMuted)
                    Text(question.prompt)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if session.isPreviewing {
                    QuestionRevealBeat()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(session.currentOptions.enumerated()), id: \.element) { index, option in
                                KahootOptionButton(
                                    index: index,
                                    text: option,
                                    isCorrect: option.comparisonKey == question.answer.comparisonKey,
                                    isPicked: option == session.playerAnswer,
                                    isReveal: isReveal,
                                    isDisabled: session.playerAnswer != nil || isReveal
                                ) {
                                    session.answer(option)
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            statusBanner
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.quizBackground)
        .animation(.spring(duration: 0.4), value: session.isPreviewing)
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.you?.emoji ?? "🧠")
                    .font(.system(size: 24))
                Text("\(session.myScore) pts")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.duelAccent)
                    .contentTransition(.numericText())
                Text(mode.isTeam ? "Équipe \(session.you?.team ?? "—")" : "#\(session.myRank) / 20")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInkMuted)
            }
            Spacer()
            if !session.isPreviewing {
                QuizTimerRing(remaining: session.timeRemaining, total: max(1, session.roundDuration))
            }
            Spacer()
            if mode.isTeam, let teamScores = session.teamScores {
                HStack(spacing: 16) {
                    teamPill(label: "A", score: teamScores.a, isMine: session.you?.team == "A")
                    teamPill(label: "B", score: teamScores.b, isMine: session.you?.team == "B")
                }
            } else if isReveal, session.lastPlayerPoints > 0 {
                Text("+\(session.lastPlayerPoints)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.gold)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func teamPill(label: String, score: Int, isMine: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(isMine ? Theme.duelAccent : Theme.quizInkMuted)
            Text("\(score)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isMine ? Theme.duelAccent.opacity(0.14) : Theme.quizCanvas))
    }

    @ViewBuilder
    private var statusBanner: some View {
        Group {
            if session.isPreviewing {
                Text("La réponse va bientôt s'ouvrir…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else if isReveal {
                Text(session.lastPlayerPoints > 0 ? "+\(session.lastPlayerPoints) points ! 🔥" : "Raté… la bonne réponse est en vert")
                    .foregroundStyle(session.lastPlayerPoints > 0 ? Theme.primary : Theme.quizInkMuted)
            } else if session.playerAnswer != nil {
                Text("Réponse verrouillée 🔒 En attente des autres joueurs…")
                    .foregroundStyle(Theme.quizInkMuted)
            } else {
                Text("À toi de jouer !")
                    .foregroundStyle(Theme.quizInkMuted)
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.quizCanvas))
    }

    private func surgeBanner(_ surge: PartySession.Surge) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.primary)
                Text("\(surge.name) va gagner \(surge.points) points !")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.quizCard))
            .overlay(Capsule().stroke(Theme.gold.opacity(0.6), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .padding(.top, 8)
            Spacer()
        }
    }
}
