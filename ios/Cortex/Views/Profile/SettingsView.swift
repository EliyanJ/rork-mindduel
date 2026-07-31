import SwiftUI

/// Réglages screen, reached from the gear icon on the Profile tab. Groups
/// account deletion, cache clearing, legal links, and sign-out — the
/// in-app Terms/Privacy links here satisfy Apple's requirement whenever the
/// app offers auto-renewable subscriptions.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let notifications = NotificationService.shared

    @State private var isDeleteConfirmPresented = false
    @State private var isDeletingAccount = false
    @State private var legalSheet: LegalLink?
    @State private var didClearCache = false

    private enum LegalLink: Identifiable {
        case privacy, terms, support
        var id: Int { hashValue }

        var title: String {
            switch self {
            case .privacy: return "Confidentialité"
            case .terms: return "Conditions"
            case .support: return "Support"
            }
        }

        var url: URL {
            switch self {
            case .privacy: return WebLinks.privacy
            case .terms: return WebLinks.terms
            case .support: return WebLinks.support
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(icon: "trash", tint: .clear, title: "Vider le cache") {
                        clearCache()
                    } trailing: {
                        if didClearCache {
                            Text("Fait !")
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.success)
                        }
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { notifications.isEnabled },
                        set: { newValue in
                            Haptics.tap()
                            notifications.isEnabled = newValue
                            Task { await notifications.reapply() }
                        }
                    )) {
                        Label("Rappels quotidiens", systemImage: "bell.badge")
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.primary)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(notificationsFooter)
                }

                Section {
                    row(icon: "hand.raised", title: "Politique de confidentialité") {
                        legalSheet = .privacy
                    }
                    row(icon: "doc.text", title: "Conditions d'utilisation") {
                        legalSheet = .terms
                    }
                    row(icon: "questionmark.circle", title: "Support / contact") {
                        legalSheet = .support
                    }
                }

                if online.isSignedIn {
                    Section {
                        row(icon: "rectangle.portrait.and.arrow.right", title: "Se déconnecter") {
                            Task { await online.signOut() }
                        }
                    }

                    Section {
                        Button {
                            Haptics.tap()
                            isDeleteConfirmPresented = true
                        } label: {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView().tint(Theme.danger)
                                } else {
                                    Label("Supprimer mon compte", systemImage: "trash.fill")
                                }
                            }
                            .foregroundStyle(Theme.danger)
                        }
                        .disabled(isDeletingAccount)
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $legalSheet) { link in
                LegalWebView(title: link.title, url: link.url)
            }
            .task {
                await notifications.refreshAuthorizationStatus()
            }
            .confirmationDialog(
                "Supprimer définitivement ton compte ?",
                isPresented: $isDeleteConfirmPresented,
                titleVisibility: .visible
            ) {
                Button("Supprimer mon compte", role: .destructive) {
                    Haptics.medium()
                    isDeletingAccount = true
                    Task {
                        let success = await online.deleteAccount()
                        isDeletingAccount = false
                        if success { dismiss() }
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Ton profil en ligne, ton classement ELO, tes amis et ton historique de duels seront supprimés définitivement. Cette action est irréversible.")
            }
        }
    }

    /// Explains what will actually happen, including the case where iOS itself
    /// is blocking the reminders — an in-app switch cannot override that.
    private var notificationsFooter: String {
        switch notifications.authorizationStatus {
        case .denied:
            return "Les notifications sont bloquées pour Minduel dans les Réglages de l'iPhone. Active-les là-bas pour recevoir tes rappels."
        case .notDetermined:
            return "Tu recevras une demande d'autorisation avant le premier rappel."
        default:
            return notifications.isEnabled
                ? "Des rappels discrets, jamais entre 22 h et 8 h, et aucun si tu as déjà travaillé dans la journée."
                : "Aucun rappel ne sera envoyé."
        }
    }

    private func row(
        icon: String,
        tint: Color = Theme.ink,
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(Theme.ink)
                Spacer()
                trailing()
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        if let tmp = try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil) {
            for file in tmp {
                try? FileManager.default.removeItem(at: file)
            }
        }
        Haptics.success()
        withAnimation(.spring(duration: 0.3)) { didClearCache = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(duration: 0.3)) { didClearCache = false }
        }
    }
}

#Preview {
    SettingsView()
}
