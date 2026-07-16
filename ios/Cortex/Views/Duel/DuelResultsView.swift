import SwiftUI

struct DuelResultsView: View {
    let session: DuelSession
    let onDone: () -> Void

    private var isWin: Bool { session.playerScore > session.botScore }
    private var isDraw: Bool { session.playerScore == session.botScore }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(isDraw ? "🤝" : (isWin ? "🏆" : "😤"))
                        .font(.system(size: 64))
                    Text(isDraw ? "Égalité !" : (isWin ? "Victoire !" : "Défaite"))
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.top, 24)

                scoreBoard
                rewardChips
                roundDetails
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

    private var scoreBoard: some View {
        HStack(spacing: 0) {
            scoreColumn(emoji: "🧠", name: "Toi", score: session.playerScore, highlighted: isWin || isDraw)
            Text("—")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.3))
            scoreColumn(
                emoji: session.opponent.emoji,
                name: session.opponent.name,
                score: session.botScore,
                highlighted: !isWin || isDraw
            )
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.duelCard))
    }

    private func scoreColumn(emoji: String, name: String, score: Int, highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 32))
            Text(name)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
            Text("\(score)")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(highlighted ? Theme.duelAccent : .white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var rewardChips: some View {
        HStack(spacing: 10) {
            rewardChip(
                icon: "chart.line.uptrend.xyaxis",
                text: session.eloChange >= 0 ? "ELO +\(session.eloChange)" : "ELO \(session.eloChange)",
                color: session.eloChange >= 0 ? Theme.success : Theme.danger
            )
            rewardChip(icon: "bolt.fill", text: "+\(max(5, session.playerScore / 10)) XP", color: Theme.gold)
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

    private var roundDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Détail des questions")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
            ForEach(Array(session.results.enumerated()), id: \.element.id) { index, result in
                roundRow(index: index, result: result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roundRow(index: Int, result: DuelSession.RoundResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(index + 1). \(result.question.prompt)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                answerBadge(
                    label: "Toi",
                    correct: result.playerCorrect,
                    points: result.playerPoints,
                    time: result.playerTime
                )
                answerBadge(
                    label: session.opponent.name,
                    correct: result.botCorrect,
                    points: result.botPoints,
                    time: result.botTime
                )
            }
            Text("Réponse : \(result.question.answer)")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent)
            Text(result.question.explanation)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.duelCard))
    }

    private func answerBadge(label: String, correct: Bool, points: Int, time: Double?) -> some View {
        HStack(spacing: 5) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(correct ? Theme.success : Theme.danger)
            Text("\(label) +\(points)")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))
            if let time {
                Text(String(format: "%.1f s", time))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.duelBackground))
    }
}
