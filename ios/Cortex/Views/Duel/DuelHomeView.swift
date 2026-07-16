import SwiftUI

struct DuelHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @State private var isRankedPresented: Bool = false
    @State private var isTrainingPresented: Bool = false
    @State private var isLeaderboardPresented: Bool = false
    @State private var isSignInPresented: Bool = false
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
                    rulesCard
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
                isLeaderboardPresented = true
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.gold.opacity(0.14)))
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

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Comment ça marche")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            ruleRow(icon: "globe", color: Theme.duelAccent.mix(with: .black, by: 0.2), text: "Match classé : un vrai joueur de ton niveau, même question au même moment.")
            ruleRow(icon: "hare.fill", color: Theme.gold.mix(with: .black, by: 0.1), text: "Bonne réponse rapide = jackpot. Lente = moins de points. Erreur = 0, sans pénalité.")
            ruleRow(icon: "chart.line.uptrend.xyaxis", color: Theme.success, text: "Ton ELO mondial monte ou descend à chaque match classé. Abandon = défaite.")
            ruleRow(icon: "person.2.fill", color: Theme.primary, text: "Ajoute des amis avec leur code dans ton profil et compare vos classements.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
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
