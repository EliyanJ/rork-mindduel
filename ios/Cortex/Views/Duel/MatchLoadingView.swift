import SwiftUI

/// Display while joining a match. The owner replaces this view only when the match is actually ready.
struct MatchLoadingView: View {
    var status: String = "Connexion des joueurs…"
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            TutorialScreenStyle.eyebrow("Préparation du duel")
            ZStack {
                Circle()
                    .stroke(Theme.primary.opacity(0.18), lineWidth: 4)
                    .frame(width: 180, height: 180)
                    .scaleEffect(isPulsing ? 1.2 : 0.85)
                    .opacity(isPulsing ? 0.1 : 0.9)
                Circle()
                    .fill(TutorialScreenStyle.peach)
                    .frame(width: 140, height: 140)
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(Theme.primary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            TutorialScreenStyle.heading("Prêt à jouer ?")
            ProgressView()
                .tint(Theme.primary)
                .controlSize(.large)
                .accessibilityLabel(status)
            Text(status)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Text("La partie démarre dès que tout le monde est prêt.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { TutorialScreenStyle.backdrop() }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    MatchLoadingView()
}
