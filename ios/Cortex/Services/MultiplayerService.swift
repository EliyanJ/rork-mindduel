import Foundation

/// HTTP client for the Cortex multiplayer backend (profiles, friends,
/// leaderboard, matchmaking queue).
nonisolated struct MultiplayerService {
    enum ServiceError: LocalizedError {
        case notSignedIn
        case badURL
        case server(String)
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Connecte-toi pour jouer en ligne"
            case .badURL: return "URL invalide"
            case .server(let message): return message
            case .http(let code): return "Erreur réseau (\(code))"
            }
        }
    }

    static let baseURL = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL

    let token: String

    private func request(path: String, method: String, body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: "\(Self.baseURL)\(path)") else {
            throw ServiceError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            if let serverError = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw ServiceError.server(serverError.error)
            }
            throw ServiceError.http(status)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    // MARK: Profile

    func syncProfile(initialElo: Int) async throws -> PlayerProfile {
        struct Wrapper: Codable { let profile: PlayerProfile }
        let data = try await request(
            path: "/api/hub/profile/sync",
            method: "POST",
            body: ["initialElo": initialElo]
        )
        return try decode(Wrapper.self, from: data).profile
    }

    func updateProfile(name: String?, emoji: String?) async throws -> PlayerProfile {
        struct Wrapper: Codable { let profile: PlayerProfile }
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let emoji { body["emoji"] = emoji }
        let data = try await request(path: "/api/hub/profile/update", method: "POST", body: body)
        return try decode(Wrapper.self, from: data).profile
    }

    // MARK: Leaderboard & friends

    func leaderboard() async throws -> LeaderboardPayload {
        let data = try await request(path: "/api/hub/leaderboard", method: "GET")
        return try decode(LeaderboardPayload.self, from: data)
    }

    func friends() async throws -> FriendsPayload {
        let data = try await request(path: "/api/hub/friends", method: "GET")
        return try decode(FriendsPayload.self, from: data)
    }

    func sendFriendRequest(code: String) async throws -> FriendsPayload {
        let data = try await request(
            path: "/api/hub/friends/request",
            method: "POST",
            body: ["code": code]
        )
        return try decode(FriendsPayload.self, from: data)
    }

    func respondFriendRequest(fromId: String, accept: Bool) async throws -> FriendsPayload {
        let data = try await request(
            path: "/api/hub/friends/respond",
            method: "POST",
            body: ["fromId": fromId, "accept": accept]
        )
        return try decode(FriendsPayload.self, from: data)
    }

    func removeFriend(id: String) async throws -> FriendsPayload {
        let data = try await request(
            path: "/api/hub/friends/remove",
            method: "POST",
            body: ["friendId": id]
        )
        return try decode(FriendsPayload.self, from: data)
    }

    // MARK: Matchmaking queue

    func joinQueue(disciplineId: String? = nil) async throws -> QueueStatus {
        var body: [String: Any] = [:]
        if let disciplineId { body["disciplineId"] = disciplineId }
        let data = try await request(path: "/api/hub/queue/join", method: "POST", body: body)
        return try parseQueue(data)
    }

    func pollQueue() async throws -> QueueStatus {
        let data = try await request(path: "/api/hub/queue/poll", method: "GET")
        return try parseQueue(data)
    }

    func leaveQueue() async throws {
        _ = try await request(path: "/api/hub/queue/leave", method: "POST", body: [:])
    }

    // MARK: Account

    func deleteAccount() async throws {
        _ = try await request(path: "/api/hub/account/delete", method: "POST", body: [:])
    }

    private func parseQueue(_ data: Data) throws -> QueueStatus {
        struct Status: Codable { let status: String }
        let status = try decode(Status.self, from: data).status
        switch status {
        case "matched":
            return .matched(try decode(MatchTicket.self, from: data))
        case "searching":
            return .searching
        default:
            return .idle
        }
    }

    /// WebSocket URL for a ranked match room, carrying the init ticket so the
    /// first player to connect can initialize the room.
    func matchSocketRequest(ticket: MatchTicket) throws -> URLRequest {
        guard var components = URLComponents(string: "\(Self.baseURL)/api/match/\(ticket.matchId)/ws") else {
            throw ServiceError.badURL
        }
        if components.scheme == "https" { components.scheme = "wss" }
        if components.scheme == "http" { components.scheme = "ws" }
        let initPayload: [String: Any] = [
            "seed": ticket.seed,
            "questionCount": ticket.questionCount,
            "roundDuration": ticket.roundDuration,
            "you": [
                "id": ticket.you.id, "name": ticket.you.name,
                "emoji": ticket.you.emoji, "elo": ticket.you.elo
            ],
            "opponent": [
                "id": ticket.opponent.id, "name": ticket.opponent.name,
                "emoji": ticket.opponent.emoji, "elo": ticket.opponent.elo
            ]
        ]
        let initData = try JSONSerialization.data(withJSONObject: initPayload)
        components.queryItems = [
            URLQueryItem(name: "init", value: String(data: initData, encoding: .utf8))
        ]
        guard let url = components.url else { throw ServiceError.badURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
