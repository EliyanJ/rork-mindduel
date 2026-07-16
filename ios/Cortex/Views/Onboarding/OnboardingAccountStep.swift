import SwiftUI
import AuthenticationServices

/// Final, always-optional step: proposes creating an account so progress is
/// backed up and online play unlocked, without ever blocking access to the
/// app. Shown after the paywall decision regardless of purchase outcome.
struct OnboardingAccountStep: View {
    let onFinished: () -> Void

    @Environment(OnlineModel.self) private var online
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var auth = online.auth

        GeometryReader { geo in
            let compact = geo.size.height < 700

            VStack(spacing: 0) {
                Spacer(minLength: compact ? 24 : 40)

                Text("🌍")
                    .font(.system(size: compact ? 44 : 56))

                Text("Ne perds jamais\nta progression")
                    .font(.system(size: compact ? 24 : 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Connecte-toi pour jouer en ligne, sauvegarder ta progression et défier tes amis.")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: compact ? 20 : 32)

                if auth.isSigningIn {
                    ProgressView().tint(Theme.primary)
                        .padding(.bottom, 10)
                }

                VStack(spacing: compact ? 10 : 14) {
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

                    Button("Continuer sans compte") {
                        Haptics.tap()
                        onFinished()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .disabled(auth.isSigningIn)
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 2)
                }
            )
            .alert("Erreur", isPresented: $auth.showError) {
                Button("OK") {}
            } message: {
                Text(auth.errorMessage)
            }
        }
    }

    private func afterSignIn() async {
        guard online.isSignedIn else { return }
        await online.syncProfile(localElo: model.store.progress.elo)
        await online.refreshFriends()
        onFinished()
    }
}

#Preview {
    OnboardingAccountStep(onFinished: {})
}
