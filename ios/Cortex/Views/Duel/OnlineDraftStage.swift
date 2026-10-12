import SwiftUI

/// Theme draft before a 1v1: four random themes, each player taps one, then
/// both chosen themes are revealed side by side before the countdown.
struct OnlineDraftStage: View {
    let session: OnlineDuelSession
    @Environment(AvatarStore.self) private var avatarStore: AvatarStore?
    @State private var appeared: Bool = false

    private var isResolved: Bool { !session.chosenThemes.isEmpty }
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(spacing: 18) {
            header
            playersRow
            if isResolved {
                resultView
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(session.draftThemes.enumerated()), id: \.element) { index, id in
                        themeTile(id: id)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(.spring(duration: 0.55, bounce: 0.3).delay(0.08 * Double(index)), value: appeared)
                    }
                }
                .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.quizBackground)
        .animation(.spring(duration: 0.55, bounce: 0.25), value: isResolved)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isResolved ? "Thèmes du duel" : "Choisis ton thème")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                    .contentTransition(.opacity)
                Text(isResolved ? "Les questions vont mélanger ces deux thèmes." : "Ton adversaire choisit aussi le sien.")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.quizInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !isResolved, let endsAt = session.draftEndsAt {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let remaining = max(0, endsAt.timeIntervalSince(context.date))
                    QuizTimerRing(remaining: remaining, total: 10)
                }
            }
        }
    }

    private var playersRow: some View {
        HStack(spacing: 10) {
            playerChip(
                avatar: avatarStore?.config,
                emoji: session.you?.emoji ?? "🧠",
                name: "Toi",
                status: session.myPick == nil ? "Choisis…" : "Choisi ✓",
                isDone: session.myPick != nil
            )
            Text("VS")
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(Theme.quizInkMuted)
            playerChip(
                avatar: nil,
                emoji: session.opponent?.emoji ?? "🎯",
                name: session.opponent?.name ?? "Adversaire",
                status: session.opponentPicked ? "Choisi ✓" : "Réfléchit…",
                isDone: session.opponentPicked
            )
        }
    }

    private func playerChip(avatar: AvatarConfig?, emoji: String, name: String, status: String, isDone: Bool) -> some View {
        HStack(spacing: 8) {
            if let avatar {
                AvatarView(config: avatar, size: 34)
            } else {
                Text(emoji)
                    .font(.system(size: 22))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.quizCanvas))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                    .lineLimit(1)
                Text(status)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(isDone ? Theme.success : Theme.quizInkMuted)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.quizCanvas))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? Theme.success.opacity(0.6) : Theme.quizLine, lineWidth: 1.5))
        .animation(.spring(duration: 0.4), value: isDone)
    }

    private func themeTile(id: String) -> some View {
        let discipline = session.discipline(for: id)
        let color = Color(hex: discipline?.colorHex ?? "#868E96")
        let isPicked = session.myPick == id
        let isDimmed = session.myPick != nil && !isPicked
        return Button {
            session.pick(id)
        } label: {
            VStack(spacing: 10) {
                ThemeArtwork(discipline: discipline, size: 64)
                Text(discipline?.name ?? id.capitalized)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.quizInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isPicked ? color.opacity(0.22) : Theme.quizCanvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isPicked ? color : Theme.quizLine, lineWidth: isPicked ? 3 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isPicked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, color)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isPicked ? 1.04 : (isDimmed ? 0.96 : 1))
            .opacity(isDimmed ? 0.45 : 1)
        }
        .buttonStyle(DraftPressStyle())
        .disabled(session.myPick != nil)
        .animation(.spring(duration: 0.4, bounce: 0.35), value: session.myPick)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private var resultView: some View {
        let themes = session.chosenThemes
        let samePick = session.myPick != nil && session.myPick == session.opponentPick
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(Array(themes.enumerated()), id: \.offset) { index, id in
                    resultCard(id: id, caption: caption(for: id, index: index, samePick: samePick))
                }
            }
            if samePick {
                Text("Vous avez choisi le même thème : le second est tiré au sort.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.quizInkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private func caption(for id: String, index: Int, samePick: Bool) -> String {
        if samePick { return index == 0 ? "Votre choix" : "Tirage au sort" }
        if id == session.myPick { return "Ton choix" }
        return "Choix de \(session.opponent?.name ?? "l'adversaire")"
    }

    private func resultCard(id: String, caption: String) -> some View {
        let discipline = session.discipline(for: id)
        let color = Color(hex: discipline?.colorHex ?? "#868E96")
        return VStack(spacing: 10) {
            ThemeArtwork(discipline: discipline, size: 76)
            Text(discipline?.name ?? id.capitalized)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(caption.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(color))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(RoundedRectangle(cornerRadius: 22).fill(color.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color, lineWidth: 2.5))
    }
}

/// A theme's illustration (remote, then bundled) or its SF symbol on colour.
private struct ThemeArtwork: View {
    let discipline: Discipline?
    let size: CGFloat

    var body: some View {
        RemoteThemeImage(urlString: discipline?.imageUrl) {
            if let illustrated = discipline?.illustratedIconName {
                Image(illustrated).resizable().scaledToFit()
            } else {
                Image(systemName: discipline?.icon ?? "questionmark")
                    .font(.system(size: size * 0.4, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color(hex: discipline?.colorHex ?? "#868E96"))
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.28))
        .accessibilityHidden(true)
    }
}

private struct DraftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
