import Foundation

/// Server-side player profile (ranked identity).
///
/// Two ratings, deliberately separate:
/// - `elo` is the hidden skill rating. It drives matchmaking and weights the
///   difficulty telemetry, and is never shown as the player's rank.
/// - `points` is the visible ladder score. It rises on a win and falls on a
///   loss, sized by how strong the opponent was on hidden rating.
nonisolated struct PlayerProfile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var elo: Int
    /// Optional so profiles serialized before the rating split still decode.
    var points: Int?
    var wins: Int
    var losses: Int
    var draws: Int
    var friendCode: String
    /// Behaviour counter (finishing games, not abandoning lobbies/matches),
    /// entirely separate from skill. Optional so profiles synced before this
    /// field existed still decode; defaults to 0.
    var reputation: Int?
    /// Personal daily learning goal (1-3), set during onboarding and kept in
    /// sync server-side so it survives reinstalls/devices. Optional so
    /// profiles synced before this field existed still decode.
    var dailyGoal: Int?

    /// The number to show the player. Falls back to the hidden rating for
    /// profiles that predate the split.
    var displayPoints: Int { points ?? elo }
    var displayReputation: Int { reputation ?? 0 }
    var displayDailyGoal: Int { dailyGoal ?? 3 }
}

nonisolated struct RankedEntry: Codable, Identifiable, Hashable {
    let rank: Int
    let id: String
    let name: String
    let emoji: String
    let elo: Int
    let points: Int?
    let wins: Int
    let losses: Int
    let draws: Int
    let friendCode: String

    var displayPoints: Int { points ?? elo }
}

nonisolated struct LeaderboardPayload: Codable {
    let top: [RankedEntry]
    let myRank: Int?
    let totalPlayers: Int
}

nonisolated struct FriendsPayload: Codable {
    let friends: [PlayerProfile]
    let incoming: [PlayerProfile]
    let outgoing: [PlayerProfile]
}

/// Ticket delivered by the matchmaking queue once an opponent is found.
/// `themes` contains both players' theme choices ("all" = every discipline),
/// sorted server-side so both clients derive the same mixed question set.
nonisolated struct MatchTicket: Codable {
    let matchId: String
    let seed: String
    let questionCount: Int
    let roundDuration: Double
    let you: PlayerProfile
    let opponent: PlayerProfile
    let themes: [String]?
}

nonisolated enum QueueStatus {
    case searching
    case matched(MatchTicket)
    case idle
}

nonisolated struct ServerError: Codable {
    let error: String
}
