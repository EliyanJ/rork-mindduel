import Foundation

/// Deterministic SplitMix64 RNG: both players of a ranked match derive the
/// exact same question list from the server seed.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    init(seedString: String) {
        self.init(seed: UInt64(seedString) ?? UInt64(abs(seedString.hashValue)))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

nonisolated enum MatchQuestionPicker {
    /// Deterministic selection: pool of non-anagram questions sorted by id,
    /// Fisher-Yates shuffled with the shared seed, first `count` taken.
    /// If `disciplineId` is provided, only questions from that discipline are used.
    static func questions(from catalog: ContentCatalog, seed: String, count: Int, disciplineId: String? = nil) -> [Question] {
        var pool: [Question] = []
        for discipline in catalog.disciplines {
            if let disciplineId, discipline.id != disciplineId { continue }
            for chapter in discipline.chapters {
                for question in chapter.allQuestions where question.type != .anagram {
                    pool.append(question)
                }
            }
        }
        pool.sort { $0.id < $1.id }
        var generator = SeededGenerator(seedString: seed)
        // Manual Fisher-Yates for a stable algorithm across runtimes.
        var items = pool
        if items.count > 1 {
            for i in stride(from: items.count - 1, through: 1, by: -1) {
                let j = Int(generator.next() % UInt64(i + 1))
                items.swapAt(i, j)
            }
        }
        return Array(items.prefix(count))
    }
}
