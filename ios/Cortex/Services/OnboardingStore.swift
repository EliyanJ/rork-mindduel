import Foundation
import Observation

/// Persists whether the first-run onboarding flow has been completed and the
/// answers collected during it.
@Observable
final class OnboardingStore {
    private static let completedKey = "cortex.onboarding.completed.v1"
    private static let prefsKey = "cortex.onboarding.prefs.v1"

    private(set) var isCompleted: Bool
    private(set) var preferences: OnboardingPreferences

    init() {
        isCompleted = UserDefaults.standard.bool(forKey: Self.completedKey)
        if let data = UserDefaults.standard.data(forKey: Self.prefsKey),
           let saved = try? JSONDecoder().decode(OnboardingPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = .initial
        }
    }

    func save(_ preferences: OnboardingPreferences) {
        self.preferences = preferences
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.prefsKey)
    }

    func saveDiagnostic(_ diagnostic: OnboardingDiagnostic) {
        var updated = preferences
        updated.diagnostic = diagnostic
        save(updated)
    }

    func complete() {
        isCompleted = true
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }

    /// Testing / debug helper to replay the flow.
    func reset() {
        isCompleted = false
        UserDefaults.standard.set(false, forKey: Self.completedKey)
    }
}
