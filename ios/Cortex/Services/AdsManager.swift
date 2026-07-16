import Foundation
import Observation
import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// Central place for AdMob: UMP consent, interstitials (forced, no reward)
/// and rewarded video (opt-in, credits livres). Uses Google's official test
/// ad unit IDs until a real AdMob account is configured.
@Observable
@MainActor
final class AdsManager: NSObject {
    static let shared = AdsManager()

    /// Google's public test ad unit IDs (safe to ship while waiting on a real AdMob account).
    private enum TestUnit {
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    }

    private(set) var isConsentReady = false
    private(set) var isLoadingInterstitial = false
    private(set) var isLoadingRewarded = false
    /// Set when an ad was requested but AdMob returned no fill — surfaces
    /// the "Pub indisponible" fallback message in the UI.
    var lastError: String?

    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?
    private var pendingInterstitialCompletion: (() -> Void)?
    private var pendingRewardCompletion: ((Bool) -> Void)?

    override private init() {
        super.init()
    }

    /// Call once at app launch. Requests UMP consent info, shows the consent
    /// form if required (EU users), then starts the Mobile Ads SDK and
    /// preloads both ad formats.
    func start() {
        Task {
            let parameters = RequestParameters()
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
                try await ConsentForm.loadAndPresentIfRequired(from: TopViewControllerFinder.topViewController())
            } catch {
                // Network or config issue — proceed with non-personalized ads.
            }
            finishConsentAndInitialize()
        }
    }

    private func finishConsentAndInitialize() {
        isConsentReady = true
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.preloadInterstitial()
                self?.preloadRewarded()
            }
        }
    }

    // MARK: - Forced interstitial (ranked duels / bot training)

    private func preloadInterstitial() {
        guard interstitialAd == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        Task {
            do {
                let ad = try await InterstitialAd.load(with: TestUnit.interstitial, request: Request())
                ad.fullScreenContentDelegate = self
                self.interstitialAd = ad
            } catch {
                self.lastError = "Pub indisponible, réessaie dans un instant"
            }
            self.isLoadingInterstitial = false
        }
    }

    /// Shows the forced interstitial if one is ready; always calls
    /// `completion` afterward (whether or not an ad was shown) so callers
    /// can proceed to matchmaking without ever blocking on ads.
    func showInterstitial(from viewController: UIViewController?, completion: @escaping () -> Void) {
        guard let ad = interstitialAd, let viewController else {
            lastError = interstitialAd == nil ? "Pub indisponible, réessaie dans un instant" : nil
            completion()
            preloadInterstitial()
            return
        }
        pendingInterstitialCompletion = completion
        ad.present(from: viewController)
    }

    // MARK: - Rewarded video (opt-in, +2 livres)

    private func preloadRewarded() {
        guard rewardedAd == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        Task {
            do {
                let ad = try await RewardedAd.load(with: TestUnit.rewarded, request: Request())
                ad.fullScreenContentDelegate = self
                self.rewardedAd = ad
            } catch {
                self.lastError = "Pub indisponible, réessaie dans un instant"
            }
            self.isLoadingRewarded = false
        }
    }

    var isRewardedReady: Bool { rewardedAd != nil }

    /// Presents the rewarded video. `onReward` is called only if the user
    /// watched it fully and AdMob granted the reward.
    func showRewarded(from viewController: UIViewController?, onReward: @escaping (Bool) -> Void) {
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

    private var pendingRewardResult = false
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            if ad is InterstitialAd {
                interstitialAd = nil
                let completion = pendingInterstitialCompletion
                pendingInterstitialCompletion = nil
                preloadInterstitial()
                completion?()
            } else if ad is RewardedAd {
                rewardedAd = nil
                let completion = pendingRewardCompletion
                pendingRewardCompletion = nil
                let result = pendingRewardResult
                pendingRewardResult = false
                preloadRewarded()
                completion?(result)
            }
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            lastError = "Pub indisponible, réessaie dans un instant"
            if ad is InterstitialAd {
                interstitialAd = nil
                let completion = pendingInterstitialCompletion
                pendingInterstitialCompletion = nil
                completion?()
            } else if ad is RewardedAd {
                rewardedAd = nil
                let completion = pendingRewardCompletion
                pendingRewardCompletion = nil
                completion?(false)
            }
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
