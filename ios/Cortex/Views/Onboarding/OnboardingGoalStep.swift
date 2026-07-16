import SwiftUI

/// Single-select motivation step, mirrors the pill-list pattern used
/// across the onboarding flow.
struct OnboardingGoalStep: View {
    @Binding var selection: LearningGoal?
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let rowFont: CGFloat = compact ? 17 : 19
            let rowPadding: CGFloat = compact ? 16 : 20

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Avec Minduel,\ntu veux surtout :",
                    emoji: "🎯"
                )
                .frame(height: compact ? 110 : 140)

                ScrollView {
                    VStack(spacing: compact ? 10 : 12) {
                        ForEach(Array(LearningGoal.allCases.enumerated()), id: \.element) { index, goal in
                            goalRow(goal, fontSize: rowFont, vPadding: rowPadding)
                                .staggeredAppear(index)
                        }
                    }
                    .padding(.top, 8)
                }

                Button("Sélectionner") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(selection == nil)
                .opacity(selection == nil ? 0.4 : 1)
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 2)
                }
            )
        }
    }

    private func goalRow(_ goal: LearningGoal, fontSize: CGFloat, vPadding: CGFloat) -> some View {
        let isSelected = selection == goal
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.25)) { selection = goal }
        } label: {
            HStack(spacing: 12) {
                Text(goal.emoji)
                    .font(.system(size: 28))
                Text(goal.label)
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
    OnboardingGoalStep(selection: .constant(.learn), onNext: {})
}
