import SwiftUI

/// Everything shared by the live quiz screens (bot duel, ranked duel, party,
/// flash, local): Kahoot-style shape+color answer badges, a circular round
/// timer, and the "top scores" interstitial shown every 2 questions. Pulling
/// these into one place keeps every mode visually consistent on the same
/// bright, airy palette instead of each screen reinventing its own look.

// MARK: - Fastest-answer callout

/// Small celebratory badge shown right at reveal when the local player was
/// the fastest correct answer of the round — sits next to the points badge
/// instead of replacing it.
struct FastestAnswerBadge: View {
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .heavy))
            Text("Le plus rapide !")
                .font(.system(.caption, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.duelAccent))
        .shadow(color: Theme.duelAccent.opacity(0.35), radius: 8, y: 3)
        .scaleEffect(appeared ? 1 : 0.4)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

// MARK: - Emotes

/// The fixed palette every emote picker offers — a mix of reactions that read
/// clearly at a glance during a fast-paced quiz.
enum QuizEmote: String, CaseIterable, Identifiable {
    case laugh = "😂", fire = "🔥", clap = "👏", shocked = "😲"
    case heart = "❤️", skull = "💀", cool = "😎", cry = "😭"
    case thumbsUp = "👍", thumbsDown = "👎", think = "🤔", party = "🎉"
    case wow = "🤩", angry = "😡", zzz = "😴", hundred = "💯"

    var id: String { rawValue }
}

/// The round side-button that opens the emote picker once the player has
/// locked in their answer.
struct EmoteTriggerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "face.smiling.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.duelAccent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.quizCanvas))
                .overlay(Circle().stroke(Theme.duelAccent.opacity(0.35), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}

/// The small grid of 16 reactions. Tapping one sends it and keeps the sheet
/// open so spamming the same (or different) reaction is one tap away.
struct EmotePickerSheet: View {
    let onPick: (QuizEmote) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.quizLine).frame(width: 40, height: 5).padding(.top, 8)
            Text("Envoie une raction")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(QuizEmote.allCases) { emote in
                    Button {
                        Haptics.tap()
                        onPick(emote)
                    } label: {
                        Text(emote.rawValue)
                            .font(.system(size: 28))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Theme.quizCanvas))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Theme.quizBackground)
    }
}

/// One reaction floating up from the sender's name, self-dismissing after a
/// couple seconds. A view model feeds a short-lived array of these; several
/// can be on screen at once when players spam reactions.
struct FloatingEmote: Identifiable, Equatable {
    let id: UUID
    let senderName: String
    let emote: QuizEmote

    init(senderName: String, emote: QuizEmote) {
        self.id = UUID()
        self.senderName = senderName
        self.emote = emote
    }
}

private struct FloatingEmoteBubble: View {
    let item: FloatingEmote

    @State private var risen = false

    var body: some View {
        VStack(spacing: 2) {
            Text(item.emote.rawValue).font(.system(size: 30))
            Text(item.senderName)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.quizBackground.opacity(0.9)))
        }
        .offset(y: risen ? -26 : 6)
        .opacity(risen ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { risen = true }
        }
    }
}

/// Stacks the currently-live floating emotes along one edge of the screen so
/// several spammed reactions from different players don't collide.
struct FloatingEmoteOverlay: View {
    let items: [FloatingEmote]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(items) { item in
                FloatingEmoteBubble(item: item)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: items.map(\.id))
    }
}

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
        .animation(.easeOut(duration: 0.34), value: isReveal)
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
/// question aloud before the choices unlock. `duration` controls how long
/// this beat lasts so call sites can show a live countdown ring.
struct QuestionRevealBeat: View {
    var label: String = "Regarde bien…"
    var duration: Double? = nil

    @State private var remaining: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            if let duration {
                ZStack {
                    Circle().stroke(Theme.quizLine, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: max(0, min(1, remaining / duration)))
                        .stroke(Theme.duelAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: remaining)
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.quizInk)
                        .contentTransition(.numericText())
                }
                .frame(width: 40, height: 40)
                .onAppear {
                    remaining = duration
                    Task {
                        var elapsed: Double = 0
                        while elapsed < duration {
                            try? await Task.sleep(for: .milliseconds(100))
                            elapsed += 0.1
                            remaining = max(0, duration - elapsed)
                        }
                    }
                }
            } else {
                ProgressView().tint(Theme.duelAccent)
            }
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.quizInkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .transition(.opacity)
    }
}

// MARK: - Live "who has voted" counter

/// A small pill that counts up in real time while players are locking in
/// their answer — "10/12 ont voté" — so a round never feels frozen even
/// when nobody around you seems to be doing anything.
struct LiveVoteCounter: View {
    let answered: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(answered)/\(total) ont voté")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .contentTransition(.numericText())
        }
        .foregroundStyle(Theme.quizInkMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.quizCanvas))
        .animation(.spring(duration: 0.55), value: answered)
    }
}

