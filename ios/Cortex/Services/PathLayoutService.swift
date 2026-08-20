import Foundation

/// Loads the learning-path ordering published from the admin "Parcours" tool.
///
/// Boot is instant on the built-in `PathDefaults`; the remote layout is fetched
/// in the background and merged in — a reorder shows up without an app update.
enum PathLayoutService {
    private static let remoteURL = "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)/api/path-layout"

    /// Synchronous default used at launch: never blocks on the network.
    static func loadLayout() -> PathLayout {
        PathDefaults.layout
    }

    /// Fetches the published layout, fully merged with the built-in defaults.
    /// Returns `nil` when nothing has been published or the fetch fails.
    static func fetchRemoteLayout() async -> PathLayout? {
        guard !Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.isEmpty else { return nil }
        guard let url = URL(string: remoteURL) else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 6

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        if let body = String(data: data, encoding: .utf8), body.contains("\"published\":false") {
            return nil
        }
        guard let remote = try? JSONDecoder().decode(PathLayout.self, from: data) else { return nil }
        print("[PathLayoutService] Organisation du parcours chargée depuis le backend")
        return merged(remote)
    }

    /// A published layout only has to describe what the admin actually
    /// reordered — anything it leaves out keeps the built-in default.
    private static func merged(_ remote: PathLayout) -> PathLayout {
        var chapterOrder = PathDefaults.chapterOrder
        for (disciplineId, order) in remote.chapterOrder where !order.isEmpty {
            chapterOrder[disciplineId] = order
        }
        return PathLayout(
            disciplineOrder: remote.disciplineOrder.isEmpty ? PathDefaults.disciplineOrder : remote.disciplineOrder,
            chapterOrder: chapterOrder,
            ringLayout: remote.ringLayout,
            disciplineKind: remote.disciplineKind
        )
    }
}
