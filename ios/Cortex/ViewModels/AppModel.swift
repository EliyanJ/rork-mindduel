import Foundation
import Observation

enum ChapterState: Equatable {
    case locked
    case available
    case completed
    case mastered
}

/// Why a ring can't be played right now.
enum RingLock: Equatable {
    /// The previous ring hasn't been cleared yet.
    case sequence
    /// A failed recap is cooling down until the given date.
    case cooldown(until: Date)
}

/// A lesson of the journey: one sub-theme (a chapter, e.g. "L'Antiquité")
/// together with its 15-question rings, in playing order.
struct PathLesson: Identifiable, Hashable {
    let chapterId: String
    let disciplineId: String
    let title: String
    let rings: [PathRing]

    var id: String { chapterId }
}

@Observable
final class AppModel {
    private(set) var catalog: ContentCatalog
    let store: ProgressStore
    let badges: BadgeStore
    /// Published ordering of disciplines / chapters / rings.
    private(set) var layout: PathLayout
    /// Disciplines in path order.
    private(set) var orderedDisciplines: [Discipline]
    /// disciplineId → its rings, in path order.
    private var ringsByDiscipline: [String: [PathRing]]
    /// The full journey through the themes, one lesson (sub-theme) at a time.
    private(set) var journeyRings: [PathRing] = []
    private(set) var lessons: [PathLesson] = []
    /// Discipline ids the player picked at onboarding for the old mixed path.
    /// Kept for API compatibility; the journey is now sequential.
    var preferredDisciplineIds: [String] = []
    /// Raw bytes of the bundled catalogue, kept to detect whether a backend
    /// refresh actually changed anything worth rebuilding for.
    private let bundledData: Data?

    init() {
        // Boot on the bundled catalogue — never block the first frame on the
        // network. `refreshFromBackend()` swaps in fresh content afterwards.
        let catalog = ContentService.loadCatalog()
        let layout = PathLayoutService.loadLayout()
        self.catalog = catalog
        self.layout = layout
        self.store = ProgressStore()
        self.badges = BadgeStore()
        self.bundledData = ContentService.bootData()
        self.orderedDisciplines = []
        self.ringsByDiscipline = [:]
        rebuild(catalog: catalog, layout: layout)
        // Progress made before badges existed is credited quietly.
        badges.award(qualifiedBadges())
    }

    // MARK: - Badges

    /// Badges whose artwork exists, in collection order.
    var visibleBadges: [Badge] {
        Badge.all.filter(\.hasArtwork)
    }

    /// Badges earned outside a lesson (duels, leagues), waiting to be
    /// celebrated by the root view.
    var pendingBadgeCelebrations: [Badge] = []

    /// Progress toward a badge, capped at what it requires.
    func badgeProgress(_ badge: Badge) -> (done: Int, required: Int) {
        let progress = store.progress
        func capped(_ done: Int, _ required: Int) -> (done: Int, required: Int) {
            (min(done, required), required)
        }
        switch badge.requirement {
        case .theme(let disciplineId, let tier):
            let rings = themeRingProgress(disciplineId: disciplineId)
            let required = tier.requiredRings(total: rings.total)
            return required == .max ? (0, 0) : capped(rings.done, required)
        case .chaptersInThemes(let count):
            return capped(themesWithAFinishedChapter(), count)
        case .allThemes(let tier):
            let reached = orderedDisciplines.filter { isThemeTierReached($0.id, tier) }.count
            return capped(reached, max(orderedDisciplines.count, 1))
        case .streak(let days):
            return capped(store.streakHistory().bestStreak, days)
        case .duelWins(let count):
            return capped(progress.duelsWon, count)
        case .perfectRings(let count):
            return capped(progress.perfectRings, count)
        case .correctAnswers(let count):
            return capped(progress.lifetimeCorrect, count)
        case .fastAnswers(let count):
            return capped(progress.fastCorrect, count)
        case .flag(let flag):
            return (store.hasBadgeFlag(flag) ? 1 : 0, 1)
        }
    }

