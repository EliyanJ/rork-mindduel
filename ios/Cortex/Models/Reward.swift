import SwiftUI

/// Something the player wins: a mission chest, a finished lesson, a won
/// duel. Display-only kinds (`xp` already credited elsewhere, `rankPoints`
/// computed by the server) ride along so the reveal screen shows everything.
nonisolated struct Reward: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: String, Hashable, Sendable {
        case diamonds, heart, duelBolt, lessonBolt, xp, rankPoints
    }

    let kind: Kind
    let amount: Int

    var id: String { kind.rawValue }
}

extension Reward.Kind {
    var icon: String {
        switch self {
        case .diamonds: return "diamond.fill"
        case .heart: return "heart.fill"
        case .duelBolt: return "bolt.fill"
        case .lessonBolt: return "bolt.fill"
        case .xp: return "star.fill"
        case .rankPoints: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .diamonds: return Theme.livres
        case .heart: return Color(hex: "FF4B4B")
        case .duelBolt: return Theme.duelAccent
        case .lessonBolt: return Theme.lessonBolt
        case .xp: return Theme.gold
        case .rankPoints: return Theme.success
        }
    }

    func label(_ amount: Int) -> String {
        let plural = amount > 1
        switch self {
        case .diamonds: return plural ? "diamants" : "diamant"
        case .heart: return plural ? "cœurs" : "cœur"
        case .duelBolt: return plural ? "éclairs de duel" : "éclair de duel"
        case .lessonBolt: return plural ? "éclairs de leçon" : "éclair de leçon"
        case .xp: return "XP"
        case .rankPoints: return "points classés"
        }
    }
}

/// One reward reveal to present full screen.
struct RewardRevealItem: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let rewards: [Reward]
    var tint: Color = Theme.primary
}
