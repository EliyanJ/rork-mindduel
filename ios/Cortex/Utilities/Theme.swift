import SwiftUI

/// Central design tokens: clean white learning side, deep navy duel arena.
enum Theme {
    static let background = Color.white
    static let card = Color.white
    /// Soft lavender-grey canvas used by the Thèmes screens so the pastel
    /// packs stand out like in the reference app.
    static let canvas = Color(hex: "F6F5FA")
    static let line = Color(hex: "ECECEC")
    static let ink = Color(hex: "3B2E28")
    static let inkMuted = Color(hex: "9B8A7C")
    static let primary = Color(hex: "FF6B00")
    static let success = Color(hex: "3DD62C")
    static let danger = Color(hex: "FF3B5C")
    static let gold = Color(hex: "FFC700")
    static let lockedFill = Color(hex: "E3D9C8")
    /// Distinct accent for the rubis currency, kept visually separate from
    /// the gold XP counter — a deep ruby red, not blue.
    static let livres = Color(hex: "D81E3A")

    /// Colors cycled along the unified learning path, one per stage.
    static let pathPalette: [Color] = [
        Color(hex: "FF6B00"),
        Color(hex: "1CB0F6"),
        Color(hex: "3DD62C"),
        Color(hex: "9B4DFF"),
        Color(hex: "FF3D8A"),
        Color(hex: "FFC700"),
        Color(hex: "00D1B2")
    ]

    static func stageColor(_ index: Int) -> Color {
        pathPalette[index % pathPalette.count]
    }

    static let duelBackground = Color(hex: "141B2E")
    static let duelCard = Color(hex: "1E2A47")
    static let duelLine = Color(hex: "31406B")
    static let duelAccent = Color(hex: "22D3C5")

    /// Airy, white game-screen palette (lobbies, live quiz, results) — swaps
    /// out the old dark-navy "duel" surface for the same clean, bright feel
    /// as the rest of the app.
    static let quizBackground = Color.white
    static let quizCard = Color.white
    static let quizCanvas = Color(hex: "F6F5FA")
    static let quizLine = Color(hex: "ECECEC")
    static let quizInk = Color(hex: "3B2E28")
    static let quizInkMuted = Color(hex: "9B8A7C")

    /// Kahoot-style answer palette: one bold color + shape per option so a
    /// choice is identifiable at a glance, not just by its text.
    static let kahootRed = Color(hex: "E8384F")
    static let kahootBlue = Color(hex: "1368CE")
    static let kahootYellow = Color(hex: "E8AA00")
    static let kahootGreen = Color(hex: "26890C")
}

extension Discipline {
    var color: Color { Color(hex: colorHex) }
}
