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
                ProgressView().tint(.white)
            }

            if let surge = session.surge {
                surgeBanner(surge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.duelBackground)
        .sheet(isPresented: Binding(
            get: { session.showLeaderboard },
            set: { _ in }
        )) {
            LeaderboardOverlay(session: session, mode: mode)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .animation(.spring(duration: 0.35), value: session.surge)
    }

    private var questionBody: some View {
        VStack(spacing: 16) {
            scoreHeader
            timerBar
            if let question = session.currentQuestion {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Manche \(session.currentRound + 1)/3 · Question \(session.currentQuestionInRound + 1)/20")
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
            VStack(alignment: .leading, spacing: 2) {
                Text(session.you?.emoji ?? "🧠")
                    .font(.system(size: 24))
                Text("\(session.myScore) pts")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.duelAccent)
                    .contentTransition(.numericText())
                Text(mode.isTeam ? "Équipe \(session.you?.team ?? "—")" : "#\(session.myRank) / 20")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.5))
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
                .foregroundStyle(isMine ? Theme.duelAccent : .white.opacity(0.5))
            Text("\(score)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isMine ? Theme.duelAccent.opacity(0.16) : Theme.duelCard))
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
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                }
                if isReveal, option == session.playerAnswer, option.comparisonKey != question.answer.comparisonKey {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(rowFill(option, question: question)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(rowBorder(option, question: question), lineWidth: 2))
            .opacity(rowOpacity(option, question: question))
        }
        .buttonStyle(.plain)
        .disabled(session.playerAnswer != nil || isReveal)
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
        if isReveal, option.comparisonKey == question.answer.comparisonKey { return Theme.success }
        if option == session.playerAnswer { return isReveal ? Theme.danger : Theme.duelAccent }
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
            } else if session.playerAnswer != nil {
                Text("Réponse verrouillée 🔒 En attente des autres joueurs…")
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("À toi de jouer !")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.duelCard))
    }

    private func surgeBanner(_ surge: PartySession.Surge) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.gold)
                Text("\(surge.name) va gagner \(surge.points) points !")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.duelCard))
            .overlay(Capsule().stroke(Theme.gold.opacity(0.6), lineWidth: 1.5))
            .padding(.top, 8)
            Spacer()
        }
    }
}

/// Top-5 sheet shown every 2 questions — individual ranking even in 10v10,
/// where it sits alongside (not instead of) the cumulative team score.
private struct LeaderboardOverlay: View {
    let session: PartySession
    let mode: PartyMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Classement")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
            VStack(spacing: 10) {
                ForEach(Array(session.topBoard.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        Text(rankLabel(index + 1))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .frame(width: 30)
                        Text(entry.emoji).font(.system(size: 20))
                        Text(entry.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(entry.isYou ? Theme.primary : Theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.score)")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(entry.isYou ? Theme.primary.opacity(0.08) : Theme.card))
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .background(Theme.background)
        .task {
            try? await Task.sleep(for: .seconds(2.2))
            dismiss()
        }
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
