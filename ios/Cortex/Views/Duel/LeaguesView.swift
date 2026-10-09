import SwiftUI

/// "Classement" tab: the five leagues as trophies in a horizontal carousel.
/// Tapping a trophy shows that league; the player's own league reads
/// "Mon classement" with their standing, progress and the players in it.
struct LeaguesView: View {
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @Environment(AppModel.self) private var model
    @State private var selected: RankLeague?
    @State private var isPaywallPresented: Bool = false
    @State private var isSignInPresented: Bool = false
    @State private var isFriendsPresented: Bool = false

    private var points: Int { online.profile?.displayPoints ?? model.store.progress.elo }
    private var myLeague: RankLeague { RankLeague.league(for: points) }
    private var shown: RankLeague { selected ?? myLeague }

    var body: some View {
        VStack(spacing: 0) {
            header
            trophyCarousel
            Rectangle().fill(Theme.line).frame(height: 1.5)
            ScrollView {
                VStack(spacing: 16) {
                    if shown == myLeague {
                        myStanding
                        playersSection
                    } else {
                        otherLeague
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
                .id(shown)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            guard online.isSignedIn else { return }
            await online.refreshFriends()
            if store.isPremium { await online.refreshLeaderboard() }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { Task { await online.refreshLeaderboard() } }
        }
        .sheet(isPresented: $isPaywallPresented) { PaywallView(source: "leagues") }
        .sheet(isPresented: $isSignInPresented) { SignInSheet() }
        .sheet(isPresented: $isFriendsPresented) { FriendsView() }
    }

    // MARK: - Header + carousel

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Division \(shown.name)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(daysLeftLabel)
            }
            .font(.system(.caption, design: .rounded, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    /// Ranked seasons reset weekly on Monday: count the days until then.
    private var daysLeftLabel: String {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (9 - weekday) % 7
        let days = daysUntilMonday == 0 ? 7 : daysUntilMonday
        return "\(days) JOUR\(days > 1 ? "S" : "") AVANT LA FIN DE LA SAISON"
    }

    private var trophyCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(RankLeague.allCases) { league in
                        trophy(league)
                            .id(league)
                    }
                }
                .padding(.vertical, 16)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .onAppear { proxy.scrollTo(myLeague, anchor: .center) }
            .onChange(of: selected) { _, league in
                guard let league else { return }
                withAnimation(.spring(duration: 0.35)) { proxy.scrollTo(league, anchor: .center) }
            }
        }
    }

    private func trophy(_ league: RankLeague) -> some View {
        let isUnlocked = league.rawValue <= myLeague.rawValue
        let isShown = league == shown
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = league }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    TrophyShape()
                        .fill(
                            isUnlocked
                                ? AnyShapeStyle(LinearGradient(colors: league.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Theme.lockedFill)
                        )
                    TrophyShape()
                        .stroke(.white.opacity(isUnlocked ? 0.5 : 0.3), lineWidth: 2)
                    Image(systemName: isUnlocked ? league.icon : "lock.fill")
                        .font(.system(size: isUnlocked ? 24 : 18, weight: .heavy))
                        .foregroundStyle(.white.opacity(isUnlocked ? 1 : 0.85))
                        .offset(y: -10)
                }
                .frame(width: 72, height: 86)
                .shadow(color: isUnlocked ? Color(hex: league.colors[1]).opacity(0.35) : .clear, radius: 8, y: 4)
                Text(league.name)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(isShown ? Theme.ink : Theme.inkMuted)
                Capsule()
                    .fill(isShown ? Color(hex: league.colors[0]) : .clear)
                    .frame(width: 24, height: 4)
            }
            .scaleEffect(isShown ? 1.08 : 0.92)
            .opacity(isShown ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ligue \(league.name)\(isUnlocked ? "" : ", verrouillée")")
    }

    // MARK: - My league

