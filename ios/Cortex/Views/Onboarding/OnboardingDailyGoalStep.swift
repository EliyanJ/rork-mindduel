import SwiftUI

/// Daily-goal stepper: how many lessons the user wants to complete per day.
struct OnboardingDailyGoalStep: View {
    @Binding var count: Int
    let onNext: () -> Void

    private let range = 1...10

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let countSize: CGFloat = compact ? 60 : 76
            let labelSize: CGFloat = compact ? 20 : 24
            let stepperSize: CGFloat = compact ? 44 : 52

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Chaque jour,\ntu veux apprendre…",
                    emoji: "🚩",
                    subtitle: "Tu pourras modifier ton objectif plus tard."
                )
                .frame(height: compact ? 150 : 180)

                Spacer(minLength: compact ? 12 : 20)

                VStack(spacing: compact ? 16 : 22) {
                    Text("Je vise")
                        .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)

                    HStack(spacing: 28) {
                        stepperButton(systemImage: "minus", size: stepperSize) {
                            if count > range.lowerBound { count -= 1 }
                        }
                        Text("\(count)")
                            .font(.system(size: countSize, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.primary)
                            .contentTransition(.numericText())
                            .frame(minWidth: 110)
                        stepperButton(systemImage: "plus", size: stepperSize) {
                            if count < range.upperBound { count += 1 }
                        }
                    }

                    Text("apprentissage\(count > 1 ? "s" : "") par jour !")
                        .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Text("⚖️")
                        .font(.system(size: compact ? 20 : 24))
                    Text("Le bon mix entre plaisir et apprentissage !")
                        .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.gold.opacity(0.18)))
                .padding(.top, compact ? 16 : 24)

                Spacer(minLength: compact ? 16 : 24)

                Button("Je me lance !") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
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

    private func stepperButton(systemImage: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.2)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingDailyGoalStep(count: .constant(3), onNext: {})
}
