import Foundation

/// Server-side player profile (ranked identity).
nonisolated struct PlayerProfile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var elo: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var friendCode: String
}

nonisolated struct RankedEntry: Codable, Identifiable, Hashable {
    let rank: Int
    let id: String
    let name: String
    let emoji: String
    let elo: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let friendCode: String
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
