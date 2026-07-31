import Foundation

/// What a ring on the learning path represents.
nonisolated enum RingKind: String, Codable, Hashable {
    /// A regular 15-question ring.
    case normal
    /// The end-of-chapter "boss": personalised recap of the whole sub-chapter.
    case recap
}

/// One circle ("rond") on the learning path.
///
/// A sub-chapter is split into several rings of `RingBuilder.ringSize` questions
/// whose difficulty ramps up, closed by a `recap` ring that gates the next
/// sub-chapter. Ring identity is stable across the themed and the mixed paths,
/// so clearing a ring in one path also clears it in the other.
nonisolated struct PathRing: Identifiable, Hashable {
    let id: String
    let disciplineId: String
    let chapterId: String
    let chapterTitle: String
    /// 0-based position of this ring inside its own sub-chapter.
    let indexInChapter: Int
    /// How many rings the sub-chapter holds in total (recap included).
    let ringsInChapter: Int
    let kind: RingKind
    /// Questions to play. For a recap ring this is the *candidate pool*
    /// (whole sub-chapter, hardest first) — the final 15 are picked per player
    /// at launch time by `AppModel.playableItems(for:)`.
    let items: [LessonItem]
    /// Average familiarity of the ring, driving its label and colour ramp.
    let tier: RingTier

    /// Short label shown under the circle, e.g. "Rond 2".
    var shortTitle: String {
        kind == .recap ? "Récap" : "Rond \(indexInChapter + 1)"
    }

    /// Full label used by the lesson header.
    var lessonTitle: String {
        kind == .recap
            ? "\(chapterTitle) · Récap"
            : "\(chapterTitle) · Rond \(indexInChapter + 1)"
    }
}

/// Difficulty band of a ring, derived from the familiarity of its questions.
/// This is what makes the path ramp up smoothly instead of jumping tiers.
nonisolated enum RingTier: Int, Codable, Hashable, CaseIterable {
    case decouverte = 0
    case solide = 1
    case pointu = 2

    var label: String {
        switch self {
        case .decouverte: return "Découverte"
        case .solide: return "Solide"
        case .pointu: return "Pointu"
        }
    }

    /// Rank of a familiarity level on the easy → hard axis.
    static func rank(of familiarity: Familiarity?) -> Int {
        switch familiarity {
        case .commun: return 0
        case .moyen: return 1
        case .pointu: return 2
        case nil: return 1
        }
    }

    /// Band a ring falls into, given the average familiarity rank of its questions.
    static func from(averageRank: Double) -> RingTier {
        switch averageRank {
        case ..<0.67: return .decouverte
        case ..<1.34: return .solide
        default: return .pointu
        }
    }
}
