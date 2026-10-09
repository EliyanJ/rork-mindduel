import SwiftUI

/// Free-tier duel bolts: shows how many are left, lets the player earn 2
/// more per rewarded video, or upgrade to unlimited duels.
struct DuelPointsSheet: View {
    let progressStore: ProgressStore
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWatchingAd: Bool = false
    @State private var justRefilled: Bool = false

    private var points: Int { progressStore.duelPoints }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(points > 0 ? Theme.duelBackground : Theme.inkMuted)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(points > 0 ? Theme.duelAccent : Theme.lockedFill))
                    .symbolEffect(.bounce, value: justRefilled)
                Text("\(points)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(points > 0 ? Theme.duelAccent : Theme.inkMuted)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .animation(.spring(duration: 0.4, bounce: 0.4), value: points)
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(points == 0 ? "Plus d'éclairs de duel" : "\(points) éclair\(points > 1 ? "s" : "") de duel")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Chaque duel coûte 1 éclair. Une vidéo = \(ProgressStore.duelPointsPerAd) éclairs, soit \(ProgressStore.duelPointsPerAd) duels de plus.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                if progressStore.canWatchRewardedAd() {
                    Button {
                        Haptics.medium()
                        watchAd()
                    } label: {
                        if isWatchingAd {
                            ProgressView().tint(Theme.duelBackground)
                        } else {
                            Label("Regarder une vidéo (+\(ProgressStore.duelPointsPerAd) éclairs)", systemImage: "play.rectangle.fill")
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
                    .disabled(isWatchingAd)
                }

                Button {
                    Haptics.tap()
                    onUpgrade()
                } label: {
                    Label("Duels illimités avec Premium", systemImage: "crown.fill")
                }
                .buttonStyle(ChunkyButtonStyle())
            }
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
            guard rewarded else { return }
            progressStore.grantDuelPointsFromAd()
            Analytics.capture("duel_points_refilled", ["amount": ProgressStore.duelPointsPerAd])
            Haptics.success()
            justRefilled = true
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                dismiss()
            }
        }
    }
}
