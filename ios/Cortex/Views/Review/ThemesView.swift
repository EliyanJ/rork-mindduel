import SwiftUI

/// Grid of theme cards — the entry point to pick a dedicated path (via
/// "Continuer") or launch a spaced-review session for one discipline (via
/// "Réviser"). Replaces the old hamburger menu: choosing a theme now always
/// starts here instead of from the Parcours tab.
struct ThemesView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    /// Switches back to the Parcours tab with the chosen discipline selected.
    let onContinueTheme: (String) -> Void

    @State private var searchText: String = ""
    @State private var themeAction: ThemeAction?
    @State private var lessonLaunch: LessonLaunch?
    @State private var isLockedPresented: Bool = false
    @State private var pendingReviseDiscipline: Discipline?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private func matchesSearch(_ discipline: Discipline) -> Bool {
        let query = searchText.normalizedForSearch
        guard !query.isEmpty else { return true }
        return discipline.name.normalizedForSearch.contains(query)
    }

    private var filteredDisciplines: [Discipline] {
        model.orderedDisciplines.filter(matchesSearch)
    }

    var body: some View {
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
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredDisciplines) { discipline in
                            ThemeCard(
                                discipline: discipline,
                                progress: model.themeRingProgress(disciplineId: discipline.id)
                            ) {
                                Haptics.tap()
                                themeAction = ThemeAction(discipline: discipline)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Theme.background)
        .sheet(item: $themeAction) { action in
            ThemeActionSheet(
                discipline: action.discipline,
                dueCount: model.dueLessonItems(disciplineId: action.discipline.id, limit: 999).count,
                onContinueTheme: {
                    onContinueTheme(action.discipline.id)
                },
                onRevise: {
                    launchReview(for: action.discipline)
                }
            )
            .presentationDetents([.height(320)])
        }
        .fullScreenCover(item: $lessonLaunch) { launch in
            LessonView(launch: launch, store: model.store) { _ in }
        }
        .sheet(isPresented: $isLockedPresented) {
            UnlockWithLivresView(kind: .review, progressStore: model.store) {
                if let discipline = pendingReviseDiscipline {
                    launchReview(for: discipline, bypassCheck: true)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Thèmes")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Choisis un thème à continuer ou à réviser")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            StatPill(icon: "bolt.fill", color: Theme.gold, value: "\(model.store.progress.xp)")
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
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: 2))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func launchReview(for discipline: Discipline, bypassCheck: Bool = false) {
        let dueItems = model.dueLessonItems(disciplineId: discipline.id, limit: 10)
        guard !dueItems.isEmpty else { return }
        let remaining = model.store.remainingFreeReviewCards(isPremium: store.isPremium)
        if !bypassCheck, remaining <= 0, !store.isPremium {
            Haptics.tap()
            pendingReviseDiscipline = discipline
            isLockedPresented = true
            return
        }
        Haptics.medium()
        let capped = store.isPremium ? dueItems : Array(dueItems.prefix(remaining))
        let items = capped.shuffled()
        model.store.registerReviewCardsUsed(items.count)
        lessonLaunch = LessonLaunch(
            title: "Révision · \(discipline.name)",
            chapterId: nil,
            items: items
        )
    }
}

/// Identifies which discipline the action sheet ("Continuer" / "Réviser") is about.
private struct ThemeAction: Identifiable {
    let discipline: Discipline
    var id: String { discipline.id }
}

/// One colour-block card per discipline: icon, name and a "done/total" rings
/// progress bar. Matches the bold-outline, raised look used across the path.
private struct ThemeCard: View {
    let discipline: Discipline
    let progress: (done: Int, total: Int)
    let action: () -> Void

    private var progressRatio: Double {
        guard progress.total > 0 else { return 0 }
        return Double(progress.done) / Double(progress.total)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Image(systemName: discipline.icon)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(.white.opacity(0.18)))
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 2))
                }
                Spacer(minLength: 14)
                Text(discipline.name)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            if progressRatio > 0 {
                                Capsule()
                                    .fill(.white)
                                    .frame(width: max(10, geo.size.width * progressRatio))
                            }
                        }
                    }
                    .frame(height: 10)
                    Text("\(progress.done)/\(progress.total) ronds")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(height: 168)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(discipline.color.mix(with: .black, by: 0.22))
                    .offset(y: 5)
            )
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(discipline.color)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Bottom sheet offering the two things a theme card can do.
private struct ThemeActionSheet: View {
    let discipline: Discipline
    let dueCount: Int
    let onContinueTheme: () -> Void
    let onRevise: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: discipline.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(discipline.color))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                Text(discipline.name)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.top, 8)

            Button {
                Haptics.medium()
                dismiss()
                onContinueTheme()
            } label: {
                Label("Continuer le parcours", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: discipline.color))

            Button {
                Haptics.medium()
                dismiss()
                onRevise()
            } label: {
                Label(
                    dueCount > 0 ? "Réviser · \(dueCount) notion\(dueCount > 1 ? "s" : "")" : "Rien à réviser",
                    systemImage: "brain.head.profile"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
            .disabled(dueCount == 0)
            .opacity(dueCount == 0 ? 0.5 : 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

private extension String {
    /// Lowercase, accent-folded form used for simple case/accent-insensitive search.
    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
