import SwiftUI

/// "Plus d'énergie" panel: the player has run out of hearts. They can refill
/// fully with rubis, watch a rewarded ad for one heart, or leave the lesson.
/// Used as a sheet before a lesson starts and as a blocking overlay mid-lesson.
struct EnergyRefillView: View {
    let progressStore: ProgressStore
    /// Label of the secondary dismissal action ("Fermer" / "Arrêter la leçon").
    let quitTitle: String
    let onQuit: () -> Void

    @State private var isWatchingAd = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)
            Image(systemName: "heart.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.danger)

            VStack(spacing: 8) {
                Text("Plus d'énergie !")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Tes cœurs sont vides. Recharge-les avec des rubis ou regarde une pub pour continuer.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Solde : \(progressStore.livresBalance) ♦️")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.livres)

            VStack(spacing: 12) {
                Button {
                    Haptics.medium()
                    if progressStore.refillEnergyWithRubis() {
                        Haptics.success()
                        onQuit()
                    }
                } label: {
                    Label("Recharger tout — \(ProgressStore.energyRefillCost) ♦️", systemImage: "bolt.heart.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.livres))
                .disabled(progressStore.livresBalance < ProgressStore.energyRefillCost)
                .opacity(progressStore.livresBalance < ProgressStore.energyRefillCost ? 0.5 : 1)

                if progressStore.canWatchRewardedAd() {
                    Button {
                        Haptics.medium()
                        watchAd()
                    } label: {
                        if isWatchingAd {
                            ProgressView().tint(.white)
                        } else {
                            Label("Regarder une pub (+1 ❤️)", systemImage: "play.rectangle.fill")
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                    .disabled(isWatchingAd)
                }
            }

            Button(quitTitle) {
                Haptics.tap()
                onQuit()
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.inkMuted)
            .padding(.vertical, 4)
        }
        .padding(24)
        .alert("Erreur", isPresented: .init(
            get: { AdsManager.shared.lastError != nil },
            set: { if !$0 { AdsManager.shared.lastError = nil } }
        )) {
            Button("OK") { AdsManager.shared.lastError = nil }
        } message: {
            Text(AdsManager.shared.lastError ?? "")
        }
    }

    private func watchAd() {
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            if rewarded {
                progressStore.grantEnergyFromAd()
                Haptics.success()
            }
        }
    }
}
