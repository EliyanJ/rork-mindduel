import SwiftUI

/// Two ways to represent a player visually: one of the hand-drawn characters
/// or a single fun emoji. `face` is a legacy value (the old custom face
/// builder) kept only so older saved configs still decode.
nonisolated enum AvatarMode: String, Codable {
    case face
    case emoji
    case illustration
}

/// Hand-drawn kawaii portraits bundled in the asset catalog
/// (`AvatarKawaii01` … `AvatarKawaii15`).
nonisolated struct AvatarIllustration: Identifiable, Hashable {
    let id: String
    let emoji: String

    var imageName: String { id }

    static let all: [AvatarIllustration] = [
        ("01", "📕"), ("02", "🌼"), ("03", "🤓"), ("04", "📚"), ("05", "😉"),
        ("06", "😜"), ("07", "🐱"), ("08", "🤔"), ("09", "🧕"), ("10", "🎧"),
        ("11", "💜"), ("12", "😎"), ("13", "🥰"), ("14", "📖"), ("15", "⭐️")
    ].map { AvatarIllustration(id: "AvatarKawaii\($0.0)", emoji: $0.1) }

    static func named(_ id: String?) -> AvatarIllustration? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

/// A player's chosen look, persisted locally and drawn everywhere the old
/// fixed emoji used to appear (profile, leaderboards, in-game rosters, emotes).
nonisolated struct AvatarConfig: Codable, Equatable {
    var mode: AvatarMode
    var backgroundColorHex: String
    var emoji: String
    /// Asset name of the chosen kawaii portrait when `mode == .illustration`.
    var illustrationId: String?

    static let emojiChoices: [String] = [
        "🐙", "🦄", "🐼", "🦊", "🐸", "🐨", "🐯", "🦁",
        "🐺", "🦉", "🐳", "🐲", "🤖", "👽", "🧠", "🔥"
    ]

    static let backgroundChoices: [String] = [
        "FFE3D0", "D8F1FF", "E4F8DA", "F4E3FF", "FFE0EC", "FFF4CC"
    ]

    static let `default` = AvatarConfig(
        mode: .illustration,
        backgroundColorHex: "FFE3D0",
        emoji: "🐙",
        illustrationId: AvatarIllustration.all.first?.id
    )

    /// Legacy face configs are shown as the default character.
    var normalized: AvatarConfig {
        guard mode == .face else { return self }
        var copy = self
        copy.mode = .illustration
        copy.illustrationId = copy.illustrationId ?? AvatarIllustration.all.first?.id
        return copy
    }

    /// A single emoji standing in for this avatar wherever only plain text
    /// can be shown (server profile field, opponent rosters, etc.).
    var representativeEmoji: String {
        switch mode {
        case .emoji: return emoji
        case .illustration, .face:
            return AvatarIllustration.named(illustrationId ?? AvatarIllustration.all.first?.id)?.emoji ?? "🙂"
        }
    }
}
