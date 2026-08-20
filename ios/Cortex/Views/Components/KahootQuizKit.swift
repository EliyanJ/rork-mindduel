import SwiftUI

/// Everything shared by the live quiz screens (bot duel, ranked duel, party,
/// flash, local): Kahoot-style shape+color answer badges, a circular round
/// timer, and the "top scores" interstitial shown every 2 questions. Pulling
/// these into one place keeps every mode visually consistent on the same
/// bright, airy palette instead of each screen reinventing its own look.

// MARK: - Answer shapes

/// One shape+color per answer slot, cycling through the classic Kahoot set.
enum AnswerBadgeStyle: CaseIterable {
    case triangle, diamond, circle, square

    var color: Color {
        switch self {
        case .triangle: return Theme.kahootRed
        case .diamond: return Theme.kahootBlue
        case .circle: return Theme.kahootYellow
        case .square: return Theme.kahootGreen
        }
    }

    static func style(at index: Int) -> AnswerBadgeStyle {
        allCases[index % allCases.count]
    }

    @ViewBuilder
    func shape(size: CGFloat) -> some View {
        switch self {
        case .triangle:
            TriangleShape().fill(.white)
                .frame(width: size, height: size * 0.9)
        case .diamond:
            DiamondShape().fill(.white)
                .frame(width: size, height: size)
        case .circle:
            Circle().fill(.white)
                .frame(width: size * 0.82, height: size * 0.82)
        case .square:
            RoundedRectangle(cornerRadius: size * 0.22).fill(.white)
                .frame(width: size * 0.82, height: size * 0.82)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// One answer row: colored tile with its shape + the option text, dimming
/// and revealing a check/cross once the round is over.
struct KahootOptionButton: View {
    let index: Int
    let text: String
    let isCorrect: Bool
    let isPicked: Bool
    let isReveal: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var style: AnswerBadgeStyle { .style(at: index) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                style.shape(size: 22)
                    .frame(width: 22, height: 22)
                Text(text)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if isReveal, isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                if isReveal, isPicked, !isCorrect {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(fill))
            .opacity(rowOpacity)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.easeOut(duration: 0.18), value: isReveal)
    }

    private var fill: Color {
        if isReveal, !isCorrect, !isPicked {
            return style.color.opacity(0.45)
        }
        return style.color
    }

    private var rowOpacity: Double {
        guard isReveal else { return 1 }
        return (isCorrect || isPicked) ? 1 : 0.6
    }
}

// MARK: - Round timer

/// Kahoot's big circular countdown, in a size that fits inline in a header.
struct QuizTimerRing: View {
    let remaining: Double
    let total: Double
    var size: CGFloat = 52

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }

    private var tint: Color {
        if fraction < 0.25 { return Theme.danger }
        if fraction < 0.55 { return Theme.gold }
        return Theme.success
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.quizLine, lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(remaining.rounded(.up)))")
                .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.quizInk)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.1), value: fraction)
    }
}

// MARK: - "Get ready" reading beat before answers unlock

/// The question appears alone for a short beat before the answer tiles
/// slide in — the same suspense pause Kahoot gives a host reading the
/// question aloud, compressed to fit a single phone screen.
struct QuestionRevealBeat: View {
    var label: String = "Regarde bien…"

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Theme.duelAccent)
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.quizInkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .transition(.opacity)
    }
}

// MARK: - Vote distribution ("who answered what") reveal chart

/// The Kahoot moment right after time's up: a bar per answer showing how
/// many people picked it, the correct one glowing green and the rest dim.
/// Sits above the answer tiles during the reveal beat.
struct QuestionVoteBars: View {
    let options: [String]
    let counts: [Int]
    let correctAnswer: String

    private var maxCount: Int { max(counts.max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isCorrect = option.comparisonKey == correctAnswer.comparisonKey
                let count = index < counts.count ? counts[index] : 0
                VStack(spacing: 6) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isCorrect ? Theme.success : Theme.quizInkMuted.opacity(0.6))
                    Text("\(count)")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(isCorrect ? Theme.success : Theme.quizInkMuted)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isCorrect ? Theme.success : AnswerBadgeStyle.style(at: index).color.opacity(0.3))
                        .frame(height: barHeight(for: count))
                        .overlay(alignment: .top) {
                            AnswerBadgeStyle.style(at: index).shape(size: 14)
                                .opacity(isCorrect ? 1 : 0.6)
                                .padding(.top, 6)
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 96, alignment: .bottom)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
    }

    private func barHeight(for count: Int) -> CGFloat {
        let fraction = CGFloat(count) / CGFloat(maxCount)
        return max(10, fraction * 58)
    }
}

