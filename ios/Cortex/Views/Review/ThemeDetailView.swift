import SwiftUI

/// Dedicated page for one theme ("Anatomie"-style reference): pastel tinted
/// full-bleed background, progress bar with packs done and average score,
/// difficulty/progression filters, and a two-column grid of lesson packs.
struct ThemeDetailView: View {
    let discipline: Discipline

    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var difficultyFilter: DifficultyLevel?
    @State private var progressionFilter: ProgressionFilter = .all
    @State private var lessonLaunch: LessonLaunch?
    @State private var cooldownRing: PathRing?
    @State private var isEnergyOutPresented = false

    private enum ProgressionFilter: String, CaseIterable {
        case all, todo, done

        var label: String {
            switch self {
            case .all: return "Tous"
            case .todo: return "À faire"
            case .done: return "Terminés"
            }
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    /// Soft full-bleed tint of the theme colour.
    private var background: Color { discipline.color.mix(with: .white, by: 0.72) }
    private var textColor: Color { discipline.color.mix(with: .black, by: 0.18) }

    private var chapters: [Chapter] { model.orderedChapters(for: discipline) }

    private var packsDone: Int { model.packProgress(disciplineId: discipline.id).done }
    private var packsTotal: Int { chapters.count }
    private var averagePercent: Int { Int((model.averageScore(disciplineId: discipline.id) * 100).rounded()) }

    private var availableDifficulties: [DifficultyLevel] {
        DifficultyLevel.allCases.filter { level in
            chapters.contains { $0.availableLevels.first == level }
        }
    }

    private func chapterDifficulty(_ chapter: Chapter) -> DifficultyLevel {
        chapter.availableLevels.first ?? .facile
    }

    private var filteredChapters: [Chapter] {
        chapters.filter { chapter in
            let query = searchText.normalizedForSearch
            let matchesSearch = query.isEmpty || chapter.title.normalizedForSearch.contains(query)
            let matchesDifficulty = difficultyFilter == nil || chapterDifficulty(chapter) == difficultyFilter
            let done = model.isPackDone(chapterId: chapter.id, disciplineId: discipline.id)
            let matchesProgression: Bool = switch progressionFilter {
            case .all: true
            case .todo: !done
            case .done: done
            }
            return matchesSearch && matchesDifficulty && matchesProgression
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            titleRow
            searchField
            progressSection
            filtersRow
            ScrollView {
                if filteredChapters.isEmpty {
                    Text("Aucun pack ne correspond.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredChapters) { chapter in
                            PackCard(
                                chapter: chapter,
                                discipline: discipline,
                                difficulty: chapterDifficulty(chapter),
                                rubisReward: rubisReward(for: chapter),
                                isDone: model.isPackDone(chapterId: chapter.id, disciplineId: discipline.id)
                            ) {
                                startPack(chapter)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $lessonLaunch) { launch in
            LessonView(launch: launch, store: model.store) { retryLaunch in
                lessonLaunch = LessonLaunch(
                    title: retryLaunch.title,
                    chapterId: retryLaunch.chapterId,
                    items: retryLaunch.items,
                    disciplineId: retryLaunch.disciplineId,
                    chapterIdRaw: retryLaunch.chapterIdRaw,
                    ringKind: retryLaunch.ringKind
                )
            }
        }
        .sheet(item: $cooldownRing) { ring in
            RecapCooldownSheet(
                ring: ring,
                unlockDate: model.store.ringLockedUntil(ring.id) ?? .now
            )
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $isEnergyOutPresented) {
            EnergyRefillView(progressStore: model.store, quitTitle: "Fermer") {
                isEnergyOutPresented = false
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .buttonStyle(.plain)
            Spacer()
            StatPill(icon: "diamond.fill", color: Theme.livres, value: "\(model.store.livresBalance)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            icon
            Text(discipline.name)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var icon: some View {
        if let illustratedIconName = discipline.illustratedIconName {
            Image(illustratedIconName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Image(systemName: discipline.icon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(textColor)
                .frame(width: 44, height: 44)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            TextField("Rechercher dans \(discipline.name)", text: $searchText)
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
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.6)))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let ratio = packsTotal > 0 ? Double(packsDone) / Double(packsTotal) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.6))
                    if ratio > 0 {
                        Capsule()
                            .fill(Theme.ink)
                            .frame(width: max(14, geo.size.width * ratio))
                    }
                }
            }
            .frame(height: 14)
            HStack {
                Text("\(packsDone) / \(packsTotal) terminés")
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Label("Moy. \(averagePercent) %", systemImage: "target")
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Filters

    private var filtersRow: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Toutes") { difficultyFilter = nil }
                ForEach(availableDifficulties, id: \.self) { level in
                    Button(level.displayName) { difficultyFilter = level }
                }
            } label: {
                filterPill(label: difficultyFilter?.displayName ?? "Difficulté")
            }
            Menu {
                ForEach(ProgressionFilter.allCases, id: \.self) { filter in
                    Button(filter.label) { progressionFilter = filter }
                }
            } label: {
                filterPill(label: progressionFilter == .all ? "Progression" : progressionFilter.label)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func filterPill(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Theme.card))
    }

    // MARK: - Launch

    /// Rubis shown on the pack: what the first full pass of the chapter pays.
    private func rubisReward(for chapter: Chapter) -> Int {
        let chapterRings = model.rings(inChapter: chapter.id, disciplineId: discipline.id)
        let normalCount = chapterRings.filter { $0.kind == .normal }.count
        let hasRecap = chapterRings.contains { $0.kind == .recap }
        return normalCount * ProgressStore.ringRubisReward + (hasRecap ? ProgressStore.recapRubisReward : 0)
    }

    private func startPack(_ chapter: Chapter) {
        guard let ring = model.nextPlayableRing(chapterId: chapter.id, disciplineId: discipline.id) else { return }
        if case .cooldown = model.lock(for: ring) {
            Haptics.error()
            cooldownRing = ring
            return
        }
        if model.store.energy <= 0 {
            Haptics.error()
            isEnergyOutPresented = true
            return
        }
        let items = model.playableItems(for: ring)
        guard !items.isEmpty else { return }
        Haptics.medium()
        lessonLaunch = LessonLaunch(
            title: ring.lessonTitle,
            chapterId: ring.id,
            items: items,
            disciplineId: ring.disciplineId,
            chapterIdRaw: ring.chapterId,
            ringKind: ring.kind
        )
    }
}

/// One white pack card: icon top-left (with a green check once the pack is
/// done), difficulty badge top-right, two-line title, and the rubis reward
/// pill at the bottom.
private struct PackCard: View {
    let chapter: Chapter
    let discipline: Discipline
    let difficulty: DifficultyLevel
    let rubisReward: Int
    let isDone: Bool
    let action: () -> Void

    private var badgeColor: Color {
        switch difficulty {
        case .facile: return Color(hex: "2FBF71")
        case .intermediaire: return Color(hex: "F5A623")
        case .difficile: return Color(hex: "FF6B00")
        case .maitre: return Color(hex: "9B4DFF")
        case .legende: return Color(hex: "FF3B5C")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    PackIcon(discipline: discipline)
                        .overlay(alignment: .topTrailing) {
                            if isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white, Theme.success)
                                    .offset(x: 6, y: -6)
                            }
                        }
                    Spacer()
                    Text(difficulty.displayName)
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(badgeColor.opacity(0.14)))
                }
                Text(chapter.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 5) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(rubisReward)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                }
                .foregroundStyle(Theme.livres)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Theme.livres.opacity(0.12)))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }
}

/// Discipline badge reused on each pack card.
private struct PackIcon: View {
    let discipline: Discipline

    var body: some View {
        Group {
            if let illustratedIconName = discipline.illustratedIconName {
                Image(illustratedIconName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: discipline.icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(discipline.color)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}
