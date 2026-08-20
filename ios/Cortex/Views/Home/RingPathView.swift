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
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            pathWidth = newWidth
        }
    }

    /// Hairline S-curve joining two consecutive tiles: a pale stroke of the
    /// theme colour, no outline, no texture — intentionally discreet.
    @ViewBuilder
    private func connector(before ring: PathRing, at index: Int) -> some View {
        let previous = rings[index - 1]
        let fromX = horizontalOffset(for: previous, width: pathWidth)
        let toX = horizontalOffset(for: ring, width: pathWidth)
        TrailConnector(fromX: fromX, toX: toX, accent: accent)
            .frame(height: 96)
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
                    accent.mix(with: .white, by: 0.68),
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

/// A single step on the path: a rounded-square tile with a small "ROND n"
/// badge on top, stacked on a darker offset base for the 3D chunky look.
/// The recap is deliberately wider, gold and crowned so it reads as a gate.
struct RingNodeView: View {
    let ring: PathRing
    let state: ChapterState
    let lock: RingLock?
    let color: Color
    let record: ChapterRecord?
    let action: () -> Void

    @State private var isPulsing: Bool = false

    private var isRecap: Bool { ring.kind == .recap }
    private var tileSize: CGFloat { isRecap ? 106 : 90 }
    private var tileWidth: CGFloat { isRecap ? 128 : 90 }
    private var isLocked: Bool { state == .locked }

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            VStack(spacing: 7) {
                badge
                tile
                caption
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked && cooldownDate == nil)
        .onAppear {
            guard state == .available else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    /// Small pill above the tile, like the "LEÇON 1" tag over a lesson card.
    private var badge: some View {
        Text(isRecap ? "RÉCAP" : "ROND \(ring.indexInChapter + 1)")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(isLocked ? Theme.inkMuted : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isLocked ? Theme.lockedFill : ringAccent)
            )
    }

    private var tile: some View {
        ZStack {
            if state == .available {
                Circle()
                    .stroke(ringAccent.opacity(0.35), lineWidth: 3.5)
                    .frame(width: tileWidth + 14, height: tileSize + 14)
                    .scaleEffect(isPulsing ? 1.05 : 0.94)
            }
            ZStack {
                Image(systemName: iconName)
                    .font(.system(size: isRecap ? 34 : 27, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: tileWidth, height: tileSize)
            .background(
                Circle()
                    .fill(fillColor.mix(with: .black, by: 0.24))
                    .offset(y: 5)
            )
            .background(
                Circle()
                    .fill(fillColor)
            )
        }
        .frame(height: tileSize + 16)
    }

    /// The checkmark reads as a clear success cue in green once a ring is
    /// mastered; every other icon stays white/muted on its coloured disc.
    private var iconColor: Color {
        if isLocked { return Theme.inkMuted }
        if state == .mastered { return Theme.success }
        return .white
    }

    @ViewBuilder
    private var caption: some View {
        if isRecap {
            Text(ring.chapterTitle)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(isLocked ? Theme.inkMuted : Theme.ink)
                .multilineTextAlignment(.center)
                .frame(width: 190)
        }
        if let cooldownDate {
            CooldownLabel(date: cooldownDate)
        } else if !isLocked, !isRecap {
            Text(ring.tier.label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var cooldownDate: Date? {
        if case .cooldown(let until) = lock { return until }
        return nil
    }

    private var ringAccent: Color { isRecap ? Theme.gold : color }

    /// Lighter, brighter tint than the raw chapter accent — the whole path
    /// reads as pastel and inviting rather than saturated and heavy.
    private var fillColor: Color {
        if isLocked { return Theme.lockedFill }
        switch state {
        case .mastered: return Theme.gold.mix(with: .white, by: 0.12)
        case .available, .completed:
            return isRecap
                ? Theme.gold.mix(with: Theme.primary, by: 0.25).mix(with: .white, by: 0.1)
                : color.mix(with: .white, by: 0.16)
        case .locked: return Theme.lockedFill
        }
    }

    private var iconName: String {
        if cooldownDate != nil { return "hourglass" }
        if isLocked { return "lock.fill" }
        if isRecap { return "crown.fill" }
        switch state {
        case .mastered: return "checkmark"
        case .completed: return "arrow.clockwise"
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
