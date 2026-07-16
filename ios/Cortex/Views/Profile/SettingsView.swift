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

    @State private var isDeleteConfirmPresented = false
    @State private var isDeletingAccount = false
    @State private var legalSheet: LegalLink?
    @State private var didClearCache = false
    @State private var isRestoring = false
    @State private var isPaywallPresented = false
    @State private var isShopPresented = false

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
                    row(icon: "books.vertical.fill", title: "Acheter des livres") {
                        isShopPresented = true
                    }
                    if store.isPremium {
                        row(icon: "crown.fill", title: "Gérer mon abonnement") {
                            openSubscriptionManagement()
                        }
                    } else {
                        row(icon: "crown.fill", title: "Passer Premium") {
                            isPaywallPresented = true
                        }
                    }
                    row(icon: "arrow.clockwise", title: "Restaurer les achats") {
                        restorePurchases()
                    } trailing: {
                        if isRestoring {
                            ProgressView().tint(Theme.primary)
                        }
                    }
                }

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
            .sheet(isPresented: $isShopPresented) {
                LivresShopView(progressStore: model.store)
            }
            .fullScreenCover(isPresented: $isPaywallPresented) {
                OnboardingPaywallStep(store: store) { isPaywallPresented = false }
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

    private func restorePurchases() {
        Haptics.tap()
        isRestoring = true
        Task {
            await store.restore()
            isRestoring = false
        }
    }

    private func openSubscriptionManagement() {
        Haptics.tap()
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
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
