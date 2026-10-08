import SwiftUI

/// Movable feedback entry point; sends only the fields explicitly entered by the player.
struct FeedbackBubble: View {
    @State private var position: CGPoint? = nil
    @State private var dragOrigin: CGPoint? = nil
    @State private var isPresented: Bool = false
    @State private var message: String = ""
    @State private var replyEmail: String = ""
    @State private var category: String = "Suggestion"
    @State private var isSending: Bool = false
    @State private var result: String? = nil
    @State private var didSend: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let initial = CGPoint(x: max(28, geometry.size.width - 44), y: max(28, geometry.size.height - 105))
            Button { isPresented = true } label: {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.primary, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            }
            .accessibilityLabel("Donner un avis sur Minduel")
            .accessibilityHint("Ouvre le formulaire de retour. La bulle peut être déplacée.")
            .position(position ?? initial)
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let origin = dragOrigin ?? position ?? initial
                    dragOrigin = origin
                    position = CGPoint(
                        x: min(max(28, origin.x + value.translation.width), max(28, geometry.size.width - 28)),
                        y: min(max(28, origin.y + value.translation.height), max(28, geometry.size.height - 80))
                    )
                }
                .onEnded { _ in dragOrigin = nil })
            .onChange(of: geometry.size) { _, size in
                guard let current = position else { return }
                position = CGPoint(x: min(max(28, current.x), max(28, size.width - 28)), y: min(max(28, current.y), max(28, size.height - 80)))
            }
        }
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
            request.httpBody = try JSONSerialization.data(withJSONObject: ["message": message, "replyEmail": replyEmail, "category": category])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            didSend = true
            result = "Merci ! Ton avis a été transmis à l’équipe."
        } catch {
            result = "L’envoi n’a pas abouti. Ton texte est conservé ; réessaie plus tard."
        }
    }
}
