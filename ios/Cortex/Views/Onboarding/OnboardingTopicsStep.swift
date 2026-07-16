import SwiftUI

/// Multi-select topic picker built on the real content catalog.
struct OnboardingTopicsStep: View {
    let disciplines: [Discipline]
    @Binding var selection: Set<String>
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let chipPadding: CGFloat = compact ? 12 : 16
            let chipFont: CGFloat = compact ? 15 : 17

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Quels sujets\nte font envie ?",
                    emoji: "🪐",
                    subtitle: "Tu pourras modifier ta sélection plus tard."
                )
                .frame(height: compact ? 140 : 170)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(disciplines) { discipline in
                            chip(discipline, padding: chipPadding, fontSize: chipFont)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                Button("Sauvegarder") {
                    Haptics.medium()
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .disabled(selection.isEmpty)
                .opacity(selection.isEmpty ? 0.4 : 1)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 0)
                }
            )
        }
    }

    private func chip(_ discipline: Discipline, padding: CGFloat, fontSize: CGFloat) -> some View {
        let isSelected = selection.contains(discipline.id)
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.22)) {
                if isSelected {
                    selection.remove(discipline.id)
                } else {
                    selection.insert(discipline.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: discipline.icon)
                    .font(.system(size: fontSize - 2, weight: .bold))
                Text(discipline.name)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(isSelected ? discipline.color : Theme.card)
            )
            .overlay(
                Capsule().stroke(isSelected ? .clear : Theme.line, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingTopicsStep(disciplines: [], selection: .constant([]), onNext: {})
}
