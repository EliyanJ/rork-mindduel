import SwiftUI

/// The learning path of ONE lesson ("sous-thème"): its rings laid out as a
/// winding vertical trail.
///
/// Each ring is a squircle tile with a "ROND n" badge, joined to the next by
/// a hairline S-curve — lighter than the old braided cord so a 10-ring lesson
/// stays airy while scrolling.
struct RingPathView: View {
    let rings: [PathRing]
    let accent: Color
    /// Looks up a ring's playability (locking rules live on the journey).
    let stateOf: (PathRing) -> ChapterState
    let lockOf: (PathRing) -> RingLock?
    let recordOf: (PathRing) -> ChapterRecord?
    var showsRecapLabel: Bool = true
    let onSelect: (PathRing) -> Void

    @State private var pathWidth: CGFloat = 360

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(rings.enumerated()), id: \.element.id) { index, ring in
                if index > 0 {
                    connector(before: ring, at: index)
                }
                RingNodeView(
                    ring: ring,
                    state: stateOf(ring),
                    lock: lockOf(ring),
                    color: ring.kind == .recap ? Theme.gold : accent,
                    record: recordOf(ring)
                ) {
                    onSelect(ring)
                }
                .zIndex(1)
                .offset(x: horizontalOffset(for: ring, width: pathWidth))
                .background {
                    if let cameo = cameo(at: index) {
                        PathMascotCameo(imageName: cameo)
                            .offset(x: cameoOffset(for: ring, width: pathWidth))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            pathWidth = newWidth
        }
    }

    /// Occasional mascot cameo beside the path: roughly one every 7 rings,
    /// never on the very first ones, rotating through the stylised poses.
    private func cameo(at index: Int) -> String? {
        guard index % 7 == 3 else { return nil }
        let poses = PathMascotCameo.poses
        var generator = RingWobbleGenerator(seed: rings[index].chapterId)
        let start = Int.random(in: 0..<poses.count, using: &generator)
        return poses[(start + index / 7) % poses.count]
    }

    /// Puts the cameo on the side the path leaves free.
    private func cameoOffset(for ring: PathRing, width: CGFloat) -> CGFloat {
        let ringX = horizontalOffset(for: ring, width: width)
        let side: CGFloat = ringX > 0 ? -1 : 1
        return side * min(width * 0.3, 120)
    }

    /// Hairline S-curve joining two consecutive tiles: a pale stroke of the
    /// theme colour, no outline, no texture — intentionally discreet.
    @ViewBuilder
    private func connector(before ring: PathRing, at index: Int) -> some View {
        let previous = rings[index - 1]
        let fromX = horizontalOffset(for: previous, width: pathWidth)
        let toX = horizontalOffset(for: ring, width: pathWidth)
        TrailConnector(fromX: fromX, toX: toX, accent: accent)
            .frame(height: 56)
    }

    /// Deterministic pseudo-random horizontal wobble per ring, so the path
    /// reads as hand-drawn and playful rather than a repeating zig-zag.
    /// Stable across renders since it's seeded from the ring's own id.
    /// The very first rings stay close to the screen's center — the wobble
    /// ramps up gradually so the entrance of a lesson never feels lopsided.
    private func horizontalOffset(for ring: PathRing, width: CGFloat) -> CGFloat {
        guard ring.kind != .recap else { return 0 }
        var generator = RingWobbleGenerator(seed: ring.id)
        let maxStep = min(width * 0.26, 92)
        let magnitude = CGFloat.random(in: 0.35...1, using: &generator)
        let sign: CGFloat = Bool.random(using: &generator) ? 1 : -1
        let rampIndex = ring.indexInChapter
        let ramp: CGFloat = rampIndex == 0 ? 0.18 : (rampIndex == 1 ? 0.55 : 1)
        return maxStep * magnitude * sign * ramp
    }
}

/// A tiny, stable pseudo-random source seeded from a string so the same ring
/// always gets the same wobble, even across view refreshes.
private struct RingWobbleGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hasher = Hasher()
        hasher.combine(seed)
        let hashed = hasher.finalize()
        state = UInt64(bitPattern: Int64(hashed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// A stylised 3D mascot pose resting quietly beside the path.
private struct PathMascotCameo: View {
    static let poses = [
        "book_mascot_peeking_cloud",
        "book_mascot_sleeping",
        "book_mascot_reading",
        "book_mascot_waving",
        "book_mascot_sitting"
    ]

    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 118, height: 118)
            .opacity(0.8)
            .accessibilityHidden(true)
    }
}