// MARK: - Interactive leaderboard page

struct QuizLeaderboardEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let score: Int
    let isYou: Bool
    var previousRank: Int? = nil
}

/// A real, full-screen "classement" page — not a dismissible popup — shown
/// between questions. Rows reorder with a spring as scores change (pass the
/// update through `withAnimation` at the call site), each carries an up/down
/// arrow versus its rank before this round, and the biggest riser gets a
/// callout banner at the bottom, Kahoot-style.
struct QuizLeaderboardOverlay: View {
    let entries: [QuizLeaderboardEntry]
    var title: String = "Classement"
    var subtitle: String? = nil
    var autoDismissAfter: Double? = 2.4
    var onDismiss: (() -> Void)?

    private var ranked: [QuizLeaderboardEntry] {
        entries.sorted { $0.score > $1.score }
    }

    private var you: (entry: QuizLeaderboardEntry, rank: Int)? {
        ranked.enumerated().first { $0.element.isYou }.map { (entry: $0.element, rank: $0.offset + 1) }
    }

    /// The entry that gained the most ranks since the previous board, if any.
    private var biggestRiser: (entry: QuizLeaderboardEntry, delta: Int)? {
        ranked.enumerated()
            .compactMap { index, entry -> (QuizLeaderboardEntry, Int)? in
                guard let previous = entry.previousRank else { return nil }
                let delta = previous - (index + 1)
                return delta > 0 ? (entry, delta) : nil
            }
            .max { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                        row(entry: entry, rank: index + 1)
                    }
                }
                .padding(16)
                .padding(.bottom, biggestRiser != nil ? 64 : 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .overlay(alignment: .bottom) {
            if let biggestRiser {
                riserToast(biggestRiser.entry, delta: biggestRiser.delta)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: biggestRiser?.entry.id)
        .task {
            guard let autoDismissAfter else { return }
            try? await Task.sleep(for: .seconds(autoDismissAfter))
            onDismiss?()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.quizInkMuted)
            }
            if let you {
                HStack(spacing: 12) {
                    Text(you.entry.emoji)
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.primary.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Toi")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.primary)
                        Text("\(you.entry.score) pts")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.quizInkMuted)
                    }
                    Spacer()
                    rankBadge(you.rank)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.primary.opacity(0.08)))
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.primary))
    }

    private func row(entry: QuizLeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text(rankLabel(rank))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .frame(width: 30)
                .foregroundStyle(rank <= 3 ? Theme.gold.mix(with: .black, by: 0.2) : Theme.quizInkMuted)
            Text(entry.emoji).font(.system(size: 20))
            Text(entry.name)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(entry.isYou ? Theme.primary : Theme.quizInk)
                .lineLimit(1)
            Spacer()
            rankArrow(entry: entry, rank: rank)
            Text("\(entry.score)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(entry.isYou ? Theme.primary.opacity(0.1) : Theme.quizCanvas)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(entry.isYou ? Theme.primary.opacity(0.35) : .clear, lineWidth: 1.5)
                )
        )
        .id(entry.id)
    }

    @ViewBuilder
    private func rankArrow(entry: QuizLeaderboardEntry, rank: Int) -> some View {
        if let previous = entry.previousRank {
            let delta = previous - rank
            if delta > 0 {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.success)
            } else if delta < 0 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private func riserToast(_ entry: QuizLeaderboardEntry, delta: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .heavy))
            Text("\(entry.name) est monté de \(delta) place\(delta > 1 ? "s" : "") !")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Theme.success))
        .shadow(color: Theme.success.opacity(0.35), radius: 12, y: 4)
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "\u{1F947}"
        case 2: return "\u{1F948}"
        case 3: return "\u{1F949}"
        default: return "#\(rank)"
        }
    }
}
