import SwiftUI
import WebKit

/// Thin WKWebView wrapper used to display legal/support pages in-app
/// instead of kicking the user out to the system browser.
struct LegalWebContent: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

/// Full legal page presented modally with a title and close button.
struct LegalWebView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalWebContent(url: url)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}
