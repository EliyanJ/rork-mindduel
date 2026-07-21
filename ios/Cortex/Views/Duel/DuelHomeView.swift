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
    @State private var selectedDuelDisciplineId: String? = nil
    @State private var showThemePicker: Bool = false
    @State private var pendingMode: DuelMode = .training

    private enum DuelMode {
        case ranked
        case training
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    rankedCard
                    trainingCard
                    leaderboardPreviewCard
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
        .sheet(isPresented: $isLeaderboardPresented) {
            LeaderboardView()
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
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    isFriendsPresented = true
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.primary.opacity(0.14)))
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var rankedCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(online.profile.map { "\($0.elo)" } ?? "—")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.duelAccent)
                        .contentTransition(.numericText())
                    Text("ELO MONDIAL")
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
                    Text("BILAN CLASSÉ")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                }
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

    private var trainingCard: some View {
        let progress = model.store.progress
        return HStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Entraînement")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Duel contre un bot · ELO local \(progress.elo)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Button {
                Haptics.medium()
                presentTraining()
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.primary))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    /// Compact top-3 preview of the world leaderboard, tappable to open the
    /// full `LeaderboardView` (the trophy shortcut moved here from the header).
    private var leaderboardPreviewCard: some View {
        Button {
            Haptics.tap()
            isLeaderboardPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Classement mondial", systemImage: "trophy.fill")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                if let top = online.leaderboard?.top, !top.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(top.prefix(3)) { entry in
                            topRow(entry)
                        }
                    }
                } else {
                    Text("Joue un match classé pour apparaître ici !")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .task { await online.refreshLeaderboard() }
    }

    private func topRow(_ entry: RankedEntry) -> some View {
        HStack(spacing: 10) {
            Text(rankLabel(entry.rank))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .frame(width: 28, alignment: .leading)
            Text(entry.emoji).font(.system(size: 20))
            Text(entry.name)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            Text("\(entry.elo)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent.mix(with: .black, by: 0.2))
        }
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
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

    private func ruleRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 26)
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
