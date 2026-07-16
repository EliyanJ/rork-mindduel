import SwiftUI

/// Asks the user to self-report their average daily screen time, then shows
/// an honest projection built purely from their own answer (no invented
/// marketing stats) before transitioning into the mini-quiz.
struct OnboardingScreenTimeStep: View {
    @Binding var selection: ScreenTimeBracket?
    let onNext: () -> Void

    @State private var revealProjection = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let rowFont: CGFloat = compact ? 17 : 19
            let rowPadding: CGFloat = compact ? 16 : 18

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Ton temps\nd'écran quotidien ?",
                    emoji: "📱",
                    subtitle: "Sois honnête, ça reste entre nous."
                )
                .frame(height: compact ? 150 : 180)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(ScreenTimeBracket.allCases.enumerated()), id: \.element) { index, bracket in
                            optionRow(bracket, fontSize: rowFont, vPadding: rowPadding)
                                .staggeredAppear(index)
                        }

                        if let selection {
                            projectionCard(for: selection)
                                .padding(.top, 8)
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
                .disabled(selection == nil)
                .opacity(selection == nil ? 0.4 : 1)
                .padding(.top, 4)
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
            }
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    revealProjection = true
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
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.primary)
                }
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

    private func projectionCard(for bracket: ScreenTimeBracket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("⏳")
                    .font(.system(size: 26))
                Text("À ce rythme, c'est environ")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkMuted)
            }
            Text("\(bracket.lifetimeYears, specifier: "%.0f") ans d'écran sur toute une vie")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Et si une petite partie de ce temps servait aussi à apprendre ?")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.primary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primary.opacity(0.3), lineWidth: 1.5))
        .opacity(revealProjection ? 1 : 0)
        .offset(y: revealProjection ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                revealProjection = true
            }
        }
    }
}

#Preview {
    OnboardingScreenTimeStep(selection: .constant(.between4and6), onNext: {})
}
