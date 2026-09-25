import SwiftUI

/// Present after onboarding when the tutorial is available; the caller starts the actual tutorial.
struct TutorialStartView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            TutorialScreenStyle.eyebrow("Bienvenue dans Minduel")
            Image("MascotWave")
                .resizable()
                .scaledToFit()
                .frame(height: 190)
                .accessibilityHidden(true)
            TutorialScreenStyle.heading("Ton aventure\ncommence ici.")
            Text("Découvre le jeu à ton rythme, un défi à la fois.")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Commencer le tutoriel", action: onStart)
                .buttonStyle(ChunkyButtonStyle())
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TutorialScreenStyle.backdrop() }
    }
}

#Preview {
    TutorialStartView(onStart: {})
}
