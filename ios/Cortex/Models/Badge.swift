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

/// One-off achievements recorded the moment they happen.
enum BadgeFlag: String, Codable {
    case masterLeague, arenaKing, earlyBird, nightOwl, friendWin
}

/// A collectible badge. Its number matches the generated artwork
/// (`Badge01`, `Badge02`, …) so new grids drop straight in.
struct Badge: Identifiable, Hashable {
    enum Requirement: Hashable {
        case theme(disciplineId: String, tier: BadgeTier)
        /// A whole chapter cleared in this many different themes.
        case chaptersInThemes(Int)
        /// This tier reached in every theme.
        case allThemes(BadgeTier)
        case streak(days: Int)
        case duelWins(Int)
        case perfectRings(Int)
        case correctAnswers(Int)
        /// Correct answers given in under 2 seconds.
        case fastAnswers(Int)
        case flag(BadgeFlag)
    }

    let number: Int
    let name: String
    let requirement: Requirement
    let rarity: BadgeRarity

    var id: String { String(format: "badge-%02d", number) }
    var imageName: String { String(format: "Badge%02d", number) }

    /// Badges 1–40 carry their name on a ribbon; the last ten are bare icons
    /// whose name is written by the app.
    var hasNameInArt: Bool { number <= 40 }

    /// Unit shown under the progress bar, e.g. "ronds réussis". Nil for
    /// one-off achievements, which have no partial progress.
    var progressUnit: String? {
        switch requirement {
        case .theme: return "ronds réussis"
        case .chaptersInThemes, .allThemes: return "thèmes"
        case .streak: return "jours de série (record)"
        case .duelWins: return "victoires"
        case .perfectRings: return "ronds sans faute"
        case .correctAnswers: return "bonnes réponses"
        case .fastAnswers: return "réponses éclair"
        case .flag: return nil
        }
    }

    /// Badges stay hidden until their artwork is in the asset catalog.
    var hasArtwork: Bool { UIImage(named: imageName) != nil }

