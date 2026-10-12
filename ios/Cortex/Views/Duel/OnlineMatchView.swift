import SwiftUI

/// Full-screen online 1v1 flow (ranked or unranked): queue → found → countdown → rounds → results.
struct OnlineMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: OnlineDuelSession

    init(catalog: ContentCatalog, store: ProgressStore, online: OnlineModel, disciplineId: String? = nil, isRanked: Bool = true) {
        _session = State(initialValue: OnlineDuelSession(catalog: catalog, store: store, online: online, disciplineId: disciplineId, isRanked: isRanked))
    }

    var body: some View {
        Group {
            switch session.phase {
            case .searching, .found:
                OnlineSearchStage(session: session, onCancel: {
                    session.cancel(voluntary: true)
                    dismiss()
                })
            case .draft:
                OnlineDraftStage(session: session)
                    .transition(.opacity)
            case .countdown:
                OnlineCountdownStage()
            case .question, .reveal:
                OnlineQuestionStage(session: session)
            case .finished:
                OnlineResultsView(session: session) {
                    session.cancel(voluntary: true)
                    dismiss()
                }
            case .cancelled(let reason), .failed(let reason):
                OnlineErrorStage(message: reason) {
                    session.cancel(voluntary: true)
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
                    roundLabel: "Question \(session.currentIndex + 1)/\(session.questions.count)",
                    themeLabel: session.themeName,
                    autoDismissAfter: nil,
                    onDismiss: nil,
                    onReact: { emote in session.sendEmote(emote) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            FloatingEmoteOverlay(items: session.floatingEmotes)
                .padding(.trailing, 12)
                .padding(.bottom, 140)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            ConnectionBanner(awayUntil: session.opponentAwayUntil, isReconnecting: session.isReconnecting, opponentName: session.opponent?.name ?? "Ton adversaire")
                .padding(.top, 6)
                .padding(.horizontal, 16)
        }
        .animation(.spring(duration: 0.6), value: session.showScoreboard)
        .animation(.spring(duration: 0.4), value: session.opponentAwayUntil)
        .animation(.spring(duration: 0.4), value: session.isReconnecting)
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
                        Text(session.isRanked ? "Match classé" : "Partie non classée")
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
    @State private var isEmotePickerPresented = false
    @Environment(AvatarStore.self) private var avatarStore: AvatarStore?

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
        .animation(.spring(duration: 0.7), value: isPreview)
        .overlay(alignment: .trailing) {
            if session.playerHasAnswered, !isReveal {
                EmoteTriggerButton { isEmotePickerPresented = true }
                    .padding(.trailing, 6)
            }
        }
        .sheet(isPresented: $isEmotePickerPresented) {
            EmotePickerSheet { emote in session.sendEmote(emote) }
        }
    }

    private var scoreHeader: some View {
        HStack {
            playerBadge(
                emoji: session.you?.emoji ?? "🧠",
                avatar: avatarStore?.config,
                name: "Toi",
                score: session.playerScore,
                points: session.lastPlayerPoints,
                alignment: .leading
            )
            Spacer()
            if !isPreview {
                QuizTimerRing(remaining: min(session.timeRemaining, session.answerWindow), total: session.answerWindow)
            } else {
                Text("VS")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInkMuted)
            }
            Spacer()
            playerBadge(
                emoji: session.opponent?.emoji ?? "🎯",
                avatar: nil,
                name: session.opponent?.name ?? "Adversaire",
                score: session.opponentScore,
                points: session.lastOpponentPoints,
                alignment: .trailing
            )
        }
    }

    private func playerBadge(emoji: String, avatar: AvatarConfig?, name: String, score: Int, points: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            HStack(spacing: 6) {
                if alignment == .trailing, isReveal, points > 0 {
                    AnimatedPointsBadge(points: points)
                }
                if let avatar {
                    AvatarView(config: avatar, size: 30)
                } else {
                    Text(emoji).font(.system(size: 26))
                }
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                    .lineLimit(1)
                if alignment == .leading, isReveal, points > 0 {
                    AnimatedPointsBadge(points: points)
                }
            }
            if alignment == .leading, isReveal, session.wasFastestCorrect {
                FastestAnswerBadge()
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

/// Top banner while a connection is down: the opponent's 10 s reconnection
/// countdown, or the player's own reconnection attempt.
private struct ConnectionBanner: View {
    let awayUntil: Date?
    let isReconnecting: Bool
    let opponentName: String

    var body: some View {
        Group {
            if isReconnecting {
                banner(icon: "wifi.exclamationmark", text: "Reconnexion en cours…", color: Theme.kahootYellow)
            } else if let awayUntil {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let seconds = Int(ceil(max(0, awayUntil.timeIntervalSince(context.date))))
                    banner(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        text: seconds > 0
                            ? "\(opponentName) s'est déconnecté… \(seconds) s pour revenir"
                            : "\(opponentName) n'est pas revenu…",
                        color: Theme.danger
                    )
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .lineLimit(2)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            if isReconnecting { ProgressView().tint(.white) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.gradient))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}
