import Foundation
import Observation
import UserNotifications

/// Daily study reminders, built entirely on **local** notifications.
///
/// Why local and not push: these reminders are personal (they depend on the
/// onboarding answers and on whether the player already practised today), they
/// must fire on time even with no network, and they cost nothing. Marketing
/// re-engagement is a separate concern and belongs to a push provider.
///
/// Scheduling strategy: rather than one repeating trigger per slot, we lay down
/// individual requests for the next few days and rebuild them whenever the app
/// becomes active or the player practises. That is what allows a reminder to be
/// skipped once the daily goal is met — a repeating trigger could never know.
@Observable
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private static let enabledKey = "cortex.reminders.enabled.v1"
    /// Rolling window of scheduled days. iOS caps pending notifications at 64;
    /// 7 days x 3 slots stays far below that.
    private static let horizonDays = 7
    /// Nothing ever fires outside this window, whatever the preferences say.
    private static let earliestHour = 8
    private static let latestHour = 21

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Last inputs used to build the schedule, so the Settings switch can
    /// rebuild it without needing access to the onboarding store.
    private var lastContext: (preferences: OnboardingPreferences, practicedToday: Bool, streak: Int)?

    /// User-facing switch. Turning it off clears every pending reminder.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { cancelAll() }
        }
    }

    private init() {
        // Defaults to on: the switch only matters once permission is granted,
        // and the onboarding already asked how often the player wants to study.
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Asks the system for permission. Called after onboarding, never at first
    /// launch: a prompt shown before any value is demonstrated gets denied, and
    /// iOS only ever allows one such prompt per install.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            // A refusal is a normal outcome, not a failure worth surfacing.
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Scheduling

    /// Rebuilds the whole reminder schedule from the current state.
    /// - Parameters:
    ///   - preferences: onboarding answers driving how many reminders and when.
    ///   - hasPracticedToday: when true, today's remaining slots are skipped.
    ///   - streak: a streak at risk changes the tone of the last slot of a day.
    func refreshSchedule(
        preferences: OnboardingPreferences,
        hasPracticedToday: Bool,
        streak: Int
    ) async {
        lastContext = (preferences, hasPracticedToday, streak)
        await refreshAuthorizationStatus()
        guard isEnabled, authorizationStatus == .authorized || authorizationStatus == .provisional else {
            cancelAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let hours = Self.reminderHours(for: preferences)
        guard !hours.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)

        for dayOffset in 0..<Self.horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            // Today is already handled: don't nag someone who has done the work.
            if dayOffset == 0 && hasPracticedToday { continue }

            for (index, hour) in hours.enumerated() {
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                components.minute = 0
                guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

                let isLastOfDay = index == hours.count - 1
                // The streak warning only makes sense for today's final slot:
                // beyond today we cannot know whether the streak still stands.
                let warnsStreak = isLastOfDay && dayOffset == 0 && streak > 0
                let content = UNMutableNotificationContent()
                let message = warnsStreak
                    ? Self.streakMessage(streak: streak)
                    : Self.reminderMessage(slot: index, dayOffset: dayOffset)
                content.title = message.title
                content.body = message.body
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "reminder-\(dayOffset)-\(hour)",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                } catch {
                    // One rejected slot must not abort the whole schedule.
                    continue
                }
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Rebuilds the schedule from the last known context — used when the player
    /// flips the Settings switch.
    func reapply() async {
        guard let context = lastContext else { return }
        await refreshSchedule(
            preferences: context.preferences,
            hasPracticedToday: context.practicedToday,
            streak: context.streak
        )
    }

    /// Human summary of when reminders will fire, shown in Settings.
    func scheduleSummary(for preferences: OnboardingPreferences) -> String {
        let hours = Self.reminderHours(for: preferences)
        guard !hours.isEmpty else { return "Aucun rappel programmé." }
        let formatted = hours.map { "\($0)h" }.joined(separator: " · ")
        return "Chaque jour à \(formatted)"
    }

    // MARK: - Timing

    /// Slot hours for the day, derived from the onboarding answers and always
    /// clamped inside the quiet-hours window.
    static func reminderHours(for preferences: OnboardingPreferences) -> [Int] {
        let count = max(1, min(3, preferences.dailyGoal))
        let anchor = preferences.preferredLearningTime?.suggestedHour ?? 19

        let raw: [Int]
        switch count {
        case 1:
            raw = [anchor]
        case 2:
            // Second slot late enough to be a genuine second chance, not an echo.
            raw = [anchor, anchor + 6]
        default:
            raw = [anchor, anchor + 4, anchor + 8]
        }

        // Clamp, then de-duplicate while preserving order, so a late anchor
        // cannot collapse three reminders onto the same hour.
        var used = Set<Int>()
        var hours: [Int] = []
        for hour in raw {
            var clamped = min(max(hour, earliestHour), latestHour)
            while used.contains(clamped) && clamped > earliestHour {
                clamped -= 1
            }
            guard !used.contains(clamped) else { continue }
            used.insert(clamped)
            hours.append(clamped)
        }
        return hours.sorted()
    }

    // MARK: - Copy

    private static func reminderMessage(slot: Int, dayOffset: Int) -> (title: String, body: String) {
        let variants: [(String, String)] = [
            ("Une question t'attend", "Deux minutes suffisent pour avancer aujourd'hui."),
            ("C'est le moment", "Ta prochaine leçon est prête."),
            ("On continue ?", "Quelques questions, et la journée est validée."),
            ("Petit rappel", "Ton parcours t'attend là où tu l'as laissé."),
            ("Prêt à apprendre ?", "Une leçon rapide, c'est déjà une victoire.")
        ]
        let index = (slot + dayOffset) % variants.count
        let picked = variants[index]
        return (picked.0, picked.1)
    }

    private static func streakMessage(streak: Int) -> (title: String, body: String) {
        (
            "Ta série de \(streak) jour\(streak > 1 ? "s" : "") est en jeu",
            "Une leçon avant minuit et elle continue."
        )
    }
}
