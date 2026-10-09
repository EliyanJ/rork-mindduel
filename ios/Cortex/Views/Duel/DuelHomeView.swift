import SwiftUI

/// Duel tab: a "Non classé / Classé" switch. Unranked holds the free modes
/// (online 1v1, Flash, offline); Ranked holds the Premium ones (ranked 1v1,
/// 1 vs 9, Flash 2 vs 2, custom).
struct DuelHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @State private var isRankedPresented: Bool = false
    @State private var isCasualOnlinePresented: Bool = false
    @State private var section: DuelSection = .casual
    @State private var isTeamFlash: Bool = false
    @Namespace private var sectionNamespace
    @State private var isTrainingPresented: Bool = false
    @State private var isSignInPresented: Bool = false
    @State private var isHelpPresented: Bool = false
    @State private var selectedDuelDisciplineId: String? = nil
    @State private var showThemePicker: Bool = false
    @State private var pendingMode: DuelMode = .training
    @State private var pendingPartyOrigin: PartySession.Origin?
    @State private var isFlashPresented: Bool = false
    @State private var isCustomSetupPresented: Bool = false
    @State private var isDuelPointsPresented: Bool = false
    @State private var isPaywallPresented: Bool = false
    @State private var paywallSource: String = "duel"
    @State private var isLeaguePresented: Bool = false
    @State private var appeared: Bool = false
    @State private var heroWobble: Bool = false

    private enum DuelMode {
        case ranked
        case casualOnline
        case training
    }

    private enum DuelSection: String, CaseIterable, Identifiable {
        case casual = "Non classé"
        case ranked = "Classé"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            sectionPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            Rectangle().fill(Theme.line).frame(height: 1.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Group {
                        if section == .ranked {
                            rankedHero
                        } else {
                            casualHero
                        }
                    }
                    .id(section)
                    .transition(.asymmetric(insertion: .move(edge: section == .ranked ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section == .ranked ? "Modes Premium" : "Autres modes")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        ForEach(Array(otherModes.enumerated()), id: \.element.id) { index, mode in
                            DuelModeTile(mode: mode, isLocked: mode.isPremium && !store.isPremium) {
                                open(mode.kind)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.08 + Double(index) * 0.06), value: appeared)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appeared)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: section)
        .onAppear {
            if !appeared, store.isPremium { section = .ranked }
            appeared = true
        }
        .fullScreenCover(isPresented: $isCasualOnlinePresented) {
            OnlineMatchView(
                catalog: model.catalog,
                store: model.store,
                online: online,
                disciplineId: selectedDuelDisciplineId,
                isRanked: false,
                onPlayBot: playBotInsteadOfCasual
            )
        }
        .fullScreenCover(isPresented: $isRankedPresented) {
            OnlineMatchView(
                catalog: model.catalog,
                store: model.store,
                online: online,
                disciplineId: selectedDuelDisciplineId,
                onPlayBot: playBotInstead
            )
        }
        .fullScreenCover(isPresented: $isTrainingPresented) {
            DuelMatchView(catalog: model.catalog, store: model.store, disciplineId: selectedDuelDisciplineId)
        }
        .fullScreenCover(item: $pendingPartyOrigin) { origin in
            PartyLobbyView(catalog: model.catalog, store: model.store, online: online, origin: origin)
        }
        .fullScreenCover(isPresented: $isFlashPresented) {
            FlashDuelView(catalog: model.catalog, store: model.store, isTeamFlavor: isTeamFlash) {
                isFlashPresented = false
            }
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet()
        }
        .sheet(isPresented: $isHelpPresented) {
            DuelHelpView()
        }
        .sheet(isPresented: $isCustomSetupPresented) {
            CustomPartySetupView { origin in
                isCustomSetupPresented = false
                guard online.isSignedIn else {
                    isSignInPresented = true
                    return
                }
                pendingPartyOrigin = origin
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isDuelPointsPresented) {
            DuelPointsSheet(progressStore: model.store) {
                isDuelPointsPresented = false
                openPaywall(source: "duel_points")
            }
            .presentationDetents([.height(440)])
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(source: paywallSource)
        }
        .sheet(isPresented: $showThemePicker) {
            DuelThemePickerView(
                catalog: model.catalog,
                selectedId: $selectedDuelDisciplineId,
                onConfirm: {
                    showThemePicker = false
                    proceedAfterThemePick()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isLeaguePresented) {
            RankView()
        }
        .task {
            if online.isSignedIn && online.profile == nil {
                await online.syncProfile(localElo: model.store.progress.elo)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Duel")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer()
            if !store.isPremium {
                duelPointsPill
            }
            Button {
                Haptics.tap()
                isHelpPresented = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.lockedInk)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Comment ça marche")
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    /// Remaining free-tier duel points; tapping explains them and offers the
    /// rewarded-video refill.
    private var duelPointsPill: some View {
        let points = model.store.duelPoints
        return Button {
            Haptics.tap()
            isDuelPointsPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("\(points)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(points > 0 ? Theme.duelAccent : Theme.lockedInk)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(points) éclairs de duel")
    }

    /// Duolingo-style two-segment switch with a sliding chunky pill.
    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(DuelSection.allCases) { item in
                let isSelected = section == item
                Button {
                    guard section != item else { return }
                    Haptics.tap()
                    section = item
                } label: {
                    HStack(spacing: 6) {
                        if item == .ranked {
                            Image(systemName: store.isPremium ? "trophy.fill" : "crown.fill")
                                .foregroundStyle(isSelected ? Theme.duelBackground : Theme.gold)
                        }
                        Text(item.rawValue.uppercased())
                            .tracking(0.6)
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.duelBackground : Theme.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.duelAccent)
                                .matchedGeometryEffect(id: "duelSection", in: sectionNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 2))
    }

    /// Free online 1v1 against a real player: no ladder points, one duel bolt.
    private var casualHero: some View {
        let points = model.store.duelPoints
        let isPremium = store.isPremium
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1 CONTRE 1 EN LIGNE")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Duel amical")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Theme.duelAccent)
                        Text(isPremium ? "Illimité · sans classement" : "1 éclair · sans classement")
                            .foregroundStyle(.white)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(.black.opacity(0.2)))
                }
                Spacer(minLength: 0)
                Image("MascotDuel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(heroWobble ? -3 : 3))
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroWobble)
                    .onAppear { heroWobble = true }
                    .accessibilityHidden(true)
            }
            Button {
                Haptics.medium()
                guard online.isSignedIn else {
                    isSignInPresented = true
                    return
                }
                guardedAction { presentCasualOnline() }
            } label: {
                Text(!online.isSignedIn ? "SE CONNECTER" : (!isPremium && points == 0 ? "RECHARGER" : "JOUER"))
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, textColor: Color(hex: "1453A8")))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(hex: "3A8BFF"), Color(hex: "1F6AE0")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(hex: "1453A8"))
                .offset(y: 5)
        )
        .padding(.bottom, 5)
    }

    private var rankedPoints: Int {
        online.profile?.displayPoints ?? model.store.progress.elo
    }

    /// The main event: one bold card for the ranked 1v1, with the player's
    /// league and a single big button.
    private var rankedHero: some View {
        let league = RankLeague.league(for: rankedPoints)
        let leagueColor = Color(hex: league.colors[0])
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1 CONTRE 1")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Match classé")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button {
                        Haptics.tap()
                        isLeaguePresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: league.icon)
                                .foregroundStyle(leagueColor)
                            Text("Ligue \(league.name) · \(rankedPoints) pts")
                                .foregroundStyle(.white)
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(Capsule().fill(.black.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ouvre ton rang")
                }
                Spacer(minLength: 0)
                Image("MascotDuel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(heroWobble ? 3 : -3))
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroWobble)
                    .onAppear { heroWobble = true }
                    .accessibilityHidden(true)
            }
            Button {
                Haptics.medium()
                if !store.isPremium {
                    openPaywall(source: "ranked")
                } else if online.isSignedIn {
                    presentRankedDuel()
                } else {
                    isSignInPresented = true
                }
            } label: {
                HStack(spacing: 8) {
                    if !store.isPremium {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.gold)
                    }
                    Text(store.isPremium && !online.isSignedIn ? "SE CONNECTER" : "JOUER")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, textColor: Color(hex: "0A7A72")))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(hex: "1CC9BC"), Color(hex: "0E9F95")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(hex: "0A7A72"))
                .offset(y: 5)
        )
        .padding(.bottom, 5)
    }

    private var otherModes: [DuelModeInfo] {
        switch section {
        case .casual:
            return [
                DuelModeInfo(kind: .flash, title: "Flash", subtitle: "Questions éclair en solo", icon: "bolt.fill", color: Color(hex: "FF9600"), isPremium: false),
                DuelModeInfo(kind: .offline, title: "Hors ligne", subtitle: "Contre un robot, sans connexion", icon: "wifi.slash", color: Color(hex: "A560FF"), isPremium: false)
            ]
        case .ranked:
            return [
                DuelModeInfo(kind: .oneVsNine, title: "1 contre 9", subtitle: "Seul face à une équipe", icon: "flame.fill", color: Color(hex: "FF4B4B"), isPremium: true),
                DuelModeInfo(kind: .teamFlash, title: "Flash 2 contre 2", subtitle: "Questions éclair en équipe", icon: "bolt.horizontal.fill", color: Color(hex: "FF9600"), isPremium: true),
                DuelModeInfo(kind: .custom, title: "Personnalisé", subtitle: "Crée ta partie entre amis", icon: "person.3.fill", color: Color(hex: "1CB0F6"), isPremium: true)
            ]
        }
    }

    private func open(_ kind: DuelModeInfo.Kind) {
        switch kind {
        case .oneVsNine:
            guard store.isPremium else { return openPaywall(source: "one_vs_nine") }
            joinParty(.oneVsTen)
        case .flash:
            guardedAction {
                isTeamFlash = false
                isFlashPresented = true
            }
        case .teamFlash:
            guard store.isPremium else { return openPaywall(source: "team_flash") }
            isTeamFlash = true
            isFlashPresented = true
        case .custom:
            guard store.isPremium else { return openPaywall(source: "custom") }
            isCustomSetupPresented = true
        case .offline:
            guardedAction { presentTraining() }
        }
    }

    /// Every free mode costs one duel point for free players (spent
    /// when the game actually begins). With no point left, the refill sheet
    /// opens instead of the mode.
    private func guardedAction(_ action: @escaping () -> Void) {
        guard model.store.canStartDuel() else {
            Haptics.error()
            isDuelPointsPresented = true
            return
        }
        action()
    }

    private func openPaywall(source: String) {
        paywallSource = source
        Task {
            // Lets a closing sheet finish before presenting the paywall.
            try? await Task.sleep(for: .milliseconds(350))
            isPaywallPresented = true
        }
    }

    /// Ranked queue found nobody: hand over to an unranked bot match with the
    /// same theme (Premium only, so it never costs a duel point).
    private func playBotInstead() {
        isRankedPresented = false
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            isTrainingPresented = true
        }
    }

    /// Nobody in the unranked queue: fall back to an offline bot match. The
    /// bolt was not spent (it is only spent once a real match is found).
    private func playBotInsteadOfCasual() {
        isCasualOnlinePresented = false
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            isTrainingPresented = true
        }
    }

    private func joinParty(_ mode: PartyMode) {
        guard online.isSignedIn else {
            isSignInPresented = true
            return
        }
        pendingPartyOrigin = .matchmaking(mode)
    }

    private func presentRankedDuel() {
        pendingMode = .ranked
        showThemePicker = true
    }

    /// Free players get an imposed theme mix; choosing a theme is Premium.
    private func presentCasualOnline() {
        pendingMode = .casualOnline
        guard store.isPremium else {
            selectedDuelDisciplineId = nil
            isCasualOnlinePresented = true
            return
        }
        showThemePicker = true
    }

    /// Free players get an imposed mix of every theme; choosing is Premium.
    private func presentTraining() {
        pendingMode = .training
        guard store.isPremium else {
            selectedDuelDisciplineId = nil
            isTrainingPresented = true
            return
        }
        showThemePicker = true
    }

    private func proceedAfterThemePick() {
        switch pendingMode {
        case .ranked:
            isRankedPresented = true
        case .casualOnline:
            isCasualOnlinePresented = true
        case .training:
            isTrainingPresented = true
        }
    }
}

/// One secondary duel format shown in the "Autres modes" list.
private struct DuelModeInfo: Identifiable {
    enum Kind: String {
        case oneVsNine, flash, teamFlash, custom, offline
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isPremium: Bool

    var id: String { kind.rawValue }
}

/// Duolingo-style list tile: chunky colored icon block, title and one short
/// line, outlined card that sinks on press. Premium-only modes show a crown.
private struct DuelModeTile: View {
    let mode: DuelModeInfo
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(mode.color))
                    .background(RoundedRectangle(cornerRadius: 16).fill(mode.color.mix(with: .black, by: 0.25)).offset(y: 3))
                    .padding(.bottom, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(mode.subtitle)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 4)
                if isLocked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .accessibilityLabel("Premium")
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.lockedInk)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(TileButtonStyle())
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 2))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.line).offset(y: 4))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
