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

// MARK: - Periodic scoreboard

struct QuizLeaderboardEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let score: Int
    let isYou: Bool
}

/// White, airy "tableau des scores" shown every 2 questions — works for a
/// 1v1 duel (2 entries) all the way up to a 20-player party (top 5).
struct QuizLeaderboardOverlay: View {
    let entries: [QuizLeaderboardEntry]
    var title: String = "Tableau des scores"
    var autoDismissAfter: Double? = 2.4
    var onDismiss: (() -> Void)?

    private var ranked: [QuizLeaderboardEntry] {
        entries.sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
                .padding(.top, 20)
            VStack(spacing: 10) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        Text(rankLabel(index + 1))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .frame(width: 30)
                            .foregroundStyle(index < 3 ? Theme.gold.mix(with: .black, by: 0.2) : Theme.quizInkMuted)
                        Text(entry.emoji).font(.system(size: 20))
                        Text(entry.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(entry.isYou ? Theme.primary : Theme.quizInk)
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.score)")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.quizInkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(entry.isYou ? Theme.primary.opacity(0.08) : Theme.quizCanvas)
                    )
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 8)
        }
        .background(Theme.quizBackground)
        .task {
            guard let autoDismissAfter else { return }
            try? await Task.sleep(for: .seconds(autoDismissAfter))
            onDismiss?()
        }
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
