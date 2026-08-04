import SwiftUI

/// Light qualification step: self-assessed level and preferred learning moment.
struct OnboardingQualificationStep: View {
    @Binding var perceivedLevel: PerceivedLevel?
    @Binding var preferredTime: PreferredLearningTime?
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            // Both questions plus the button must fit without scrolling, so
            // every metric shrinks together as available height drops.
            let veryCompact = geo.size.height < 640
            let compact = geo.size.height < 700
            let rowFont: CGFloat = veryCompact ? 14 : (compact ? 15 : 17)
            let rowPadding: CGFloat = veryCompact ? 9 : (compact ? 10 : 13)
            let rowEmoji: CGFloat = veryCompact ? 18 : 22
            let sectionTitle: CGFloat = veryCompact ? 14 : (compact ? 15 : 17)
            let rowSpacing: CGFloat = veryCompact ? 6 : 8
            let groupSpacing: CGFloat = veryCompact ? 10 : (compact ? 14 : 20)

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Un peu plus\nsur toi :",
                    emoji: "🧭",
                    // No subtitle here: with two questions to show at once,
                    // the extra sentence just eats space without adding
                    // anything the section titles below don't already say.
                    subtitle: nil
                )
                .frame(height: veryCompact ? 60 : (compact ? 76 : 100))

                VStack(alignment: .leading, spacing: groupSpacing) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        Text("Ton niveau en culture générale")
                            .font(.system(size: sectionTitle, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)

                        ForEach(Array(PerceivedLevel.allCases.enumerated()), id: \.element) { index, level in
                            optionRow(
                                title: level.label,
                                emoji: level.emoji,
                                isSelected: perceivedLevel == level,
                                fontSize: rowFont,
                                vPadding: rowPadding,
                                emojiSize: rowEmoji
                            ) {
                                Haptics.tap()
                                withAnimation(.spring(duration: 0.25)) { perceivedLevel = level }
                            }
                            .staggeredAppear(index)
                        }
                    }

                    VStack(alignment: .leading, spacing: rowSpacing) {
                        Text("Quand préfères-tu apprendre ?")
                            .font(.system(size: sectionTitle, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)

                        ForEach(Array(PreferredLearningTime.allCases.enumerated()), id: \.element) { index, time in
                            optionRow(
                                title: time.label,
                                emoji: time.emoji,
                                isSelected: preferredTime == time,
                                fontSize: rowFont,
                                vPadding: rowPadding,
                                emojiSize: rowEmoji
                            ) {
                                Haptics.tap()
                                withAnimation(.spring(duration: 0.25)) { preferredTime = time }
                            }
                            .staggeredAppear(index, delay: 0.3)
                        }
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 8)

                Button("Continuer") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(perceivedLevel == nil || preferredTime == nil)
                .opacity(perceivedLevel == nil || preferredTime == nil ? 0.4 : 1)
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

    private func optionRow(title: String, emoji: String, isSelected: Bool, fontSize: CGFloat, vPadding: CGFloat, emojiSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: emojiSize))
                Text(title)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, vPadding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Theme.gold.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.gold : Theme.line, lineWidth: isSelected ? 2 : 1.5)
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
