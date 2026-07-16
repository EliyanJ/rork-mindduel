import Foundation

/// Loads the question catalog — tries the remote backend first (so new
/// questions published from the admin panel appear instantly without an
/// app update), and falls back to the bundled `content.json` if the server
/// is unreachable or has never been published to.
enum ContentService {
    private static let remoteURL = "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)/api/content"

    static func loadCatalog() -> ContentCatalog {
        // Try remote first — it has the latest content pushed by the admin panel.
        if let remote = loadRemoteCatalog() {
            return remote
        }
        // Fallback: the version compiled into the app bundle.
        return loadBundledCatalog()
    }

    /// Synchronous remote fetch with a short timeout. Returns `nil` on any
    /// failure — the caller falls back to the bundled copy.
    private static func loadRemoteCatalog() -> ContentCatalog? {
        guard !Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.isEmpty else { return nil }
        guard let url = URL(string: remoteURL) else { return nil }

        var result: ContentCatalog?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: url) { data, response, _ in
            defer { semaphore.signal() }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return }
            // Check the "published" flag — if no content has been pushed yet,
            // the server returns a small JSON body, not a catalog.
            if let body = String(data: data, encoding: .utf8),
               body.contains("\"published\":false") {
                return
            }
            result = try? JSONDecoder().decode(ContentCatalog.self, from: data)
        }.resume()

        // Wait up to 4 seconds — if the server is slow or down, use the bundle.
        _ = semaphore.wait(timeout: .now() + 4)
        if result != nil {
            print("[ContentService] Catalogue chargé depuis le backend")
        }
        return result
    }

    private static func loadBundledCatalog() -> ContentCatalog {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[ContentService] content.json introuvable dans le bundle")
            return ContentCatalog(disciplines: [])
        }
        do {
            return try JSONDecoder().decode(ContentCatalog.self, from: data)
        } catch {
            print("[ContentService] Échec du décodage : \(error.localizedDescription)")
            return ContentCatalog(disciplines: [])
        }
    }
}
