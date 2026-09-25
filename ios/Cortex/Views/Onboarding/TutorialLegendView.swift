import SwiftUI

/// Handoff screen after nickname and goals are confirmed; stats are supplied by the game.
struct TutorialLegendView: View {
    let name: String
    let level: Int
    let xp: Int
    let nextLevelXP: Int
    let gamesPlayed: Int
    let goals: [String]
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TutorialScreenStyle.eyebrow("Ton aventure commence")
                Image("MascotCheer")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .accessibilityHidden(true)
                TutorialScreenStyle.heading("À toi d’écrire\nla suite, \(name) !")
                VStack(alignment: .leading, spacing: 18) {
                    Label("Niveau \(level)", systemImage: "star.fill")
                        .foregroundStyle(Theme.primary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(xp) / \(nextLevelXP) XP")
                        ProgressView(value: Double(xp), total: Double(max(1, nextLevelXP)))
                            .tint(Theme.primary)
                    }
                    Label("\(gamesPlayed) parties jouées", systemImage: "gamecontroller.fill")
                    Label(goals.isEmpty ? "Objectifs à découvrir" : "Objectifs : \(goals.joined(separator: " · "))", systemImage: "scope")
                }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(.white, in: .rect(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1) }
                Text("Une partie après l’autre, ta légende grandit.")
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                Button("Commencer mon aventure", action: onContinue)
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background { TutorialScreenStyle.backdrop() }
    }
}

#Preview {
    TutorialLegendView(name: "Alex", level: 1, xp: 0, nextLevelXP: 100, gamesPlayed: 0, goals: ["Standard", "Sniper"], onContinue: {})
}
