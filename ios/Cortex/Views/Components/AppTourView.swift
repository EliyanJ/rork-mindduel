import SwiftUI

/// Places of the main screen the first-run tour can spotlight.
enum TourTarget: String, Hashable, Sendable {
    case stats, banner, ring, tabDuel, tabLeague, tabMissions, tabPremium

    init?(tab: AppTab) {
        switch tab {
        case .duel: self = .tabDuel
        case .classement: self = .tabLeague
        case .missions: self = .tabMissions
        case .premium: self = .tabPremium
        default: return nil
        }
    }
}

/// Collects the on-screen frame of every tour target.
nonisolated struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as a spot the tour can highlight. `nil` does nothing.
    func tourAnchor(_ target: TourTarget?) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { anchor in
            guard let target else { return [:] }
            return [target: anchor]
        }
    }
}

/// One beat of the tour: what to light up and what the mascot says.
struct TourStep: Identifiable {
    let id: Int
    let target: TourTarget?
    let mascot: String
    let title: String
    let text: String
}

extension TourStep {
    static let all: [TourStep] = [
        TourStep(id: 0, target: nil, mascot: "MascotWave",
                 title: "Salut, moi c'est Mindy !",
                 text: "Je te fais visiter Minduel en 30 secondes."),
        TourStep(id: 1, target: .stats, mascot: "MascotIdea",
                 title: "Tes ressources",
                 text: "Diamants, éclairs pour lancer une leçon, cœurs, et ta série de jours d'affilée."),
        TourStep(id: 2, target: .banner, mascot: "MascotRead",
                 title: "Ton chapitre",
                 text: "Touche-le pour voir tous les chapitres et changer de thème."),
        TourStep(id: 3, target: .ring, mascot: "MascotStudy",
                 title: "Ta prochaine épreuve",
                 text: "Une petite fiche à lire, puis un quiz. Valide-la pour avancer sur le chemin !"),
        TourStep(id: 4, target: .tabDuel, mascot: "MascotDuel",
                 title: "Les duels",
                 text: "Affronte tes amis ou des joueurs du monde entier, en direct."),
        TourStep(id: 5, target: .tabLeague, mascot: "MascotTrophy",
                 title: "Le classement",
                 text: "Gagne des points et grimpe chaque semaine face aux autres joueurs."),
        TourStep(id: 6, target: .tabMissions, mascot: "MascotGift",
                 title: "Les missions",
                 text: "Des défis chaque jour, avec des cadeaux à ouvrir : cœurs, éclairs, diamants."),
        TourStep(id: 7, target: .tabPremium, mascot: "MascotCelebrate",
                 title: "Premium",
                 text: "Tout en illimité, tous les thèmes et les modes classés exclusifs."),
        TourStep(id: 8, target: nil, mascot: "MascotCheer",
                 title: "À toi de jouer !",
                 text: "Lance ta première épreuve, je t'attends au bout du chemin.")
    ]
}

/// First-run guided tour: dims the screen, cuts a glowing hole around the
/// element being explained and lets the mascot comment each spot in a
/// speech bubble. The hole glides from one spot to the next like a montage.
struct AppTourView: View {
    let anchors: [TourTarget: Anchor<CGRect>]
    let onFinish: () -> Void

    @State private var index: Int = 0
    @State private var typedCount: Int = 0
    @State private var isPulsing: Bool = false
    @State private var typingTask: Task<Void, Never>?

    private let steps = TourStep.all
    private var step: TourStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        // The outer reader keeps the real safe-area insets (Dynamic Island,
        // home indicator); the inner one covers the full screen for the veil.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            GeometryReader { geo in
                tourLayer(geo: geo, insets: insets)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            Analytics.capture("app_tour_started")
            startTyping()
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isPulsing = true }
        }
        .onDisappear { typingTask?.cancel() }
    }

    private func tourLayer(geo: GeometryProxy, insets: EdgeInsets) -> some View {
            let hole = holeRect(in: geo)
            let cardOnTop = hole.map { $0.midY > geo.size.height * 0.5 } ?? false
            let topInset = max(insets.top, 47) + 52
            let bottomInset = max(insets.bottom, 20) + 16

            return ZStack {
                SpotlightShape(hole: hole ?? CGRect(x: geo.size.width / 2, y: geo.size.height / 2, width: 0, height: 0),
                               cornerRadius: hole == nil ? 0 : 18)
                    .fill(Color.black.opacity(0.68), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: advance)

                if let hole {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: hole.width, height: hole.height)
                        .scaleEffect(isPulsing ? 1.06 : 1)
                        .opacity(isPulsing ? 0.35 : 1)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    if !cardOnTop { Spacer(minLength: 0) }
                    card
                        .padding(.horizontal, 16)
                        .padding(.top, cardOnTop ? topInset : 0)
                        .padding(.bottom, cardOnTop ? 0 : bottomInset)
                        .id(step.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: cardOnTop ? .top : .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    if cardOnTop { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: index)
            .overlay(alignment: .topTrailing) {
            if !isLast {
                Button {
                    Haptics.tap()
                    Analytics.capture("app_tour_skipped", ["step": index])
                    onFinish()
                } label: {
                    Text("Passer")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, max(insets.top, 47) + 6)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                Image(step.mascot)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .id(step.mascot)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.primary)
                    ZStack(alignment: .topLeading) {
                        Text(step.text)
                            .opacity(0)
                        Text(String(step.text.prefix(typedCount)))
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(step.text)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 2))
                .overlay(alignment: .bottomLeading) {
                    BubbleTail()
                        .fill(Theme.card)
                        .frame(width: 12, height: 14)
                        .offset(x: -10, y: -20)
                }
            }
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    ForEach(steps) { item in
                        Capsule()
                            .fill(item.id == index ? Color.white : Color.white.opacity(0.35))
                            .frame(width: item.id == index ? 16 : 6, height: 6)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                Button(isLast ? "C'EST PARTI" : "CONTINUER", action: advance)
                    .buttonStyle(TourButtonStyle())
                    .fixedSize()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func holeRect(in geo: GeometryProxy) -> CGRect? {
        guard let target = step.target, let anchor = anchors[target] else { return nil }
        return geo[anchor].insetBy(dx: -8, dy: -8)
    }

    private func advance() {
        if typedCount < step.text.count {
            typingTask?.cancel()
            typedCount = step.text.count
            return
        }
        Haptics.tap()
        guard !isLast else {
            Haptics.success()
            Analytics.capture("app_tour_completed")
            onFinish()
            return
        }
        var next = index + 1
        // Skip any spot that is not on screen (e.g. journey finished).
        while next < steps.count - 1, let target = steps[next].target, anchors[target] == nil {
            next += 1
        }
        index = next
        startTyping()
    }

    private func startTyping() {
        typingTask?.cancel()
        typedCount = 0
        let total = step.text.count
        typingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            while typedCount < total, !Task.isCancelled {
                typedCount += 1
                try? await Task.sleep(for: .milliseconds(18))
            }
        }
    }
}

/// Full-screen rectangle with a rounded hole; animates between holes.
private struct SpotlightShape: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(hole.origin.x, hole.origin.y),
                AnimatablePair(AnimatablePair(hole.size.width, hole.size.height), cornerRadius)
            )
        }
        set {
            hole = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first.first, height: newValue.second.first.second)
            cornerRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if hole.width > 0, hole.height > 0 {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        return path
    }
}

/// Small tail on the left side of the bubble, pointing at the mascot.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TourButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.primary))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.primary.mix(with: .black, by: 0.25)).offset(y: 3))
            .padding(.bottom, 3)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