    private var myStanding: some View {
        let league = myLeague
        let range = league.range
        let span = Double(range.upperBound - range.lowerBound + 1)
        let progress = min(1, max(0, Double(points - range.lowerBound) / span))
        return VStack(alignment: .leading, spacing: 14) {
            Text("MON CLASSEMENT")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color(hex: league.colors[1]))
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ligue \(league.name)")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(online.isSignedIn ? "\(points) points classés" : "Niveau local : \(points) points")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                if let rank = myRankInLeague {
                    VStack(spacing: 0) {
                        Text("#\(rank)")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Text("dans la ligue")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule()
                            .fill(LinearGradient(colors: league.colors.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(12, geo.size.width * progress))
                    }
                }
                .frame(height: 14)
                if let next = RankLeague(rawValue: league.rawValue + 1) {
                    Text("Encore \(range.upperBound - points + 1) pts pour la ligue \(next.name)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                } else {
                    Text("Ligue la plus haute : reste au sommet !")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            HStack(spacing: 10) {
                statTile(value: "\(online.profile?.wins ?? model.store.progress.duelsWon)", label: "Victoires", color: Theme.success)
                statTile(value: "\(online.profile?.losses ?? max(0, model.store.progress.duelsPlayed - model.store.progress.duelsWon))", label: "Défaites", color: Theme.danger)
                statTile(value: "\(online.profile?.draws ?? 0)", label: "Nuls", color: Theme.inkMuted)
            }
            if !online.isSignedIn {
                Button {
                    Haptics.medium()
                    isSignInPresented = true
                } label: {
                    Label("Se connecter pour jouer classé", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(ChunkyButtonStyle(color: Color(hex: league.colors[1])))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: league.colors[0]).opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: league.colors[0]).opacity(0.5), lineWidth: 2))
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
    }

    /// Players in the player's league: the world board for Premium, friends otherwise.
    private var leaguePlayers: [RankedEntry] {
        let range = myLeague.range
        var pool: [RankedEntry] = []
        if store.isPremium, let board = online.leaderboard {
            pool = board.top
        }
        for friend in online.friends where !pool.contains(where: { $0.id == friend.id }) {
            pool.append(entry(from: friend))
        }
        if let me = online.profile, !pool.contains(where: { $0.id == me.id }) {
            pool.append(entry(from: me))
        }
        return pool
            .filter { range.contains(min(max($0.displayPoints, 400), 1500)) }
            .sorted { $0.displayPoints > $1.displayPoints }
            .enumerated()
            .map { index, player in
                RankedEntry(rank: index + 1, id: player.id, name: player.name, emoji: player.emoji, elo: player.elo, points: player.points, wins: player.wins, losses: player.losses, draws: player.draws, friendCode: player.friendCode)
            }
    }

    private var myRankInLeague: Int? {
        guard let id = online.profile?.id else { return nil }
        return leaguePlayers.first { $0.id == id }?.rank
    }

    private func entry(from player: PlayerProfile) -> RankedEntry {
        RankedEntry(rank: 0, id: player.id, name: player.name, emoji: player.emoji, elo: player.elo, points: player.points, wins: player.wins, losses: player.losses, draws: player.draws, friendCode: player.friendCode)
    }

    @ViewBuilder
    private var playersSection: some View {
        if online.isSignedIn {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.isPremium ? "JOUEURS DE TA LIGUE" : "TES AMIS DANS CETTE LIGUE")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                }
                let players = leaguePlayers
                if players.count <= 1 {
                    emptyLeague
                } else {
                    VStack(spacing: 8) {
                        ForEach(players) { player in
                            playerRow(player)
                        }
                    }
                }
                if !store.isPremium {
                    worldTeaser
                }
            }
        }
    }

    private var emptyLeague: some View {
        VStack(spacing: 12) {
            Image("MascotWaiting")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .accessibilityHidden(true)
            Text("Joue un duel pour rejoindre la compétition de la semaine. Allez, courage !")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Button("Ajouter des amis") {
                Haptics.tap()
                isFriendsPresented = true
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(Theme.primary)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func playerRow(_ player: RankedEntry) -> some View {
        let isMe = player.id == online.profile?.id
        return HStack(spacing: 12) {
            Text(player.rank <= 3 ? ["🥇", "🥈", "🥉"][player.rank - 1] : "\(player.rank)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 32)
            Text(player.emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.canvas))
            Text(isMe ? "\(player.name) (toi)" : player.name)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            Text("\(player.displayPoints) pts")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(isMe ? Color(hex: myLeague.colors[0]).opacity(0.14) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isMe ? Color(hex: myLeague.colors[0]).opacity(0.6) : Theme.line, lineWidth: 1.5))
    }

    private var worldTeaser: some View {
        Button {
            Haptics.medium()
            isPaywallPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "9B4DFF")))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Classement mondial")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text("Affronte tous les joueurs de ta ligue avec Premium")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Other leagues

    private var otherLeague: some View {
        let league = shown
        let isPassed = league.rawValue < myLeague.rawValue
        return VStack(spacing: 14) {
            Image(isPassed ? "MascotTrophy" : "MascotIdea")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .accessibilityHidden(true)
            Text(isPassed ? "Ligue \(league.name) déjà conquise" : "Ligue \(league.name)")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("De \(league.range.lowerBound) à \(league.range.upperBound) points classés.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            if !isPassed {
                Text("Encore \(max(0, league.range.lowerBound - points)) pts pour l'atteindre. Gagne des duels classés pour monter !")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = myLeague }
            } label: {
                Text("Voir mon classement")
            }
            .buttonStyle(ChunkyButtonStyle(color: Color(hex: myLeague.colors[1])))
            .padding(.top, 6)
        }
        .padding(.top, 20)
        .padding(.horizontal, 8)
    }
}

/// Simple cup silhouette used for league trophies.
struct TrophyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.06))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.12), control: CGPoint(x: w * 0.3, y: 0))
        path.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.06), control: CGPoint(x: w * 0.7, y: 0))
        path.addCurve(to: CGPoint(x: w * 0.58, y: h * 0.66), control1: CGPoint(x: w * 1.0, y: h * 0.4), control2: CGPoint(x: w * 0.8, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.8))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.96), control: CGPoint(x: w * 0.82, y: h * 0.84))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.96))
        path.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.8), control: CGPoint(x: w * 0.18, y: h * 0.84))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.66))
        path.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.06), control1: CGPoint(x: w * 0.2, y: h * 0.6), control2: CGPoint(x: w * 0.0, y: h * 0.4))
        path.closeSubpath()
        return path
    }
}
