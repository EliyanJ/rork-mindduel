import SwiftUI

/// "Il te manque X 💎": shown whenever the player taps something they can't
/// afford. Offers a +2 video, the daily missions, or Premium. Closes by
/// itself as soon as the balance covers the price.
struct InsufficientDiamondsSheet: View {
    /// Price of the item the player wanted.
    let cost: Int
    let progressStore: ProgressStore
    let onOpenMissions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreViewModel.self) private var store
    @State private var isWatchingAd: Bool = false
    @State private var isPaywallPresented: Bool = false
    @State private var bounce: Bool = false

    private var missing: Int { max(0, cost - progressStore.livresBalance) }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.livres.opacity(0.14))
                    .frame(width: 96, height: 96)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.livres)
                    .rotationEffect(.degrees(bounce ? -8 : 8))
                    .scaleEffect(bounce ? 1.06 : 0.94)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Il te manque \(missing) 💎")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("Gagne des diamants en regardant une vidéo ou en finissant tes missions, ou passe Premium.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            DiamondBalance(amount: progressStore.livresBalance)

            VStack(spacing: 12) {
                videoButton

                Button {
                    Haptics.tap()
                    dismiss()
                    onOpenMissions()
                } label: {
                    Label("Voir mes missions", systemImage: "target")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.success))

                Button {
                    Haptics.tap()
                    isPaywallPresented = true
                } label: {
                    Label("Passer Premium", systemImage: "crown.fill")
                }
                .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(source: "missing_diamonds")
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
        .onChange(of: missing) { _, newValue in
            guard newValue == 0 else { return }
            Haptics.success()
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            }
        }
        .task {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
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

    @ViewBuilder
    private var videoButton: some View {
        if progressStore.diamondAdsRemainingToday > 0 {
            Button {
                Haptics.medium()
                watchAd()
            } label: {
                if isWatchingAd {
                    ProgressView().tint(Theme.duelBackground)
                } else {
                    Label("Regarder une vidéo (+\(ProgressStore.rewardedAdLivres) 💎)", systemImage: "play.rectangle.fill")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
            .disabled(isWatchingAd)
        } else {
            Text("Plus de vidéos aujourd'hui, reviens demain")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.lockedFill))
        }
    }

    private func watchAd() {
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            guard rewarded else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                progressStore.creditRewardedAd()
            }
            Haptics.success()
        }
    }
}
