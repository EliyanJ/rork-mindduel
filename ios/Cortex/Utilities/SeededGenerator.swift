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
    /// Deterministic selection shared by both players of a ranked match.
    ///
    /// - `themes`: both players' theme choices ("all" = every discipline). When
    ///   the two players picked two distinct themes the duel splits 15 questions
    ///   as 5 from theme A + 5 from theme B + 5 from a "basique" pool drawn from
    ///   all general-culture disciplines. Same-theme or "all" matches draw all
    ///   questions evenly across the available theme(s).
    /// - `averageElo`: average of both players' ELO, used to bias question
    ///   difficulty toward their shared level (with fallback when a theme has
    ///   too few questions at that difficulty).
    ///
    /// Everything is derived from the shared seed so both clients build the
    /// exact same question list.
    static func questions(
        from catalog: ContentCatalog,
        seed: String,
        count: Int,
        themes rawThemes: [String]? = nil,
        averageElo: Int = 1000
    ) -> [Question] {
        let themes = normalizedThemes(rawThemes)
        let allowed = allowedLevels(forElo: averageElo)
        var generator = SeededGenerator(seedString: seed)
        var used = Set<String>()

        // Two distinct explicit themes → 5 / 5 / 5 split with a basique pool
        // of general-culture questions (excluding the two chosen themes so a
        // player who picked a generale theme doesn't see it duplicated).
        if themes.count == 2, themes.allSatisfy({ $0 != "all" }) {
            return mixedTwoTheme(
                from: catalog,
                themes: themes,
                basiqueCount: count / 3,
                perThemeCount: count / 3 + (count % 3 > 0 ? 1 : 0),
                allowed: allowed,
                generator: &generator,
                used: &used
            )
        }

        var perTheme: [[Question]] = []
        for (index, theme) in themes.enumerated() {
            let share = count / themes.count + (index < count % themes.count ? 1 : 0)
            var pool = pool(from: catalog, theme: theme, allowedLevels: allowed)
            if pool.count < share {
                pool = self.pool(from: catalog, theme: theme, allowedLevels: nil)
            }
            shuffle(&pool, using: &generator)
            var picked: [Question] = []
            for question in pool where picked.count < share {
                if used.insert(question.id).inserted {
                    picked.append(question)
                }
            }
            perTheme.append(picked)
        }

        // Round-robin interleave so themes alternate through the duel.
        var result: [Question] = []
        var cursor = 0
        while result.count < count {
            var addedAny = false
            for list in perTheme where cursor < list.count {
                result.append(list[cursor])
                addedAny = true
                if result.count == count { break }
            }
            if !addedAny { break }
            cursor += 1
        }

        // Shortfall (tiny themes): top up from the full catalog.
        if result.count < count {
            var fallback = pool(from: catalog, theme: "all", allowedLevels: nil)
            shuffle(&fallback, using: &generator)
            for question in fallback where result.count < count {
                if used.insert(question.id).inserted {
                    result.append(question)
                }
            }
        }
        return result
    }

    /// 5 / 5 / 5 split for two distinct themes: theme A, theme B, and a
    /// "basique" pool drawn from general-culture disciplines (kind == .generale)
    /// excluding the two chosen themes. Interleaves the three buckets so the
    /// duel alternates A → B → basique → A → B → basique …
    private static func mixedTwoTheme(
        from catalog: ContentCatalog,
        themes: [String],
        basiqueCount: Int,
        perThemeCount: Int,
        allowed: Set<DifficultyLevel>,
        generator: inout SeededGenerator,
        used: inout Set<String>
    ) -> [Question] {
        let themeA = themes[0]
        let themeB = themes[1]
        let count = basiqueCount + perThemeCount * 2

        var poolA = pool(from: catalog, theme: themeA, allowedLevels: allowed)
        if poolA.count < perThemeCount {
            poolA = self.pool(from: catalog, theme: themeA, allowedLevels: nil)
        }
        shuffle(&poolA, using: &generator)

        var poolB = pool(from: catalog, theme: themeB, allowedLevels: allowed)
        if poolB.count < perThemeCount {
            poolB = self.pool(from: catalog, theme: themeB, allowedLevels: nil)
        }
        shuffle(&poolB, using: &generator)

        var basique = basiquePool(from: catalog, excluding: [themeA, themeB], allowedLevels: allowed)
        if basique.count < basiqueCount {
            basique = basiquePool(from: catalog, excluding: [themeA, themeB], allowedLevels: nil)
        }
        shuffle(&basique, using: &generator)

        func pick(_ source: [Question], _ n: Int) -> [Question] {
            var picked: [Question] = []
            for q in source where picked.count < n {
                if used.insert(q.id).inserted { picked.append(q) }
            }
            return picked
        }

        let pickedA = pick(poolA, perThemeCount)
        let pickedB = pick(poolB, perThemeCount)
        let pickedBasique = pick(basique, basiqueCount)

        // Interleave A → B → basique round-robin.
        let buckets = [pickedA, pickedB, pickedBasique]
        var result: [Question] = []
        var cursor = 0
        while result.count < count {
            var addedAny = false
            for bucket in buckets where cursor < bucket.count {
                result.append(bucket[cursor])
                addedAny = true
                if result.count == count { break }
            }
            if !addedAny { break }
            cursor += 1
        }

        // Shortfall: top up from the full catalog.
        if result.count < count {
            var fallback = pool(from: catalog, theme: "all", allowedLevels: nil)
            shuffle(&fallback, using: &generator)
            for q in fallback where result.count < count {
                if used.insert(q.id).inserted { result.append(q) }
            }
        }
        return result
    }

    /// General-culture question pool (disciplines with kind == .generale),
    /// excluding any discipline ids in `exclude` (so a chosen generale theme
    /// isn't duplicated in the basique bucket).
    private static func basiquePool(
        from catalog: ContentCatalog,
        excluding exclude: [String],
        allowedLevels: Set<DifficultyLevel>?
    ) -> [Question] {
        var result: [Question] = []
        let excludeSet = Set(exclude)
        for discipline in catalog.disciplines {
            guard discipline.resolvedKind == .generale, !excludeSet.contains(discipline.id) else { continue }
            for chapter in discipline.chapters {
                if let levels = chapter.levels, let allowedLevels {
                    for level in DifficultyLevel.allCases where allowedLevels.contains(level) {
                        for question in levels[level.rawValue]?.questions ?? [] where question.type != .anagram {
                            result.append(question)
                        }
                    }
                } else {
                    for question in chapter.allQuestions where question.type != .anagram {
                        result.append(question)
                    }
                }
            }
        }
        result.sort { $0.id < $1.id }
        return result
    }

    /// Legacy single-theme entry point (kept for training/bot flows).
    static func questions(from catalog: ContentCatalog, seed: String, count: Int, disciplineId: String?) -> [Question] {
        questions(from: catalog, seed: seed, count: count, themes: disciplineId.map { [$0] })
    }

    // MARK: internals

    /// Sorted, deduped theme list; nil/empty input means "all themes".
    private static func normalizedThemes(_ raw: [String]?) -> [String] {
        let cleaned = (raw ?? []).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return ["all"] }
        var seen = Set<String>()
        return cleaned.sorted().filter { seen.insert($0).inserted }
    }

    /// Difficulty band matching the players' shared ELO.
    private static func allowedLevels(forElo elo: Int) -> Set<DifficultyLevel> {
        switch elo {
        case ..<1100: return [.facile, .intermediaire]
        case ..<1400: return [.facile, .intermediaire, .difficile]
        case ..<1800: return [.intermediaire, .difficile, .maitre]
        default: return [.difficile, .maitre, .legende]
        }
    }

    /// Non-anagram question pool for one theme, sorted by id for determinism.
    /// Legacy flat chapters (no levels) always contribute all their questions.
    private static func pool(
        from catalog: ContentCatalog,
        theme: String,
        allowedLevels: Set<DifficultyLevel>?
    ) -> [Question] {
        var result: [Question] = []
        for discipline in catalog.disciplines {
            if theme != "all" && discipline.id != theme { continue }
            for chapter in discipline.chapters {
                if let levels = chapter.levels, let allowedLevels {
                    for level in DifficultyLevel.allCases where allowedLevels.contains(level) {
                        for question in levels[level.rawValue]?.questions ?? [] where question.type != .anagram {
                            result.append(question)
                        }
                    }
                } else {
                    for question in chapter.allQuestions where question.type != .anagram {
                        result.append(question)
                    }
                }
            }
        }
        result.sort { $0.id < $1.id }
        return result
    }

    /// Manual Fisher-Yates for a stable algorithm across runtimes.
    private static func shuffle(_ items: inout [Question], using generator: inout SeededGenerator) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, through: 1, by: -1) {
            let j = Int(generator.next() % UInt64(i + 1))
            items.swapAt(i, j)
        }
    }
}
