import SwiftUI

/// First screen of the onboarding flow: logo, a slogan revealed word by word,
/// then the promises of Minduel one by one, and finally the entry points.
struct OnboardingWelcomeStep: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    /// How many reveal beats have played (logo, slogan words, promises, buttons).
    @State private var beat: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Promise: Identifiable {
        let id: Int
        let icon: String
        let color: Color
        let text: String
    }

    private static let sloganWords: [String] = ["Le", "savoir", "qui", "se", "joue."]

    private static let promises: [Promise] = [
        Promise(id: 0, icon: "brain.head.profile.fill", color: Theme.primary, text: "5 minutes par jour pour devenir incollable"),
        Promise(id: 1, icon: "bolt.fill", color: Theme.kahootBlue, text: "Des duels en direct contre de vrais joueurs"),
        Promise(id: 2, icon: "trophy.fill", color: Theme.gold, text: "Des ligues, des badges et ta série à tenir"),
        Promise(id: 3, icon: "globe.europe.africa.fill", color: Theme.success, text: "Histoire, sciences, géo, culture pop…")
    ]

    private var logoBeat: Int { 1 }
    private var firstWordBeat: Int { 2 }
    private var firstPromiseBeat: Int { firstWordBeat + Self.sloganWords.count }
    private var buttonsBeat: Int { firstPromiseBeat + Self.promises.count }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let mascotHeight: CGFloat = compact ? 86 : 118
            let titleSize: CGFloat = compact ? 40 : 50
            let sloganSize: CGFloat = compact ? 24 : 29

            VStack(spacing: 0) {
                Spacer(minLength: compact ? 8 : 16)

                VStack(spacing: compact ? 6 : 10) {
                    Image("MascotWave")
                        .resizable()
                        .scaledToFit()
                        .frame(height: mascotHeight)
                        .accessibilityHidden(true)
                    HStack(spacing: 2) {
                        Text("Min").foregroundStyle(Theme.ink)
                        Text("duel").foregroundStyle(Theme.primary)
                    }
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)
                }
                .modifier(Reveal(isShown: beat >= logoBeat, distance: 14))

                sloganLine(size: sloganSize)
                    .padding(.top, compact ? 8 : 12)

                Spacer(minLength: compact ? 16 : 28)

                VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                    ForEach(Self.promises) { promise in
                        promiseRow(promise, compact: compact)
                            .modifier(Reveal(isShown: beat >= firstPromiseBeat + promise.id, distance: 18))
                    }
                }
                .frame(maxWidth: 420)

                Spacer(minLength: compact ? 20 : 32)

                VStack(spacing: compact ? 10 : 14) {
                    Button("Commencer", action: onStart)
                        .buttonStyle(ChunkyButtonStyle(color: Theme.primary))

                    Button("J'ai déjà un compte", action: onSkip)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(minHeight: 44)
                }
                .modifier(Reveal(isShown: beat >= buttonsBeat, distance: 20))
                .padding(.bottom, compact ? 6 : 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 0)
                }
                .ignoresSafeArea()
            )
        }
        .task { await playReveal() }
    }

    private func sloganLine(size: CGFloat) -> some View {
        HStack(spacing: size * 0.26) {
            ForEach(Array(Self.sloganWords.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .italic(index >= 3)
                    .foregroundStyle(index >= 3 ? Theme.primary : Theme.ink)
                    .modifier(Reveal(isShown: beat >= firstWordBeat + index, distance: 10))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.sloganWords.joined(separator: " "))
    }

    private func promiseRow(_ promise: Promise, compact: Bool) -> some View {
        let tile: CGFloat = compact ? 36 : 42
        return HStack(spacing: 14) {
            Image(systemName: promise.icon)
                .font(.system(size: tile * 0.44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: tile, height: tile)
                .background(RoundedRectangle(cornerRadius: tile * 0.32).fill(promise.color.gradient))
                .shadow(color: promise.color.opacity(0.3), radius: 6, y: 3)
            Text(promise.text)
                .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Plays the beats one after another; with Reduce Motion everything shows at once.
    private func playReveal() async {
        guard beat == 0 else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { beat = buttonsBeat }
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.smooth(duration: 0.8)) { beat = logoBeat }
        try? await Task.sleep(for: .milliseconds(550))
        for _ in Self.sloganWords {
            withAnimation(.smooth(duration: 0.7)) { beat += 1 }
            try? await Task.sleep(for: .milliseconds(150))
        }
        try? await Task.sleep(for: .milliseconds(350))
        for _ in Self.promises {
            withAnimation(.smooth(duration: 0.75)) { beat += 1 }
            try? await Task.sleep(for: .milliseconds(320))
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.smooth(duration: 0.8)) { beat = buttonsBeat }
    }
}

/// Soft reveal: fades in, rises a few points and comes into focus.
private struct Reveal: ViewModifier {
    let isShown: Bool
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .blur(radius: isShown ? 0 : 8)
            .offset(y: isShown ? 0 : distance)
    }
}

#Preview {
    OnboardingWelcomeStep(onStart: {}, onSkip: {})
}
