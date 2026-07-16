import Foundation

/// Generates the optional 21-question onboarding diagnostic.
enum DiagnosticGenerator {
    static let questionsPerDiscipline = 3
    static let eligibleTypes: Set<QuestionType> = [.multipleChoice, .trueFalse]

    /// Picks up to `questionsPerDiscipline` questions per discipline, each from a
    /// different randomly chosen chapter, filtered to QCM/Vrai-Faux by default.
    /// The final list is shuffled so disciplines are interleaved.
    static func generateDiagnosticQuestions(catalog: ContentCatalog) -> [Question] {
        var selected: [Question] = []

        for discipline in catalog.disciplines {
            let shuffledChapters = discipline.chapters.shuffled()
            let chosenChapters = Array(shuffledChapters.prefix(questionsPerDiscipline))

            for chapter in chosenChapters {
                var pool = chapter.allQuestions.filter { eligibleTypes.contains($0.type) }
                if pool.isEmpty {
                    pool = chapter.allQuestions
                }
                if let question = pool.randomElement() {
                    selected.append(question)
                }
            }
        }

        return selected.shuffled()
    }

    /// Computes per-discipline results from the answered diagnostic questions.
    static func computeResults(
        session: DiagnosticSession,
        catalog: ContentCatalog
    ) -> [DisciplineDiagnosticResult] {
        var counts: [String: (correct: Int, total: Int, name: String)] = [:]
        for (i, item) in session.items.enumerated() {
            let id = item.disciplineId
            let name = catalog.disciplines.first { $0.id == id }?.name ?? id
            var entry = counts[id] ?? (correct: 0, total: 0, name: name)
            entry.total += 1
            if i < session.wasCorrect.count, session.wasCorrect[i] {
                entry.correct += 1
            }
            counts[id] = entry
        }
        return counts.map { id, entry in
            DisciplineDiagnosticResult(
                disciplineId: id,
                disciplineName: entry.name,
                correctCount: entry.correct,
                totalCount: entry.total,
                tier: diagnosticTier(correctCount: entry.correct)
            )
        }
    }
}
