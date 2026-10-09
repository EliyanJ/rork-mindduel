import StoreKit
import UIKit

/// Native rating prompt after a won duel, at most once every 30 days.
enum ReviewPrompt {
    private static let lastKey = "cortex.review.lastDuelWinPrompt.v1"

    @MainActor
    static func requestAfterDuelWin() {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastKey) as? Date,
           Date().timeIntervalSince(last) < 30 * 24 * 3600 { return }
        defaults.set(Date(), forKey: lastKey)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }
}
