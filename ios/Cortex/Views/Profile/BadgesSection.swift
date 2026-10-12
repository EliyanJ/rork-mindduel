import SwiftUI

/// Badge artwork, full colour when earned, a dimmed grey silhouette with a
/// padlock otherwise.
struct BadgeMedalView: View {
    let badge: Badge
    let isEarned: Bool
    var size: CGFloat = 96

    var body: some View {
        Image(badge.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(isEarned ? 1 : 0)
            .opacity(isEarned ? 1 : 0.35)
            .overlay {
                if !isEarned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.2, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(size * 0.09)
                        .background(Circle().fill(Theme.inkMuted.opacity(0.85)))
                }
            }
            .accessibilityLabel(isEarned ? badge.name : "\(badge.name), verrouillé")
    }
}

/// "BADGES" card of the profile: earned count, a progress bar and the
/// collection grid. Tapping a badge opens its detail.
struct BadgesSection: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Badge?

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        let badges = model.visibleBadges
        let earnedCount = badges.filter { model.badges.isEarned($0) }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("BADGES")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(Theme.inkMuted)
                if !model.badges.unseen.isEmpty {
                    Text("NOUVEAU")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.danger))
                }
                Spacer()
                Text("\(earnedCount) / \(badges.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.primary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: badges.isEmpty ? 0 : max(earnedCount > 0 ? 10 : 0, geo.size.width * CGFloat(earnedCount) / CGFloat(badges.count)))
                }
            }
            .frame(height: 8)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(badges) { badge in
                    Button {
                        Haptics.tap()
                        selected = badge
                    } label: {
                        VStack(spacing: 4) {
                            BadgeMedalView(badge: badge, isEarned: model.badges.isEarned(badge), size: 92)
                                .overlay(alignment: .topTrailing) {
                                    if model.badges.unseen.contains(badge.id) {
                                        Circle()
                                            .fill(Theme.danger)
                                            .frame(width: 12, height: 12)
                                            .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                                    }
                                }
                            if !badge.hasNameInArt {
                                Text(badge.name)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(model.badges.isEarned(badge) ? Theme.ink : Theme.inkMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            if !model.badges.isEarned(badge) {
                                let progress = model.badgeProgress(badge)
                                Text(badge.progressUnit == nil ? "À débloquer" : "\(progress.done)/\(progress.required)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.inkMuted)
                                    .monospacedDigit()
                            } else {
                                Text(badge.rarity.label)
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(badge.rarity.color)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(BadgePressStyle())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { model.badges.markAllSeen() }
    }
}

private struct BadgePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Detail of one badge: big artwork, rarity, how to earn it and either the
/// date it was earned or the rings left.
struct BadgeDetailSheet: View {
    let badge: Badge
    @Environment(AppModel.self) private var model
    @State private var isShown: Bool = false

    var body: some View {
        let isEarned = model.badges.isEarned(badge)
        let progress = model.badgeProgress(badge)
        VStack(spacing: 14) {
            BadgeMedalView(badge: badge, isEarned: isEarned, size: 170)
                .scaleEffect(isShown ? 1 : 0.6)
                .rotationEffect(.degrees(isShown ? 0 : -8))
                .padding(.top, 22)
            Text(badge.rarity.label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(badge.rarity.color))
            Text(badge.name)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(badge.conditionText(themeName: model.themeName(for: badge)))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            if isEarned, let date = model.badges.earnedDate(badge) {
                Label("Obtenu le \(date.formatted(.dateTime.day().month(.wide).year()))", systemImage: "checkmark.seal.fill")
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.success)
            } else if progress.required > 0, let unit = badge.progressUnit {
                VStack(spacing: 6) {
                    ProgressView(value: Double(progress.done), total: Double(progress.required))
                        .tint(badge.rarity.color)
                    Text("\(progress.done) / \(progress.required) \(unit)")
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .monospacedDigit()
                }
                .padding(.horizontal, 48)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isShown = true }
        }
    }
}
