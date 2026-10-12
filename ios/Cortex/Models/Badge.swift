import SwiftUI
import UIKit

/// How hard a badge is to get. Theme tiers map bronze → commun,
/// argent → rare, or → épique.
enum BadgeRarity: Int, Codable, Comparable {
    case commun, rare, epique, legendaire

    static func < (lhs: BadgeRarity, rhs: BadgeRarity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .commun: return "Commun"
        case .rare: return "Rare"
        case .epique: return "Épique"
        case .legendaire: return "Légendaire"
        }
    }

    var color: Color {
        switch self {
        case .commun: return Color(hex: "C27A4A")
        case .rare: return Color(hex: "6E86B8")
        case .epique: return Color(hex: "E8A817")
        case .legendaire: return Color(hex: "B04DE0")
        }
    }
}

/// One step of a theme: a third, two thirds, or the whole theme cleared.
enum BadgeTier: Int, Codable, CaseIterable {
    case bronze = 1, argent = 2, or = 3

    var rarity: BadgeRarity {
        switch self {
        case .bronze: return .commun
        case .argent: return .rare
        case .or: return .epique
        }
    }

    /// Rings that must be cleared, out of `total`, to earn this tier.
    func requiredRings(total: Int) -> Int {
        guard total > 0 else { return .max }
        switch self {
        case .bronze: return Int((Double(total) / 3).rounded(.up))
        case .argent: return Int((Double(total) * 2 / 3).rounded(.up))
        case .or: return total
        }
    }
}

/// A collectible badge. Its number matches the generated artwork
/// (`Badge01`, `Badge02`, …) so new grids drop straight in.
struct Badge: Identifiable, Hashable {
    enum Requirement: Hashable {
        case theme(disciplineId: String, tier: BadgeTier)
    }

    let number: Int
    let name: String
    let requirement: Requirement
    let rarity: BadgeRarity

    var id: String { String(format: "badge-%02d", number) }
    var imageName: String { String(format: "Badge%02d", number) }

    /// Badges stay hidden until their artwork is in the asset catalog.
    var hasArtwork: Bool { UIImage(named: imageName) != nil }

    /// Short "how to earn it" line, e.g. "1/3 d'Histoire".
    func conditionText(themeName: String) -> String {
        switch requirement {
        case .theme(_, let tier):
            switch tier {
            case .bronze: return "Termine 1/3 \(Self.ofTheme(themeName))"
            case .argent: return "Termine 2/3 \(Self.ofTheme(themeName))"
            case .or: return "Termine \(Self.theTheme(themeName)) à 100 %"
            }
        }
    }

    private static func startsWithVowel(_ name: String) -> Bool {
        guard let first = name.folding(options: .diacriticInsensitive, locale: .current).lowercased().first else { return false }
        return "aeiouyh".contains(first)
    }

    private static func ofTheme(_ name: String) -> String {
        startsWithVowel(name) ? "d'\(name)" : "de \(name)"
    }

    private static func theTheme(_ name: String) -> String {
        startsWithVowel(name) ? "l'\(name)" : "le thème \(name)"
    }

    // MARK: - Catalogue

    private static func themeTrio(_ disciplineId: String, start: Int, names: [String]) -> [Badge] {
        BadgeTier.allCases.enumerated().map { offset, tier in
            Badge(
                number: start + offset,
                name: names[offset],
                requirement: .theme(disciplineId: disciplineId, tier: tier),
                rarity: tier.rarity
            )
        }
    }

    /// Every badge in collection order.
    static let all: [Badge] =
        themeTrio("histoire", start: 1, names: ["Apprenti chroniqueur", "Gardien des archives", "Maître du Temps"])
        + themeTrio("sciences", start: 4, names: ["Petit chimiste", "Explorateur de l'atome", "Génie des sciences"])
        + themeTrio("geographie", start: 7, names: ["Routard", "Globe-trotteur", "Maître cartographe"])
        + themeTrio("litterature", start: 10, names: ["Rat de bibliothèque", "Plume d'argent", "Grand écrivain"])
        + themeTrio("arts", start: 13, names: ["Artiste en herbe", "Virtuose", "Chef-d'œuvre"])
        + themeTrio("nature", start: 16, names: ["Petit naturaliste", "Ranger", "Gardien de la nature"])
        + themeTrio("technologie", start: 19, names: ["Bidouilleur", "Ingénieur", "Commandant de bord"])
        + themeTrio("football", start: 22, names: ["Espoir du foot", "Titulaire", "Légende du foot"])
}
