import SwiftUI

/// Replaces the old fabricated "85%" analyzing screen: shows the user's
/// real mini-quiz score and an encouraging message, then transitions into
/// the commitment step.
struct OnboardingQuizResultStep: View {
    let score: Int
    let total: Int
    let onFinished: () -> Void

    @State private var displayedScore = 0
    @State private var titleVisible = false
    @State private var captionVisible = false

    private var message: String {
        switch score {
        case total: return "Score parfait, tu es déjà redoutable !"
        case total - 1: return "Excellent ! Il ne manquait presque rien."
        case 0: return "Pas grave, c'est fait pour ça : on progresse ensemble."
        default: return "Beau début, et ce n'est que la première question de beaucoup d'autres."
        }
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let scoreSize: CGFloat = compact ? 64 : 88
            let totalSize: CGFloat = compact ? 30 : 40
            let mascotHeight: CGFloat = compact ? 72 : 96
            let messageSize: CGFloat = compact ? 18 : 22

            VStack(spacing: 0) {
                Spacer(minLength: compact ? 16 : 24)

                Image(score >= total - 1 ? "MascotJump" : "MascotWink")
                    .resizable()
                    .scaledToFit()
                    .frame(height: mascotHeight)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 10)
                    .accessibilityHidden(true)

                Text("Tu as trouvé")
                    .font(.system(size: compact ? 20 : 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 10)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(displayedScore)")
                        .font(.system(size: scoreSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("/\(total)")
                        .font(.system(size: totalSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 8)

                Text(message)
                    .font(.system(size: messageSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .opacity(captionVisible ? 1 : 0)
                    .offset(y: captionVisible ? 0 : 10)

                Spacer(minLength: compact ? 16 : 24)

                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { i in
                        Image(systemName: i < score ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundStyle(i < score ? Theme.ink : Theme.ink.opacity(0.25))
                            .scaleEffect(i < displayedScore ? 1 : 0.4)
                            .opacity(i < displayedScore ? 1 : 0.4)
                    }
                }
                .padding(.bottom, 8)

                Spacer(minLength: 12)

                Button("Et maintenant, à toi de jouer") {
                    Haptics.success()
                    onFinished()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.ink, textColor: Theme.gold))
                .opacity(captionVisible ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.gold)
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { titleVisible = true }
                try? await Task.sleep(for: .milliseconds(350))

                for step in 1...max(score, 1) where score > 0 {
                    try? await Task.sleep(for: .milliseconds(280))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        displayedScore = step
                    }
                    Haptics.tap()
                }
                if score == 0 {
                    try? await Task.sleep(for: .milliseconds(200))
                }

                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { captionVisible = true }
            }
        }
    }
}

#Preview {
    OnboardingQuizResultStep(score: 4, total: 5, onFinished: {})
}