    /// Short "how to earn it" line, e.g. "Termine 1/3 d'Histoire".
    func conditionText(themeName: String) -> String {
        switch requirement {
        case .theme(_, let tier):
            switch tier {
            case .bronze: return "Termine 1/3 \(Self.ofTheme(themeName))"
            case .argent: return "Termine 2/3 \(Self.ofTheme(themeName))"
            case .or: return "Termine \(Self.theTheme(themeName)) à 100 %"
            }
        case .chaptersInThemes(let count):
            return "Termine un chapitre dans \(count) thèmes différents"
        case .allThemes(let tier):
            switch tier {
            case .bronze: return "Obtiens le Bronze dans tous les thèmes"
            case .argent: return "Obtiens l'Argent dans tous les thèmes"
            case .or: return "Obtiens l'Or dans tous les thèmes"
            }
        case .streak(let days):
            return "Atteins une série de \(days) jours"
        case .duelWins(let count):
            return count == 1 ? "Gagne ton premier duel" : "Gagne \(count) duels"
        case .perfectRings(let count):
            return count == 1 ? "Termine un rond sans aucune erreur" : "Termine \(count) ronds sans aucune erreur"
        case .correctAnswers(let count):
            return "Donne \(count.formatted(.number.locale(Locale(identifier: "fr_FR")))) bonnes réponses"
        case .fastAnswers(let count):
            return "Donne \(count) bonnes réponses en moins de 2 secondes"
        case .flag(let flag):
            switch flag {
            case .masterLeague: return "Atteins la division Maître en classé"
            case .arenaKing: return "Gagne une partie à 10 joueurs ou plus"
            case .earlyBird: return "Termine une leçon avant 7 h du matin"
            case .nightOwl: return "Termine une leçon après 23 h"
            case .friendWin: return "Gagne un duel contre un ami"
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

    private static let themeBadges: [Badge] =
        themeTrio("histoire", start: 1, names: ["Apprenti chroniqueur", "Gardien des archives", "Maître du Temps"])
        + themeTrio("sciences", start: 4, names: ["Petit chimiste", "Explorateur de l'atome", "Génie des sciences"])
        + themeTrio("geographie", start: 7, names: ["Routard", "Globe-trotteur", "Maître cartographe"])
        + themeTrio("litterature", start: 10, names: ["Rat de bibliothèque", "Plume d'argent", "Grand écrivain"])
        + themeTrio("arts", start: 13, names: ["Artiste en herbe", "Virtuose", "Chef-d'œuvre"])
        + themeTrio("nature", start: 16, names: ["Petit naturaliste", "Ranger", "Gardien de la nature"])
        + themeTrio("technologie", start: 19, names: ["Bidouilleur", "Ingénieur", "Commandant de bord"])
        + themeTrio("football", start: 22, names: ["Espoir du foot", "Titulaire", "Légende du foot"])

    private static let careerBadges: [Badge] = [
        Badge(number: 25, name: "Curieux", requirement: .chaptersInThemes(4), rarity: .rare),
        Badge(number: 26, name: "Touche-à-tout", requirement: .allThemes(.bronze), rarity: .epique),
        Badge(number: 27, name: "Encyclopédie vivante", requirement: .allThemes(.or), rarity: .legendaire),
        Badge(number: 28, name: "Flamme naissante", requirement: .streak(days: 7), rarity: .commun),
        Badge(number: 29, name: "Feu de camp", requirement: .streak(days: 30), rarity: .commun),
        Badge(number: 30, name: "Brasier", requirement: .streak(days: 100), rarity: .rare),
        Badge(number: 31, name: "Volcan", requirement: .streak(days: 200), rarity: .rare),
        Badge(number: 32, name: "Une année de feu", requirement: .streak(days: 365), rarity: .epique),
        Badge(number: 33, name: "Phénix", requirement: .streak(days: 500), rarity: .epique),
        Badge(number: 34, name: "Flamme éternelle", requirement: .streak(days: 730), rarity: .legendaire),
        Badge(number: 35, name: "Premier duel", requirement: .duelWins(1), rarity: .commun),
        Badge(number: 36, name: "Duelliste", requirement: .duelWins(10), rarity: .commun),
        Badge(number: 37, name: "Gladiateur", requirement: .duelWins(50), rarity: .rare),
        Badge(number: 38, name: "Champion", requirement: .duelWins(100), rarity: .rare),
        Badge(number: 39, name: "Conquérant", requirement: .duelWins(250), rarity: .epique),
        Badge(number: 40, name: "Invincible", requirement: .duelWins(500), rarity: .legendaire),
        Badge(number: 41, name: "Diamant", requirement: .flag(.masterLeague), rarity: .epique),
        Badge(number: 42, name: "Roi de l'arène", requirement: .flag(.arenaKing), rarity: .epique),
        Badge(number: 43, name: "Sans-faute", requirement: .perfectRings(1), rarity: .commun),
        Badge(number: 44, name: "Perfectionniste", requirement: .perfectRings(25), rarity: .rare),
        Badge(number: 45, name: "Mille neurones", requirement: .correctAnswers(1_000), rarity: .rare),
        Badge(number: 46, name: "Cerveau d'acier", requirement: .correctAnswers(10_000), rarity: .legendaire),
        Badge(number: 47, name: "Lève-tôt", requirement: .flag(.earlyBird), rarity: .commun),
        Badge(number: 48, name: "Oiseau de nuit", requirement: .flag(.nightOwl), rarity: .commun),
        Badge(number: 49, name: "Éclair", requirement: .fastAnswers(50), rarity: .rare),
        Badge(number: 50, name: "Ami fidèle", requirement: .flag(.friendWin), rarity: .commun)
    ]

    /// Every badge in collection order.
    static let all: [Badge] = themeBadges + careerBadges
}
