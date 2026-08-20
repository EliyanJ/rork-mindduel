import SwiftUI

/// Grid of pastel theme cards — one card per discipline. Tapping a card opens
/// the theme's dedicated page with its progression and its lesson packs.
/// The visual language follows the reference: soft pastel pills, two columns,
/// name in the theme's own colour with the illustrated badge on the right.
struct ThemesView: View {
    @Environment(AppModel.self) private var model

    @State private var searchText: String = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private func matchesSearch(_ discipline: Discipline) -> Bool {
        let query = searchText.normalizedForSearch
        guard !query.isEmpty else { return true }
        return discipline.name.normalizedForSearch.contains(query)
    }

    private var filteredDisciplines: [Discipline] {
        model.orderedDisciplines.filter(matchesSearch)
    }

    /// Total packs across every theme, for the playful footer line.
    private var totalPackCount: Int {
        model.orderedDisciplines.reduce(0) { $0 + $1.chapters.count }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchField
                ScrollView {
                    if filteredDisciplines.isEmpty {
                        Text("Aucun thème ne correspond à ta recherche.")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.inkMuted)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredDisciplines) { discipline in
                                NavigationLink(value: discipline) {
                                    ThemePillCard(discipline: discipline)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        footer
                    }
                }
            }
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Discipline.self) { discipline in
                ThemeDetailView(discipline: discipline)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Thèmes")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .offset(y: -1)
                }
                Text("Tous nos packs, classés par thèmes")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            StatPill(icon: "diamond.fill", color: Theme.livres, value: "\(model.store.livresBalance)")
                .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            TextField("Rechercher un thème", text: $searchText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled(true)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// "Suggest a pack" card + pack-count footer, like the reference screen.
    private var footer: some View {
        VStack(spacing: 14) {
            Link(destination: URL(string: "mailto:hello@minduel.app?subject=Id%C3%A9e%20de%20pack")!) {
                HStack {
                    Text("Nous soumettre une idée de thèmes")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color(hex: "5B4BC4"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "5B4BC4"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            }
            .padding(.horizontal, 16)

            Text("\(totalPackCount) packs écrits à la main.")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.top, 26)
        .padding(.bottom, 32)
    }
}

/// One pastel pill per theme: soft tinted background, name in the theme's own
/// deeper colour, illustrated badge on the right.
private struct ThemePillCard: View {
    let discipline: Discipline

    private var pastel: Color { discipline.color.mix(with: .white, by: 0.72) }
    private var textColor: Color { discipline.color.mix(with: .black, by: 0.18) }

    var body: some View {
        HStack(spacing: 8) {
            Text(discipline.name)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            icon
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(pastel))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var icon: some View {
        if let illustratedIconName = discipline.illustratedIconName {
            Image(illustratedIconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            Image(systemName: discipline.icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(textColor)
                .frame(width: 30, height: 30)
        }
    }
}

extension String {
    /// Lowercase, accent-folded form used for simple case/accent-insensitive search.
    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