    /// Theme name used in theme-tier condition lines.
    func themeName(for badge: Badge) -> String {
        guard case .theme(let disciplineId, _) = badge.requirement else { return "" }
        return discipline(withId: disciplineId)?.name ?? "ce thème"
    }

    private func isThemeTierReached(_ disciplineId: String, _ tier: BadgeTier) -> Bool {
        let rings = themeRingProgress(disciplineId: disciplineId)
        let required = tier.requiredRings(total: rings.total)
        return required != .max && rings.done >= required
    }

    /// Themes in which at least one chapter has every ring cleared.
    private func themesWithAFinishedChapter() -> Int {
        let finished = lessons.filter { lesson in
            !lesson.rings.isEmpty && lesson.rings.allSatisfy { store.isRingPassed($0.id) }
        }
        return Set(finished.map(\.disciplineId)).count
    }

    /// Checks badges after a duel or a league change and queues the new ones
    /// for the root celebration overlay.
    func queueNewBadges() {
        let fresh = awardNewBadges()
        guard !fresh.isEmpty else { return }
        pendingBadgeCelebrations.append(contentsOf: fresh)
    }

    /// Visible badges whose condition is currently met.
    private func qualifiedBadges() -> [Badge] {
        visibleBadges.filter { badge in
            let progress = badgeProgress(badge)
            return progress.required > 0 && progress.done >= progress.required
        }
    }

    /// Credits any badge just earned and returns the new ones (for the
    /// celebration screen), rarest last.
    func awardNewBadges() -> [Badge] {
        badges.award(qualifiedBadges()).sorted { $0.rarity < $1.rarity }
    }

    /// Pulls the latest catalogue and published path layout from the backend,
    /// then rebuilds the path if anything changed. Ring identity is derived
    /// from chapter ids, so player progress survives a rebuild.
    func refreshFromBackend() async {
        async let remoteCatalog = ContentService.fetchRemoteCatalog()
        async let remoteLayout = PathLayoutService.fetchRemoteLayout()
        let layoutResult = await remoteLayout
        let catalogResult = await remoteCatalog

        var changed = false
        var newLayout = layout
        var newCatalog = catalog
        if let layoutResult, layoutResult != layout {
            newLayout = layoutResult
            changed = true
        }
        if let (fresh, data) = catalogResult, data != bundledData {
            newCatalog = fresh
            changed = true
        }
        guard changed else { return }
        rebuild(catalog: newCatalog, layout: newLayout)
    }

    private func rebuild(catalog: ContentCatalog, layout: PathLayout) {
        self.catalog = catalog
        self.layout = layout

        let disciplines = PathLayout.apply(
            order: layout.disciplineOrder,
            to: catalog.disciplines,
            id: { $0.id }
        )
        self.orderedDisciplines = disciplines

        var rings: [String: [PathRing]] = [:]
        for discipline in disciplines {
            let chapters = PathLayout.apply(
                order: layout.chapterOrder[discipline.id] ?? [],
                to: discipline.chapters,
                id: { $0.id }
            )
            rings[discipline.id] = chapters.flatMap { chapter in
                RingBuilder.rings(
                    for: chapter,
                    disciplineId: discipline.id,
                    slots: layout.ringLayout[chapter.id]
                )
            }
        }
        self.ringsByDiscipline = rings
        rebuildJourney()
    }

    // MARK: - Journey

    /// Rings of the active path (the full journey by default, themed when a
    /// discipline is selected).
    var rings: [PathRing] {
        if let id = selectedDisciplineId, let themed = ringsByDiscipline[id] {
            return themed
        }
        return journeyRings
    }

    /// Currently selected theme; nil means the default journey across themes.
    var selectedDisciplineId: String?

    /// Set from elsewhere (news feed) to open the Parcours chapters page.
    var isChaptersMenuRequested: Bool = false

    /// Set from a sheet or screen to switch the main tab (e.g. "Voir mes missions").
    var requestedTab: AppTab?

    /// Set when the profile should open scrolled to the streak calendar.
    var isStreakCalendarRequested: Bool = false

    /// Opens the profile tab directly on the streak calendar.
    func openStreakCalendar() {
        isStreakCalendarRequested = true
        requestedTab = .plus
    }

