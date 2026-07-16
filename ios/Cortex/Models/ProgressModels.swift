import Foundation

nonisolated struct ChapterRecord: Codable {
    var bestScore: Double
    var attempts: Int
}

/// Per-level progress for a chapter, tracking partial session completion
/// so a player can resume the second half of a 20-question chapter/level.
nonisolated struct ChapterProgress: Codable {
    let disciplineId: String
    let chapterId: String
    let level: String
    var sessionsDone: Int
    var totalCorrect: Int
    var totalAnswered: Int
    var isCompleted: Bool
    var questionsSeenIds: [String]
    var bestScore: Double

    var currentScore: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }

    var passed: Bool {
        isCompleted && currentScore >= 0.80
    }

    static func empty(disciplineId: String, chapterId: String, level: String) -> ChapterProgress {
        ChapterProgress(
            disciplineId: disciplineId,
            chapterId: chapterId,
            level: level,
            sessionsDone: 0,
            totalCorrect: 0,
            totalAnswered: 0,
            isCompleted: false,
            questionsSeenIds: [],
            bestScore: 0
        )
    }
}

/// Spaced-repetition tracking for a single question.
/// Uses an ease-factor algorithm (inspired by SM-2) so well-mastered cards
/// space out progressively instead of capping at a fixed interval.
nonisolated struct ReviewItem: Codable {
    let questionId: String
    let disciplineId: String
    var intervalDays: Int
    var dueDate: Date
    var strength: Double
    var lapses: Int

    // Ease-factor fields (added in v2). Defaults ensure backward-compatible
    // decoding of ReviewItems saved before these fields existed.
    var easeFactor: Double
    var consecutiveCorrect: Int

    private enum CodingKeys: String, CodingKey {
        case questionId, disciplineId, intervalDays, dueDate, strength, lapses
        case easeFactor, consecutiveCorrect
    }

    init(
        questionId: String,
        disciplineId: String,
        intervalDays: Int,
        dueDate: Date,
        strength: Double,
        lapses: Int,
        easeFactor: Double = 2.5,
        consecutiveCorrect: Int = 0
    ) {
        self.questionId = questionId
        self.disciplineId = disciplineId
        self.intervalDays = intervalDays
        self.dueDate = dueDate
        self.strength = strength
        self.lapses = lapses
        self.easeFactor = easeFactor
        self.consecutiveCorrect = consecutiveCorrect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try c.decode(String.self, forKey: .questionId)
        disciplineId = try c.decode(String.self, forKey: .disciplineId)
        intervalDays = try c.decode(Int.self, forKey: .intervalDays)
        dueDate = try c.decode(Date.self, forKey: .dueDate)
        strength = try c.decode(Double.self, forKey: .strength)
        lapses = try c.decode(Int.self, forKey: .lapses)
        easeFactor = try c.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        consecutiveCorrect = try c.decodeIfPresent(Int.self, forKey: .consecutiveCorrect) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(questionId, forKey: .questionId)
        try c.encode(disciplineId, forKey: .disciplineId)
        try c.encode(intervalDays, forKey: .intervalDays)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(strength, forKey: .strength)
        try c.encode(lapses, forKey: .lapses)
        try c.encode(easeFactor, forKey: .easeFactor)
        try c.encode(consecutiveCorrect, forKey: .consecutiveCorrect)
    }
}

/// Resets every calendar day: tracks free-quota consumption for lessons and
/// reviews, plus livres-based unlocks and rewarded-ad usage for that day.
nonisolated struct DailyUsage: Codable {
    var day: Date
    var lessonsCompleted: Int
    var extraLessonsUnlocked: Int
    var reviewCardsUsed: Int
    var extraReviewCardsUnlocked: Int
    var rewardedAdsWatched: Int

    static func empty(day: Date) -> DailyUsage {
        DailyUsage(
            day: day,
            lessonsCompleted: 0,
            extraLessonsUnlocked: 0,
            reviewCardsUsed: 0,
            extraReviewCardsUnlocked: 0,
            rewardedAdsWatched: 0
        )
    }
}

