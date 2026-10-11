import SwiftUI

/// "Tu nous as manqué": full-screen offer shown at launch when the streak
/// broke less than 48 h ago. Repair it with diamonds (once a week) or
/// start again from zero.
struct StreakRepairView: View {
    let broken: ProgressStore.BrokenStreak
    let progressStore: ProgressStore
    let onRepaired: () -> Void
    let onRestart: () -> Void
    let onOpenMissions: () -> Void

    @State private var isMissingPresented: Bool = false
    @State private var appeared: Bool = false
    @State private var flicker: Bool = false
    @State private var isRepaired: Bool = false

    private var nextRepair: Date? { progressStore.nextStreakRepairDate() }
    private var dayWord: String { broken.length > 1 ? "jours" : "jour" }

    var body: some View {
        ZStack {
            Theme.duelBackground.ignoresSafeArea()
            RadialGradient(
                colors: [(isRepaired ? Theme.primary : Theme.livres).opacity(0.28), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: isRepaired)

            VStack(spacing: 0) {
                Spacer()
                flameBadge
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)

                Text(isRepaired ? "Série réparée !" : "Tu nous as manqué !")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
                    .contentTransition(.opacity)

                Text(message)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                if !isRepaired {
                    balancePill
                        .padding(.top, 22)
                }
                Spacer()

                buttons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
            }
        }
        .sheet(isPresented: $isMissingPresented) {
            InsufficientDiamondsSheet(cost: broken.cost, progressStore: progressStore) {
                onOpenMissions()
            }
        }
        .task {
            Haptics.medium()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { flicker = true }
        }
    }

    private var message: String {
        if isRepaired {
            return "Ta série de \(broken.length) \(dayWord) repart de plus belle. Fais une leçon aujourd'hui pour la prolonger !"
        }
        if let nextRepair {
            return "Ta série de \(broken.length) \(dayWord) s'est arrêtée. Tu l'as déjà réparée cette semaine : prochaine réparation possible \(nextRepair.formatted(.dateTime.weekday(.wide).day().month(.wide)))."
        }
        return "Ta série de \(broken.length) \(dayWord) s'est arrêtée. Répare-la pour \(broken.cost) 💎 ?"
    }

    private var flameBadge: some View {
        ZStack {
            Circle()
                .fill((isRepaired ? Theme.primary : Theme.livres).opacity(0.16))
                .frame(width: 190, height: 190)
            Image(systemName: isRepaired ? "flame.fill" : "flame")
                .font(.system(size: 92, weight: .bold))
                .foregroundStyle(
                    isRepaired
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.primary], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.white.opacity(0.35))
                )
                .scaleEffect(flicker ? 1.04 : 0.96)
                .contentTransition(.symbolEffect(.replace))
            Text("\(broken.length)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: 22)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Série de \(broken.length) \(dayWord)")
    }

    private var balancePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(Theme.livres)
            Text("Tu as \(progressStore.livresBalance)")
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var buttons: some View {
        if isRepaired {
            Button {
                Haptics.tap()
                onRepaired()
            } label: {
                Text("C'EST PARTI !")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
        } else {
            VStack(spacing: 14) {
                if nextRepair == nil {
                    Button {
                        repair()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Réparer ma série")
                            Text("· \(broken.cost)")
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.livres))
                }
                Button {
                    Haptics.tap()
                    onRestart()
                } label: {
                    Text("Repartir de zéro")
                }
                .buttonStyle(ChunkyButtonStyle(color: .white.opacity(0.12)))
            }
        }
    }

    private func repair() {
        guard progressStore.livresBalance >= broken.cost else {
            Haptics.error()
            isMissingPresented = true
            return
        }
        guard progressStore.repairStreak() else {
            Haptics.error()
            return
        }
        Haptics.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { isRepaired = true }
    }
}

#Preview {
    StreakRepairView(
        broken: .init(length: 12, cost: 60, expiresAt: .now.addingTimeInterval(3600)),
        progressStore: ProgressStore(),
        onRepaired: {},
        onRestart: {},
        onOpenMissions: {}
    )
    .environment(StoreViewModel())
}
