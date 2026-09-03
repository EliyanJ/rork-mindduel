import Foundation

/// The party formats: 10-vs-10 team score, 1-vs-19 individual ranking,
/// 1-vs-10 (a lone challenger against a team of ten), or a free-form custom
/// room where the host picked both team sizes and invited people with a
/// share code. Wire format mirrors the server exactly: "team10", "solo",
/// "oneVsTen", or `custom:<allies>:<opponents>`.
nonisolated struct PartyMode: Codable, Hashable, Identifiable {
    let raw: String

    init(raw: String) { self.raw = raw }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        raw = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    static let team10 = PartyMode(raw: "team10")
    static let solo = PartyMode(raw: "solo")
    static let oneVsTen = PartyMode(raw: "oneVsTen")

    /// `allies` is teammates besides the host (0-9); `opponents` is the
    /// other side's size (1-19).
    static func custom(allies: Int, opponents: Int) -> PartyMode {
        PartyMode(raw: "custom:\(max(0, min(9, allies))):\(max(1, min(19, opponents)))")
    }

    var isCustom: Bool { raw.hasPrefix("custom:") }

    private var customParts: [Int] {
        guard isCustom else { return [] }
        return raw.split(separator: ":").dropFirst().compactMap { Int($0) }
    }

    /// Teammates besides the host, for a custom room.
    var allyCount: Int { customParts.first ?? 0 }
    /// The other side's size, for a custom room.
    var opponentCount: Int { customParts.count > 1 ? customParts[1] : 0 }

    /// Team formats cumulate a side's score; `solo` ranks everyone individually.
    var isTeam: Bool { self == .team10 || self == .oneVsTen || isCustom }
    public var id: String { raw }
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
    /// Only present for custom rooms — the code the host shares to invite people.
    let roomCode: String?
    /// Whether the local player created this custom room and can force-start it.
    let isHost: Bool?
}

nonisolated enum PartyQueueStatus {
    case idle
    case waiting(PartyLobbyState)
    case matched(PartyTicket)
}
