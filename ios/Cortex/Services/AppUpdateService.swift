import Foundation
import Observation

@Observable
final class AppUpdateService {
    static let shared = AppUpdateService()
    private(set) var policy: AppVersionPolicy?
    private var isRefreshing: Bool = false
    private let cacheKey: String = "minduel.app-version-policy.v1"

    var requiresUpdate: Bool {
        policy.map { AppVersion.isOlder(AppVersion.current, than: $0.minVersion) } ?? false
    }
    var requiresPartyUpdate: Bool {
        policy.map { AppVersion.isOlder(AppVersion.current, than: $0.minVersionParty) } ?? false
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            policy = try? JSONDecoder().decode(AppVersionPolicy.self, from: data)
        }
    }

    /// Keep the last known policy offline; a network error never invents a forced update.
    func refresh() async {
        guard !isRefreshing, let url = URL(string: "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)/api/app/config") else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var request = AppVersion.request(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 6
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let newPolicy = try JSONDecoder().decode(AppVersionPolicy.self, from: data)
            policy = newPolicy
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch { /* Preserve cached policy when offline. */ }
    }
}
