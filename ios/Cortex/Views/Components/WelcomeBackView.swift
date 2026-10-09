import SwiftUI

/// Remembers when the player last opened Minduel, to greet them after a break.
enum ReturnTracker {
    private static let key = "minduel.lastOpenedAt"
    /// Absence (in days) after which the "welcome back" screen shows up.
    static let threshold: Int = 3

    /// Returns true when the player has been away long enough, then records
    /// the current visit.
    static func checkAndRecord(now: Date = .now) -> Bool {
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: key) as? Date
        defaults.set(now, forKey: key)
        guard let last else { return false }
        let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
        return days >= threshold
    }

    static func touch() {
        UserDefaults.standard.set(Date.now, forKey: key)
    }
}

/// Full-screen "c'est vraiment toi !?" greeting with a bouncing mascot,
/// shown when the player comes back after several days away.
struct WelcomeBackView: View {
    let name: String
    let onContinue: () -> Void

    @State private var mascotIn: Bool = false
    @State private var isHopping: Bool = false
    @State private var textIn: Bool = false
    @State private var buttonIn: Bool = false
    @State private var sparkle: Bool = false

    var body: some View {
        ZStack {
            Theme.duelBackground.ignoresSafeArea()
            RadialGradient(colors: [Theme.primary.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
                .opacity(mascotIn ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        let angle = Double(index) / 6 * 2 * .pi
                        Image(systemName: "sparkle")
                            .font(.system(size: index.isMultiple(of: 2) ? 20 : 13, weight: .bold))
                            .foregroundStyle(index.isMultiple(of: 2) ? Theme.gold : .white.opacity(0.8))
                            .offset(x: cos(angle) * (sparkle ? 130 : 60), y: sin(angle) * (sparkle ? 120 : 50))
                            .opacity(sparkle ? 0 : 1)
                            .scaleEffect(sparkle ? 1.2 : 0.4)
                    }
                    Ellipse()
                        .fill(.black.opacity(0.35))
                        .frame(width: isHopping ? 120 : 150, height: 26)
                        .offset(y: 110)
                    Image("MascotWave")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .offset(y: isHopping ? -18 : 0)
                        .rotationEffect(.degrees(isHopping ? -3 : 3))
                        .scaleEffect(mascotIn ? 1 : 0.2, anchor: .bottom)
                        .accessibilityHidden(true)
                }
                .frame(height: 280)

                Text("\(name), c'est vraiment toi !?")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 36)
                    .opacity(textIn ? 1 : 0)
                    .offset(y: textIn ? 0 : 16)
                Text("Ça fait plaisir de te revoir. Ta prochaine leçon t'attend !")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 10)
                    .opacity(textIn ? 1 : 0)
                Spacer()
                Button {
                    Haptics.success()
                    onContinue()
                } label: {
                    Text("JE SUIS DE RETOUR !")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 30)
            }
        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { mascotIn = true }
            Haptics.medium()
            withAnimation(.easeOut(duration: 0.9)) { sparkle = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { isHopping = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { textIn = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { buttonIn = true }
        }
    }
}

#Preview {
    WelcomeBackView(name: "Eliyan") {}
}
