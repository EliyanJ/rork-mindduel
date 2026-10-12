import Foundation
import Observation

/// Remembers which badges the player earned and when. Badges are local,
/// derived from progress, and never taken back once earned.
@Observable
final class BadgeStore {
    private static let key = "minduel.badges.earned.v1"
    private static let seenKey = "minduel.badges.seen.v1"

    /// badge id → date earned.
    private(set) var earned: [String: Date]
    /// Earned badges the player hasn't opened in the profile yet.
    private(set) var unseen: Set<String>

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: Date].self, from: data) {
            earned = saved
        } else {
            earned = [:]
        }
        unseen = Set(UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? [])
    }

    func isEarned(_ badge: Badge) -> Bool { earned[badge.id] != nil }

    func earnedDate(_ badge: Badge) -> Date? { earned[badge.id] }

    /// Records newly earned badges and returns only the ones that are new.
    @discardableResult
    func award(_ badges: [Badge], date: Date = .now) -> [Badge] {
        let fresh = badges.filter { earned[$0.id] == nil }
        guard !fresh.isEmpty else { return [] }
        for badge in fresh {
            earned[badge.id] = date
            unseen.insert(badge.id)
            Analytics.capture("badge_earned", ["badge": badge.id, "name": badge.name])
        }
        persist()
        return fresh
    }

    func markAllSeen() {
        guard !unseen.isEmpty else { return }
        unseen.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(earned) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        UserDefaults.standard.set(Array(unseen), forKey: Self.seenKey)
    }
}
