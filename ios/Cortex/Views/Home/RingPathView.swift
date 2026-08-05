import SwiftUI

/// The learning path as a vertical trail of rings ("ronds").
///
/// Rings are grouped by sub-chapter on a themed path (each group gets a
/// header), and flow continuously on the mixed path where consecutive rings
/// belong to different disciplines.
struct RingPathView: View {
    @Environment(AppModel.self) private var model
    let onSelect: (PathRing) -> Void

    @State private var pathWidth: CGFloat = 360

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(model.rings.enumerated()), id: \.element.id) { index, ring in
                if index > 0 {
                    connector(before: ring, at: index)
                }
                if shouldShowHeader(at: index) {
                    ChapterHeaderView(
                        ring: ring,
                        counts: model.chapterProgressCounts(
                            chapterId: ring.chapterId,
                            disciplineId: ring.disciplineId
                        ),
                        color: color(for: ring)
                    )
                    .padding(.bottom, 6)
                }
                RingNodeView(
                    ring: ring,
                    state: model.state(of: ring),
                    lock: model.lock(for: ring),
                    color: color(for: ring),
                    record: model.store.ringRecord(ring.id),
                    discipline: model.discipline(withId: ring.disciplineId),
                    showsDisciplineBadge: model.isMixedPath
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

    /// On a themed path each sub-chapter opens with a header. The mixed path
    /// alternates disciplines every ring, so headers there would be noise.
    private func shouldShowHeader(at index: Int) -> Bool {
        guard !model.isMixedPath else { return false }
        guard index > 0 else { return true }
        return model.rings[index - 1].chapterId != model.rings[index].chapterId
    }

    private func color(for ring: PathRing) -> Color {
        model.discipline(withId: ring.disciplineId)?.color ?? Theme.primary
    }

    /// The thick, winding cord that joins two consecutive rings — replaces
    /// the old plain dotted connector with a bold illustrated trail.
    @ViewBuilder
    private func connector(before ring: PathRing, at index: Int) -> some View {
        let previous = model.rings[index - 1]
        let isChapterBreak = !model.isMixedPath && previous.chapterId != ring.chapterId
        let fromX = horizontalOffset(for: previous, width: pathWidth)
        let toX = horizontalOffset(for: ring, width: pathWidth)
        let height = connectorHeight(for: ring, isChapterBreak: isChapterBreak)
        TrailConnector(fromX: fromX, toX: toX)
            .frame(height: height)
            .opacity(isChapterBreak ? 0.55 : 1)
    }

    /// Deterministic pseudo-random horizontal wobble per ring, so the path
    /// reads as hand-drawn and playful rather than a repeating zig-zag.
    /// Stable across renders since it's seeded from the ring's own id.
    private func horizontalOffset(for ring: PathRing, width: CGFloat) -> CGFloat {
        guard ring.kind != .recap else { return 0 }
        var generator = RingWobbleGenerator(seed: ring.id)
        let maxStep = min(width * 0.32, 96)
        let magnitude = CGFloat.random(in: 0.3...1, using: &generator)
        let sign: CGFloat = Bool.random(using: &generator) ? 1 : -1
        return maxStep * magnitude * sign
    }

    /// Varies the vertical distance between rings a little so the trail
    /// doesn't feel mechanically regular.
    private func connectorHeight(for ring: PathRing, isChapterBreak: Bool) -> CGFloat {
        if isChapterBreak { return 58 }
        var generator = RingWobbleGenerator(seed: ring.id + "-h")
        return CGFloat.random(in: 78...118, using: &generator)
    }
}

/// A tiny, stable pseudo-random source seeded from a string so the same ring
/// always gets the same wobble and gap, even across view refreshes.
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

/// Thick illustrated cord joining two rings with a bold black outline, drawn
/// as a single S-curve between their (offset) centers — the visual language
/// of a hand-drawn board-game trail rather than a plain connecting dots.
private struct TrailConnector: View {
    let fromX: CGFloat
    let toX: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let shape = TrailShape(fromX: fromX, toX: toX)
            ZStack {
                shape.stroke(Theme.ink, style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                shape.stroke(Theme.gold, style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                shape.stroke(Theme.gold.mix(with: .white, by: 0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .offset(x: -2, y: -2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct TrailShape: Shape {
    let fromX: CGFloat
    let toX: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.midX + fromX, y: rect.minY)
        let end = CGPoint(x: rect.midX + toX, y: rect.maxY)
        let midY = (rect.minY + rect.maxY) / 2
        let control1 = CGPoint(x: rect.midX + fromX, y: rect.minY + (midY - rect.minY) * 0.75)
        let control2 = CGPoint(x: rect.midX + toX, y: rect.maxY - (rect.maxY - midY) * 0.75)
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

/// Sub-chapter banner shown above the first ring of each chapter.
private struct ChapterHeaderView: View {
    let ring: PathRing
    let counts: (done: Int, total: Int)
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(ring.chapterTitle.uppercased())
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                ForEach(0..<counts.total, id: \.self) { index in
                    Capsule()
                        .fill(index < counts.done ? color : Theme.line)
                        .frame(width: index < counts.done ? 18 : 12, height: 5)
                }
            }
            Text("\(counts.done)/\(counts.total) ronds")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.18), lineWidth: 1.5)
                )
        )
        .padding(.top, 8)
    }
}

/// A single circle on the path. The recap ring is deliberately bigger, gold
/// and crowned so it reads as a gate rather than another lesson.
struct RingNodeView: View {
    let ring: PathRing
    let state: ChapterState
    let lock: RingLock?
    let color: Color
    let record: ChapterRecord?
    let discipline: Discipline?
    var showsDisciplineBadge: Bool = false
    let action: () -> Void

    @State private var isPulsing: Bool = false

    private var isRecap: Bool { ring.kind == .recap }
    private var diameter: CGFloat { isRecap ? 96 : 74 }
    private var isLocked: Bool { state == .locked }

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            VStack(spacing: 8) {
                circle
                labels
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

    private var circle: some View {
        ZStack {
            if state == .available {
                Circle()
                    .stroke(ringAccent.opacity(0.35), lineWidth: 4)
                    .frame(width: diameter + 18, height: diameter + 18)
                    .scaleEffect(isPulsing ? 1.05 : 0.94)
            }
            Circle()
                .fill(fillColor.mix(with: .black, by: 0.25))
                .frame(width: diameter, height: diameter)
                .offset(y: 5)
            Circle()
                .fill(fillColor)
                .frame(width: diameter, height: diameter)
            if isRecap && !isLocked {
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 3)
                    .frame(width: diameter - 14, height: diameter - 14)
            }
            Image(systemName: iconName)
                .font(.system(size: isRecap ? 38 : 28, weight: .bold))
                .foregroundStyle(isLocked ? Theme.inkMuted : .white)

            if let discipline, showsDisciplineBadge, !isRecap {
                Image(systemName: discipline.icon)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(discipline.color))
                    .overlay(Circle().stroke(Theme.background, lineWidth: 2.5))
                    .offset(x: diameter / 2 - 6, y: -diameter / 2 + 6)
            }
        }
        .frame(height: diameter + 18)
    }

    @ViewBuilder
    private var labels: some View {
        Text(isRecap ? "RÉCAP · \(ring.chapterTitle)" : ring.shortTitle)
            .font(.system(isRecap ? .subheadline : .caption, design: .rounded, weight: .heavy))
            .foregroundStyle(isLocked ? Theme.inkMuted : Theme.ink)
            .multilineTextAlignment(.center)
            .frame(width: 170)

        if showsDisciplineBadge, let discipline, !isRecap {
            Text(discipline.name)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(isLocked ? Theme.inkMuted : discipline.color)
        }

        if let cooldownDate {
            CooldownLabel(date: cooldownDate)
        } else if let record, record.bestScore > 0 {
            Text("\(Int(record.bestScore * 100)) %")
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(record.bestScore >= ProgressStore.ringMasteryScore ? Theme.gold.mix(with: .black, by: 0.2) : Theme.inkMuted)
        } else if !isLocked, !isRecap {
            Text(ring.tier.label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(ringAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(ringAccent.opacity(0.14)))
        }
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
        case .available, .completed: return isRecap ? Theme.gold.mix(with: Theme.primary, by: 0.25) : color
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
