import SwiftUI

/// First screen of the onboarding flow: logo, promise, entry points.
struct OnboardingWelcomeStep: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let mascotHeight: CGFloat = compact ? 90 : 128
            let titleSize: CGFloat = compact ? 40 : 52
            let subtitleSize: CGFloat = compact ? 20 : 24
            let topicSpacing: CGFloat = compact ? 8 : 10
            let bottomSpacing: CGFloat = compact ? 8 : 12

            VStack(spacing: 0) {
                Spacer(minLength: compact ? 8 : 12)

                Image("MascotWave")
                    .resizable()
                    .scaledToFit()
                    .frame(height: mascotHeight)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .accessibilityHidden(true)

                VStack(spacing: compact ? 10 : 14) {
                    HStack(spacing: 2) {
                        Text("Min")
                            .foregroundStyle(Theme.ink)
                        Text("duel")
                            .foregroundStyle(Theme.primary)
                    }
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)

                    Text("Un peu de culture,\nbeaucoup de plaisir.")
                        .font(.system(size: subtitleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Sans effort.")
                        .font(.system(size: subtitleSize, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer(minLength: compact ? 12 : 20)

                VStack(spacing: topicSpacing) {
                    floatingTopic("Histoire", delay: 0, compact: compact)
                    floatingTopic("Sciences", delay: 0.08, compact: compact)
                    HStack(spacing: topicSpacing) {
                        Spacer(minLength: 0)
                        floatingTopic("Géographie", delay: 0.16, big: true, compact: compact)
                        Spacer(minLength: 0)
                    }
                    floatingTopic("Culture pop", delay: 0.24, compact: compact)
                    floatingTopic("Espace", delay: 0.32, compact: compact)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: compact ? 20 : 32)

                VStack(spacing: compact ? 10 : 14) {
                    Button("Commencer", action: onStart)
                        .buttonStyle(ChunkyButtonStyle(color: Theme.primary))

                    Button("J'ai déjà un compte", action: onSkip)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(.bottom, bottomSpacing)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 0)
                }
            )
            .onAppear {
                withAnimation(.spring(duration: 0.5)) { appeared = true }
            }
        }
    }

    private func floatingTopic(_ name: String, delay: Double, big: Bool = false, compact: Bool) -> some View {
        let fontSize: CGFloat = big ? (compact ? 18 : 22) : (compact ? 15 : 17)
        let hPadding: CGFloat = big ? (compact ? 18 : 24) : (compact ? 14 : 18)
        let vPadding: CGFloat = big ? (compact ? 12 : 16) : (compact ? 9 : 11)
        return Text(name)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(big ? .white : Theme.ink)
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(
                Capsule().fill(big ? Theme.primary : Theme.card)
            )
            .overlay(
                Capsule().stroke(big ? .clear : Theme.line, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(big ? 0.18 : 0), radius: 8, y: 4)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.spring(duration: 0.5).delay(delay), value: appeared)
    }
}

#Preview {
    OnboardingWelcomeStep(onStart: {}, onSkip: {})
}
