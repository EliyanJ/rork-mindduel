import Foundation

nonisolated enum QuestionType: String, Codable {
    case multipleChoice
    case trueFalse
    case fillBlank
    case anagram

    var label: String {
        switch self {
        case .multipleChoice: return "QCM"
        case .trueFalse: return "Vrai ou Faux"
        case .fillBlank: return "Texte à trou"
        case .anagram: return "Anagramme"
        }
    }
}

/// How well-known a fact is. Lets a level stay coherent for its audience
/// (e.g. "facile" never surprises a casual player with an expert-only fact)
/// and can be surfaced in the UI so players understand why a question felt easy or tricky.
nonisolated enum Familiarity: String, Codable {
    case commun
    case moyen
    case pointu

    var label: String {
        switch self {
        case .commun: return "Connu de tous"
        case .moyen: return "Culture moyenne"
        case .pointu: return "Pointu"
        }
    }

    var icon: String {
        switch self {
        case .commun: return "person.2.fill"
        case .moyen: return "person.fill.checkmark"
        case .pointu: return "sparkles"
        }
    }
}

nonisolated struct Question: Codable, Identifiable, Hashable {
    let id: String
    let type: QuestionType
    let prompt: String
    let options: [String]?
    let answer: String
    let explanation: String
    /// Optional for backward-compat with older content.json entries generated before this field existed.
    let familiarity: Familiarity?

    private enum CodingKeys: String, CodingKey {
        case id, type, prompt, options, answer, explanation, familiarity
    }
}

/// Five difficulty levels per chapter, unlocked progressively.
nonisolated enum DifficultyLevel: String, Codable, CaseIterable {
    case facile
    case intermediaire
    case difficile
    case maitre
    case legende

    var displayName: String {
        switch self {
        case .facile: return "Facile"
        case .intermediaire: return "Intermédiaire"
        case .difficile: return "Difficile"
        case .maitre: return "Maître"
        case .legende: return "Légende"
        }
    }

    var shortLabel: String {
        switch self {
        case .facile: return "F"
        case .intermediaire: return "I"
        case .difficile: return "D"
        case .maitre: return "M"
        case .legende: return "L"
        }
    }

    var idLetter: String {
        switch self {
        case .facile: return "f"
        case .intermediaire: return "i"
        case .difficile: return "d"
        case .maitre: return "m"
        case .legende: return "l"
        }
    }

    var requiredChaptersToUnlock: Int { 5 }

    var previous: DifficultyLevel? {
        switch self {
        case .facile: return nil
        case .intermediaire: return .facile
        case .difficile: return .intermediaire
        case .maitre: return .difficile
        case .legende: return .maitre
        }
    }

    var next: DifficultyLevel? {
        switch self {
        case .facile: return .intermediaire
        case .intermediaire: return .difficile
        case .difficile: return .maitre
        case .maitre: return .legende
        case .legende: return nil
        }
    }
}

/// A difficulty level within a chapter, containing its own question set.
nonisolated struct ChapterLevel: Codable, Hashable {
    let questions: [Question]
}

/// A chapter supports two formats:
/// - **Legacy (v1):** a flat `questions` array
/// - **Multi-level (v2):** a `levels` dictionary keyed by difficulty name
/// The custom Codable handles both transparently.
nonisolated struct Chapter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let levels: [String: ChapterLevel]?
    let questions: [Question]?

    var hasLevels: Bool { levels != nil }

    /// Questions for a specific difficulty level, or all questions if the
    /// chapter uses the legacy flat format.
    func questionsAtLevel(_ level: DifficultyLevel) -> [Question] {
        if let levels {
            return levels[level.rawValue]?.questions ?? []
        }
        return questions ?? []
    }

    /// All questions across every level (or the flat array for legacy chapters).
    var allQuestions: [Question] {
        if let levels {
            return DifficultyLevel.allCases.flatMap { levels[$0.rawValue]?.questions ?? [] }
        }
        return questions ?? []
    }

    /// Total question count regardless of format.
    var questionCount: Int { allQuestions.count }

    /// Available difficulty levels for this chapter (non-empty levels only),
    /// or `[.facile]` for legacy chapters.
    var availableLevels: [DifficultyLevel] {
        if let levels {
            return DifficultyLevel.allCases.filter { levels[$0.rawValue]?.questions.isEmpty == false }
        }
        return [.facile]
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, levels, questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        levels = try container.decodeIfPresent([String: ChapterLevel].self, forKey: .levels)
        questions = try container.decodeIfPresent([Question].self, forKey: .questions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if let levels {
            try container.encode(levels, forKey: .levels)
        } else if let questions {
            try container.encode(questions, forKey: .questions)
        }
    }

    init(id: String, title: String, levels: [String: ChapterLevel]? = nil, questions: [Question]? = nil) {
        self.id = id
        self.title = title
        self.levels = levels
        self.questions = questions
    }
}

/// Whether a discipline is general culture or a specific domain (e.g. football).
/// Used by matchmaking and the diagnostic to weight theme selection.
nonisolated enum DisciplineKind: String, Codable {
    case generale
    case specifique
}

nonisolated struct Discipline: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let chapters: [Chapter]
    /// General culture (histoire, sciences, ...) vs specific domain (football).
    /// Optional for backward-compat with older catalogs that predate this field.
    let kind: DisciplineKind?

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, chapters, kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        kind = try container.decodeIfPresent(DisciplineKind.self, forKey: .kind)
    }

    /// Convenience accessor defaulting to general culture when the field is missing.
    var resolvedKind: DisciplineKind { kind ?? .generale }
}

nonisolated struct ContentCatalog: Codable {
    let disciplines: [Discipline]
}
