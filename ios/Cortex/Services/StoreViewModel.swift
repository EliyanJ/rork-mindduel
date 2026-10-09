import Foundation
import Observation
import RevenueCat

/// Central place for Minduel Premium. RevenueCat is the only source of truth:
/// every premium perk reads `isPremium`, which only reflects the active
/// "premium" entitlement. Prices and trial wording always come from the App
/// Store products, never from hard-coded values.
@Observable
@MainActor
final class StoreViewModel {
    static let entitlementId = "premium"

    private(set) var offering: Offering?
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var error: String?
    var notice: String?

    /// Products for which the player can still claim the introductory offer.
    private(set) var trialEligibleProductIds: Set<String> = []

    private var isEntitledToPremium = false

    /// Whether the player gets the Premium perks.
    var isPremium: Bool {
        Monetization.isEnabled ? isEntitledToPremium : true
    }

    var annualPackage: Package? {
        offering?.annual ?? offering?.availablePackages.first { $0.storeProduct.subscriptionPeriod?.unit == .year }
    }

    var monthlyPackage: Package? {
        offering?.monthly ?? offering?.availablePackages.first { $0.storeProduct.subscriptionPeriod?.unit == .month }
    }

    init() {
        Self.configureIfNeeded()
        guard Purchases.isConfigured else { return }
        Task { await listenForUpdates() }
        Task { await loadOfferings() }
    }

    /// Configures the SDK once, with the Test Store key in debug builds and
    /// the App Store key in TestFlight/App Store builds.
    private static func configureIfNeeded() {
        guard Monetization.isEnabled, !Purchases.isConfigured else { return }
        #if DEBUG
        let apiKey = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        Purchases.logLevel = .warn
        #else
        let apiKey = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY
        #endif
        guard !apiKey.isEmpty else { return }
        Purchases.configure(withAPIKey: apiKey)
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        isEntitledToPremium = info.entitlements[Self.entitlementId]?.isActive == true
    }

    func loadOfferings() async {
        guard Purchases.isConfigured, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
            await refreshTrialEligibility()
        } catch {
            self.error = "Impossible de charger les offres. Vérifie ta connexion et réessaie."
        }
    }

    private func refreshTrialEligibility() async {
        guard let packages = offering?.availablePackages, !packages.isEmpty else { return }
        let ids = packages.map(\.storeProduct.productIdentifier)
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)
        var eligible: Set<String> = []
        for package in packages {
            let product = package.storeProduct
            guard product.introductoryDiscount != nil else { continue }
            switch eligibility[product.productIdentifier]?.status {
            case .ineligible, .noIntroOfferExists:
                continue
            default:
                eligible.insert(product.productIdentifier)
            }
        }
        trialEligibleProductIds = eligible
    }

    /// Introductory free trial the player can still claim on this package.
    func freeTrial(for package: Package) -> StoreProductDiscount? {
        guard trialEligibleProductIds.contains(package.storeProduct.productIdentifier),
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        return intro
    }

    /// Returns true when Premium is active after the purchase.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        guard Purchases.isConfigured, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            apply(result.customerInfo)
            if isEntitledToPremium {
                Analytics.capture("premium_purchased", ["product": package.storeProduct.productIdentifier])
            }
            return isEntitledToPremium
        } catch ErrorCode.purchaseCancelledError {
            return false
        } catch ErrorCode.paymentPendingError {
            notice = "Achat en attente de validation. Premium s'activera dès qu'il sera approuvé."
            return false
        } catch {
            self.error = "L'achat n'a pas pu aboutir. Aucun montant n'a été débité."
            return false
        }
    }

    func restore() async {
        guard Purchases.isConfigured, !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            notice = isEntitledToPremium
                ? "Ton abonnement Premium est restauré."
                : "Aucun abonnement actif n'a été trouvé pour ce compte Apple."
        } catch {
            self.error = "La restauration a échoué. Vérifie ta connexion et réessaie."
        }
    }

    func checkStatus() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
    }

    /// Ties purchases to the Minduel account so Premium follows the player
    /// across devices and can be mirrored server-side.
    func identify(userId: String?) async {
        guard Purchases.isConfigured else { return }
        if let userId {
            guard Purchases.shared.appUserID != userId else { return }
            if let result = try? await Purchases.shared.logIn(userId) {
                apply(result.customerInfo)
            }
        } else if !Purchases.shared.isAnonymous {
            if let info = try? await Purchases.shared.logOut() {
                apply(info)
            }
        }
    }
}