    /// Switches to the Missions tab once the caller's own sheet has closed.
    func openMissions() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            requestedTab = .missions
        }
    }

    func rings(for disciplineId: String) -> [PathRing] {
        ringsByDiscipline[disciplineId] ?? []
    }

    var selectedDiscipline: Discipline? {
        guard let id = selectedDisciplineId else { return nil }
        return discipline(withId: id)
    }

    /// General culture vs specific domain, published layout winning over the
    /// catalog so the classification is editable from the back-office.
    func kind(of discipline: Discipline) -> DisciplineKind {
        layout.kind(of: discipline)
    }

    /// Themes that feed the journey.
    var generalDisciplines: [Discipline] {
        orderedDisciplines.filter { kind(of: $0) == .generale }
    }

    /// Themes reachable only by picking them deliberately.
    var specificDisciplines: [Discipline] {
        orderedDisciplines.filter { kind(of: $0) == .specifique }
    }

    /// The journey walks each theme to completion before moving to the next:
    /// disciplines in path order, their chapters in path order. Specific
    /// themes (football, ...) stay out — the journey is the general-culture
    /// run; a specific theme is played by choosing it from the themes tab,
    /// which jumps straight into that theme's own dedicated path instead.
    private func rebuildJourney() {
        var merged: [PathRing] = []
        var lessons: [PathLesson] = []
        for discipline in generalDisciplines {
            let rings = ringsByDiscipline[discipline.id] ?? []
            merged.append(contentsOf: rings)
            lessons.append(contentsOf: Self.groupIntoLessons(rings))
        }
        journeyRings = merged
        self.lessons = lessons
    }

    /// Groups consecutive rings of the same chapter into one `PathLesson`,
    /// preserving ring order. Shared by the mixed general journey and by a
    /// single theme's own dedicated path (built on demand).
    private static func groupIntoLessons(_ rings: [PathRing]) -> [PathLesson] {
        var lessons: [PathLesson] = []
        for ring in rings {
            if let last = lessons.last, last.chapterId == ring.chapterId {
                lessons[lessons.count - 1] = PathLesson(
                    chapterId: last.chapterId,
                    disciplineId: last.disciplineId,
                    title: last.title,
                    rings: last.rings + [ring]
                )
            } else {
                lessons.append(
                    PathLesson(
                        chapterId: ring.chapterId,
                        disciplineId: ring.disciplineId,
                        title: ring.chapterTitle,
                        rings: [ring]
                    )
                )
            }
        }
        return lessons
    }

    /// The lesson the player should be working on: the first lesson with an
    /// uncleared ring, or the very last one when the journey is done.
    var currentLesson: PathLesson? {
        lessons.first { !isLessonDone($0) } ?? lessons.last
    }

    /// Every ring of the lesson cleared.
    func isLessonDone(_ lesson: PathLesson) -> Bool {
        guard !lesson.rings.isEmpty else { return false }
        return lesson.rings.allSatisfy { store.isRingPassed($0.id) }
    }

    /// A lesson is unlocked once its first ring is playable (previous
    /// lesson's recap cleared) — or already partially played.
    func isLessonUnlocked(_ lesson: PathLesson) -> Bool {
        guard let first = lesson.rings.first else { return false }
        return lock(for: first) == nil || store.isRingPassed(first.id)
    }

    /// Rings cleared vs. total inside one lesson, for the banner percentage.
    func lessonRingCounts(_ lesson: PathLesson) -> (done: Int, total: Int) {
        let total = lesson.rings.count
        guard total > 0 else { return (0, 0) }
        return (lesson.rings.filter { store.isRingPassed($0.id) }.count, total)
    }

    /// Lessons of one theme, in journey order — used by the lessons menu.
    /// General disciplines reuse the pre-built journey lessons; a specific
    /// theme (football, ...) isn't part of the mixed journey, so its own
    /// lessons are grouped on demand from its rings.
    func lessons(inDiscipline id: String) -> [PathLesson] {
        let cached = lessons.filter { $0.disciplineId == id }
        if !cached.isEmpty { return cached }
        return Self.groupIntoLessons(ringsByDiscipline[id] ?? [])
    }

    /// The lesson to land on when jumping straight into one theme's own
    /// path: the first not-yet-cleared lesson, or the last one when the
    /// whole theme is already done.
    func currentLesson(inDiscipline id: String) -> PathLesson? {
        let group = lessons(inDiscipline: id)
        return group.first { !isLessonDone($0) } ?? group.last
    }

    /// The lesson right after `lesson` on the active path (the theme's own
    /// path when one is selected, the mixed journey otherwise).
    func lesson(after lesson: PathLesson) -> PathLesson? {
        let group = selectedDisciplineId.map { lessons(inDiscipline: $0) } ?? lessons
        guard let index = group.firstIndex(where: { $0.id == lesson.id }), index + 1 < group.count else { return nil }
        return group[index + 1]
    }

    /// The hardest questions of a lesson, used by its placement test.
    func placementItems(for lesson: PathLesson) -> [LessonItem] {
        let supported = lesson.rings.flatMap(\.items).filter { $0.question.type != .anagram }
        var seen = Set<String>()
        let unique = supported.filter { seen.insert($0.id).inserted }
        let hardestFirst = lesson.rings.first { $0.kind == .recap }?.items.filter { $0.question.type != .anagram } ?? []
        var picked: [LessonItem] = []
        var used = Set<String>()
        for item in hardestFirst + unique.shuffled() where picked.count < ProgressStore.placementQuestionCount {
            guard used.insert(item.id).inserted else { continue }
            picked.append(item)
        }
        return picked.shuffled()
    }

    /// 1-based position of a lesson within its theme ("LEÇON 2").
    func lessonIndex(_ lesson: PathLesson) -> Int {
        let group = lessons(inDiscipline: lesson.disciplineId)
        return (group.firstIndex { $0.chapterId == lesson.chapterId } ?? 0) + 1
    }

    // MARK: - Ring state

    /// Position of a ring within the active path.
    private func pathIndex(of ring: PathRing) -> Int? {
        rings.firstIndex { $0.id == ring.id }
    }

    /// Rings of the same sub-chapter that must be cleared before its recap.
    private func normalRings(inChapter chapterId: String, disciplineId: String) -> [PathRing] {
        (ringsByDiscipline[disciplineId] ?? [])
            .filter { $0.chapterId == chapterId && $0.kind == .normal }
    }

    func state(of ring: PathRing) -> ChapterState {
        if store.isRingMastered(ring.id) { return .mastered }
        if lock(for: ring) != nil { return .locked }
        if store.isRingPassed(ring.id) { return .completed }
        return .available
    }

    /// Why a ring is locked, or nil when it's playable.
    func lock(for ring: PathRing) -> RingLock? {
        // A failed recap always cools down, even if everything else is cleared.
        if let until = store.ringLockedUntil(ring.id) {
            return .cooldown(until: until)
        }
        if ring.kind == .recap {
            let siblings = normalRings(inChapter: ring.chapterId, disciplineId: ring.disciplineId)
            let allCleared = siblings.allSatisfy { store.isRingPassed($0.id) }
            return allCleared ? nil : .sequence
        }
        // First ring of a chapter opened early through its placement test.
        if ring.indexInChapter == 0, store.isChapterUnlockedByTest(ring.chapterId) { return nil }
        guard let index = pathIndex(of: ring), index > 0 else { return nil }
        let previous = rings[index - 1]
        // Already-cleared rings stay replayable.
        if store.isRingPassed(ring.id) { return nil }
        return store.isRingPassed(previous.id) ? nil : .sequence
    }

    /// The ring proposed as "lesson of the day" on the active path.
    var nextRing: PathRing? {
        rings.first { state(of: $0) == .available } ?? rings.first { state(of: $0) == .completed } ?? rings.first
    }

    /// Questions actually played for a ring.
    ///
    /// Normal rings play their fixed 15. A recap is personalised: the player's
    /// own mistakes in that sub-chapter come first, topped up with its hardest
    /// questions so the boss is always a full ring.
    func playableItems(for ring: PathRing) -> [LessonItem] {
        guard ring.kind == .recap else { return ring.items }
        let pool = ring.items
        let poolIds = pool.map(\.id)
        let lapsed = store.laspedQuestionIds(among: poolIds)
        let byId = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var picked: [LessonItem] = []
        var used = Set<String>()
        for id in lapsed where picked.count < RingBuilder.ringSize {
            guard let item = byId[id] else { continue }
            picked.append(item)
            used.insert(id)
        }
        // `pool` is already ordered hardest-first.
        for item in pool where picked.count < RingBuilder.ringSize {
            guard !used.contains(item.id) else { continue }
            picked.append(item)
            used.insert(item.id)
        }
        return picked
    }

    /// Sub-chapter progress used by the path header, as cleared/total rings.
    func chapterProgressCounts(chapterId: String, disciplineId: String) -> (done: Int, total: Int) {
        let all = (ringsByDiscipline[disciplineId] ?? []).filter { $0.chapterId == chapterId }
        return (all.filter { store.isRingPassed($0.id) }.count, all.count)
    }

    // MARK: - Lookups

    func discipline(withId id: String) -> Discipline? {
        catalog.disciplines.first { $0.id == id }
    }

    /// Rings cleared vs. total for one discipline, shown as "done/total" on
    /// its theme card.
    func themeRingProgress(disciplineId: String) -> (done: Int, total: Int) {
        let all = ringsByDiscipline[disciplineId] ?? []
        return (all.filter { store.isRingPassed($0.id) }.count, all.count)
    }

    // MARK: - Theme packs (chapters of a discipline)

    /// Chapters of a discipline in published path order.
    func orderedChapters(for discipline: Discipline) -> [Chapter] {
        PathLayout.apply(
            order: layout.chapterOrder[discipline.id] ?? [],
            to: discipline.chapters,
            id: { $0.id }
        )
    }

    /// Rings of one chapter, in playing order (normals first, recap last).
    func rings(inChapter chapterId: String, disciplineId: String) -> [PathRing] {
        (ringsByDiscipline[disciplineId] ?? []).filter { $0.chapterId == chapterId }
    }

    /// Hand-written revision lesson for a chapter, if the admin catalog set
    /// one — otherwise `nil`, and `StudyGuide` falls back to explanations
    /// distilled from the ring's own questions.
    func chapterLesson(chapterId: String, disciplineId: String) -> ChapterLesson? {
        discipline(withId: disciplineId)?.chapters.first { $0.id == chapterId }?.lesson
    }

    /// A pack counts as done once every ring of its chapter has been passed.
    func isPackDone(chapterId: String, disciplineId: String) -> Bool {
        let chapterRings = rings(inChapter: chapterId, disciplineId: disciplineId)
        guard !chapterRings.isEmpty else { return false }
        return chapterRings.allSatisfy { store.isRingPassed($0.id) }
    }

    /// Done vs. total packs for a discipline — drives the "X / Y terminés"
    /// header of a theme detail page.
    func packProgress(disciplineId: String) -> (done: Int, total: Int) {
        guard let discipline = discipline(withId: disciplineId) else { return (0, 0) }
        let chapters = orderedChapters(for: discipline)
        return (chapters.filter { isPackDone(chapterId: $0.id, disciplineId: disciplineId) }.count, chapters.count)
    }

    /// Average best score across a discipline's rings (0–1), shown as
    /// "Moy. X %" on the theme detail header.
    func averageScore(disciplineId: String) -> Double {
        let all = ringsByDiscipline[disciplineId] ?? []
        guard !all.isEmpty else { return 0 }
        let total = all.reduce(0.0) { $0 + (store.ringRecord($1.id)?.bestScore ?? 0) }
        return total / Double(all.count)
    }

    /// The next ring to play inside a chapter: the first not yet passed, or
    /// the last ring when everything is cleared (replay).
    func nextPlayableRing(chapterId: String, disciplineId: String) -> PathRing? {
        let chapterRings = rings(inChapter: chapterId, disciplineId: disciplineId)
        return chapterRings.first { !store.isRingPassed($0.id) } ?? chapterRings.last
    }
}
