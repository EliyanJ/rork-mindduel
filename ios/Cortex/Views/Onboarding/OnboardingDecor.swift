import SwiftUI

/// A single floating cartoon doodle (book, pencil, lightbulb...) used as
/// ambient background decoration on onboarding screens.
private struct Doodle {
    let emoji: String
    let size: CGFloat
    let rotation: Double
    let opacity: Double
    let x: CGFloat // relative 0...1
    let y: CGFloat // relative 0...1
}

/// Scattered, softly-rotated cartoon doodles (little books, pencils, a
/// lightbulb) placed behind the content to give each onboarding screen a
/// playful "study corner" backdrop without competing with the text.
struct OnboardingDecor: View {
    var variant: Int = 0
    @State private var floated = false

    private var doodles: [Doodle] {
        let sets: [[Doodle]] = [
            [
                Doodle(emoji: "📚", size: 46, rotation: -18, opacity: 0.16, x: 0.86, y: 0.08),
                Doodle(emoji: "✏️", size: 34, rotation: 22, opacity: 0.14, x: 0.08, y: 0.2),
                Doodle(emoji: "📖", size: 40, rotation: 10, opacity: 0.13, x: 0.12, y: 0.82),
                Doodle(emoji: "💡", size: 32, rotation: -12, opacity: 0.15, x: 0.9, y: 0.78)
            ],
            [
                Doodle(emoji: "📖", size: 48, rotation: 14, opacity: 0.16, x: 0.9, y: 0.1),
                Doodle(emoji: "📝", size: 30, rotation: -20, opacity: 0.14, x: 0.1, y: 0.14),
                Doodle(emoji: "🔖", size: 30, rotation: 16, opacity: 0.13, x: 0.85, y: 0.84),
                Doodle(emoji: "📚", size: 38, rotation: -8, opacity: 0.14, x: 0.1, y: 0.8)
            ],
            [
                Doodle(emoji: "🧠", size: 40, rotation: -10, opacity: 0.15, x: 0.88, y: 0.12),
                Doodle(emoji: "📚", size: 44, rotation: 12, opacity: 0.14, x: 0.1, y: 0.16),
                Doodle(emoji: "✨", size: 26, rotation: 0, opacity: 0.18, x: 0.85, y: 0.8),
                Doodle(emoji: "✏️", size: 30, rotation: -24, opacity: 0.13, x: 0.12, y: 0.84)
            ]
        ]
        return sets[variant % sets.count]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(doodles.enumerated()), id: \.offset) { index, doodle in
                    Text(doodle.emoji)
                        .font(.system(size: doodle.size))
                        .opacity(doodle.opacity)
                        .rotationEffect(.degrees(doodle.rotation + (floated ? 4 : -4)))
                        .position(x: geo.size.width * doodle.x, y: geo.size.height * doodle.y)
                        .offset(y: floated ? -6 : 6)
                        .animation(
                            .easeInOut(duration: 3.2 + Double(index) * 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: floated
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { floated = true }
    }
}

#Preview {
    OnboardingDecor()
        .background(Theme.background)
}
