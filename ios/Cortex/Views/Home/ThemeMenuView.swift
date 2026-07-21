import SwiftUI

/// Left-side drawer to pick the active path: the default mixed journey,
/// or a dedicated path gathering every question of one theme.
///
/// "Parcours mixte" is free for everyone. Picking a precise theme (and
/// using the search bar to find one) is a Premium feature: free users
/// still see the full list and question counts (so they know what
/// they're missing) but tapping a theme or typing a search opens the
/// paywall instead of selecting it.
struct ThemeMenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    let onClose: () -> Void

    @State private var searchText: String = ""
    @State private var isPaywallPresented = false

    private var filteredDisciplines: [Discipline] {
        let query = searchText.normalizedForSearch
        guard !query.isEmpty else { return model.catalog.disciplines }
        return model.catalog.disciplines.filter { $0.name.normalizedForSearch.contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Parcours")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            Text("Choisis un thème dédié\nou mélange tout")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 6) {
                    menuRow(
                        id: nil,
                        name: "Parcours mixte",
                        icon: "sparkles",
                        color: Theme.primary,
                        subtitle: "Tous les thèmes mélangés",
                        isLocked: false
                    )

                    searchField

                    HStack(spacing: 10) {
                        Rectangle().fill(Theme.line).frame(height: 1.5)
                        Text("THÈMES")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.inkMuted)
                        Rectangle().fill(Theme.line).frame(height: 1.5)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)

                    if filteredDisciplines.isEmpty {
                        Text("Aucun thème ne correspond à ta recherche.")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.inkMuted)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(filteredDisciplines) { discipline in
                        menuRow(
                            id: discipline.id,
                            name: discipline.name,
                            icon: discipline.icon,
                            color: discipline.color,
                            subtitle: "\(questionCount(of: discipline)) questions",
                            isLocked: !store.isPremium
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 300, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(bottomTrailingRadius: 28, topTrailingRadius: 28)
                .fill(Theme.background)
                .shadow(color: .black.opacity(0.2), radius: 18, x: 6, y: 0)
                .ignoresSafeArea()
        )
        .fullScreenCover(isPresented: $isPaywallPresented) {
            OnboardingPaywallStep(store: store) { isPaywallPresented = false }
        }
    }

    /// Free users can see and tap the search field, but typing anything
    /// opens the paywall instead of actually filtering — themed search
    /// is a Premium feature just like picking a precise theme.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            TextField("Rechercher un thème", text: $searchText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled(true)
            if !store.isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.gold)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
        .padding(.top, 2)
        .padding(.bottom, 4)
        .onChange(of: searchText) { _, newValue in
            guard !store.isPremium, !newValue.isEmpty else { return }
            Haptics.tap()
            searchText = ""
            isPaywallPresented = true
        }
    }

    private func questionCount(of discipline: Discipline) -> Int {
        discipline.chapters.reduce(0) { $0 + $1.questionCount }
    }

    private func menuRow(id: String?, name: String, icon: String, color: Color, subtitle: String, isLocked: Bool) -> some View {
        let isSelected = model.selectedDisciplineId == id
        return Button {
            if isLocked {
                Haptics.tap()
                isPaywallPresented = true
                return
            }
            Haptics.tap()
            model.selectedDisciplineId = id
            onClose()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(color))
                    .opacity(isLocked ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 0)
                if isLocked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.gold.opacity(0.15)))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected && !isLocked ? color.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected && !isLocked ? color.opacity(0.45) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    /// Lowercase, accent-folded form used for simple case/accent-insensitive search.
    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
