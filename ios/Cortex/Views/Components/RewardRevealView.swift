import SwiftUI

/// Full-screen "you just won something" moment: a gift box wobbles until the
/// player taps it, bursts open with light rays and confetti, then each reward
/// pops out one after the other with its count rolling up.
struct RewardRevealView: View {
    let eyebrow: String
    let title: String
    let rewards: [Reward]
    var tint: Color = Theme.primary
    let onDone: () -> Void

    @State private var isOpened: Bool = false
    @State private var wobble: Bool = false
    @State private var revealedCount: Int = 0
    @State private var raysRotation: Double = 0
    @State private var burst: Bool = false
    @State private var showButton: Bool = false

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                VStack(spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text(isOpened ? title : "Une récompense t'attend")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)
                ZStack {
                    rays
                    ConfettiBurst(isActive: burst, colors: [tint, Theme.gold, Theme.livres, Color(hex: "FF4B4B"), Theme.success])
                    if isOpened {
                        rewardStack
                    } else {
                        giftButton
                    }
                }
                .frame(height: 320)
                Spacer(minLength: 16)

                Group {
                    if showButton {
                        Button("CONTINUER") {
                            Haptics.tap()
                            onDone()
                        }
                        .buttonStyle(ChunkyButtonStyle(color: tint))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !isOpened {
                        Text("Touche le cadeau pour l'ouvrir")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(height: 60)
                    } else {
                        Color.clear.frame(height: 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) { wobble = true }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { raysRotation = 360 }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color(hex: "0E1620")
            RadialGradient(
                colors: [tint.opacity(isOpened ? 0.55 : 0.3), .clear],
                center: .center, startRadius: 10, endRadius: 420
            )
            .animation(.easeOut(duration: 0.6), value: isOpened)
        }
        .ignoresSafeArea()
    }

    private var rays: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.35), .clear], startPoint: .bottom, endPoint: .top))
                    .frame(width: 26, height: 190)
                    .offset(y: -95)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
        .rotationEffect(.degrees(raysRotation))
        .scaleEffect(isOpened ? 1.15 : 0.7)
        .opacity(isOpened ? 1 : 0.45)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isOpened)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var giftButton: some View {
        Button(action: open) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 190, height: 190)
                Image(systemName: "gift.fill")
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.25)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: tint.opacity(0.6), radius: 24)
                    .rotationEffect(.degrees(wobble ? -6 : 6))
                    .scaleEffect(wobble ? 1.04 : 0.98)
            }
            .frame(width: 220, height: 220)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir la récompense")
        .transition(.scale(scale: 1.6).combined(with: .opacity))
    }

    private var rewardStack: some View {
        VStack(spacing: 12) {
            ForEach(Array(rewards.enumerated()), id: \.element.id) { index, reward in
                if index < revealedCount {
                    RewardRow(reward: reward)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            if rewards.isEmpty {
                Image("MascotCelebrate")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 170)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 32)
    }

    private func open() {
        guard !isOpened else { return }
        Haptics.medium()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            isOpened = true
            burst = true
        }
        Task { @MainActor in
            for index in rewards.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 280 : 360))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { revealedCount = index + 1 }
                Haptics.tap()
            }
            try? await Task.sleep(for: .milliseconds(380))
            Haptics.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showButton = true }
        }
    }
}

private struct RewardRow: View {
    let reward: Reward
    @State private var shown: Int = 0
    @State private var pop: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: reward.kind.icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 16).fill(reward.kind.color))
                .background(RoundedRectangle(cornerRadius: 16).fill(reward.kind.color.mix(with: .black, by: 0.3)).offset(y: 3))
                .scaleEffect(pop ? 1 : 0.6)
                .symbolEffect(.bounce, value: pop)
            VStack(alignment: .leading, spacing: 0) {
                Text("+\(shown)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(reward.kind.color)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                Text(reward.kind.label(reward.amount))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(reward.kind.color.opacity(0.5), lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("+\(reward.amount) \(reward.kind.label(reward.amount))")
        .task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pop = true }
            let steps = min(reward.amount, 12)
            for step in 1...max(steps, 1) {
                try? await Task.sleep(for: .milliseconds(40))
                withAnimation(.snappy(duration: 0.15)) {
                    shown = steps == 0 ? reward.amount : reward.amount * step / steps
                }
            }
        }
    }
}

/// Cheap confetti: coloured pieces flung outward from the centre once.
private struct ConfettiBurst: View {
    let isActive: Bool
    let colors: [Color]

    private struct Piece: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let spin: Double
        let colorIndex: Int
    }

    private let pieces: [Piece] = (0..<36).map { index in
        Piece(
            id: index,
            angle: Double(index) / 36 * 2 * .pi + Double.random(in: -0.15...0.15),
            distance: CGFloat.random(in: 110...190),
            size: CGFloat.random(in: 7...12),
            spin: Double.random(in: 180...540),
            colorIndex: index
        )
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[piece.colorIndex % colors.count])
                    .frame(width: piece.size, height: piece.size * 0.55)
                    .rotationEffect(.degrees(isActive ? piece.spin : 0))
                    .offset(
                        x: isActive ? cos(piece.angle) * piece.distance : 0,
                        y: isActive ? sin(piece.angle) * piece.distance + 40 : 0
                    )
                    .opacity(isActive ? 0 : 1)
                    .animation(.easeOut(duration: 1.3), value: isActive)
            }
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    RewardRevealView(
        eyebrow: "Mission terminée",
        title: "Bien joué !",
        rewards: [Reward(kind: .heart, amount: 1), Reward(kind: .diamonds, amount: 10)],
        onDone: {}
    )
}

/// Shows the reward reveal on top of a results screen the first time it
/// appears; "Continuer" fades it away to uncover the detailed results.
private struct RewardRevealOverlay: ViewModifier {
    let eyebrow: String
    let title: String
    let rewards: [Reward]
    let tint: Color
    @State private var isDismissed: Bool = false

    func body(content: Content) -> some View {
        content.overlay {
            if !rewards.isEmpty, !isDismissed {
                RewardRevealView(eyebrow: eyebrow, title: title, rewards: rewards, tint: tint) {
                    withAnimation(.easeOut(duration: 0.3)) { isDismissed = true }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}

extension View {
    /// Covers the view with the reward reveal until the player continues.
    /// Does nothing when `rewards` is empty.
    func rewardReveal(eyebrow: String, title: String, rewards: [Reward], tint: Color = Theme.duelAccent) -> some View {
        modifier(RewardRevealOverlay(eyebrow: eyebrow, title: title, rewards: rewards, tint: tint))
    }
}
