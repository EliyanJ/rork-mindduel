import Foundation

/// Canonical URLs for the legal/support pages already live on the web app,
/// shown in-app via `LegalWebView` wherever Apple requires them.
enum WebLinks {
    private static let base = "https://pqvvji2o1xg9ygfbwj3m1-web.rork.live"

    static let privacy = URL(string: "\(base)/privacy")!
    static let terms = URL(string: "\(base)/terms")!
    static let support = URL(string: "\(base)/support")!
}
