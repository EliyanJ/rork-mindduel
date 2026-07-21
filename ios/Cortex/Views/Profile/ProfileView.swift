import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @State private var isSignInPresented: Bool = false
    @State private var didCopyCode: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isFriendsPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    accountCard
                    if online.isSignedIn {
                        friendsShortcutCard
                    }
                    streakCard
                    statsGrid
                    masteryCard
                }
                .padding(16)
                .padding(.bottom, 32)
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
        .task {
            if online.isSignedIn {
                if online.profile == nil {
                    await online.syncProfile(localElo: model.store.progress.elo)
                }
                await online.refreshFriends()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(online.profile?.emoji ?? "🧠")
                .font(.system(size: 34))
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.primary.opacity(0.12)))
                .overlay(Circle().stroke(Theme.primary.opacity(0.3), lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(online.profile?.name ?? "Ton profil")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(online.profile.map { "ELO mondial \($0.elo)" } ?? "ELO local \(model.store.progress.elo)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
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

    @ViewBuilder
    private var accountCard: some View {
        if let profile = online.profile {
            signedInCard(profile)
        } else if online.isSignedIn {
            HStack(spacing: 12) {
                ProgressView().tint(Theme.primary)
                Text("Synchronisation du profil…")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        } else {
            signedOutCard
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

    private func signedInCard(_ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Compte en ligne", systemImage: "checkmark.seal.fill")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.success)
                Spacer()
                Button("Déconnexion") {
                    Task { await online.signOut() }
                }
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.danger)
            }
            HStack(spacing: 20) {
                statColumn(value: "\(profile.elo)", label: "ELO MONDIAL", color: Theme.duelAccent.mix(with: .black, by: 0.2))
                statColumn(value: "\(profile.wins)", label: "VICTOIRES", color: Theme.success)
                statColumn(value: "\(profile.losses)", label: "DÉFAITES", color: Theme.danger)
            }
            Button {
                UIPasteboard.general.string = profile.friendCode
                didCopyCode = true
                Haptics.success()
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    didCopyCode = false
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TON CODE AMI")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.inkMuted)
                        Text(profile.friendCode)
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .kerning(2)
                    }
                    Spacer()
                    Label(didCopyCode ? "Copié !" : "Copier", systemImage: didCopyCode ? "checkmark" : "doc.on.doc")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(didCopyCode ? Theme.success : Theme.primary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Text("Partage ce code pour que tes amis t'ajoutent.")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    /// Compact entry point to the full-screen `FriendsView` (moved out of
    /// the profile so the Duel screen can also open it — see DuelHomeView).
    private var friendsShortcutCard: some View {
        Button {
            Haptics.tap()
            isFriendsPresented = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amis")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(online.friends.isEmpty ? "Ajoute des amis avec leur code" : "\(online.friends.count) ami\(online.friends.count > 1 ? "s" : "")")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                if !online.incomingRequests.isEmpty {
                    Text("\(online.incomingRequests.count)")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.danger))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func statColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var streakCard: some View {
        let streak = model.store.currentStreak
        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(streak > 0 ? Theme.primary : Theme.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) jour\(streak > 1 ? "s" : "") de suite")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(streak > 0 ? "Ne casse pas ta série !" : "Termine une leçon pour allumer la flamme")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
            }
            weekRow
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    private var weekRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Today on the left, past days extending to the right so the streak
        // visually grows from left to right as the user keeps it alive.
        let days: [Date] = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        return HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let isActive = model.store.progress.activeDays.contains(day)
                VStack(spacing: 5) {
                    Text(dayLetter(day))
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                    Image(systemName: isActive ? "flame.fill" : "circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isActive ? Theme.primary : Theme.line)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    private var statsGrid: some View {
        let progress = model.store.progress
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard(icon: "text.book.closed.fill", color: Theme.gold, value: "\(progress.xp)", label: "XP total")
            statCard(icon: "diamond.fill", color: Theme.livres, value: "\(progress.livresBalance)", label: "Rubis")
            statCard(icon: "crown.fill", color: Theme.primary, value: "\(model.store.masteredChaptersCount)", label: "Étapes maîtrisées")
            statCard(icon: "trophy.fill", color: Theme.duelAccent.mix(with: .black, by: 0.15), value: "\(progress.duelsWon)", label: "Duels gagnés")
            statCard(icon: "chart.line.uptrend.xyaxis", color: Theme.success, value: online.profile.map { "\($0.elo)" } ?? "\(progress.elo)", label: online.profile != nil ? "ELO mondial" : "ELO local")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
    }

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Maîtrise par thème")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            ForEach(model.catalog.disciplines) { discipline in
                let mastery = model.masteryPercent(for: discipline)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(discipline.name, systemImage: discipline.icon)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(discipline.color)
                        Spacer()
                        Text("\(Int(mastery * 100)) %")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line.opacity(0.6))
                            if mastery > 0 {
                                Capsule()
                                    .fill(discipline.color)
                                    .frame(width: max(10, geo.size.width * mastery))
                            }
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }
}
