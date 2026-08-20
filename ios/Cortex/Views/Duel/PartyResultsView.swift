import SwiftUI

/// End-of-game screen — two distinct layouts sharing one entry point:
/// cumulative team score for 10 vs 10, podium + full ranking for 1 vs 19.
struct PartyResultsView: View {
    let session: PartySession
    let mode: PartyMode
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                if mode.isTeam {
                    teamScoreBoard
                    contributionList
                } else {
                    podium
                    remainingRanking
                }
                rewardChips
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Terminer", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.quizBackground.opacity(0.95))
        }
        .background(Theme.quizBackground)
    }

    private var didWin: Bool {
        mode.isTeam
            ? (session.winningTeam != nil && session.winningTeam == session.you?.team)
            : session.finalEntries.first { $0.isYou }.map { $0.rank <= 3 } ?? false
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(didWin ? "🏆" : "🎉")
                .font(.system(size: 64))
            Text(mode.isTeam ? (session.winningTeam == nil ? "Égalité !" : (didWin ? "Équipe victorieuse !" : "Équipe adverse gagnante")) : "Partie terminée")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: 10 vs 10

    private var teamScoreBoard: some View {
        HStack(spacing: 0) {
            teamColumn(label: "Équipe A", score: session.teamScores?.a ?? 0, isMine: session.you?.team == "A", isWinner: session.winningTeam == "A")
            Text("VS")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
            teamColumn(label: "Équipe B", score: session.teamScores?.b ?? 0, isMine: session.you?.team == "B", isWinner: session.winningTeam == "B")
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.quizCanvas))
    }

    private func teamColumn(label: String, score: Int, isMine: Bool, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            if isWinner {
                Text("GAGNANTE")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.gold.mix(with: .black, by: 0.15))
            }
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isMine ? Theme.duelAccent : Theme.quizInkMuted)
            Text("\(score)")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(isWinner ? Theme.duelAccent : Theme.quizInkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var contributionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribution de chacun")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
            ForEach(session.finalEntries) { entry in
                contributionRow(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contributionRow(_ entry: PartySession.FinalEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.team == "A" ? "🔵" : "🔴")
                .font(.system(size: 14))
            Text(entry.name)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(entry.isYou ? Theme.primary : Theme.quizInk)
                .lineLimit(1)
            Spacer()
            Text("\(entry.score) pts")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.quizCanvas))
    }

    // MARK: 1 vs 19

    private var podium: some View {
        let top3 = Array(session.finalEntries.prefix(3))
        return HStack(alignment: .bottom, spacing: 10) {
            if top3.count > 1 { podiumColumn(top3[1], height: 90) }
            if top3.count > 0 { podiumColumn(top3[0], height: 120) }
            if top3.count > 2 { podiumColumn(top3[2], height: 70) }
        }
        .padding(.top, 8)
    }

    private func podiumColumn(_ entry: PartySession.FinalEntry, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(entry.emoji).font(.system(size: 28))
            Text(entry.name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(entry.isYou ? Theme.primary : Theme.quizInk)
                .lineLimit(1)
            Text("\(entry.score)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
            RoundedRectangle(cornerRadius: 10)
                .fill(podiumColor(entry.rank))
                .frame(height: height)
                .overlay(Text(medal(entry.rank)).font(.system(size: 22)).padding(.top, 8), alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.gold
        case 2: return Color(hex: "C0C0C0")
        default: return Color(hex: "B08D57")
        }
    }

    private func medal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }

    private var remainingRanking: some View {
        let rest = session.finalEntries.filter { $0.rank > 3 }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Classement complet")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
            ForEach(rest) { entry in
                HStack(spacing: 12) {
                    Text("#\(entry.rank)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInkMuted)
                        .frame(width: 34, alignment: .leading)
                    Text(entry.emoji).font(.system(size: 18))
                    Text(entry.name)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.isYou ? Theme.primary : Theme.quizInk)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.score) pts")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.quizInkMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(entry.isYou ? Theme.primary.opacity(0.08) : Theme.quizCanvas))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: shared reward chips

    private var rewardChips: some View {
        HStack(spacing: 10) {
            rewardChip(
                icon: "chart.line.uptrend.xyaxis",
                text: session.pointsDelta >= 0 ? "Points +\(session.pointsDelta)" : "Points \(session.pointsDelta)",
                color: session.pointsDelta >= 0 ? Theme.success : Theme.danger
            )
            rewardChip(
                icon: "heart.fill",
                text: session.reputationDelta >= 0 ? "Réputation +\(session.reputationDelta)" : "Réputation \(session.reputationDelta)",
                color: Theme.gold
            )
        }
    }

    private func rewardChip(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
