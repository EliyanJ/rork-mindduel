import Foundation

/// Canonical URLs for the legal/support pages already live on the web app,
/// shown in-app via `LegalWebView` wherever Apple requires them.
enum WebLinks {
    private static let base = "https://mindduel-kqfozex.rork.app"

    static let appStore = URL(string: "https://apps.apple.com/app/id6788570245")!
    static let privacy = URL(string: "\(base)/privacy")!
    static let terms = URL(string: "\(base)/terms")!
    static let support = URL(string: "\(base)/support")!
}
