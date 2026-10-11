import SwiftUI

/// "Plus d'énergie" panel: the player is missing hearts. They can buy one
/// heart or a full refill with diamonds, watch a rewarded ad for one heart,
/// or leave. Used as a sheet before a lesson starts and as a blocking
/// overlay mid-lesson.
struct EnergyRefillView: View {
    let progressStore: ProgressStore
    /// Label of the secondary dismissal action ("Fermer" / "Arrêter la leçon").
    let quitTitle: String
    let onQuit: () -> Void
    /// Called after hearts were bought (nil: the host hides itself, e.g. mid-lesson).
    var onRefilled: (() -> Void)?
    /// "Voir mes missions" from the missing-diamonds sheet.
    let onOpenMissions: () -> Void

    @State private var isWatchingAd = false
    @State private var missingCost: Int?

    private var missingHearts: Int { max(0, ProgressStore.energyMax - progressStore.energy) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)
            Image(systemName: "heart.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.danger)

            VStack(spacing: 8) {
                Text(progressStore.energy == 0 ? "Plus d'énergie !" : "Recharge tes cœurs")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Tu as \(ProgressStore.energyMax) cœurs par jour. Recharge-les avec des diamants, regarde une pub, ou reviens demain : ils reviennent à minuit.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DiamondBalance(amount: progressStore.livresBalance)

            VStack(spacing: 12) {
                if missingHearts > 0 {
                    Button {
                        buy(cost: ProgressStore.heartCost) { progressStore.buyHeart() }
                    } label: {
                        Label("+1 cœur — \(ProgressStore.heartCost) 💎", systemImage: "heart.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.livres))

                    if missingHearts == ProgressStore.energyMax {
                        Button {
                            buy(cost: ProgressStore.energyRefillCost) { progressStore.refillEnergyWithRubis() }
                        } label: {
                            Label("Recharger tout — \(ProgressStore.energyRefillCost) 💎", systemImage: "diamond.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.livres.mix(with: .black, by: 0.15)))
                    }
                }

                if progressStore.canWatchRewardedAd() && missingHearts > 0 {
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
        .sheet(item: Binding(
            get: { missingCost.map(MissingHeartCost.init) },
            set: { missingCost = $0?.cost }
        )) { item in
            InsufficientDiamondsSheet(cost: item.cost, progressStore: progressStore, onOpenMissions: onOpenMissions)
        }
        .alert("Erreur", isPresented: .init(
            get: { AdsManager.shared.lastError != nil && missingCost == nil },
            set: { if !$0 { AdsManager.shared.lastError = nil } }
        )) {
            Button("OK") { AdsManager.shared.lastError = nil }
        } message: {
            Text(AdsManager.shared.lastError ?? "")
        }
    }

    private func buy(cost: Int, perform: () -> Bool) {
        Haptics.medium()
        guard progressStore.livresBalance >= cost else {
            Haptics.error()
            missingCost = cost
            return
        }
        if perform() {
            Haptics.success()
            onRefilled?()
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

private struct MissingHeartCost: Identifiable {
    let cost: Int
    var id: Int { cost }
}
