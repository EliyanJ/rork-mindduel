import SwiftUI

/// Renders a saved `AvatarConfig` — either a hand-drawn character or the chosen
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
            } else if let illustration = AvatarIllustration.named(config.illustrationId ?? AvatarIllustration.all.first?.id) {
                Image(illustration.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.primary.opacity(0.25), lineWidth: max(1.5, size * 0.03)))
    }
}
