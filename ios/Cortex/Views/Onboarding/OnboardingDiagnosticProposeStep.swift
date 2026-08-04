import SwiftUI

/// Optional step after the mini-quiz: offers a ~3-minute diagnostic across
/// all disciplines to adapt the suggested path. Fully skippable.
struct OnboardingDiagnosticProposeStep: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geo in
            // Everything (mascot, copy, benefits card, buttons) must be
            // visible at once — no scrolling — so sizes shrink together as
            // available height drops.
            let veryCompact = geo.size.height < 640
            let compact = geo.size.height < 700
            let titleSize: CGFloat = veryCompact ? 22 : (compact ? 25 : 32)
            let mascotHeight: CGFloat = veryCompact ? 64 : (compact ? 80 : 150)
            let stackSpacing: CGFloat = veryCompact ? 10 : (compact ? 14 : 24)

            VStack(spacing: 0) {
                VStack(spacing: stackSpacing) {
                    Image("MascotWave")
                        .resizable()
                        .scaledToFit()
                        .frame(height: mascotHeight)
                        .padding(.top, veryCompact ? 2 : (compact ? 4 : 12))

                    VStack(alignment: .leading, spacing: veryCompact ? 6 : 12) {
                        Text("On évalue ton niveau dans les 7 domaines ?")
                            .font(.system(size: titleSize, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.primary)
                                .frame(width: veryCompact ? 28 : 36, height: veryCompact ? 28 : 36)
                                .background(Circle().fill(Theme.primary.opacity(0.12)))

                            Text("Environ 3 minutes")
                                .font(.system(size: veryCompact ? 16 : 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                        }

                        if !veryCompact {
                            Text("Pour adapter ton parcours à tes points forts et à tes lacunes.")
                                .font(.system(size: compact ? 17 : 19, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: veryCompact ? 8 : 12) {
                        Text("Ce que ça donne :")
                            .font(.system(size: veryCompact ? 16 : 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)

                        benefitRow(icon: "chart.bar.fill", text: "Un aperçu par discipline", compact: veryCompact)
                        benefitRow(icon: "arrow.up.forward.circle.fill", text: "Un parcours recommandé dans ton ordre idéal", compact: veryCompact)
                        benefitRow(icon: "shared.with.you.circle.fill", text: "Un résultat facile à partager", compact: veryCompact)
                    }
                    .padding(veryCompact ? 14 : 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, compact ? 4 : 8)

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button("C'est parti") {
                        Haptics.success()
                        onStart()
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.ink, textColor: Theme.gold))

                    Button("Passer") {
                        Haptics.tap()
                        onSkip()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 0)
                }
            )
        }
    }

    private func benefitRow(icon: String, text: String, compact: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 15 : 17, weight: .bold))
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingDiagnosticProposeStep(onStart: {}, onSkip: {})
}
