import SwiftUI

struct DuelHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @State private var isRankedPresented: Bool = false
    @State private var isTrainingPresented: Bool = false
    @State private var isLeaderboardPresented: Bool = false
    @State private var isSignInPresented: Bool = false
    @State private var isHelpPresented: Bool = false
    @State private var isFriendsPresented: Bool = false
    @State private var isMissionsPresented: Bool = false
    @State private var selectedDuelDisciplineId: String? = nil
    @State private var showThemePicker: Bool = false
    @State private var pendingMode: DuelMode = .training
    @State private var pendingPartyMode: PartyMode?
    @State private var pendingFlash: FlashKind?
    @State private var isLocalPresented: Bool = false

    private enum DuelMode {
        case ranked
        case training
    }

    private enum FlashKind: Identifiable {
        case solo, duo
        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 22) {
                    shortcutRow
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Jeu duel")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        rankedCard
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            modeCard(title: "10 vs 10", subtitle: "Équipes", icon: "person.3.fill", colors: ["6C5CE7", "4834D4"]) {
                                joinParty(.team10)
                            }
                            modeCard(title: "2 vs 2", subtitle: "En duo", icon: "person.2.fill", colors: ["00B894", "00896B"]) {
                                joinParty(.duo)
                            }
                            modeCard(title: "Flash", subtitle: "Solo rapide", icon: "bolt.fill", colors: ["FDCB6E", "E17055"]) {
                                pendingFlash = .solo
                            }
                            modeCard(title: "Flash 2v2", subtitle: "Duo rapide", icon: "bolt.badge.clock.fill", colors: ["FF7675", "D63031"]) {
                                pendingFlash = .duo
                            }
                            modeCard(title: "Local", subtitle: "Même réseau", icon: "wifi", colors: ["0984E3", "0652DD"]) {
                                Haptics.medium()
                                isLocalPresented = true
                            }
                            modeCard(title: "Entraînement", subtitle: "Contre un bot", icon: "figure.strengthtraining.traditional", colors: ["FF9F43", "E58E26"]) {
                                Haptics.medium()
                                presentTraining()
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background)
        .fullScreenCover(isPresented: $isRankedPresented) {
            OnlineMatchView(catalog: model.catalog, store: model.store, online: online, disciplineId: selectedDuelDisciplineId)
        }
        .fullScreenCover(isPresented: $isTrainingPresented) {
            DuelMatchView(catalog: model.catalog, store: model.store, disciplineId: selectedDuelDisciplineId)
        }
        .fullScreenCover(item: $pendingPartyMode) { mode in
            PartyLobbyView(catalog: model.catalog, store: model.store, online: online, mode: mode)
        }
        .fullScreenCover(item: $pendingFlash) { kind in
            FlashDuelView(catalog: model.catalog, store: model.store, isTeamFlavor: kind == .duo) {
                pendingFlash = nil
            }
        }
        .fullScreenCover(isPresented: $isLocalPresented) {
            LocalDuelView(
                catalog: model.catalog,
                store: model.store,
                displayName: online.profile?.name ?? "Toi",
                displayEmoji: online.profile?.emoji ?? "🧠"
            ) {
                isLocalPresented = false
            }
        }
        .sheet(isPresented: $isLeaderboardPresented) {
            RankView()
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet()
        }
        .sheet(isPresented: $isHelpPresented) {
            DuelHelpView()
        }
        .sheet(isPresented: $isFriendsPresented) {
            FriendsView()
        }
        .sheet(isPresented: $isMissionsPresented) {
            MissionsView()
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
        .task {
            if online.isSignedIn && online.profile == nil {
                await online.syncProfile(localElo: model.store.progress.elo)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duel")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Affronte des joueurs du monde entier")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Button {
                Haptics.tap()
                isHelpPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// The three quick-access shortcuts (rank, missions, friends), shown as a
    /// row of round icon tabs right under the header.
    private var shortcutRow: some View {
        HStack(spacing: 0) {
            shortcut(icon: "crown.fill", color: Theme.gold, label: "Rang") {
                isLeaderboardPresented = true
            }
            Spacer()
            shortcut(icon: "flag.checkered", color: Theme.primary, label: "Missions") {
                isMissionsPresented = true
            }
            Spacer()
            shortcut(icon: "person.2.fill", color: Theme.duelAccent, label: "Amis") {
                isFriendsPresented = true
            }
        }
        .padding(.horizontal, 24)
    }

    private func shortcut(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(color.opacity(0.14)))
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .buttonStyle(.plain)
    }

    private var rankedCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(online.profile.map { "\($0.displayPoints)" } ?? "—")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.duelAccent)
                        .contentTransition(.numericText())
                    Text("POINTS CLASSÉS")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Rectangle()
                    .fill(Theme.duelLine)
                    .frame(width: 1.5, height: 52)
                VStack(spacing: 4) {
                    Text(online.profile.map { "\($0.wins) V · \($0.losses) D" } ?? "Hors ligne")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("1V1 CLASSÉ")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image("MascotDuel")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .accessibilityHidden(true)
            }
            Button {
                Haptics.medium()
                if online.isSignedIn {
                    presentRankedDuel()
                } else {
                    isSignInPresented = true
                }
            } label: {
                Label(
                    online.isSignedIn ? "Match classé" : "Se connecter pour jouer",
                    systemImage: online.isSignedIn ? "globe" : "person.crop.circle.badge.plus"
                )
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: Theme.duelBackground))
            Text("Vrais joueurs · matchmaking ELO · classement mondial")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Theme.duelCard, Theme.duelBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    /// One colourful, chunky mode card — mirrors the reference casual-game
    /// grid: bold gradient, icon top-left, name + short tag underneath.
    private func modeCard(title: String, subtitle: String, icon: String, colors: [String], action: @escaping () -> Void) -> some View {
        Button {
            Haptics.medium()
            guardedAction(action)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.2)))
                Spacer(minLength: 14)
                Text(title.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(16)
            .frame(height: 118, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: colors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Party/team modes need a signed-in profile for matchmaking; Local and
    /// Flash are fully offline and skip the sign-in gate entirely.
    private func guardedAction(_ action: @escaping () -> Void) {
        action()
    }

    private func joinParty(_ mode: PartyMode) {
        guard online.isSignedIn else {
            isSignInPresented = true
            return
        }
        pendingPartyMode = mode
    }

    private func presentRankedDuel() {
        pendingMode = .ranked
        showThemePicker = true
    }

    private func presentTraining() {
        pendingMode = .training
        showThemePicker = true
    }

    private func proceedAfterThemePick() {
        switch pendingMode {
        case .ranked:
            guard !store.isPremium, model.store.shouldShowRankedDuelAd() else {
                isRankedPresented = true
                return
            }
            AdsManager.shared.showInterstitial(from: TopViewControllerFinder.topViewController()) {
                model.store.resetRankedDuelAdCounter()
                isRankedPresented = true
            }
        case .training:
            guard !store.isPremium, model.store.shouldShowBotMatchAd() else {
                isTrainingPresented = true
                return
            }
            AdsManager.shared.showInterstitial(from: TopViewControllerFinder.topViewController()) {
                model.store.resetBotMatchAdCounter()
                isTrainingPresented = true
            }
        }
    }
}