nonisolated struct UserProgress: Codable {
    var xp: Int
    var streak: Int
    var lastActiveDay: Date?
    var activeDays: [Date]
    var chapterRecords: [String: ChapterRecord]
    var reviewItems: [String: ReviewItem]
    var elo: Int
    var duelsPlayed: Int
    var duelsWon: Int

    // MARK: - Monetization (livres economy)
    var livresBalance: Int
    var lastLivreAwardDay: Date?
    var dailyUsage: DailyUsage
    var duelsSinceLastAd: Int
    var botMatchesSinceLastAd: Int

    // MARK: - Multi-level progression (v2)
    /// Key: "disciplineId_chapterId_level" → ChapterProgress
    var chapterProgress: [String: ChapterProgress]

    static let initial = UserProgress(
        xp: 0,
        streak: 0,
        lastActiveDay: nil,
        activeDays: [],
        chapterRecords: [:],
        reviewItems: [:],
        elo: 1000,
        duelsPlayed: 0,
        duelsWon: 0,
        livresBalance: 0,
        lastLivreAwardDay: nil,
        dailyUsage: .empty(day: Calendar.current.startOfDay(for: .now)),
        duelsSinceLastAd: 0,
        botMatchesSinceLastAd: 0,
        chapterProgress: [:]
    )

    private enum CodingKeys: String, CodingKey {
        case xp, streak, lastActiveDay, activeDays, chapterRecords, reviewItems, elo, duelsPlayed, duelsWon
        case livresBalance, lastLivreAwardDay, dailyUsage, duelsSinceLastAd, botMatchesSinceLastAd
        case chapterProgress
    }

    init(
        xp: Int,
        streak: Int,
        lastActiveDay: Date?,
        activeDays: [Date],
        chapterRecords: [String: ChapterRecord],
        reviewItems: [String: ReviewItem],
        elo: Int,
        duelsPlayed: Int,
        duelsWon: Int,
        livresBalance: Int,
        lastLivreAwardDay: Date?,
        dailyUsage: DailyUsage,
        duelsSinceLastAd: Int,
        botMatchesSinceLastAd: Int,
        chapterProgress: [String: ChapterProgress]
    ) {
        self.xp = xp
        self.streak = streak
        self.lastActiveDay = lastActiveDay
        self.activeDays = activeDays
        self.chapterRecords = chapterRecords
        self.reviewItems = reviewItems
        self.elo = elo
        self.duelsPlayed = duelsPlayed
        self.duelsWon = duelsWon
        self.livresBalance = livresBalance
        self.lastLivreAwardDay = lastLivreAwardDay
        self.dailyUsage = dailyUsage
        self.duelsSinceLastAd = duelsSinceLastAd
        self.botMatchesSinceLastAd = botMatchesSinceLastAd
        self.chapterProgress = chapterProgress
    }

    /// Custom decoding keeps older saved profiles loading fine — missing
    /// fields fall back to defaults instead of failing the whole decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        xp = try container.decode(Int.self, forKey: .xp)
        streak = try container.decode(Int.self, forKey: .streak)
        lastActiveDay = try container.decodeIfPresent(Date.self, forKey: .lastActiveDay)
        activeDays = try container.decode([Date].self, forKey: .activeDays)
        chapterRecords = try container.decode([String: ChapterRecord].self, forKey: .chapterRecords)
        reviewItems = try container.decode([String: ReviewItem].self, forKey: .reviewItems)
        elo = try container.decode(Int.self, forKey: .elo)
        duelsPlayed = try container.decode(Int.self, forKey: .duelsPlayed)
        duelsWon = try container.decode(Int.self, forKey: .duelsWon)
        livresBalance = try container.decodeIfPresent(Int.self, forKey: .livresBalance) ?? 0
        lastLivreAwardDay = try container.decodeIfPresent(Date.self, forKey: .lastLivreAwardDay)
        dailyUsage = try container.decodeIfPresent(DailyUsage.self, forKey: .dailyUsage)
            ?? .empty(day: Calendar.current.startOfDay(for: .now))
        duelsSinceLastAd = try container.decodeIfPresent(Int.self, forKey: .duelsSinceLastAd) ?? 0
        botMatchesSinceLastAd = try container.decodeIfPresent(Int.self, forKey: .botMatchesSinceLastAd) ?? 0
        chapterProgress = try container.decodeIfPresent([String: ChapterProgress].self, forKey: .chapterProgress) ?? [:]
    }
}
