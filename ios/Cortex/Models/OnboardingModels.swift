import Foundation

/// Single-select motivation shown on the "goal" onboarding step.
nonisolated enum LearningGoal: String, Codable, CaseIterable, Identifiable {
    case curiosity
    case learn
    case shareFacts
    case lessScrolling
    case dailyHabit

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .curiosity: return "👀"
        case .learn: return "📚"
        case .shareFacts: return "🗣️"
        case .lessScrolling: return "📵"
        case .dailyHabit: return "🗓️"
        }
    }

    var label: String {
        switch self {
        case .curiosity: return "Nourrir ma curiosité"
        case .learn: return "Apprendre de nouvelles choses"
        case .shareFacts: return "Avoir toujours un fait cool à partager"
        case .lessScrolling: return "Passer moins de temps à scroller"
        case .dailyHabit: return "Ancrer l'apprentissage dans mon quotidien"
        }
    }
}

/// Self-assessed level of general knowledge, used to tune difficulty.
nonisolated enum PerceivedLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case expert

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .beginner: return "🌱"
        case .intermediate: return "🌿"
        case .expert: return "🌳"
        }
    }

    var label: String {
        switch self {
        case .beginner: return "Débutant"
        case .intermediate: return "Moyen"
        case .expert: return "Expert"
        }
    }
}

/// Preferred moment of the day to learn. Drives the daily notification timing.
nonisolated enum PreferredLearningTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case pause
    case evening

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .morning: return "☕️"
        case .pause: return "🥪"
        case .evening: return "🌙"
        }
    }

    var label: String {
        switch self {
        case .morning: return "Le matin"
        case .pause: return "Pendant une pause"
        case .evening: return "Le soir"
        }
    }

    /// Suggested notification hour for this moment (24h format).
    var suggestedHour: Int {
        switch self {
        case .morning: return 8
        case .pause: return 14
        case .evening: return 20
        }
    }
}

/// Daily screen time bracket, self-reported during onboarding to build an
/// honest, non-invented projection of cumulative time.
nonisolated enum ScreenTimeBracket: String, Codable, CaseIterable, Identifiable {
    case under2
    case between2and4
    case between4and6
    case between6and8
    case over8

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under2: return "Moins de 2h"
        case .between2and4: return "2h - 4h"
        case .between4and6: return "4h - 6h"
        case .between6and8: return "6h - 8h"
        case .over8: return "Plus de 8h"
        }
    }

    /// Midpoint of the bracket, used only to project the user's own answer
    /// forward — never an invented marketing statistic.
    var averageHours: Double {
        switch self {
        case .under2: return 1.5
        case .between2and4: return 3
        case .between4and6: return 5
        case .between6and8: return 7
        case .over8: return 9
        }
    }

    /// Years of a typical 70-year lifespan spent on screens at this daily pace.
    var lifetimeYears: Double {
        (averageHours * 365 * 70) / (24 * 365)
    }
}

/// Answers collected during onboarding, persisted locally and reused to
/// personalize the home screen, difficulty, and reminders.
nonisolated struct OnboardingPreferences: Codable {
    var nickname: String
    var goal: LearningGoal?
    var topicIds: [String]
    var dailyGoal: Int
    var perceivedLevel: PerceivedLevel?
    var preferredLearningTime: PreferredLearningTime?
    var screenTimeBracket: ScreenTimeBracket?
    var quizScore: Int?
    var commitmentText: String?
    var signedAt: Date?
    var diagnostic: OnboardingDiagnostic?

    static let initial = OnboardingPreferences(
        nickname: "",
        goal: nil,
        topicIds: [],
        dailyGoal: 3,
        perceivedLevel: nil,
        preferredLearningTime: nil,
        screenTimeBracket: nil,
        quizScore: nil,
        commitmentText: nil,
        signedAt: nil,
        diagnostic: nil
    )

    private enum CodingKeys: String, CodingKey {
        case nickname, goal, topicIds, dailyGoal, perceivedLevel, preferredLearningTime
        case screenTimeBracket, quizScore, commitmentText, signedAt, diagnostic
    }

    init(
        nickname: String,
        goal: LearningGoal?,
        topicIds: [String],
        dailyGoal: Int,
        perceivedLevel: PerceivedLevel?,
        preferredLearningTime: PreferredLearningTime?,
        screenTimeBracket: ScreenTimeBracket?,
        quizScore: Int?,
        commitmentText: String?,
        signedAt: Date?,
        diagnostic: OnboardingDiagnostic? = nil
    ) {
        self.nickname = nickname
        self.goal = goal
        self.topicIds = topicIds
        self.dailyGoal = dailyGoal
        self.perceivedLevel = perceivedLevel
        self.preferredLearningTime = preferredLearningTime
        self.screenTimeBracket = screenTimeBracket
        self.quizScore = quizScore
        self.commitmentText = commitmentText
        self.signedAt = signedAt
        self.diagnostic = diagnostic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try c.decode(String.self, forKey: .nickname)
        goal = try c.decodeIfPresent(LearningGoal.self, forKey: .goal)
        topicIds = try c.decode([String].self, forKey: .topicIds)
        dailyGoal = try c.decode(Int.self, forKey: .dailyGoal)
        perceivedLevel = try c.decodeIfPresent(PerceivedLevel.self, forKey: .perceivedLevel)
        preferredLearningTime = try c.decodeIfPresent(PreferredLearningTime.self, forKey: .preferredLearningTime)
        screenTimeBracket = try c.decodeIfPresent(ScreenTimeBracket.self, forKey: .screenTimeBracket)
        quizScore = try c.decodeIfPresent(Int.self, forKey: .quizScore)
        commitmentText = try c.decodeIfPresent(String.self, forKey: .commitmentText)
        signedAt = try c.decodeIfPresent(Date.self, forKey: .signedAt)
        diagnostic = try c.decodeIfPresent(OnboardingDiagnostic.self, forKey: .diagnostic)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nickname, forKey: .nickname)
        try c.encodeIfPresent(goal, forKey: .goal)
        try c.encode(topicIds, forKey: .topicIds)
        try c.encode(dailyGoal, forKey: .dailyGoal)
        try c.encodeIfPresent(perceivedLevel, forKey: .perceivedLevel)
        try c.encodeIfPresent(preferredLearningTime, forKey: .preferredLearningTime)
        try c.encodeIfPresent(screenTimeBracket, forKey: .screenTimeBracket)
        try c.encodeIfPresent(quizScore, forKey: .quizScore)
        try c.encodeIfPresent(commitmentText, forKey: .commitmentText)
        try c.encodeIfPresent(signedAt, forKey: .signedAt)
        try c.encodeIfPresent(diagnostic, forKey: .diagnostic)
    }
}
