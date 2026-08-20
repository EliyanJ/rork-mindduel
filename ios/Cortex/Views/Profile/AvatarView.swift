import SwiftUI

/// Renders a saved `AvatarConfig` — either the built 2D face or the chosen
/// stand-in emoji — inside a fixed circular frame so it drops into any
/// avatar-shaped slot (profile header, leaderboard rows, emote bubbles).
struct AvatarView: View {
    let config: AvatarConfig
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: config.backgroundColorHex))
            if config.mode == .emoji {
                Text(config.emoji)
                    .font(.system(size: size * 0.52))
            } else {
                faceLayer
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.primary.opacity(0.25), lineWidth: max(1.5, size * 0.03)))
    }

    private var faceLayer: some View {
        ZStack {
            Circle()
                .fill(config.skinTone.color)
                .frame(width: size * 0.74, height: size * 0.74)
            VStack(spacing: size * 0.1) {
                eyesRow
                mouthShape
            }
        }
    }

    private var eyesRow: some View {
        HStack(spacing: size * 0.14) {
            eyeShape
            eyeShape
        }
        .padding(.top, size * 0.02)
    }

    @ViewBuilder
    private var eyeShape: some View {
        let eyeSize = size * 0.1
        switch config.eyeStyle {
        case .round:
            Circle().fill(Theme.quizInk).frame(width: eyeSize, height: eyeSize)
        case .sleepy:
            Capsule().fill(Theme.quizInk).frame(width: eyeSize * 1.3, height: eyeSize * 0.35)
        case .star:
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: eyeSize, height: eyeSize)
                .foregroundStyle(Theme.quizInk)
        case .wink:
            Capsule().fill(Theme.quizInk).frame(width: eyeSize * 1.1, height: eyeSize * 0.3)
        case .wide:
            Circle().fill(Theme.quizInk).frame(width: eyeSize * 1.4, height: eyeSize * 1.4)
        case .happy:
            Capsule().fill(Theme.quizInk)
                .frame(width: eyeSize * 1.2, height: eyeSize * 0.4)
                .rotationEffect(.degrees(-20))
        }
    }

    @ViewBuilder
    private var mouthShape: some View {
        switch config.mouthStyle {
        case .smile:
            SmileShape().stroke(Theme.quizInk, style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round))
                .frame(width: size * 0.32, height: size * 0.14)
        case .grin:
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(Theme.quizInk)
                .frame(width: size * 0.34, height: size * 0.1)
        case .surprised:
            Circle().fill(Theme.quizInk).frame(width: size * 0.14, height: size * 0.14)
        case .cool:
            Capsule().fill(Theme.quizInk).frame(width: size * 0.28, height: size * 0.045)
        case .shy:
            Capsule().fill(Theme.quizInk.opacity(0.7)).frame(width: size * 0.16, height: size * 0.05)
        case .laugh:
            SmileShape().fill(Theme.quizInk)
                .frame(width: size * 0.34, height: size * 0.18)
        }
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
