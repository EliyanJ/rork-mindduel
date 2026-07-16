import SwiftUI
import AuthenticationServices

/// Google / Apple sign-in sheet used by the Duel and Profile tabs.
struct SignInSheet: View {
    @Environment(OnlineModel.self) private var online
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var auth = online.auth

        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("🌍")
                    .font(.system(size: 52))
                Text("Joue en ligne")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Crée ton profil pour affronter de vrais joueurs, ajouter des amis et grimper au classement mondial.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)

            if auth.isSigningIn {
                ProgressView()
                    .tint(Theme.primary)
                    .padding(.vertical, 6)
            }

            Button {
                Haptics.medium()
                Task {
                    await online.auth.signIn(provider: "google")
                    await afterSignIn()
                }
            } label: {
                Label("Continuer avec Google", systemImage: "globe")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
            .disabled(auth.isSigningIn)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { _ in
                Task {
                    await online.auth.signIn(provider: "apple")
                    await afterSignIn()
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(auth.isSigningIn)

            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .alert("Erreur", isPresented: $auth.showError) {
            Button("OK") { }
        } message: {
            Text(auth.errorMessage)
        }
    }

    private func afterSignIn() async {
        guard online.isSignedIn else { return }
        await online.syncProfile(localElo: model.store.progress.elo)
        await online.refreshFriends()
        dismiss()
    }
}
