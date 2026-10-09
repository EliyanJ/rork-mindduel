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
    @State private var pendingPartyOrigin: PartySession.Origin?
    @State private var isFlashPresented: Bool = false
    @State private var isLocalPresented: Bool = false
    @State private var isCustomSetupPresented: Bool = false
    @State private var isDuelPointsPresented: Bool = false
    @State private var isPaywallPresented: Bool = false
    @State private var paywallSource: String = "duel"

    private enum DuelMode {
        case ranked
        case training
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
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            rankedModeCard
                            modeCard(title: "1 vs 10", subtitle: "Toi contre tous", icon: "flame.fill", colors: ["FF7675", "D63031"]) {
                                joinParty(.oneVsTen)
                            }
                            modeCard(title: "Flash", subtitle: "Solo rapide", icon: "bolt.fill", colors: ["FDCB6E", "E17055"]) {
                                Haptics.medium()
                                isFlashPresented = true
                            }
                            modeCard(title: "Personnalisé", subtitle: "Choisis tes équipes", icon: "slider.horizontal.3", colors: ["00B894", "00896B"]) {
                                Haptics.medium()
                                isCustomSetupPresented = true
                            }
                            modeCard(title: "Local", subtitle: "Même réseau", icon: "wifi", colors: ["0984E3", "0652DD"]) {
                                Haptics.medium()
                                isLocalPresented = true
                            }
                            modeCard(title: "Entraînement", subtitle: "Non classé", icon: "figure.strengthtraining.traditional", colors: ["FF9F43", "E58E26"]) {
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
            FlashDuelView(catalog: model.catalog, store: model.store, isTeamFlavor: false) {
                isFlashPresented = false
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
            if !store.isPremium {
                duelPointsPill
            }
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

    /// Remaining free-tier duel points; tapping explains them and offers the
    /// rewarded-video refill.
    private var duelPointsPill: some View {
        let points = model.store.duelPoints
        return Button {
            Haptics.tap()
            isDuelPointsPresented = true
        } label: {
            HStack(spacing: 3) {
                ForEach(0..<ProgressStore.duelPointsMax, id: \.self) { index in
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(index < points ? Theme.duelAccent : Theme.inkMuted.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(Theme.duelAccent.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(points) points de duel sur \(ProgressStore.duelPointsMax)")
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

    /// 1v1 ranked slots into the mode grid like every other mode — it's not
    /// special, it's just the mode where the queue finds a real opponent.
    /// The points/record live here as the subtitle instead of a dedicated
    /// full-width banner.
    private var rankedModeCard: some View {
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
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.2)))
                    Spacer()
                    if !store.isPremium {
                        Label("Premium", systemImage: "crown.fill")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.duelBackground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.gold))
                    } else if online.isSignedIn, let profile = online.profile {
                        Text("\(profile.displayPoints)")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
                Spacer(minLength: 14)
                Text("1V1")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(!store.isPremium ? "Match classé" : (online.isSignedIn ? "Match classé" : "Se connecter"))
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
                            colors: [Theme.duelAccent, Theme.duelAccent.mix(with: .black, by: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
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

    /// Every non-ranked mode costs one duel point for free players (spent
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
        case .training:
            isTrainingPresented = true
        }
    }
}
