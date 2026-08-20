import SwiftUI

/// Shared "quota reached" screen: explains the daily free lesson limit,
/// offers to spend rubis or watch a rewarded ad to top up the balance.
struct UnlockWithLivresView: View {
    enum Kind {
        case lesson

        var title: String { "Leçon du jour terminée" }
        var message: String { "Tu as utilisé ta leçon gratuite d'aujourd'hui. Débloque-en une de plus avec des rubis, ou reviens demain." }
        var cost: Int { ProgressStore.extraLessonCost }
        var unlockLabel: String { "Débloquer cette leçon" }
    }

    let kind: Kind
    let progressStore: ProgressStore
    let onUnlocked: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWatchingAd = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)
                Text("♦️")
                    .font(.system(size: 56))
                VStack(spacing: 8) {
                    Text(kind.title)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text(kind.message)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)

                Text("Solde : \(progressStore.livresBalance) ♦️")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.livres)

                Spacer(minLength: 4)

                VStack(spacing: 12) {
                    Button {
                        Haptics.medium()
                        unlock()
                    } label: {
                        Label("\(kind.unlockLabel) — \(kind.cost) ♦️", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.livres))
                    .disabled(progressStore.livresBalance < kind.cost)
                    .opacity(progressStore.livresBalance < kind.cost ? 0.5 : 1)

                    rewardedAdButton
                }
                .padding(.bottom, 8)
            }
            .padding(24)
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Erreur", isPresented: .init(
                get: { AdsManager.shared.lastError != nil },
                set: { if !$0 { AdsManager.shared.lastError = nil } }
            )) {
                Button("OK") { AdsManager.shared.lastError = nil }
            } message: {
                Text(AdsManager.shared.lastError ?? "")
            }
        }
    }

    @ViewBuilder
    private var rewardedAdButton: some View {
        let remaining = progressStore.rewardedAdsRemainingToday
        if remaining > 0 {
            Button {
                Haptics.medium()
                watchAd()
            } label: {
                if isWatchingAd {
                    ProgressView().tint(.white)
                } else {
                    Label("Regarder une pub (+\(ProgressStore.rewardedAdLivres) ♦️)", systemImage: "play.rectangle.fill")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
            .disabled(isWatchingAd)
        } else {
            Text("Pubs épuisées pour aujourd'hui — reviens demain")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.lockedFill))
        }
    }

    private func unlock() {
        let ok = progressStore.unlockExtraLesson()
        if ok {
            Haptics.success()
            dismiss()
            onUnlocked()
        }
    }

    private func watchAd() {
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            if rewarded {
                progressStore.creditRewardedAd()
                Haptics.success()
            }
        }
    }
}
