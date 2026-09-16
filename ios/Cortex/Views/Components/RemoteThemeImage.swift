import SwiftUI

/// Displays a remote theme/chapter illustration published from the admin
/// catalog, downloaded and transparently cached on-device (`URLSession`'s
/// shared `URLCache`, which `AsyncImage` already honours) — falling back to
/// bundled artwork while loading, offline, or on any failure.
struct RemoteThemeImage<Fallback: View>: View {
    let urlString: String?
    @ViewBuilder var fallback: () -> Fallback

    private var resolvedURL: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        // Uploaded images are served from the project's own backend as a
        // relative `/api/images/<id>` path — resolve it against the
        // functions base URL, same as every other backend call.
        if urlString.hasPrefix("/") {
            return URL(string: "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)\(urlString)")
        }
        return URL(string: urlString)
    }

    var body: some View {
        if let url = resolvedURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                } else {
                    fallback()
                }
            }
        } else {
            fallback()
        }
    }
}
