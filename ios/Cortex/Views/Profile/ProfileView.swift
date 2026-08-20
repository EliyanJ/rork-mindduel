import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @State private var isSignInPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isFriendsPresented: Bool = false
    @State private var isQRPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    friendsRow
                    if !online.isSignedIn {
                        signedOutCard
                    }
                    recapCard
                    streakCard
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
        .sheet(isPresented: $isQRPresented) {
            FriendQRView()
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
}
