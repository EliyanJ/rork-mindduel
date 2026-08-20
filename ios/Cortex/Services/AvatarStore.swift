import Foundation
import Observation

/// Persists the player's customizable avatar locally (no server storage
/// needed — every screen that wants to show "you" reads this directly).
@Observable
final class AvatarStore {
    private static let key = "cortex.avatar.config.v1"

    private(set) var config: AvatarConfig

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(AvatarConfig.self, from: data) {
            config = saved
        } else {
            config = .default
        }
    }

    func save(_ config: AvatarConfig) {
        self.config = config
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
