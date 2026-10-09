import SwiftUI

/// One card of the "Fil d'actualité": an app update, new content or a tip.
private struct NewsItem: Identifiable {
    enum Kind {
        case update, content, tip

        var label: String {
            switch self {
            case .update: return "NOUVEAUTÉ"
            case .content: return "NOUVEAU CONTENU"
            case .tip: return "ASTUCE"
            }
        }

        var color: Color {
            switch self {
            case .update: return Theme.primary
            case .content: return Color(hex: "1CB0F6")
            case .tip: return Color(hex: "E8A317")
            }
        }
    }

    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let body: String
    let image: String
    let isSystemImage: Bool
    let background: Color
    let cta: String?
    let destination: AppTab?
}

/// "Fil d'actualité" tab: latest releases, newly added content and tips,
/// each with an illustrated banner and an optional shortcut into the app.
struct NewsFeedView: View {
    @Environment(AppModel.self) private var model
    let onOpen: (AppTab) -> Void

    @State private var appeared: Bool = false

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private var items: [NewsItem] {
        var list: [NewsItem] = [
            NewsItem(
                id: "leagues",
                kind: .update,
                date: Self.day(2026, 10, 9),
                title: "Les ligues arrivent !",
                body: "Bronze, Argent, Or, Platine, Maître : grimpe les divisions en gagnant tes duels et suis ta place dans « Mon classement ».",
                image: "MascotTrophy",
                isSystemImage: false,
                background: Color(hex: "FFE7C2"),
                cta: "VOIR MA LIGUE",
                destination: .classement
            ),
            NewsItem(
                id: "premium",
                kind: .update,
                date: Self.day(2026, 10, 8),
                title: "Minduel Premium est là",
                body: "Leçons illimitées, choix libre des thèmes, mode classé et duels sans limite. Essai gratuit de 7 jours sur l'offre annuelle.",
                image: "MascotGift",
                isSystemImage: false,
                background: Color(hex: "FFF1B8"),
                cta: "DÉCOUVRIR",
                destination: .premium
            )
        ]
        let disciplines = model.catalog.disciplines
        for (index, discipline) in disciplines.prefix(4).enumerated() {
            let chapters = discipline.chapters.count
            list.append(
                NewsItem(
                    id: "content-\(discipline.id)",
                    kind: .content,
                    date: Self.day(2026, 10, 7 - index),
                    title: "\(discipline.name) : \(chapters) chapitre\(chapters > 1 ? "s" : "") à explorer",
                    body: "De nouvelles questions ont été ajoutées en \(discipline.name.lowercased()). Teste tes connaissances et fais grimper ta série !",
                    image: discipline.illustratedIconName ?? discipline.icon,
                    isSystemImage: discipline.illustratedIconName == nil,
                    background: discipline.color.opacity(0.22),
                    cta: "TESTE TES CONNAISSANCES",
                    destination: .themes
                )
            )
        }
        list.append(
            NewsItem(
                id: "tip-daily",
                kind: .tip,
                date: Self.day(2026, 10, 2),
                title: "Un peu chaque jour",
                body: "Deux leçons par jour suffisent pour mieux retenir ce que tu apprends. Ta flamme te remerciera !",
                image: "MascotStudy",
                isSystemImage: false,
                background: Color(hex: "FCEFD9"),
                cta: nil,
                destination: nil
            )
        )
        list.append(
            NewsItem(
                id: "tip-friends",
                kind: .tip,
                date: Self.day(2026, 9, 28),
                title: "Défie tes amis",
                body: "Partage ton code ami ou scanne celui d'un proche pour comparer vos points dans le classement entre amis.",
                image: "MascotDuel",
                isSystemImage: false,
                background: Color(hex: "D7F5F2"),
                cta: "JOUER UN DUEL",
                destination: .duel
            )
        )
        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fil d'actualité")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            Rectangle().fill(Theme.line).frame(height: 1.5)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        card(item)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 18)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(min(index, 5)) * 0.06), value: appeared)
                        if index < items.count - 1 {
                            Rectangle().fill(Theme.line).frame(height: 1.5)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private func card(_ item: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            item.background
                .frame(height: 170)
                .overlay {
                    Group {
                        if item.isSystemImage {
                            Image(systemName: item.image)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(item.image)
                                .resizable()
                                .scaledToFit()
                                .padding(18)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 20))
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(item.kind.label)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(item.kind.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(item.kind.color.opacity(0.12)))
                Text(relative(item.date))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Text(item.title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(item.body)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let cta = item.cta, let destination = item.destination {
                Button {
                    Haptics.tap()
                    onOpen(destination)
                } label: {
                    Text(cta)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 2))
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.line).offset(y: 3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 22)
    }

    private func relative(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        switch days {
        case ..<1: return "Aujourd'hui"
        case 1: return "Hier"
        case 2..<7: return "\(days) jours"
        case 7..<14: return "1 semaine"
        default: return "\(days / 7) semaines"
        }
    }
}
