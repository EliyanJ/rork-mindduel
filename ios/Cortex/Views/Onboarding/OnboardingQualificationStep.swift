import SwiftUI

/// Light qualification step: self-assessed level and preferred learning moment.
struct OnboardingQualificationStep: View {
    @Binding var perceivedLevel: PerceivedLevel?
    @Binding var preferredTime: PreferredLearningTime?
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let rowFont: CGFloat = compact ? 17 : 19
            let rowPadding: CGFloat = compact ? 16 : 18
            let sectionTitle: CGFloat = compact ? 18 : 20

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Un peu plus\nsur toi :",
                    emoji: "🧭",
                    subtitle: "On adapte la difficulté et les rappels à ton rythme."
                )
                .frame(height: compact ? 150 : 180)

                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 16 : 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ton niveau en culture générale")
                                .font(.system(size: sectionTitle, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)

                            ForEach(Array(PerceivedLevel.allCases.enumerated()), id: \.element) { index, level in
                                optionRow(
                                    title: level.label,
                                    emoji: level.emoji,
                                    isSelected: perceivedLevel == level,
                                    fontSize: rowFont,
                                    vPadding: rowPadding
                                ) {
                                    Haptics.tap()
                                    withAnimation(.spring(duration: 0.25)) { perceivedLevel = level }
                                }
                                .staggeredAppear(index)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quand préfères-tu apprendre ?")
                                .font(.system(size: sectionTitle, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .padding(.top, 8)

                            ForEach(Array(PreferredLearningTime.allCases.enumerated()), id: \.element) { index, time in
                                optionRow(
                                    title: time.label,
                                    emoji: time.emoji,
                                    isSelected: preferredTime == time,
                                    fontSize: rowFont,
                                    vPadding: rowPadding
                                ) {
                                    Haptics.tap()
                                    withAnimation(.spring(duration: 0.25)) { preferredTime = time }
                                }
                                .staggeredAppear(index, delay: 0.3)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                Button("Continuer") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(perceivedLevel == nil || preferredTime == nil)
                .opacity(perceivedLevel == nil || preferredTime == nil ? 0.4 : 1)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 2)
                }
            )
        }
    }

    private func optionRow(title: String, emoji: String, isSelected: Bool, fontSize: CGFloat, vPadding: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, vPadding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.gold.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Theme.gold : Theme.line, lineWidth: isSelected ? 2.5 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingQualificationStep(
        perceivedLevel: .constant(.beginner),
        preferredTime: .constant(.morning),
        onNext: {}
    )
}
