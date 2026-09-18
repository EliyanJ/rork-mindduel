import SwiftUI

struct UpdateRequiredView: View {
    let isPartyOnly: Bool
    let onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Mise à jour nécessaire")
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(isPartyOnly ? "Mets à jour Minduel pour jouer en groupe." : "Installe la dernière version de Minduel pour continuer à jouer en toute sécurité.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link(destination: WebLinks.appStore) {
                Text("Mettre à jour sur l’App Store")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .accessibilityIdentifier("update.appStore")
            if let onDismiss {
                Button("Revenir aux autres modes", action: onDismiss)
                    .frame(minHeight: 44)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas)
        .accessibilityIdentifier("update.required")
    }
}
