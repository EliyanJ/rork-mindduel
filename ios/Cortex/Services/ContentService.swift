import Foundation

/// Loads the question catalog.
///
/// Launch is never blocked by the network: the app boots on the catalogue
/// compiled into the bundle (instant), then refreshes from the backend in the
/// background so new questions and moderation decisions published from the
/// admin panel appear without an app update.
enum ContentService {
    private static let remoteURL = "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)/api/content"

    /// Instant catalogue: the version compiled into the app bundle.
    static func loadCatalog() -> ContentCatalog {
        loadBundledCatalog()
    }

    /// Raw bundled payload, kept around so a background refresh can tell
    /// whether the server actually serves something different.
    static func bundledData() -> Data? {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Fetches the latest catalogue from the backend. Returns `nil` on any
    /// failure (offline, server down, nothing published yet) — the caller
    /// just keeps the bundled copy.
    static func fetchRemoteCatalog() async -> (catalog: ContentCatalog, data: Data)? {
        guard !Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.isEmpty else { return nil }
        guard let url = URL(string: remoteURL) else { return nil }

        // Never serve a cached response: it could keep questions whose
        // moderation decisions have since been published.
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 6

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        // Check the "published" flag — if no content has been pushed yet,
        // the server returns a small JSON body, not a catalog.
        if let body = String(data: data, encoding: .utf8), body.contains("\"published\":false") {
            return nil
        }
        guard let catalog = try? JSONDecoder().decode(ContentCatalog.self, from: data) else { return nil }
        print("[ContentService] Catalogue chargé depuis le backend")
        return (catalog, data)
    }

    private static func loadBundledCatalog() -> ContentCatalog {
        guard let data = bundledData() else {
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
