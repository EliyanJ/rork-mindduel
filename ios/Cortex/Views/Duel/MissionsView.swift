import SwiftUI

/// "Missions" tab, in the spirit of Duolingo's quests: a colorful banner with
/// the time left today, then one card per daily mission with a thick
/// progress bar and a chest to open once it's done. Everything resets at
/// midnight (counters live in `DailyUsage`).
struct MissionsView: View {
    @Environment(AppModel.self) private var model
    @State private var appeared: Bool = false
    @State private var reveal: RewardRevealItem?

    private var missions: [DailyMission] {
        let usage = model.store.dailyUsage
        let practicedToday = model.store.progress.lastActiveDay.map { Calendar.current.isDateInToday($0) } ?? false
        let list: [DailyMission] = [
            DailyMission(id: "rings", icon: "star.fill", color: Theme.primary,
                         title: "Termine 2 épreuves", progress: usage.ringsCompleted, goal: 2,
                         rewards: [Reward(kind: .lessonBolt, amount: 1)]),
            DailyMission(id: "answers", icon: "checkmark.seal.fill", color: Theme.success,
                         title: "Donne 15 bonnes réponses", progress: usage.correctAnswers, goal: 15,
                         rewards: [Reward(kind: .diamonds, amount: 5)]),
            DailyMission(id: "duel", icon: "bolt.fill", color: Theme.duelAccent,
                         title: "Joue 1 duel", progress: usage.duelsPlayed, goal: 1,
                         rewards: [Reward(kind: .duelBolt, amount: 1)]),
            DailyMission(id: "win", icon: "trophy.fill", color: Theme.gold,
                         title: "Gagne 1 duel", progress: usage.duelsWon, goal: 1,
                         rewards: [Reward(kind: .heart, amount: 1)]),
            DailyMission(id: "streak", icon: "flame.fill", color: Color(hex: "FF4B4B"),
                         title: "Entretiens ta série", progress: practicedToday ? 1 : 0, goal: 1,
                         rewards: [Reward(kind: .diamonds, amount: 3)])
        ]
        return list
    }

    private var doneCount: Int { missions.filter(\.isDone).count }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Missions")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.livres)
                    Text("\(model.store.livresBalance)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.livres)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(model.store.livresBalance) diamants")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            Rectangle().fill(Theme.line).frame(height: 1.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    banner
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Missions du jour")
                                .font(.system(.title2, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                Label(Self.timeLeft(from: context.date), systemImage: "clock.fill")
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .foregroundStyle(Theme.gold.mix(with: .black, by: 0.1))
                            }
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(missions.enumerated()), id: \.element.id) { index, mission in
                                MissionRow(
                                    mission: mission,
                                    isClaimed: model.store.isMissionClaimed(mission.id),
                                    onClaim: { claim(mission) }
                                )
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 14)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.06), value: appeared)
                                if index < missions.count - 1 {
                                    Rectangle().fill(Theme.line).frame(height: 1.5)
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.background))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 2))
                    }
                    bonusCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(item: $reveal) { item in
            RewardRevealView(eyebrow: item.eyebrow, title: item.title, rewards: item.rewards, tint: item.tint) {
                reveal = nil
            }
        }
        .onAppear { appeared = true }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(doneCount == missions.count ? "Bravo, tout est bouclé !" : "Gagne des cœurs, des éclairs et des diamants")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(doneCount) sur \(missions.count) missions terminées")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Image(doneCount == missions.count ? "MascotCelebrate" : "MascotCheer")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(hex: "A560FF"), Color(hex: "7B3FE4")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    /// Big chest unlocked once every daily mission is done.
    private var bonusCard: some View {
        let allDone = doneCount == missions.count
        let claimed = model.store.isMissionClaimed(Self.bonusId)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Coffre du jour")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 14) {
                Image(systemName: claimed ? "shippingbox.and.arrow.backward.fill" : "shippingbox.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(allDone ? Theme.gold : Theme.lockedInk)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 16).fill(allDone ? Theme.gold.opacity(0.16) : Theme.lockedFill.opacity(0.5)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Termine toutes les missions")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(claimed ? "Coffre ouvert, à demain !" : "Cœur, éclair de duel et diamants")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 0)
                if allDone && !claimed {
                    Button("OUVRIR") {
                        claim(DailyMission(id: Self.bonusId, icon: "", color: Theme.gold, title: "", progress: 1, goal: 1, rewards: Self.bonusRewards))
                    }
                    .buttonStyle(ClaimButtonStyle())
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 2))
        }
    }

    private static let bonusId = "bonus"
    private static let bonusRewards: [Reward] = [
        Reward(kind: .heart, amount: 1),
        Reward(kind: .duelBolt, amount: 1),
        Reward(kind: .diamonds, amount: 10)
    ]

    private func claim(_ mission: DailyMission) {
        guard let granted = model.store.claimMission(mission.id, rewards: mission.rewards) else { return }
        Haptics.medium()
        Analytics.capture("mission_claimed", ["mission": mission.id])
        let isBonus = mission.id == Self.bonusId
        reveal = RewardRevealItem(
            eyebrow: isBonus ? "Coffre du jour" : "Mission terminée",
            title: isBonus ? "Coffre ouvert !" : "Tu as gagné",
            rewards: granted,
            tint: isBonus ? Theme.gold : mission.color
        )
    }

    private static func timeLeft(from date: Date) -> String {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        let minutes = max(0, Int(midnight.timeIntervalSince(date) / 60))
        let hours = minutes / 60
        return hours > 0 ? "\(hours) h" : "\(minutes) min"
    }
}

private struct DailyMission: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let progress: Int
    let goal: Int
    let rewards: [Reward]

    var isDone: Bool { progress >= goal }
    var ratio: Double { min(1, Double(progress) / Double(max(goal, 1))) }
}

private struct MissionRow: View {
    let mission: DailyMission
    let isClaimed: Bool
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mission.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(mission.color)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 10) {
                Text(mission.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 10) {
                    ProgressPill(ratio: mission.ratio, label: "\(min(mission.progress, mission.goal)) / \(mission.goal)", color: mission.color)
                    reward
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var reward: some View {
        if mission.isDone && !isClaimed {
            Button("OUVRIR", action: onClaim)
                .buttonStyle(ClaimButtonStyle())
                .accessibilityLabel("Ouvrir la récompense")
        } else if isClaimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.success)
                .frame(width: 44, height: 32)
                .accessibilityLabel("Récompense récupérée")
        } else {
            RewardPreview(rewards: mission.rewards)
        }
    }
}

/// Thick Duolingo-style progress bar with the count written inside.
private struct ProgressPill: View {
    let ratio: Double
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Capsule().fill(Theme.lockedFill)
            GeometryReader { geo in
                Capsule()
                    .fill(color)
                    .frame(width: ratio > 0 ? max(22, geo.size.width * ratio) : 0)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 5)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: ratio)
            }
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(ratio > 0.45 ? .white : Theme.inkMuted)
                .monospacedDigit()
        }
        .frame(height: 20)
    }
}

private struct ClaimButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minWidth: 56, minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.success))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.success.mix(with: .black, by: 0.25)).offset(y: 3))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Small "+1 ♥" style tag showing what a mission will give.
private struct RewardPreview: View {
    let rewards: [Reward]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(rewards) { reward in
                HStack(spacing: 2) {
                    Text("+\(reward.amount)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: reward.kind.icon)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(reward.kind.color)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("À gagner : " + rewards.map { "\($0.amount) \($0.kind.label($0.amount))" }.joined(separator: ", "))
    }
}
