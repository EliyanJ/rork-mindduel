import Foundation
import Observation
import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// Central place for AdMob: UMP consent and rewarded video only. Minduel never
/// shows a forced ad — every video is started by the player in exchange for a
/// reward (rubis, hearts, duel points, a retry). Debug builds use Google's
/// official test ad unit; Release builds (TestFlight / App Store) use Minduel's
/// real AdMob unit.
@Observable
@MainActor
final class AdsManager: NSObject {
    static let shared = AdsManager()

    private enum AdUnit {
        #if DEBUG
        /// Google's public test rewarded unit — never serves real ads.
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        #else
        /// Minduel's production rewarded video unit.
        static let rewarded = "ca-app-pub-7718590117935313/1584873895"
        #endif
    }

    private(set) var isConsentReady = false
    private(set) var isLoadingRewarded = false
    private var hasStarted = false
    /// Set when an ad was requested but AdMob returned no fill — surfaces
    /// the "Pub indisponible" fallback message in the UI.
    var lastError: String?

    private var rewardedAd: RewardedAd?
    private var pendingRewardCompletion: ((Bool) -> Void)?
    private var pendingRewardResult = false

    override private init() {
        super.init()
    }

    /// Call once the onboarding is finished. Requests UMP consent info, shows
    /// the consent form if required (EU users), then starts the Mobile Ads SDK
    /// and preloads a rewarded video.
    func start() {
        guard Monetization.isEnabled, !hasStarted else { return }
        hasStarted = true
        Task {
            let parameters = RequestParameters()
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
                try await ConsentForm.loadAndPresentIfRequired(from: TopViewControllerFinder.topViewController())
            } catch {
                // Never infer consent from a failed consent request.
            }
            finishConsentAndInitialize()
        }
    }

    private func finishConsentAndInitialize() {
        guard Monetization.isEnabled, ConsentInformation.shared.canRequestAds else { return }
        isConsentReady = true
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.preloadRewarded()
            }
        }
    }

    // MARK: - Rewarded video (opt-in)

    private func preloadRewarded() {
        guard Monetization.isEnabled, isConsentReady, ConsentInformation.shared.canRequestAds, rewardedAd == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        Task {
            do {
                let ad = try await RewardedAd.load(with: AdUnit.rewarded, request: Request())
                ad.fullScreenContentDelegate = self
                self.rewardedAd = ad
            } catch {
                self.lastError = "Pub indisponible, réessaie dans un instant"
            }
            self.isLoadingRewarded = false
        }
    }

    var isRewardedReady: Bool { rewardedAd != nil }

    /// Presents the rewarded video. `onReward` is called with `true` only if
    /// the user watched it fully and AdMob granted the reward. The tracking
    /// permission is asked right before the very first video, when the player
    /// can understand why.
    func showRewarded(from viewController: UIViewController?, onReward: @escaping (Bool) -> Void) {
        Task {
            await TrackingManager.requestAuthorizationIfNeeded()
            presentRewarded(from: viewController ?? TopViewControllerFinder.topViewController(), onReward: onReward)
        }
    }

    private func presentRewarded(from viewController: UIViewController?, onReward: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd, let viewController else {
            lastError = "Pub indisponible, réessaie dans un instant"
            onReward(false)
            preloadRewarded()
            return
        }
        pendingRewardCompletion = onReward
        pendingRewardResult = false
        ad.present(from: viewController) { [weak self] in
            // Called by the SDK only when the reward is actually granted.
            self?.pendingRewardResult = true
        }
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            guard ad is RewardedAd else { return }
            rewardedAd = nil
            let completion = pendingRewardCompletion
            pendingRewardCompletion = nil
            let result = pendingRewardResult
            pendingRewardResult = false
            preloadRewarded()
            completion?(result)
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            lastError = "Pub indisponible, réessaie dans un instant"
            guard ad is RewardedAd else { return }
            rewardedAd = nil
            let completion = pendingRewardCompletion
            pendingRewardCompletion = nil
            completion?(false)
        }
    }
}

/// Finds the top-most view controller to present ads from.
enum TopViewControllerFinder {
    @MainActor
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
