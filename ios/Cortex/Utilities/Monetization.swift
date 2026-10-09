import Foundation

/// Single switch controlling every paid surface of the app: the Minduel
/// Premium subscription (RevenueCat), rewarded videos (never forced ads) and
/// the free-tier limits. When `false`, everyone behaves as Premium.
enum Monetization {
    /// Whether the subscription, rewarded videos and free-tier limits are active.
    static let isEnabled = true

    /// Convenience inverse used by views that unlock content when free.
    static var isFreeVersion: Bool { !isEnabled }
}
