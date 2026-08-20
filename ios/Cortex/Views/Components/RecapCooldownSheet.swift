import SwiftUI

/// Explains why a failed recap is locked until tomorrow: the player should
/// replay the chapter's rings to train before the next attempt.
struct RecapCooldownSheet: View {
    let ring: PathRing
    let unlockDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.danger.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "hourglass")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.danger)
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Récap verrouillé")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Le récap de « \(ring.chapterTitle) » se débloque \(unlockDate, style: .relative). Rejoue les ronds de ce pack pour t'entraîner avant de retenter.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("J'ai compris") {
                Haptics.tap()
                dismiss()
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }
}
