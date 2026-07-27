import Foundation

/// Single switch controlling every paid surface of the app.
///
/// Version 1.0 ships free: no paywall, no rubis shop, no ads, and no daily
/// quotas. All lesson/review limits and themed-path locks behave as if the
/// player owned Premium, so nothing is gated behind a purchase.
///
/// Flip `isEnabled` back to `true` to restore the full monetization flow
/// (RevenueCat subscriptions, rubis packs, rewarded/interstitial ads and the
/// free-tier quotas) once the App Store paid-apps agreement is in place.
enum Monetization {
    /// Whether purchases, ads and free-tier quotas are active.
    static let isEnabled = false

    /// Convenience inverse used by views that unlock content when free.
    static var isFreeVersion: Bool { !isEnabled }
}
