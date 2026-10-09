import Foundation
import PostHog

/// Thin wrapper around PostHog (EU cloud). Never receives e-mail or names:
/// the only identity is the opaque Rork user id.
enum Analytics {
    private static let enabledKey = "cortex.analytics.enabled.v1"
    private static let goalDayKey = "cortex.analytics.goalDay.v1"
    private static let goalCountKey = "cortex.analytics.goalCount.v1"
    private static var isConfigured = false

    /// Player preference; anonymous usage statistics are on by default.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Starts the SDK: app lifecycle events (session length) and masked session replay.
    static func setup() {
        let token = Config.EXPO_PUBLIC_POSTHOG_PROJECT_TOKEN
        let host = Config.EXPO_PUBLIC_POSTHOG_HOST
        guard !token.isEmpty, !host.isEmpty else { return }
        let config = PostHogConfig(apiKey: token, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllSandboxedViews = true
        config.optOut = !isEnabled
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        guard isConfigured else { return }
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    static func capture(_ event: String, _ properties: [String: Any] = [:]) {
        guard isConfigured, isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: properties.isEmpty ? nil : properties)
    }

    static func identify(userId: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId)
    }

    static func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }

    /// Counts today's finished rounds and reports the daily goal once when reached.
    static func roundFinishedToday(dailyGoal: Int) {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        var count = defaults.double(forKey: goalDayKey) == today ? defaults.integer(forKey: goalCountKey) : 0
        count += 1
        defaults.set(today, forKey: goalDayKey)
        defaults.set(count, forKey: goalCountKey)
        if count == max(1, dailyGoal) {
            capture("daily_goal_reached")
        }
    }
}
