import SwiftUI

/// Two ways to represent a player visually: a built, interchangeable 2D face
/// (skin tone + eyes + mouth) or a single fun emoji standing in for the whole
/// avatar (an octopus, a robot, anything).
nonisolated enum AvatarMode: String, Codable {
    case face
    case emoji
}

nonisolated enum AvatarEyeStyle: String, Codable, CaseIterable, Identifiable {
    case round, sleepy, star, wink, wide, happy

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .round: return "circle.fill"
        case .sleepy: return "minus"
        case .star: return "star.fill"
        case .wink: return "eye.fill"
        case .wide: return "circle.circle.fill"
        case .happy: return "arrow.up"
        }
    }
}

nonisolated enum AvatarMouthStyle: String, Codable, CaseIterable, Identifiable {
    case smile, grin, surprised, cool, shy, laugh

    var id: String { rawValue }
}

nonisolated enum AvatarSkinTone: String, Codable, CaseIterable, Identifiable {
    case peach, tan, honey, almond, cocoa, porcelain

    var id: String { rawValue }
    var hex: String {
        switch self {
        case .peach: return "FFD9B8"
        case .tan: return "E8B180"
        case .honey: return "D99A5B"
        case .almond: return "C17F4E"
        case .cocoa: return "8A5638"
        case .porcelain: return "FFEFE0"
        }
    }
    var color: Color { Color(hex: hex) }
}

/// A player's chosen look, persisted locally and drawn everywhere the old
/// fixed emoji used to appear (profile, leaderboards, in-game rosters, emotes).
nonisolated struct AvatarConfig: Codable, Equatable {
    var mode: AvatarMode
    var skinTone: AvatarSkinTone
    var eyeStyle: AvatarEyeStyle
    var mouthStyle: AvatarMouthStyle
    var backgroundColorHex: String
    var emoji: String

    static let emojiChoices: [String] = [
        "🐙", "🦄", "🐼", "🦊", "🐸", "🐨", "🐯", "🦁",
        "🐺", "🦉", "🐳", "🐲", "🤖", "👽", "🧠", "🔥"
    ]

    static let backgroundChoices: [String] = [
        "FFE3D0", "D8F1FF", "E4F8DA", "F4E3FF", "FFE0EC", "FFF4CC"
    ]

    static let `default` = AvatarConfig(
        mode: .face,
        skinTone: .peach,
        eyeStyle: .round,
        mouthStyle: .smile,
        backgroundColorHex: "FFE3D0",
        emoji: "🐙"
    )

    /// A single emoji standing in for this avatar wherever only plain text
    /// can be shown (server profile field, opponent rosters, etc.).
    var representativeEmoji: String {
        mode == .emoji ? emoji : "🙂"
    }
}
