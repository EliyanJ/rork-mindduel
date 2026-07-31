import Foundation

/// Turns the flat question list of a sub-chapter into the ordered rings
/// ("ronds") shown on the learning path.
///
/// Difficulty ramps up **continuously**: questions are sorted by difficulty
/// bucket first, then by how well-known the fact is (`familiarity`). Chunking
/// that ordered list into fixed-size rings means an individual ring can hold
/// the tail of one tier and the head of the next, which smooths the curve
/// instead of jumping between levels.
nonisolated enum RingBuilder {
    /// Questions per ring.
    static let ringSize = 15
    /// A trailing chunk smaller than this is merged into the previous ring
    /// rather than becoming a frustratingly short ring of its own.
    static let minTrailingRing = 6

    // MARK: - Ordering

    /// Sort key placing the easiest, most widely-known questions first.
    private static func difficultyRank(_ question: Question, levelIndex: Int) -> (Int, Int) {
        (levelIndex, RingTier.rank(of: question.familiarity))
    }

    /// All questions of a chapter, ordered from easiest to hardest.
    static func orderedQuestions(of chapter: Chapter) -> [Question] {
        var ranked: [(question: Question, key: (Int, Int), offset: Int)] = []
        var offset = 0
        for (levelIndex, level) in DifficultyLevel.allCases.enumerated() {
            for question in chapter.questionsAtLevel(level) {
                ranked.append((question, difficultyRank(question, levelIndex: levelIndex), offset))
                offset += 1
            }
        }
        // Stable sort: equal difficulty keeps the authored order.
        return ranked.sorted { lhs, rhs in
            if lhs.key.0 != rhs.key.0 { return lhs.key.0 < rhs.key.0 }
            if lhs.key.1 != rhs.key.1 { return lhs.key.1 < rhs.key.1 }
            return lhs.offset < rhs.offset
        }.map(\.question)
    }

    /// Chapter questions ordered hardest-first — the recap ring's candidate pool.
    static func hardestFirstQuestions(of chapter: Chapter) -> [Question] {
        orderedQuestions(of: chapter).reversed()
    }

    // MARK: - Ring construction

    /// Splits the ordered questions of a chapter into fixed-size groups.
    private static func chunk(_ questions: [Question]) -> [[Question]] {
        guard !questions.isEmpty else { return [] }
        var chunks: [[Question]] = []
        var start = 0
        while start < questions.count {
            let end = min(start + ringSize, questions.count)
            chunks.append(Array(questions[start..<end]))
            start = end
        }
        if let last = chunks.last, last.count < minTrailingRing, chunks.count >= 2 {
            chunks[chunks.count - 2].append(contentsOf: last)
            chunks.removeLast()
        }
        return chunks
    }

    private static func tier(of questions: [Question]) -> RingTier {
        guard !questions.isEmpty else { return .decouverte }
        let total = questions.reduce(0) { $0 + RingTier.rank(of: $1.familiarity) }
        return RingTier.from(averageRank: Double(total) / Double(questions.count))
    }

    /// Default timeline for a chapter: every normal ring in ramp order,
    /// closed by a single recap.
    static func defaultSlots(normalRingCount: Int) -> [RingSlot] {
        var slots = (0..<normalRingCount).map { RingSlot(kind: .normal, source: $0) }
        slots.append(RingSlot(kind: .recap))
        return slots
    }

    /// Builds the rings of one sub-chapter, honouring an admin-published
    /// timeline when there is one.
    static func rings(
        for chapter: Chapter,
        disciplineId: String,
        slots: [RingSlot]?
    ) -> [PathRing] {
        let ordered = orderedQuestions(of: chapter)
        guard !ordered.isEmpty else { return [] }

        let groups = chunk(ordered)
        let byId = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let recapPool = hardestFirstQuestions(of: chapter)
            .map { LessonItem(question: $0, disciplineId: disciplineId) }

        let timeline = normalizedSlots(
            slots,
            normalRingCount: groups.count,
            knownQuestionIds: Set(byId.keys)
        )
        var rings: [PathRing] = []
        var normalCounter = 0
        var recapCounter = 0

        for (slotIndex, slot) in timeline.enumerated() {
            switch slot.kind {
            case .normal:
                // Explicit timelines pin question ids; auto ones point at a chunk.
                let questions: [Question]
                let ringId: String
                if let ids = slot.questionIds {
                    questions = ids.compactMap { byId[$0] }
                    ringId = "ring-\(chapter.id)-x\(slotIndex)"
                } else if let source = slot.source, groups.indices.contains(source) {
                    questions = groups[source]
                    ringId = "ring-\(chapter.id)-\(source)"
                } else {
                    continue
                }
                // An empty ring is a back-office staging area, never served.
                guard !questions.isEmpty else { continue }
                rings.append(
                    PathRing(
                        id: ringId,
                        disciplineId: disciplineId,
                        chapterId: chapter.id,
                        chapterTitle: chapter.title,
                        indexInChapter: normalCounter,
                        ringsInChapter: timeline.count,
                        kind: .normal,
                        items: questions.map { LessonItem(question: $0, disciplineId: disciplineId) },
                        tier: tier(of: questions)
                    )
                )
                normalCounter += 1
            case .recap:
                // Extra recaps get a suffix so their progress is tracked apart.
                let suffix = recapCounter == 0 ? "" : "-\(recapCounter)"
                rings.append(
                    PathRing(
                        id: "recap-\(chapter.id)\(suffix)",
                        disciplineId: disciplineId,
                        chapterId: chapter.id,
                        chapterTitle: chapter.title,
                        indexInChapter: normalCounter,
                        ringsInChapter: timeline.count,
                        kind: .recap,
                        items: recapPool,
                        tier: .pointu
                    )
                )
                recapCounter += 1
            }
        }
        return rings
    }

    /// Keeps a published timeline safe to use.
    ///
    /// Auto mode: drops slots pointing at rings that no longer exist and
    /// appends normal rings the layout doesn't know about. Explicit mode: drops
    /// ids that no longer exist and files any question missing from every ring
    /// into a new trailing ring — so newly published questions can never become
    /// unreachable. Both guarantee a closing recap.
    private static func normalizedSlots(
        _ slots: [RingSlot]?,
        normalRingCount: Int,
        knownQuestionIds: Set<String>
    ) -> [RingSlot] {
        guard let slots, !slots.isEmpty else {
            return defaultSlots(normalRingCount: normalRingCount)
        }

        if slots.contains(where: { $0.kind == .normal && $0.questionIds != nil }) {
            var seenIds = Set<String>()
            var cleaned: [RingSlot] = []
            for slot in slots {
                guard slot.kind == .normal else {
                    cleaned.append(slot)
                    continue
                }
                let ids = (slot.questionIds ?? []).filter { id in
                    guard knownQuestionIds.contains(id), !seenIds.contains(id) else { return false }
                    seenIds.insert(id)
                    return true
                }
                cleaned.append(RingSlot(kind: .normal, questionIds: ids, targetLevel: slot.targetLevel))
            }
            // A question in no ring at all would be unreachable — file it in.
            let orphans = knownQuestionIds.subtracting(seenIds)
            if !orphans.isEmpty {
                let insertAt = cleaned.lastIndex { $0.kind == .recap } ?? cleaned.count
                cleaned.insert(RingSlot(kind: .normal, questionIds: orphans.sorted()), at: insertAt)
            }
            if !cleaned.contains(where: { $0.kind == .recap }) {
                cleaned.append(RingSlot(kind: .recap))
            }
            return cleaned
        }

        var seen = Set<Int>()
        var cleaned: [RingSlot] = []
        for slot in slots {
            switch slot.kind {
            case .normal:
                guard let source = slot.source,
                      source >= 0, source < normalRingCount,
                      !seen.contains(source) else { continue }
                seen.insert(source)
                cleaned.append(slot)
            case .recap:
                cleaned.append(slot)
            }
        }
        // Any newly-generated ring the layout predates goes before the last recap.
        let missing = (0..<normalRingCount).filter { !seen.contains($0) }
        if !missing.isEmpty {
            let insertAt = cleaned.lastIndex { $0.kind == .recap } ?? cleaned.count
            cleaned.insert(contentsOf: missing.map { RingSlot(kind: .normal, source: $0) }, at: insertAt)
        }
        if !cleaned.contains(where: { $0.kind == .recap }) {
            cleaned.append(RingSlot(kind: .recap))
        }
        return cleaned
    }
}