// MARK: - Countdown digits

/// The big "3-2-1" number used by every launch screen. Explicitly animates
/// on every change of `value` (rather than depending on the call site
/// remembering to wrap the mutation in `withAnimation`), so the digits
/// always visibly scroll through instead of snapping.
struct CountdownDigits: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 110, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.duelAccent)
            .id(value)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 1.3)),
                removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.6))
            ))
            .animation(.spring(response: 0.7, dampingFraction: 0.68), value: value)
    }
}

// MARK: - Animated points badge

/// The "+120" callout shown right after a reveal. Punches in with an
/// overshoot scale and a little upward drift instead of a flat fade, so
/// the reward actually feels rewarding.
struct AnimatedPointsBadge: View {
    let points: Int
    var color: Color = Theme.gold

    @State private var didAppear = false

    var body: some View {
        Text("+\(points)")
            .font(.system(.title2, design: .rounded, weight: .heavy))
            .foregroundStyle(color)
            .scaleEffect(didAppear ? 1 : 0.2)
            .offset(y: didAppear ? -4 : 6)
            .opacity(didAppear ? 1 : 0)
            .onAppear {
                didAppear = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                    didAppear = true
                }
            }
            .transition(.identity)
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

    /// Bars start flat and grow into place on appear — a static chart never
    /// sells the "votes coming in" feeling the way a rising bar does.
    @State private var grown = false

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
                        .contentTransition(.numericText())
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isCorrect ? Theme.success : AnswerBadgeStyle.style(at: index).color.opacity(0.3))
                        .frame(height: grown ? barHeight(for: count) : 4)
                        .overlay(alignment: .top) {
                            if grown {
                                AnswerBadgeStyle.style(at: index).shape(size: 14)
                                    .opacity(isCorrect ? 1 : 0.6)
                                    .padding(.top, 6)
                                    .transition(.opacity)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.85, dampingFraction: 0.72).delay(Double(index) * 0.15), value: grown)
            }
        }
        .frame(height: 96, alignment: .bottom)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
        .onAppear { grown = true }
        .onChange(of: counts) { grown = false; DispatchQueue.main.async { grown = true } }
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
    /// "Question 6/15" style progress readout shown above the title.
    var roundLabel: String? = nil
    /// The current round's theme/discipline name, shown next to `roundLabel`.
    var themeLabel: String? = nil
    var autoDismissAfter: Double? = 4.0
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
                        LeaderboardRow(entry: entry, rank: index + 1, appearDelay: Double(index) * 0.07)
                    }
                }
                .padding(16)
                .padding(.top, 46)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.quizBackground)
        .overlay(alignment: .top) {
            if let biggestRiser {
                riserToast(biggestRiser.entry, delta: biggestRiser.delta)
                    .padding(.horizontal, 16)
                    .padding(.top, 210)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.7), value: biggestRiser?.entry.id)
        .task {
            guard let autoDismissAfter else { return }
            try? await Task.sleep(for: .seconds(autoDismissAfter))
            onDismiss?()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            if roundLabel != nil || themeLabel != nil {
                HStack(spacing: 6) {
                    if let roundLabel {
                        Text(roundLabel)
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.duelAccent))
                    }
                    if let themeLabel {
                        Text(themeLabel)
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.quizInkMuted)
                            .lineLimit(1)
                    }
                }
            }
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

    private func riserToast(_ entry: QuizLeaderboardEntry, delta: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .heavy))
            Text("\(entry.name) est monté de \(delta) place\(delta > 1 ? "s" : "") !")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.quizInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(Theme.danger, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

/// One leaderboard row, extracted as its own view so it can hold the small
/// per-row entrance state (staggered fade + rise-in, plus a little bounce
/// whenever its rank actually changes) that a plain function body can't.
private struct LeaderboardRow: View {
    let entry: QuizLeaderboardEntry
    let rank: Int
    let appearDelay: Double

    @State private var appeared = false
    @State private var bounced = false

    var body: some View {
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
            rankArrow
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
                .shadow(color: .black.opacity(entry.isYou ? 0.1 : 0), radius: 8, y: 3)
        )
        .zIndex(entry.isYou ? 1 : 0)
        .scaleEffect(appeared ? (bounced ? 1.03 : 1) : 0.9)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .id(entry.id)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.68).delay(appearDelay)) {
                appeared = true
            }
            guard entry.previousRank != nil, entry.previousRank != rank else { return }
            Task {
                try? await Task.sleep(for: .seconds(appearDelay + 0.55))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { bounced = true }
                try? await Task.sleep(for: .seconds(0.22))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { bounced = false }
            }
        }
    }

    @ViewBuilder
    private var rankArrow: some View {
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

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "\u{1F947}"
        case 2: return "\u{1F948}"
        case 3: return "\u{1F949}"
        default: return "#\(rank)"
        }
    }
}
