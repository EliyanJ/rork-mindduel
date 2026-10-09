import SwiftUI

/// Free-tier duel points: shows the remaining points, lets the player refill
/// all of them with one rewarded video, or upgrade to unlimited duels.
struct DuelPointsSheet: View {
    let progressStore: ProgressStore
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWatchingAd: Bool = false
    @State private var justRefilled: Bool = false

    private var points: Int { progressStore.duelPoints }
    private var maxPoints: Int { ProgressStore.duelPointsMax }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ForEach(0..<maxPoints, id: \.self) { index in
                    let isFull = index < points
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(isFull ? .white : Theme.inkMuted.opacity(0.4))
                        .frame(width: 58, height: 58)
                        .background(
                            Circle().fill(isFull ? Theme.duelAccent : Theme.lockedFill.opacity(0.6))
                        )
                        .scaleEffect(justRefilled && isFull ? 1.08 : 1)
                        .animation(.spring(duration: 0.35, bounce: 0.5).delay(Double(index) * 0.08), value: justRefilled)
                }
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(points == 0 ? "Plus de points de duel" : "\(points) point\(points > 1 ? "s" : "") de duel")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Chaque duel coûte 1 point. Regarde une vidéo pour recharger tes \(maxPoints) points d'un coup.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                if points < maxPoints {
                    Button {
                        Haptics.medium()
                        watchAd()
                    } label: {
                        if isWatchingAd {
                            ProgressView().tint(Theme.duelBackground)
                        } else {
                            Label("Regarder une vidéo (+\(maxPoints) ⚡)", systemImage: "play.rectangle.fill")
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
            progressStore.refillDuelPoints()
            Analytics.capture("duel_points_refilled")
            Haptics.success()
            justRefilled = true
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                dismiss()
            }
        }
    }
}
