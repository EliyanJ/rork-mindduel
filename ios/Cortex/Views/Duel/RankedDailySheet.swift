import SwiftUI

/// Free-tier ranked gate: explains the "one ranked match per day" rule.
/// With today's match available it lets the player start it; once spent it
/// points to the unranked modes (refillable with videos) or Premium.
struct RankedDailySheet: View {
    let remaining: Int
    let onPlay: () -> Void
    let onPlayUnranked: () -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appeared: Bool = false

    private var isAvailable: Bool { remaining > 0 }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isAvailable ? Color(hex: "1CC9BC").opacity(0.18) : Theme.lockedFill)
                    .frame(width: 104, height: 104)
                    .scaleEffect(appeared ? 1 : 0.6)
                Image(systemName: isAvailable ? "trophy.fill" : "moon.zzz.fill")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(isAvailable ? Theme.gold : Theme.inkMuted)
                    .symbolEffect(.bounce, value: appeared)
            }
            .padding(.top, 10)

            VStack(spacing: 8) {
                Text(isAvailable ? "Ta partie classée du jour" : "Partie classée déjà jouée")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(isAvailable
                     ? "En gratuit, tu as droit à 1 partie classée par jour. Elle fait monter ou descendre ta ligue. Elle ne se recharge pas avec les vidéos."
                     : "En gratuit, c'est 1 partie classée par jour. Reviens demain, ou joue en non classé : là, tu peux recharger tes éclairs à l'infini avec des vidéos.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                Text("\(remaining)/\(ProgressStore.freeRankedPerDay) aujourd'hui")
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(isAvailable ? Color(hex: "0E9F95") : Theme.inkMuted)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Capsule().stroke(Theme.line, lineWidth: 2))

            VStack(spacing: 12) {
                if isAvailable {
                    Button {
                        Haptics.medium()
                        onPlay()
                    } label: {
                        Text("JOUER MA PARTIE CLASSÉE")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Color(hex: "1CC9BC"), textColor: .white))
                } else {
                    Button {
                        Haptics.medium()
                        onPlayUnranked()
                    } label: {
                        Text("JOUER EN NON CLASSÉ")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                }

                Button {
                    Haptics.tap()
                    onUpgrade()
                } label: {
                    Label("Classé illimité avec Premium", systemImage: "crown.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.card, textColor: Theme.ink))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
