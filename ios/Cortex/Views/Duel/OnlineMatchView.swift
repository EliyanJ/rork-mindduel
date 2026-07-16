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
        .background(Theme.duelBackground)
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
                    .background(Circle().fill(Theme.duelCard))
            }
            VStack(spacing: 8) {
                Text(isFound ? "Adversaire trouvé !" : "Recherche mondiale…")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                if isFound, let opponent = session.opponent {
                    Text("\(opponent.name) · ELO \(opponent.elo)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.duelAccent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 4) {
                        Text("Matchmaking ELO avec de vrais joueurs")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        if session.searchSeconds > 3 {
                            Text("En attente depuis \(session.searchSeconds) s")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(.white.opacity(0.35))
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
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 24)
            }
        }
        .padding(20)
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
                .foregroundStyle(.white.opacity(0.6))
            Text("\(count)")
                .font(.system(size: 110, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.duelAccent)
                .id(count)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
        .animation(.spring(duration: 0.35), value: count)
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
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Retour", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                .padding(.bottom, 24)
        }
        .padding(20)
    }
}

private struct OnlineQuestionStage: View {
    let session: OnlineDuelSession

    private var isReveal: Bool { session.phase == .reveal }

    var body: some View {
        VStack(spacing: 16) {
            scoreHeader
            timerBar
            if let question = session.currentQuestion {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Question \(session.currentIndex + 1)/\(session.questions.count)")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(question.prompt)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(session.currentOptions, id: \.self) { option in
                            optionRow(option, question: question)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            statusBanner
        }
        .padding(16)
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
            Text("VS")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.35))
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
                    pointsChip(points)
                }
                Text(emoji).font(.system(size: 26))
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if alignment == .leading, isReveal, points > 0 {
                    pointsChip(points)
                }
            }
            Text("\(score)")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.5), value: score)
        }
    }

    private func pointsChip(_ points: Int) -> some View {
        Text("+\(points)")
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .foregroundStyle(Theme.duelBackground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.gold))
            .transition(.scale.combined(with: .opacity))
    }

    private var timerBar: some View {
        let fraction = session.timeRemaining / max(1, session.roundDuration)
        return HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.duelLine)
                    Capsule()
                        .fill(fraction < 0.3 ? Theme.danger : Theme.duelAccent)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
            Text("\(Int(session.timeRemaining.rounded(.up)))")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 26)
        }
    }

    private func optionRow(_ option: String, question: Question) -> some View {
        Button {
            session.answer(option)
        } label: {
            HStack {
                Text(option)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isReveal, option.comparisonKey == question.answer.comparisonKey {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                }
                if isReveal, option == session.playerAnswer, option.comparisonKey != question.answer.comparisonKey {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(rowFill(option, question: question)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(rowBorder(option, question: question), lineWidth: 2))
            .opacity(rowOpacity(option, question: question))
        }
        .buttonStyle(.plain)
        .disabled(session.playerHasAnswered || isReveal)
        .animation(.easeOut(duration: 0.15), value: session.playerAnswer)
    }

    private func rowFill(_ option: String, question: Question) -> Color {
        if isReveal, option.comparisonKey == question.answer.comparisonKey {
            return Theme.success.opacity(0.22)
        }
        if option == session.playerAnswer {
            return isReveal ? Theme.danger.opacity(0.18) : Theme.duelAccent.opacity(0.16)
        }
        return Theme.duelCard
    }

    private func rowBorder(_ option: String, question: Question) -> Color {
        if isReveal, option.comparisonKey == question.answer.comparisonKey {
            return Theme.success
        }
        if option == session.playerAnswer {
            return isReveal ? Theme.danger : Theme.duelAccent
        }
        return Theme.duelLine
    }

    private func rowOpacity(_ option: String, question: Question) -> Double {
        guard isReveal else { return 1 }
        let isCorrect = option.comparisonKey == question.answer.comparisonKey
        let isPicked = option == session.playerAnswer
        return (isCorrect || isPicked) ? 1 : 0.5
    }

    @ViewBuilder
    private var statusBanner: some View {
        let opponentName = session.opponent?.name ?? "Adversaire"
        let opponentEmoji = session.opponent?.emoji ?? "🎯"
        Group {
            if isReveal {
                Text(session.lastPlayerPoints > 0 ? "+\(session.lastPlayerPoints) points ! 🔥" : "Raté… la bonne réponse est en vert")
                    .foregroundStyle(session.lastPlayerPoints > 0 ? Theme.gold : .white.opacity(0.7))
            } else if session.playerHasAnswered {
                Text("Réponse verrouillée 🔒 En attente de \(opponentName)…")
                    .foregroundStyle(.white.opacity(0.7))
            } else if session.opponentHasAnswered {
                Text("\(opponentEmoji) \(opponentName) a répondu !")
                    .foregroundStyle(Theme.gold)
            } else {
                Text("\(opponentEmoji) \(opponentName) réfléchit…")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.duelCard))
        .animation(.easeOut(duration: 0.2), value: session.opponentHasAnswered)
        .animation(.easeOut(duration: 0.2), value: session.playerHasAnswered)
    }
}
