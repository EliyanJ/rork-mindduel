import SwiftUI

/// Feedback entry point pinned to the left edge at mid-height, clear of the
/// navigation bars; sends only the fields explicitly entered by the player.
struct FeedbackBubble: View {
    @State private var isPresented: Bool = false
    @State private var message: String = ""
    @State private var replyEmail: String = ""
    @State private var category: String = "Suggestion"
    @State private var isSending: Bool = false
    @State private var result: String? = nil
    @State private var didSend: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.tap()
                isPresented = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(isBeta ? "BÊTA" : "AVIS")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 14, height: 40)
                }
                .foregroundStyle(.white)
                .frame(width: 30, height: 78)
                .background(Theme.primary, in: UnevenRoundedRectangle(bottomTrailingRadius: 12, topTrailingRadius: 12))
                .shadow(color: .black.opacity(0.16), radius: 6, x: 2, y: 2)
                .frame(width: 44, height: 78, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isBeta ? "Signaler un bug ou donner un avis sur la bêta" : "Donner un avis sur Minduel")
            .accessibilityHint("Ouvre le formulaire de retour.")
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                Form {
                    Section {
                        Text(isBeta ? "Tu testes Minduel : ton avis nous aide à améliorer l’application." : "Ton avis nous aide à améliorer Minduel.")
                        Text("Un bug, une idée ou une difficulté ? Décris ce qui s’est passé. Ce formulaire n’est pas un chat en direct.")
                            .font(.subheadline)
                    } header: { Text(isBeta ? "Retours bêta" : "Ton avis") }
                    Section("Ton retour") {
                        Picker("Type", selection: $category) {
                            ForEach(["Suggestion", "Bug", "Question", "Autre"], id: \.self) { Text($0) }
                        }
                        TextEditor(text: $message).frame(minHeight: 140)
                            .accessibilityLabel("Message de retour")
                        TextField("Email de réponse (facultatif)", text: $replyEmail)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    Section {
                        Text("Ton message sera envoyé à l’équipe Minduel. L’email est facultatif et sert uniquement à te répondre. Aucun journal ni historique de jeu n’est joint. N’envoie pas de mot de passe ou de donnée sensible.")
                            .font(.footnote)
                        Link("Politique de confidentialité", destination: WebLinks.privacy)
                        if let result { Text(result).foregroundStyle(didSend ? Theme.success : Theme.danger) }
                        Button {
                            Task { await send() }
                        } label: {
                            if isSending { ProgressView() } else { Text("Envoyer mon avis") }
                        }
                        .disabled(isSending || didSend || !(10...4000).contains(message.trimmingCharacters(in: .whitespacesAndNewlines).count))
                    }
                }
                .navigationTitle(isBeta ? "Avis sur la bêta" : "Donner un avis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { isPresented = false }.disabled(isSending)
                } }
            }
            .onAppear { if didSend { message = ""; replyEmail = ""; didSend = false; result = nil } }
        }
    }

    private var isBeta: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    private func send() async {
        isSending = true
        result = nil
        defer { isSending = false }
        do {
            guard let url = URL(string: "\(MultiplayerService.baseURL)/api/feedback") else { throw URLError(.badURL) }
            var request = AppVersion.request(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 25
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
            let context = "Minduel \(AppVersion.current) (\(build))\(isBeta ? " · TestFlight" : "") · iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
            request.httpBody = try JSONSerialization.data(withJSONObject: ["message": message, "replyEmail": replyEmail, "category": category, "context": context])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            didSend = true
            result = "Merci ! Ton avis a été transmis à l’équipe."
        } catch {
            result = "L’envoi n’a pas abouti. Ton texte est conservé ; réessaie plus tard."
        }
    }
}
