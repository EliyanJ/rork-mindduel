import SwiftUI
import UIKit

/// Central design tokens. Every surface/ink token adapts to the phone's
/// light/dark setting; brand accents stay identical in both modes.
enum Theme {
    /// Builds a color that resolves differently in light and dark mode.
    static func adaptive(light: String, dark: String) -> Color {
        let lightColor = UIColor(Color(hex: light))
        let darkColor = UIColor(Color(hex: dark))
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }

    static let background = adaptive(light: "FFFFFF", dark: "131F24")
    static let card = adaptive(light: "FFFFFF", dark: "1C2B33")
    /// Soft canvas used by the Thèmes screens so the pastel packs stand out.
    static let canvas = adaptive(light: "F6F5FA", dark: "131F24")
    /// Raised band slightly lighter than the background (e.g. "À suivre").
    static let raised = adaptive(light: "F7F7F7", dark: "202F36")
    static let line = adaptive(light: "ECECEC", dark: "37464F")
    static let ink = adaptive(light: "3B2E28", dark: "F1F7FB")
    static let inkMuted = adaptive(light: "9B8A7C", dark: "8A9BA6")
    static let primary = Color(hex: "FF6B00")
    static let success = Color(hex: "3DD62C")
    static let danger = Color(hex: "FF3B5C")
    static let gold = Color(hex: "FFC700")
    static let lockedFill = adaptive(light: "E5E5E5", dark: "37464F")
    /// Icon tint on a locked tile.
    static let lockedInk = adaptive(light: "AFAFAF", dark: "52656D")
    /// Link-style blue used for outline buttons ("AVANCER ICI ?").
    static let link = adaptive(light: "1899D6", dark: "49C0F8")
    /// Dark, high-contrast button face that stays dark in both modes.
    static let contrastButton = adaptive(light: "3B2E28", dark: "2B3A42")
    /// Black in light mode, white in dark: used to deepen/lighten accents
    /// so they stay readable on their pastel tint.
    static let deepen = adaptive(light: "000000", dark: "FFFFFF")
    /// Diamonds, the soft currency (spent on lesson bolts and hearts).
    static let livres = Color(hex: "1CB0F6")
    /// Lesson bolts: how many lessons are left today. Warm yellow so they
    /// never get confused with the turquoise duel bolts.
    static let lessonBolt = Color(hex: "FFB800")

    /// Soft tinted surface for a theme/accent color, light or dark.
    static func pastel(_ color: Color, strength: Double = 0.72) -> Color {
        color.mix(with: background, by: strength)
    }

    /// Accent darkened (light mode) or lightened (dark mode) for text on
    /// its own pastel.
    static func pastelInk(_ color: Color) -> Color {
        color.mix(with: deepen, by: 0.18)
    }

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

    /// Game-screen palette (lobbies, live quiz, results) — same adaptive
    /// surfaces as the rest of the app.
    static let quizBackground = background
    static let quizCard = card
    static let quizCanvas = canvas
    static let quizLine = line
    static let quizInk = ink
    static let quizInkMuted = inkMuted
    /// Fixed dark ink for drawn faces (avatars) that sit on bright skins.
    static let faceInk = Color(hex: "3B2E28")

    /// Kahoot-style answer palette.
    static let kahootRed = Color(hex: "E8384F")
    static let kahootBlue = Color(hex: "1368CE")
    static let kahootYellow = Color(hex: "E8AA00")
    static let kahootGreen = Color(hex: "26890C")
}

extension Discipline {
    var color: Color { Color(hex: colorHex) }
}
