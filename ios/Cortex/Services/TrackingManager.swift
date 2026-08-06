import AppTrackingTransparency
import Foundation

/// Wraps the system App Tracking Transparency prompt ("Autoriser à suivre
/// votre activité sur les autres apps"). Required by Apple once ad
/// personalization/cross-app tracking is in play (AdMob here); without it,
/// personalized ads must not be requested.
@MainActor
enum TrackingManager {
    /// Asks the system for permission if the user hasn't been prompted yet.
    /// Safe to call multiple times: iOS only ever shows the dialog once per
    /// install, subsequent calls just read back the stored status.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return ATTrackingManager.trackingAuthorizationStatus
        }
        return await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Whether AdMob is allowed to personalize ads using the device identifier.
    static var isAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
}
