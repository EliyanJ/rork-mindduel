import Foundation
import Observation
import RevenueCat

/// Central place for subscription state, backed by RevenueCat. Configured
/// once in the app's init(); shared across the paywall and settings.
///
/// When `Monetization.isEnabled` is false the app ships as a fully free
/// version: RevenueCat is never contacted and `isPremium` always reports
/// true so every quota and themed path stays unlocked.
@Observable
@MainActor
final class StoreViewModel {
    var offerings: Offerings?
    var livresOffering: Offering?
    var isLoading = false
    var isPurchasing = false
    var error: String?

    /// Real RevenueCat entitlement state. Only meaningful when monetization is on.
    private var isEntitledToPremium = false

    /// Whether the player should get unrestricted access. In the free version
    /// this is unconditionally true so no feature is ever gated.
    var isPremium: Bool {
        Monetization.isEnabled ? isEntitledToPremium : true
    }

    /// Maps a livres-pack store identifier to the number of livres it grants.
    static let livresPackAmounts: [String: Int] = [
        "minduel_livres_s": 20,
        "minduel_livres_m": 65,
        "minduel_livres_l": 120,
        "minduel_livres_xl": 260
    ]

    init() {
        guard Monetization.isEnabled else { return }
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
        Task { await fetchLivresOffering() }
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            isEntitledToPremium = info.entitlements["premium"]?.isActive == true
        }
    }

    func fetchOfferings() async {
        guard Monetization.isEnabled else { return }
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchLivresOffering() async {
        guard Monetization.isEnabled else { return }
        do {
            let all = try await Purchases.shared.offerings()
            livresOffering = all.offering(identifier: "livres")
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Purchases a one-time livres pack and returns how many livres were
    /// granted (0 if cancelled/pending/failed).
    @discardableResult
    func purchaseLivresPack(package: Package) async -> Int {
        guard Monetization.isEnabled else { return 0 }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return 0 }
            return Self.livresPackAmounts[package.storeProduct.productIdentifier] ?? 0
        } catch ErrorCode.purchaseCancelledError {
            return 0
        } catch ErrorCode.paymentPendingError {
            return 0
        } catch {
            self.error = error.localizedDescription
            return 0
        }
    }

    func purchase(package: Package) async {
        guard Monetization.isEnabled else { return }
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isEntitledToPremium = result.customerInfo.entitlements["premium"]?.isActive == true
            }
        } catch ErrorCode.purchaseCancelledError {
            // StoreKit cancellation — not an error.
        } catch ErrorCode.paymentPendingError {
            // Awaiting parental approval or extra auth — not a failure.
        } catch {
            self.error = error.localizedDescription
        }
        isPurchasing = false
    }

    func restore() async {
        guard Monetization.isEnabled else { return }
        isLoading = true
        do {
            let info = try await Purchases.shared.restorePurchases()
            isEntitledToPremium = info.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func checkStatus() async {
        guard Monetization.isEnabled else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isEntitledToPremium = info.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
