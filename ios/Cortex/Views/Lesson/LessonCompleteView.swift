import SwiftUI

struct LessonCompleteView: View {
    let xp: Int
    let accuracy: Double
    let streak: Int
    let onDone: () -> Void

    @State private var hasAppeared: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.14))
                    .frame(width: 170, height: 170)
                Image(accuracy == 1 ? "MascotJump" : "MascotWave")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 132)
                    .accessibilityHidden(true)
            }
            .scaleEffect(hasAppeared ? 1 : 0.3)

            VStack(spacing: 6) {
                Text("Leçon terminée !")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(accuracy == 1 ? "Sans faute, bravo 🎉" : "Continue comme ça, ça rentre !")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .opacity(hasAppeared ? 1 : 0)

            HStack(spacing: 12) {
                statCard(title: "XP", value: "+\(xp)", icon: "bolt.fill", color: Theme.gold)
                statCard(title: "Précision", value: "\(Int(accuracy * 100)) %", icon: "target", color: Theme.success)
                statCard(title: "Série", value: "\(streak)", icon: "flame.fill", color: Theme.primary)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 24)

            Spacer()
            Button("Continuer", action: onDone)
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(20)
        .background(Theme.background)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
    }
}
