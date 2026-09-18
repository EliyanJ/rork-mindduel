import SwiftUI

/// Loads artwork with the app version header and standard HTTP caching.
struct RemoteThemeImage<Fallback: View>: View {
    let urlString: String?
    @ViewBuilder var fallback: () -> Fallback
    @State private var loadedImage: UIImage?

    private var resolvedURL: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("/") {
            return URL(string: "\(Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)\(urlString)")
        }
        return URL(string: urlString)
    }

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage).resizable()
            } else {
                fallback()
            }
        }
        .task(id: resolvedURL) {
            loadedImage = nil
            guard let url = resolvedURL else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: AppVersion.request(url: url))
                guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                loadedImage = UIImage(data: data)
            } catch { /* Bundled artwork remains visible on failure. */ }
        }
    }
}
