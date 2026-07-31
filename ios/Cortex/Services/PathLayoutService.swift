import Foundation

/// Loads the learning-path ordering published from the admin "Parcours" tool.
///
/// Mirrors `ContentService`: the remote layout wins so a reorder shows up
/// without an app update, and any failure falls back to the built-in
/// `PathDefaults` so the path is never empty or broken.
enum PathLayoutService {
    private static let remoteURL = "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)/api/path-layout"

    static func loadLayout() -> PathLayout {
        guard let remote = loadRemoteLayout() else { return PathDefaults.layout }
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

    private static func loadRemoteLayout() -> PathLayout? {
        guard !Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.isEmpty else { return nil }
        guard let url = URL(string: remoteURL) else { return nil }

        var result: PathLayout?
        let semaphore = DispatchSemaphore(value: 0)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return }
            if let body = String(data: data, encoding: .utf8),
               body.contains("\"published\":false") {
                return
            }
            result = try? JSONDecoder().decode(PathLayout.self, from: data)
        }.resume()

        _ = semaphore.wait(timeout: .now() + 4)
        if result != nil {
            print("[PathLayoutService] Organisation du parcours chargée depuis le backend")
        }
        return result
    }
}
