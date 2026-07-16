import SwiftUI

/// World ranked leaderboard (top 50 + own rank), served by the backend.
struct LeaderboardView: View {
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let board = online.leaderboard {
                    boardList(board)
                } else {
                    ProgressView("Chargement du classement…")
                        .tint(Theme.duelAccent)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.duelBackground)
            .navigationTitle("Classement mondial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.duelAccent)
                }
            }
            .toolbarBackground(Theme.duelCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await online.refreshLeaderboard() }
    }

    private func boardList(_ board: LeaderboardPayload) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                if let myRank = board.myRank, let profile = online.profile {
                    myRankCard(rank: myRank, profile: profile, total: board.totalPlayers)
                }
                ForEach(board.top) { entry in
                    entryRow(entry)
                }
                if board.top.isEmpty {
                    Text("Personne au classement pour l'instant.\nSois le premier à jouer un match classé !")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .refreshable { await online.refreshLeaderboard() }
    }

    private func myRankCard(rank: Int, profile: PlayerProfile, total: Int) -> some View {
        HStack(spacing: 12) {
            Text(profile.emoji).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text("Toi · \(profile.name)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(total) joueur\(total > 1 ? "s" : "") dans le monde")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("#\(rank)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.gold)
                Text("ELO \(profile.elo)")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.duelAccent)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.duelAccent.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.duelAccent.opacity(0.5), lineWidth: 1.5))
    }

    private func entryRow(_ entry: RankedEntry) -> some View {
        let isMe = entry.id == online.profile?.id
        return HStack(spacing: 12) {
            Text(rankLabel(entry.rank))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(entry.rank <= 3 ? Theme.gold : .white.opacity(0.5))
                .frame(width: 40, alignment: .leading)
            Text(entry.emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(entry.wins) V · \(entry.losses) D")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Text("\(entry.elo)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isMe ? Theme.duelAccent.opacity(0.14) : Theme.duelCard)
        )
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}
