import SwiftUI

/// Dedicated explanation page for ranked Duel mode: how matchmaking works,
/// how ELO moves, and how the world leaderboard is computed. Content moved
/// here from the old `rulesCard` that used to sit directly on `DuelHomeView`.
struct DuelHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Le mode Duel classé te fait affronter de vrais joueurs du monde entier sur les mêmes questions, en même temps.")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    helpSection(
                        icon: "globe",
                        color: Theme.duelAccent.mix(with: .black, by: 0.2),
                        title: "Matchmaking ELO",
                        text: "Un match classé t'oppose à un vrai joueur de niveau proche du tien (même ELO), pour un duel équilibré. Vous recevez tous les deux les mêmes questions, au même moment."
                    )
                    helpSection(
                        icon: "hare.fill",
                        color: Theme.gold.mix(with: .black, by: 0.1),
                        title: "Vitesse et score",
                        text: "Une bonne réponse rapide vaut un jackpot de points. Une bonne réponse lente en vaut moins. Une erreur vaut 0 point, sans pénalité supplémentaire."
                    )
                    helpSection(
                        icon: "chart.line.uptrend.xyaxis",
                        color: Theme.success,
                        title: "Ton ELO mondial",
                        text: "Chaque match classé fait monter ou descendre ton ELO mondial selon le résultat et le niveau de ton adversaire. Abandonner un match compte comme une défaite."
                    )
                    helpSection(
                        icon: "trophy.fill",
                        color: Theme.gold,
                        title: "Le classement mondial",
                        text: "Le classement mondial trie tous les joueurs par ELO décroissant. Il se met à jour après chaque match classé — le top 3 est visible directement sur l'écran Duel."
                    )
                    helpSection(
                        icon: "person.2.fill",
                        color: Theme.primary,
                        title: "Jouer entre amis",
                        text: "Ajoute des amis avec leur code ami pour suivre leur ELO et vous comparer, depuis l'écran Amis accessible sur l'écran Duel."
                    )
                }
                .padding(18)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("Comment ça marche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }

    private func helpSection(icon: String, color: Color, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(color)
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5))
    }
}
