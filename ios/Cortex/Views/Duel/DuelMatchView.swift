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
            case .question, .reveal:
                DuelQuestionStage(session: session)
            case .finished:
                DuelResultsView(session: session) { dismiss() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.duelBackground)
        .task { session.start() }
        .onDisappear { session.cancel() }
    }

    private func countdownStage(_ count: Int) -> some View {
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
                    .background(Circle().fill(Theme.duelCard))
            }
            VStack(spacing: 8) {
                Text(isFound ? "Adversaire trouvé !" : "Recherche d'un adversaire…")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                if isFound {
                    Text("\(session.opponent.name) · ELO \(session.opponent.elo)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.duelAccent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Matchmaking basé sur ton ELO")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .animation(.spring(duration: 0.4), value: isFound)
            Spacer()
            if !isFound {
                Button("Annuler") {
                    onCancel()
                }
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

private struct DuelQuestionStage: View {
    let session: DuelSession

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
            playerBadge(emoji: "🧠", name: "Toi", score: session.playerScore, points: session.lastPlayerPoints, alignment: .leading)
            Spacer()
            Text("VS")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.35))
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
                    pointsChip(points)
                }
                Text(emoji).font(.system(size: 26))
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
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
        let fraction = session.timeRemaining / DuelSession.roundDuration
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
        Group {
            if isReveal {
                Text(session.lastPlayerPoints > 0 ? "+\(session.lastPlayerPoints) points ! 🔥" : "Raté… la bonne réponse est en vert")
                    .foregroundStyle(session.lastPlayerPoints > 0 ? Theme.gold : .white.opacity(0.7))
            } else if session.playerHasAnswered {
                Text("Réponse verrouillée 🔒 En attente de \(session.opponent.name)…")
                    .foregroundStyle(.white.opacity(0.7))
            } else if session.botHasAnswered {
                Text("\(session.opponent.emoji) \(session.opponent.name) a répondu !")
                    .foregroundStyle(Theme.gold)
            } else {
                Text("\(session.opponent.emoji) \(session.opponent.name) réfléchit…")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.duelCard))
        .animation(.easeOut(duration: 0.2), value: session.botHasAnswered)
        .animation(.easeOut(duration: 0.2), value: session.playerHasAnswered)
    }
}
