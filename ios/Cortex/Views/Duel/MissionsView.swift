import SwiftUI

/// Daily mission list, reachable from the Duel screen's shortcut row. Each
/// mission tracks something the player already does elsewhere in the app
/// (duels, lessons, streak) — this is purely a motivating recap, no new
/// state is introduced.
struct MissionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss

    private var missions: [Mission] {
        let progress = model.store.progress
        return [
            Mission(
                icon: "bolt.fill",
                color: Theme.duelAccent,
                title: "Joue 1 duel",
                subtitle: "Classé, entraînement ou multijoueur",
                progress: min(progress.duelsPlayed, 1),
                goal: 1,
                reward: 15
            ),
            Mission(
                icon: "flame.fill",
                color: Theme.gold,
                title: "Maintiens ta série",
                subtitle: "\(model.store.currentStreak) jour\(model.store.currentStreak > 1 ? "s" : "") d'affilée",
                progress: model.store.currentStreak > 0 ? 1 : 0,
                goal: 1,
                reward: 5
            ),
            Mission(
                icon: "trophy.fill",
                color: Theme.success,
                title: "Gagne un duel",
                subtitle: "Remporte n'importe quel format",
                progress: min(progress.duelsWon, 1),
                goal: 1,
                reward: 25
            ),
            Mission(
                icon: "diamond.fill",
                color: Theme.primary,
                title: "Amasse des rubis",
                subtitle: "\(progress.livresBalance) rubis en poche",
                progress: min(progress.livresBalance, 50),
                goal: 50,
                reward: 10
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    ForEach(missions) { mission in
                        missionRow(mission)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("Missions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("🎯")
                .font(.system(size: 40))
            Text("Missions du jour")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Elles se réinitialisent chaque jour à minuit")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func missionRow(_ mission: Mission) -> some View {
        let isDone = mission.progress >= mission.goal
        return HStack(spacing: 14) {
            Image(systemName: isDone ? "checkmark" : mission.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isDone ? .white : mission.color)
                .frame(width: 46, height: 46)
                .background(Circle().fill(isDone ? mission.color : mission.color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 5) {
                Text(mission.title)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(mission.subtitle)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule()
                            .fill(mission.color)
                            .frame(width: geo.size.width * min(1, Double(mission.progress) / Double(mission.goal)))
                    }
                }
                .frame(height: 6)
            }
            Spacer(minLength: 6)
            VStack(spacing: 2) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.gold)
                Text("+\(mission.reward)")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5))
        .opacity(isDone ? 0.7 : 1)
    }
}

private struct Mission: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let progress: Int
    let goal: Int
    let reward: Int
}
