import SwiftUI

/// Asks the user for a nickname to personalize the home screen and profile.
struct OnboardingNicknameStep: View {
    @Binding var nickname: String
    let onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let fieldSize: CGFloat = compact ? 24 : 30
            let fieldPadding: CGFloat = compact ? 16 : 22

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Comment doit-on\nt'appeler ?",
                    emoji: "👋",
                    subtitle: "Ce surnom apparaîtra sur ton profil et dans les classements."
                )
                .staggeredAppear(0, delay: 0)
                .frame(height: compact ? 120 : 150)

                Spacer(minLength: compact ? 16 : 24)

                VStack(spacing: 18) {
                    TextField("Ton surnom", text: $nickname)
                        .font(.system(size: fieldSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, fieldPadding)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Theme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(isFocused ? Theme.primary : Theme.line, lineWidth: isFocused ? 3 : 1.5)
                        )
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
                        .staggeredAppear(0)
                        .onAppear {
                            isFocused = true
                        }
                }

                Spacer(minLength: compact ? 16 : 24)

                Button("Continuer") {
                    Haptics.medium()
                    isFocused = false
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 1)
                }
            )
        }
    }
}

#Preview {
    OnboardingNicknameStep(nickname: .constant(""), onNext: {})
}
