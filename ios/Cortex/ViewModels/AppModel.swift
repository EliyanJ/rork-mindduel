import Foundation
import Observation

enum ChapterState: Equatable {
    case locked
    case available
    case completed
    case mastered
}

@Observable
final class AppModel {
    let catalog: ContentCatalog
    let store: ProgressStore
    /// Default unified path: every stage mixes questions from all themes.
    private let mixedStages: [PathStage]
    /// One dedicated path per discipline, gathering all of its questions.
    private let themedStages: [String: [PathStage]]
    /// Currently selected theme; nil means the default mixed path.
    var selectedDisciplineId: String?

    private let questionIndex: [String: (question: Question, disciplineId: String)]

    init() {
        let catalog = ContentService.loadCatalog()
        self.catalog = catalog
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

        let allQueues: [[LessonItem]] = catalog.disciplines.map { discipline in
            discipline.chapters.flatMap { chapter in
                chapter.allQuestions.map { LessonItem(question: $0, disciplineId: discipline.id) }
            }
        }
        self.mixedStages = Self.buildStages(items: Self.interleave(allQueues), idPrefix: "stage")

        var themed: [String: [PathStage]] = [:]
        for discipline in catalog.disciplines {
            let chapterQueues: [[LessonItem]] = discipline.chapters.map { chapter in
                chapter.allQuestions.map { LessonItem(question: $0, disciplineId: discipline.id) }
            }
            themed[discipline.id] = Self.buildStages(
                items: Self.interleave(chapterQueues),
                idPrefix: "stage-\(discipline.id)"
            )
        }
        self.themedStages = themed
    }

    /// The stages of the active path (mixed by default, themed when a discipline is selected).
    var stages: [PathStage] {
        if let id = selectedDisciplineId, let themed = themedStages[id] {
            return themed
        }
        return mixedStages
    }

    var selectedDiscipline: Discipline? {
        guard let id = selectedDisciplineId else { return nil }
        return discipline(withId: id)
    }

    func state(of stage: PathStage) -> ChapterState {
        if let record = store.progress.chapterRecords[stage.id] {
            return record.bestScore >= 0.8 ? .mastered : .completed
        }
        if stage.index == 0 { return .available }
        let previous = stages[stage.index - 1]
        if let previousRecord = store.progress.chapterRecords[previous.id], previousRecord.bestScore >= 0.6 {
            return .available
        }
        return .locked
    }

    /// The stage suggested as "lesson of the day".
    var nextStage: PathStage? {
        stages.first { stage in
            let stageState = state(of: stage)
            return stageState == .available || stageState == .completed
        } ?? stages.last
    }

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

    // MARK: - Path building

    /// Round-robin merge of several question queues so consecutive
    /// questions vary (across themes for the mixed path, across chapters
    /// for a themed path).
    private static func interleave(_ queues: [[LessonItem]]) -> [LessonItem] {
        var queues = queues
        var mixed: [LessonItem] = []
        while queues.contains(where: { !$0.isEmpty }) {
            for i in queues.indices where !queues[i].isEmpty {
                mixed.append(queues[i].removeFirst())
            }
        }
        return mixed
    }

    /// Chunks an ordered list of questions into stages of ~15 questions.
    private static func buildStages(items: [LessonItem], idPrefix: String) -> [PathStage] {
        let stageSize = 10
        var chunks: [[LessonItem]] = []
        var start = 0
        while start < items.count {
            let end = min(start + stageSize, items.count)
            chunks.append(Array(items[start..<end]))
            start = end
        }
        // Merge a too-small trailing chunk into the previous stage.
        if let last = chunks.last, last.count < 4, chunks.count >= 2 {
            chunks[chunks.count - 2].append(contentsOf: last)
            chunks.removeLast()
        }

        return chunks.enumerated().map { index, items in
            var featured: [String] = []
            for item in items where !featured.contains(item.disciplineId) {
                featured.append(item.disciplineId)
            }
            return PathStage(
                id: "\(idPrefix)-\(index + 1)",
                index: index,
                title: stageName(at: index),
                items: items,
                disciplineIds: featured
            )
        }
    }

    private static let stageNames: [String] = [
        "Premiers pas", "Esprit curieux", "Tête chercheuse", "Explorateur",
        "Érudit en herbe", "Esprit vif", "Globe-trotteur", "Fine plume",
        "Cerveau musclé", "Œil de lynx", "Maître du temps", "Stratège",
        "Encyclopédie vivante", "Sage éclairé", "Légende du savoir"
    ]

    private static func stageName(at index: Int) -> String {
        index < stageNames.count ? stageNames[index] : "Étape \(index + 1)"
    }
}
