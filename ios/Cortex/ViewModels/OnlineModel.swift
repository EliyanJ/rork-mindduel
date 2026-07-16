import Foundation
import Observation

/// Shared online state: server profile, friends, world leaderboard.
/// Wraps AuthManager + MultiplayerService for the whole app.
@Observable
final class OnlineModel {
    let auth: AuthManager

    private(set) var profile: PlayerProfile?
    private(set) var friends: [PlayerProfile] = []
    private(set) var incomingRequests: [PlayerProfile] = []
    private(set) var outgoingRequests: [PlayerProfile] = []
    private(set) var leaderboard: LeaderboardPayload?
    private(set) var isSyncing = false
    var friendActionError: String?

    init(auth: AuthManager) {
        self.auth = auth
    }

    var isSignedIn: Bool { auth.user != nil }

    private func service() async -> MultiplayerService? {
        guard let token = await auth.validAccessToken() else { return nil }
        return MultiplayerService(token: token)
    }

    /// Creates the server profile on first sign-in (seeding ELO from local
    /// progress) and refreshes it afterwards.
    func syncProfile(localElo: Int) async {
        guard let service = await service() else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            profile = try await service.syncProfile(initialElo: localElo)
        } catch {
            print("profile sync failed: \(error.localizedDescription)")
        }
    }

    func updateProfile(name: String?, emoji: String?) async {
        guard let service = await service() else { return }
        do {
            profile = try await service.updateProfile(name: name, emoji: emoji)
        } catch {
            friendActionError = error.localizedDescription
        }
    }

    func refreshFriends() async {
        guard let service = await service() else { return }
        do {
            apply(try await service.friends())
        } catch {
            print("friends refresh failed: \(error.localizedDescription)")
        }
    }

    func addFriend(code: String) async -> Bool {
        guard let service = await service() else { return false }
        do {
            apply(try await service.sendFriendRequest(code: code))
            return true
        } catch {
            friendActionError = error.localizedDescription
            return false
        }
    }

    func respondToRequest(from player: PlayerProfile, accept: Bool) async {
        guard let service = await service() else { return }
        do {
            apply(try await service.respondFriendRequest(fromId: player.id, accept: accept))
        } catch {
            friendActionError = error.localizedDescription
        }
    }

    func removeFriend(_ player: PlayerProfile) async {
        guard let service = await service() else { return }
        do {
            apply(try await service.removeFriend(id: player.id))
        } catch {
            friendActionError = error.localizedDescription
        }
    }

    func refreshLeaderboard() async {
        guard let service = await service() else { return }
        do {
            leaderboard = try await service.leaderboard()
        } catch {
            print("leaderboard refresh failed: \(error.localizedDescription)")
        }
    }

    /// Called after a ranked match settles to reflect the new ELO instantly.
    func applyRankedResult(newElo: Int?, won: Bool, draw: Bool) {
        guard var updated = profile else { return }
        if let newElo { updated.elo = newElo }
        if draw { updated.draws += 1 } else if won { updated.wins += 1 } else { updated.losses += 1 }
        profile = updated
    }

    func signOut() async {
        await auth.signOut()
        profile = nil
        friends = []
        incomingRequests = []
        outgoingRequests = []
        leaderboard = nil
    }

    /// Permanently deletes the server-side account (profile, friends, match
    /// history) then signs out locally. Local on-device progress is untouched.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let service = await service() else { return false }
        do {
            try await service.deleteAccount()
            await signOut()
            return true
        } catch {
            friendActionError = error.localizedDescription
            return false
        }
    }

    private func apply(_ payload: FriendsPayload) {
        friends = payload.friends
        incomingRequests = payload.incoming
        outgoingRequests = payload.outgoing
    }
}
