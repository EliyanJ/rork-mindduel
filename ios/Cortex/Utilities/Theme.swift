import SwiftUI

/// Central design tokens: warm cream learning side, deep navy duel arena.
enum Theme {
    static let background = Color(hex: "FDF8EF")
    static let card = Color.white
    static let line = Color(hex: "EAE0D0")
    static let ink = Color(hex: "3B2E28")
    static let inkMuted = Color(hex: "9B8A7C")
    static let primary = Color(hex: "FF5A21")
    static let success = Color(hex: "58B412")
    static let danger = Color(hex: "E5484D")
    static let gold = Color(hex: "FFB020")
    static let lockedFill = Color(hex: "E3D9C8")
    /// Distinct accent for the rubis currency, kept visually separate from
    /// the gold XP counter — a deep ruby red, not blue.
    static let livres = Color(hex: "D81E3A")

    /// Colors cycled along the unified learning path, one per stage.
    static let pathPalette: [Color] = [
        Color(hex: "FF5A21"),
        Color(hex: "1CB0F6"),
        Color(hex: "58B412"),
        Color(hex: "A560E8"),
        Color(hex: "FF4B8C"),
        Color(hex: "FFB020"),
        Color(hex: "2BB3A3")
    ]

    static func stageColor(_ index: Int) -> Color {
        pathPalette[index % pathPalette.count]
    }

    static let duelBackground = Color(hex: "141B2E")
    static let duelCard = Color(hex: "1E2A47")
    static let duelLine = Color(hex: "31406B")
    static let duelAccent = Color(hex: "22D3C5")
}

extension Discipline {
    var color: Color { Color(hex: colorHex) }
}
