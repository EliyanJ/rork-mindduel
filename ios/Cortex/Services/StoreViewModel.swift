import Foundation
import Observation

/// Central place for premium/entitlement state.
///
/// Version 1.0 ships as a fully free app, so the RevenueCat SDK is not linked
/// into this build at all and `isPremium` always reports true — no feature is
/// ever gated behind a purchase.
///
/// To restore the paid flow in 1.1: flip `Monetization.isEnabled` back to true,
/// re-add the `purchases-ios-spm` package, and restore `LivresShopView` and
/// `OnboardingPaywallStep` (plus this file's RevenueCat calls) from git history.
@Observable
@MainActor
final class StoreViewModel {
    var isLoading = false
    var isPurchasing = false
    var error: String?

    /// Real entitlement state. Stays false while the app ships free because no
    /// store is wired up; `isPremium` is what the UI should read.
    private var isEntitledToPremium = false

    /// Whether the player should get unrestricted access. In the free version
    /// this is unconditionally true so no feature is ever gated.
    var isPremium: Bool {
        Monetization.isEnabled ? isEntitledToPremium : true
    }

    /// Maps a livres-pack store identifier to the number of livres it grants.
    /// Kept for the 1.1 paid build.
    static let livresPackAmounts: [String: Int] = [
        "minduel_livres_s": 20,
        "minduel_livres_m": 65,
        "minduel_livres_l": 120,
        "minduel_livres_xl": 260
    ]

    /// No-op while the app ships free: there is nothing to restore because no
    /// purchase can be made in this build.
    func restore() async {}

    /// No-op while the app ships free.
    func checkStatus() async {}
}
