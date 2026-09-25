import SwiftUI

/// Shown after the actual tutorial reports success; nickname validation stays with the caller.
struct TutorialNameView: View {
    @Binding var name: String
    let onChooseWeapons: () -> Void

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            TutorialScreenStyle.eyebrow("Tutoriel terminé")
            Image("MascotTrophy")
                .resizable()
                .scaledToFit()
                .frame(height: 155)
                .accessibilityHidden(true)
            TutorialScreenStyle.heading("Une légende est née.")
            Text("Comment veux-tu qu’on t’appelle ?")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
            TextField("Ton pseudo", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(18)
                .background(.white, in: .rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5) }
                .accessibilityLabel("Pseudo de ton personnage")
            Spacer()
            Button("Choisir mes objectifs", action: onChooseWeapons)
                .buttonStyle(ChunkyButtonStyle())
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TutorialScreenStyle.backdrop() }
    }
}

#Preview {
    TutorialNameView(name: .constant("Alex"), onChooseWeapons: {})
}
