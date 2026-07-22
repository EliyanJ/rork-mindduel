import SwiftUI

/// Full-screen congratulation shown right after a lesson unlocks new
/// content: a new chapter, a new difficulty tier, or (in the future) a
/// new theme. A celebratory badge with orbiting sparkles, then a claim CTA.
struct UnlockCelebrationView: View {
    enum Kind {
        case chapter(title: String)
        case level(DifficultyLevel, disciplineName: String)
        case theme(name: String, icon: String, color: Color)
    }

    let kind: Kind
    let onClaim: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var badgeBounce: Bool = false

    private var eyebrow: String {
        switch kind {
        case .chapter: return "Nouveau chapitre débloqué"
        case .level: return "Nouveau niveau débloqué"
        case .theme: return "Nouvelle thématique débloquée"
        }
    }

    private var highlighted: String {
        switch kind {
        case .chapter(let title): return title
        case .level(let level, let disciplineName): return "\(level.displayName) · \(disciplineName)"
        case .theme(let name, _, _): return name
        }
    }

    private var tint: Color {
        switch kind {
        case .chapter: return Theme.primary
        case .level: return Theme.gold
        case .theme(_, _, let color): return color
        }
    }

    private var icon: String {
        switch kind {
        case .chapter: return "book.fill"
        case .level: return "bolt.fill"
        case .theme(_, let icon, _): return icon
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            Text(eyebrow)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .opacity(hasAppeared ? 1 : 0)
            Text(highlighted)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .opacity(hasAppeared ? 1 : 0)

            Spacer(minLength: 8)

            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    sparkle(index: index)
                }
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 196, height: 196)
                Circle()
                    .stroke(tint, lineWidth: 4)
                    .frame(width: 168, height: 168)
                Circle()
                    .fill(Theme.card)
                    .frame(width: 150, height: 150)
                Image(systemName: icon)
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(tint)
            }
            .scaleEffect(badgeBounce ? 1 : 0.4)
            .opacity(hasAppeared ? 1 : 0)

            Spacer()

            Button {
                Haptics.success()
                onClaim()
            } label: {
                Text("Récupérer les récompenses")
            }
            .buttonStyle(ChunkyButtonStyle(color: tint))
        }
        .padding(20)
        .background(Theme.background)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                hasAppeared = true
            }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.55).delay(0.12)) {
                badgeBounce = true
            }
        }
    }

    private func sparkle(index: Int) -> some View {
        let angle = Double(index) / 8 * 360
        let radius: CGFloat = 118
        return Image(systemName: "sparkle")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tint.opacity(0.6))
            .offset(
                x: badgeBounce ? cos(angle * .pi / 180) * radius : 0,
                y: badgeBounce ? sin(angle * .pi / 180) * radius : 0
            )
            .opacity(badgeBounce ? 0.9 : 0)
            .scaleEffect(badgeBounce ? 1 : 0.2)
    }
}

#Preview {
    UnlockCelebrationView(kind: .chapter(title: "La Rome antique"), onClaim: {})
}
