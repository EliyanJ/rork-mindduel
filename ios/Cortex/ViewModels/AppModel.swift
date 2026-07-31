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

@Observable
final class AppModel {
    let catalog: ContentCatalog
    let store: ProgressStore
    /// Published ordering of disciplines / chapters / rings.
    let layout: PathLayout
    /// Disciplines in path order.
    let orderedDisciplines: [Discipline]
    /// disciplineId → its rings, in path order.
    private let ringsByDiscipline: [String: [PathRing]]
    /// Currently selected theme; nil means the default mixed path.
    var selectedDisciplineId: String?
    /// Discipline ids the player picked at onboarding. Drives the rotation of
    /// the mixed path — favourites come round more often.
    var preferredDisciplineIds: [String] = [] {
        didSet {
            guard oldValue != preferredDisciplineIds else { return }
            rebuildMixedRings()
        }
    }

    private var mixedRings: [PathRing] = []
    private let questionIndex: [String: (question: Question, disciplineId: String)]

    init() {
        let catalog = ContentService.loadCatalog()
        let layout = PathLayoutService.loadLayout()
        self.catalog = catalog
        self.layout = layout
        self.store = ProgressStore()

        var index: [String: (question: Question, disciplineId: String)] = [:]
        for discipline in catalog.disciplines {
            for chapter in discipline.chapters {
                for question in chapter.allQuestions {
                    index[question.id] = (question, discipline.id)
                }
            }
        }
        self.questionIndex = index

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
        rebuildMixedRings()
    }

    // MARK: - Paths

    /// Rings of the active path (mixed by default, themed when a discipline is selected).
    var rings: [PathRing] {
        if let id = selectedDisciplineId, let themed = ringsByDiscipline[id] {
            return themed
        }
        return mixedRings
    }

    func rings(for disciplineId: String) -> [PathRing] {
        ringsByDiscipline[disciplineId] ?? []
    }

    var selectedDiscipline: Discipline? {
        guard let id = selectedDisciplineId else { return nil }
        return discipline(withId: id)
    }

    var isMixedPath: Bool { selectedDisciplineId == nil }

    /// Round-robin across disciplines so the mixed path alternates themes while
    /// keeping each discipline's own rings in order. Preferred themes are
    /// visited more than once per lap, so they come round more often without
    /// ever excluding the others.
    private func rebuildMixedRings() {
        var queues: [String: [PathRing]] = [:]
        for discipline in orderedDisciplines {
            queues[discipline.id] = ringsByDiscipline[discipline.id] ?? []
        }
        let preferred = preferredDisciplineIds.filter { queues[$0]?.isEmpty == false }
        // One lap = every discipline once, plus an extra visit for favourites.
        var lap = orderedDisciplines.map(\.id)
        lap.append(contentsOf: preferred)

        var merged: [PathRing] = []
        while queues.values.contains(where: { !$0.isEmpty }) {
            for disciplineId in lap {
                guard var queue = queues[disciplineId], !queue.isEmpty else { continue }
                merged.append(queue.removeFirst())
                queues[disciplineId] = queue
            }
        }
        mixedRings = merged
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

    func dueLessonItems(limit: Int = 10) -> [LessonItem] {
        Array(store.dueQuestionIds().prefix(limit)).compactMap { id in
            guard let entry = questionIndex[id] else { return nil }
            return LessonItem(question: entry.question, disciplineId: entry.disciplineId)
        }
    }

    func discipline(withId id: String) -> Discipline? {
        catalog.disciplines.first { $0.id == id }
    }

    /// Average memory strength across every question of a discipline (unseen = 0).
    func masteryPercent(for discipline: Discipline) -> Double {
        let questionCount = discipline.chapters.reduce(0) { $0 + $1.questionCount }
        guard questionCount > 0 else { return 0 }
        let total = store.progress.reviewItems.values
            .filter { $0.disciplineId == discipline.id }
            .reduce(0.0) { $0 + $1.strength }
        return min(1, total / Double(questionCount))
    }
}
