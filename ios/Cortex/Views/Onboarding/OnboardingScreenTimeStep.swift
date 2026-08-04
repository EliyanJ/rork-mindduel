import SwiftUI

/// Asks the user to self-report their average daily screen time, then shows
/// an honest projection built purely from their own answer (no invented
/// marketing stats) before transitioning into the mini-quiz.
struct OnboardingScreenTimeStep: View {
    @Binding var selection: ScreenTimeBracket?
    let onNext: () -> Void

    @State private var revealProjection = false
    @State private var projectionScale: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            // Everything must fit without scrolling, so every metric shrinks
            // together as available height drops instead of clipping content.
            let compact = geo.size.height < 700
            let veryCompact = geo.size.height < 640
            let rowFont: CGFloat = veryCompact ? 15 : (compact ? 16 : 18)
            let rowPadding: CGFloat = veryCompact ? 10 : (compact ? 12 : 15)
            let rowSpacing: CGFloat = veryCompact ? 8 : 10

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Ton temps\nd'écran quotidien ?",
                    emoji: "📱",
                    subtitle: "Sois honnête, ça reste entre nous."
                )
                .frame(height: veryCompact ? 100 : (compact ? 120 : 150))

                VStack(alignment: .leading, spacing: rowSpacing) {
                    ForEach(Array(ScreenTimeBracket.allCases.enumerated()), id: \.element) { index, bracket in
                        optionRow(bracket, fontSize: rowFont, vPadding: rowPadding)
                            .staggeredAppear(index)
                    }
                }
                .padding(.top, 8)

                if let selection {
                    projectionCard(for: selection, compact: veryCompact)
                        .padding(.top, veryCompact ? 10 : 14)
                } else {
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 8)

                Button("Continuer") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(selection == nil)
                .opacity(selection == nil ? 0.4 : 1)
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

    private func optionRow(_ bracket: ScreenTimeBracket, fontSize: CGFloat, vPadding: CGFloat) -> some View {
        let isSelected = selection == bracket
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.25)) {
                selection = bracket
                revealProjection = false
                projectionScale = 0.6
            }
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                Haptics.medium()
                withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                    revealProjection = true
                    projectionScale = 1
                }
            }
        } label: {
            HStack(spacing: 14) {
                Text(bracket.label)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: fontSize + 1))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, vPadding)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Theme.gold.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.gold : Theme.line, lineWidth: isSelected ? 2.5 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// A single, unmissable punchline — no supporting sentence underneath —
    /// so the whole step reads at a glance with zero scrolling.
    private func projectionCard(for bracket: ScreenTimeBracket, compact: Bool) -> some View {
        VStack(spacing: 2) {
            Text("Tu perds")
                .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(bracket.lifetimeYears, specifier: "%.0f")")
                    .font(.system(size: compact ? 46 : 56, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primary)
                Text(bracket.lifetimeYears >= 2 ? "ans de vie" : "an de vie")
                    .font(.system(size: compact ? 20 : 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
            .scaleEffect(projectionScale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 14 : 18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.primary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primary.opacity(0.3), lineWidth: 1.5))
        .opacity(revealProjection ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                revealProjection = true
                projectionScale = 1
            }
        }
    }
}

#Preview {
    OnboardingScreenTimeStep(selection: .constant(.between4and6), onNext: {})
}