/// Fine cord joining two tiles: a single pale S-curve between their
/// (offset) centers, in the spirit of the soft track on the reference path.
private struct TrailConnector: View {
    let fromX: CGFloat
    let toX: CGFloat
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            TrailShape(fromX: fromX, toX: toX)
                .stroke(
                    Theme.pastel(accent, strength: 0.7),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct TrailShape: Shape {
    let fromX: CGFloat
    let toX: CGFloat

    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: rect.midX + fromX, y: rect.minY)
        let end = CGPoint(x: rect.midX + toX, y: rect.maxY)
        let midY = (rect.minY + rect.maxY) / 2
        let control1 = CGPoint(x: rect.midX + fromX, y: rect.minY + (midY - rect.minY) * 0.75)
        let control2 = CGPoint(x: rect.midX + toX, y: rect.maxY - (rect.maxY - midY) * 0.75)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

/// A single step on the path: a thick Duolingo-style disc — slightly domed
/// face with a soft highlight, sitting on a clearly visible darker edge that
/// it sinks into when pressed. No labels: the icon says it all.
struct RingNodeView: View {
    let ring: PathRing
    let state: ChapterState
    let lock: RingLock?
    let color: Color
    let record: ChapterRecord?
    let action: () -> Void

    @State private var isPulsing: Bool = false

    private var isRecap: Bool { ring.kind == .recap }
    private var faceWidth: CGFloat { isRecap ? 92 : 76 }
    private var faceHeight: CGFloat { isRecap ? 82 : 68 }
    private var depth: CGFloat { isRecap ? 9 : 8 }
    private var isLocked: Bool { state == .locked }

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            EmptyView()
        }
        .buttonStyle(
            DiscButtonStyle(
                faceWidth: faceWidth,
                faceHeight: faceHeight,
                depth: depth,
                face: fillColor,
                edge: edgeColor,
                isLocked: isLocked,
                icon: iconName,
                iconSize: isRecap ? 32 : 28,
                iconColor: iconColor
            )
        )
        .background {
            if state == .available {
                Ellipse()
                    .stroke(ringAccent.opacity(0.35), lineWidth: 5)
                    .frame(width: faceWidth + 24, height: faceHeight + depth + 22)
                    .scaleEffect(isPulsing ? 1.04 : 0.96)
                    .offset(y: depth / 2)
            }
        }
        .overlay(alignment: .bottom) {
            if let cooldownDate {
                CooldownLabel(date: cooldownDate)
                    .offset(y: 26)
            }
        }
        .padding(.vertical, 10)
        .disabled(isLocked && cooldownDate == nil)
        .onAppear {
            guard state == .available else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var iconColor: Color {
        if isLocked { return Theme.lockedInk }
        return .white
    }

    private var cooldownDate: Date? {
        if case .cooldown(let until) = lock { return until }
        return nil
    }

    private var ringAccent: Color { isRecap ? Theme.gold : color }

    private var fillColor: Color {
        if isLocked { return Theme.lockedFill }
        switch state {
        case .mastered: return Theme.gold
        case .available, .completed:
            return isRecap ? Theme.gold.mix(with: Theme.primary, by: 0.25) : color
        case .locked: return Theme.lockedFill
        }
    }

    private var edgeColor: Color {
        if isLocked { return Theme.lockedFill.mix(with: .black, by: 0.28) }
        return fillColor.mix(with: .black, by: 0.25)
    }

    private var iconName: String {
        if cooldownDate != nil { return "hourglass" }
        if isLocked { return isRecap ? "trophy.fill" : "star.fill" }
        if isRecap { return "crown.fill" }
        switch state {
        case .mastered, .completed: return "checkmark"
        default: return "star.fill"
        }
    }

    private var accessibilityText: String {
        if let cooldownDate {
            return "\(ring.lessonTitle), verrouillé jusqu'au \(cooldownDate.formatted(date: .abbreviated, time: .shortened))"
        }
        if isLocked { return "\(ring.lessonTitle), verrouillé" }
        return ring.lessonTitle
    }
}

/// Draws the 3D disc and sinks its face onto the edge while pressed.
private struct DiscButtonStyle: ButtonStyle {
    let faceWidth: CGFloat
    let faceHeight: CGFloat
    let depth: CGFloat
    let face: Color
    let edge: Color
    let isLocked: Bool
    let icon: String
    let iconSize: CGFloat
    let iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        ZStack(alignment: .top) {
            Ellipse()
                .fill(edge)
                .frame(width: faceWidth, height: faceHeight)
                .offset(y: depth)
            ZStack {
                Ellipse().fill(face)
                // Soft dome: lighter crown, gently darker rim.
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(isLocked ? 0.06 : 0.22), .clear],
                            center: UnitPoint(x: 0.45, y: 0.28),
                            startRadius: 2,
                            endRadius: faceWidth * 0.55
                        )
                    )
                Ellipse()
                    .fill(.white.opacity(isLocked ? 0.05 : 0.28))
                    .frame(width: faceWidth * 0.42, height: faceHeight * 0.16)
                    .offset(x: -faceWidth * 0.12, y: -faceHeight * 0.3)
                    .blur(radius: 1.5)
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(iconColor)
                    .shadow(color: .black.opacity(isLocked ? 0 : 0.15), radius: 0, y: 2)
            }
            .frame(width: faceWidth, height: faceHeight)
            .offset(y: pressed ? depth - 1 : 0)
        }
        .frame(width: faceWidth, height: faceHeight + depth, alignment: .top)
        .contentShape(Ellipse())
        .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Live countdown shown under a recap that's cooling down after a failure.
private struct CooldownLabel: View {
    let date: Date

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 9, weight: .bold))
            Text(date, style: .relative)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.danger)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.danger.opacity(0.12)))
    }
}
