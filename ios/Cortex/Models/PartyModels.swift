import Foundation

/// The two party formats: 10-vs-10 team score, or 1-vs-19 individual ranking.
nonisolated enum PartyMode: String, Codable {
    case team10
    case solo
}

/// One seat in a party game, real or bot. `isBot` and `team` are carried in
/// the wire payload purely to drive server logic and the local game engine —
/// no UI ever reads `isBot`, so a bot is never distinguishable on screen.
nonisolated struct PartyPlayer: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let elo: Int
    let isBot: Bool
    var team: String?
}

/// Delivered once a lobby is full (real players + bots) and ready to play.
nonisolated struct PartyTicket: Codable {
    let partyId: String
    let mode: PartyMode
    let seed: String
    let rounds: Int
    let questionsPerRound: Int
    let roundDuration: Double
    let you: PartyPlayer
    let players: [PartyPlayer]

    var totalQuestions: Int { rounds * questionsPerRound }
}

/// Lobby still filling with real players (bots only appear once finalized).
nonisolated struct PartyLobbyState: Codable {
    let lobbyId: String
    let mode: PartyMode
    let capacity: Int
    let players: [PlayerProfile]
    let waitingSince: Double
}

nonisolated enum PartyQueueStatus {
    case idle
    case waiting(PartyLobbyState)
    case matched(PartyTicket)
}
