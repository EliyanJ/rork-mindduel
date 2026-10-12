import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(AvatarStore.self) private var avatarStore
    @State private var onboardingStore = OnboardingStore()
    @State private var isSignInPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isFriendsPresented: Bool = false
    @State private var isQRPresented: Bool = false
    @State private var isAvatarEditorPresented: Bool = false
    @State private var isRenamePresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        friendsRow
                        if !online.isSignedIn {
                            signedOutCard
                        }
                        recapCard
                        StreakCalendarView(
                            history: model.store.streakHistory(),
                            currentStreak: model.store.currentStreak,
                            freezes: model.store.streakFreezes
                        )
                        .id(Self.streakAnchor)
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
                .onChange(of: model.isStreakCalendarRequested, initial: true) { _, isRequested in
                    guard isRequested else { return }
                    model.isStreakCalendarRequested = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            proxy.scrollTo(Self.streakAnchor, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .sheet(isPresented: $isFriendsPresented) {
            FriendsView()
        }
        .sheet(isPresented: $isQRPresented) {
            FriendsView(initialPage: .qrCode)
        }
        .sheet(isPresented: $isAvatarEditorPresented) {
            AvatarEditorView(store: avatarStore) { isAvatarEditorPresented = false }
        }
        .sheet(isPresented: $isRenamePresented) {
            RenameNicknameSheet(
                currentName: online.profile?.name ?? onboardingStore.preferences.nickname,
                changesUsed: onboardingStore.preferences.nicknameChangeCount,
                store: model.store,
                onSave: { newName in
                    var prefs = onboardingStore.preferences
                    prefs.nickname = newName
                    prefs.nicknameChangeCount += 1
                    onboardingStore.save(prefs)
                    if online.isSignedIn {
                        Task { await online.updateProfile(name: newName, emoji: nil) }
                    }
                    isRenamePresented = false
                },
                onCancel: { isRenamePresented = false }
            )
        }
        .task {
            if online.isSignedIn {
                if online.profile == nil {
                    await online.syncProfile(localElo: model.store.progress.elo)
                }
                await online.refreshFriends()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                isAvatarEditorPresented = true
            } label: {
                AvatarView(config: avatarStore.config, size: 62)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.primary)
                            .background(Circle().fill(Theme.card))
                    }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    Haptics.tap()
                    isRenamePresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .buttonStyle(.plain)
                if let profile = online.profile {
                    Text("@\(handle(from: profile.friendCode))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                } else {
                    Text("Joueur hors-ligne")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            Spacer()
            Button {
                Haptics.tap()
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func handle(from code: String) -> String {
        code.replacingOccurrences(of: "#", with: "").lowercased()
    }

    private var displayName: String {
        if let name = online.profile?.name, !name.isEmpty { return name }
        if !onboardingStore.preferences.nickname.isEmpty { return onboardingStore.preferences.nickname }
        return "Ton profil"
    }

    // MARK: - Friends row

    private var friendsRow: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                if online.isSignedIn {
                    isFriendsPresented = true
                } else {
                    isSignInPresented = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .heavy))
                    Text("AJOUTER DES AMIS")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .tracking(0.3)
                    if !online.incomingRequests.isEmpty {
                        Text("\(online.incomingRequests.count)")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Theme.danger))
                    }
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                if online.isSignedIn {
                    isQRPresented = true
                } else {
                    isSignInPresented = true
                }
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var signedOutCard: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Compte en ligne", systemImage: "person.crop.circle.badge.plus")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Connecte-toi pour affronter de vrais joueurs, ajouter des amis et apparaître au classement mondial.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.medium()
                    isSignInPresented = true
                } label: {
                    Label("Se connecter", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
            }
            Spacer(minLength: 0)
            Image("MascotWink")
                .resizable()
                .scaledToFit()
                .frame(width: 64)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    // MARK: - Récap

    /// Compact summary: streak, ranked standing and win/loss record. Rubis,
    /// énergie and total XP live only in the Parcours/Thèmes tabs now.
    private var recapCard: some View {
        let progress = model.store.progress
        return VStack(alignment: .leading, spacing: 14) {
            Text("RÉCAP")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.inkMuted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                recapItem(icon: "flame.fill", color: Theme.primary, value: "\(model.store.currentStreak)", label: "Jours de suite")
                recapItem(
                    icon: "chart.line.uptrend.xyaxis",
                    color: Theme.success,
                    value: online.profile.map { "\($0.displayPoints)" } ?? "\(progress.elo)",
                    label: online.profile != nil ? "Points classés" : "Niveau local"
                )
                recapItem(icon: "crown.fill", color: Theme.gold, value: "\(model.store.masteredChaptersCount)", label: "Leçons maîtrisées")
                if let profile = online.profile {
                    recapItem(icon: "trophy.fill", color: Theme.duelAccent.mix(with: .black, by: 0.15), value: "\(profile.wins)V · \(profile.losses)D", label: "Duels")
                } else {
                    recapItem(icon: "trophy.fill", color: Theme.duelAccent.mix(with: .black, by: 0.15), value: "\(progress.duelsWon)", label: "Duels gagnés")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    private func recapItem(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Streak

    private static let streakAnchor = "streakCalendar"
}
