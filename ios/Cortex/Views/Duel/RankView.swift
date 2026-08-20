import SwiftUI

/// One of the five skill leagues spanning the 400-1500 points ladder.
nonisolated enum RankLeague: Int, CaseIterable, Identifiable {
    case bronze, argent, or, platine, maitre

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .argent: return "Argent"
        case .or: return "Or"
        case .platine: return "Platine"
        case .maitre: return "Maître"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .bronze: return 400...599
        case .argent: return 600...799
        case .or: return 800...999
        case .platine: return 1000...1249
        case .maitre: return 1250...1500
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .argent: return "shield.lefthalf.filled"
        case .or: return "star.fill"
        case .platine: return "diamond.fill"
        case .maitre: return "crown.fill"
        }
    }

    var colors: [String] {
        switch self {
        case .bronze: return ["C68A4A", "8A5A2C"]
        case .argent: return ["B8C2CC", "7C8896"]
        case .or: return ["FFD764", "E8A317"]
        case .platine: return ["7EE0E8", "2E9AA6"]
        case .maitre: return ["B084FF", "6C3CE0"]
        }
    }

    static func league(for points: Int) -> RankLeague {
        let clamped = min(max(points, 400), 1500)
        return allCases.first { $0.range.contains(clamped) } ?? .maitre
    }
}

/// Dedicated "Rang" page: current league standing on one side, the full
/// world ranking on the other, tabbed within a single screen.
struct RankView: View {
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .league

    private enum Tab: String, CaseIterable {
        case league = "Ma ligue"
        case world = "Classement mondial"
    }

    private var points: Int { online.profile?.displayPoints ?? 400 }
    private var league: RankLeague { RankLeague.league(for: points) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                ScrollView {
                    VStack(spacing: 18) {
                        switch tab {
                        case .league:
                            leagueHero
                            leagueLadder
                        case .world:
                            worldRanking
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.duelBackground)
            .navigationTitle("Rang")
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

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { candidate in
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.2)) { tab = candidate }
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(tab == candidate ? Theme.duelBackground : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(tab == candidate ? Theme.duelAccent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.duelCard))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - League tab

    private var leagueHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: league.colors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: league.icon)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 2) {
                Text("Ligue \(league.name)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                Text(online.isSignedIn ? "\(points) points" : "Connecte-toi pour jouer classé")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            progressToNextLeague
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.duelCard))
    }

    @ViewBuilder
    private var progressToNextLeague: some View {
        let range = league.range
        let span = Double(range.upperBound - range.lowerBound + 1)
        let progress = min(1, max(0, Double(points - range.lowerBound) / span))
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Color(hex: league.colors[0]))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            if let next = RankLeague(rawValue: league.rawValue + 1) {
                Text("\(range.upperBound - points + 1) pts avant la ligue \(next.name)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("Ligue la plus haute — reste au sommet !")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 28)
    }

    private var leagueLadder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LES 5 LIGUES")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
            VStack(spacing: 8) {
                ForEach(RankLeague.allCases.reversed()) { candidate in
                    ladderRow(candidate)
                }
            }
        }
    }

    private func ladderRow(_ candidate: RankLeague) -> some View {
        let isCurrent = candidate == league
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: candidate.colors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: candidate.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(candidate.name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(candidate.range.lowerBound)–\(candidate.range.upperBound) pts")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            if isCurrent {
                Text("TOI")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Theme.duelBackground)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.duelAccent))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrent ? Theme.duelAccent.opacity(0.14) : Theme.duelCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Theme.duelAccent.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }

    // MARK: - World ranking tab

    @ViewBuilder
    private var worldRanking: some View {
        if let board = online.leaderboard {
            VStack(spacing: 10) {
                if let myRank = board.myRank, let profile = online.profile {
                    myRankCard(rank: myRank, profile: profile, total: board.totalPlayers)
                }
                ForEach(board.top) { entry in
                    entryRow(entry)
                }
                if board.top.isEmpty {
                    VStack(spacing: 12) {
                        Image("MascotDuel")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 110)
                            .accessibilityHidden(true)
                        Text("Personne au classement pour l'instant.\nSois le premier à jouer un match classé !")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }
            }
        } else {
            ProgressView("Chargement du classement…")
                .tint(Theme.duelAccent)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 60)
        }
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
                Text("\(profile.displayPoints) pts")
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
            Text("\(entry.displayPoints)")
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
