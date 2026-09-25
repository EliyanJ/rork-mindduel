import SwiftUI

/// Shared visual language for the five handoff screens; does not own game progression.
enum TutorialScreenStyle {
    static let surface = Color(hex: "FFF9F2")
    static let peach = Color(hex: "FFE8D2")

    static func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(.largeTitle, design: .rounded, weight: .black))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .rounded, weight: .black))
            .tracking(2)
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(peach))
    }

    static func backdrop() -> some View {
        ZStack {
            surface
            Circle().fill(Theme.gold.opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 12)
                .offset(x: 160, y: -290)
            Circle().fill(Theme.primary.opacity(0.07))
                .frame(width: 380, height: 380)
                .blur(radius: 20)
                .offset(x: -150, y: 340)
        }
        .ignoresSafeArea()
    }
}
