import Foundation
import Observation

/// Persists user progress (XP, streak, chapter mastery, spaced repetition, ELO)
/// and implements the spaced-repetition scheduling logic.
@Observable
final class ProgressStore {
    private static let storageKey = "cortex.progress.v1"

    // MARK: - Livres economy tuning
    static let freeLessonDailyLimit = 1
    static let premiumLessonDailyLimit = 4
    static let freeReviewDailyCap = 10
    static let extraReviewGrant = 5
    static let extraReviewCost = 5
    static let extraLessonCost = 10
    static let rewardedAdLivres = 2
    static let rewardedAdDailyCap = 20
    static let streakLivreReward = 1
    static let rankedDuelAdInterval = 2
    static let botMatchAdInterval = 3

    // MARK: - Spaced repetition (ease-factor / SM-2 inspired)
    private static let easeDefault: Double = 2.5
    private static let easeMin: Double = 1.3
    private static let easeMax: Double = 2.8
    private static let easeDeltaCorrect: Double = 0.1
    private static let easeDeltaWrong: Double = 0.2
    private static let firstIntervalDays: Int = 1
    private static let secondIntervalDays: Int = 6
    private static let intervalCapDays: Int = 180
    private static let strengthDeltaCorrect: Double = 0.25
    private static let strengthDeltaWrong: Double = 0.3
    private static let strengthMin: Double = 0.05
    private static let strengthMax: Double = 1.0

    private(set) var progress: UserProgress

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(UserProgress.self, from: data) {
            progress = saved
            migrateReviewItemsIfNeeded()
        } else {
            progress = .initial
        }
    }

    /// One-time migration: reconstruct easeFactor and consecutiveCorrect for
    /// ReviewItems saved before the ease-factor algorithm was introduced.
    /// Old items have intervalDays set by the doubling system but no
    /// consecutiveCorrect — we infer it from the existing interval.
    /// intervalDays and dueDate are preserved so the next correct answer
    /// resumes from the current interval × easeFactor, not from zero.
    private func migrateReviewItemsIfNeeded() {
        var migrated = false
        for (key, var item) in progress.reviewItems {
            guard item.consecutiveCorrect == 0, item.intervalDays > 0 else { continue }
            item.easeFactor = Self.easeDefault
            switch item.intervalDays {
            case 0: item.consecutiveCorrect = 0
            case 1...3: item.consecutiveCorrect = 1
            case 4...7: item.consecutiveCorrect = 2
            default: item.consecutiveCorrect = 3
            }
            progress.reviewItems[key] = item
            migrated = true
        }
        if migrated { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Streak shown in the UI: falls back to 0 when a day has been skipped.
    var currentStreak: Int {
        guard let last = progress.lastActiveDay else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        return days <= 1 ? progress.streak : 0
    }

    func registerActivity(on date: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        if let last = progress.lastActiveDay {
            let lastDay = calendar.startOfDay(for: last)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                progress.streak += 1
            } else if diff > 1 {
                progress.streak = 1
            }
        } else {
            progress.streak = 1
        }
        progress.lastActiveDay = today
        if !progress.activeDays.contains(today) {
            progress.activeDays.append(today)
        }
        if progress.streak > 0, progress.lastLivreAwardDay != today {
            progress.livresBalance += Self.streakLivreReward
            progress.lastLivreAwardDay = today
        }
        save()
    }

    // MARK: - Daily rollover

    /// Livres/quotas are tracked per calendar day; roll them over transparently
    /// whenever they're read or written on a new day.
    private func rolloverIfNeeded(reference: Date = .now) {
        let today = Calendar.current.startOfDay(for: reference)
        if !Calendar.current.isDate(progress.dailyUsage.day, inSameDayAs: today) {
            progress.dailyUsage = .empty(day: today)
            save()
        }
    }

    var livresBalance: Int { progress.livresBalance }

    /// Credits livres bought via an IAP pack.
    func addLivres(_ amount: Int) {
        guard amount > 0 else { return }
        progress.livresBalance += amount
        save()
    }

    var dailyUsage: DailyUsage {
        rolloverIfNeeded()
        return progress.dailyUsage
    }

    // MARK: - Lessons quota

    func lessonDailyLimit(isPremium: Bool) -> Int {
        isPremium ? Self.premiumLessonDailyLimit : Self.freeLessonDailyLimit
    }

    func remainingFreeLessons(isPremium: Bool) -> Int {
        let usage = dailyUsage
        let allowance = lessonDailyLimit(isPremium: isPremium) + usage.extraLessonsUnlocked
        return max(0, allowance - usage.lessonsCompleted)
    }

    func canStartLesson(isPremium: Bool) -> Bool {
        isPremium || remainingFreeLessons(isPremium: false) > 0
    }

    func registerLessonCompleted() {
        rolloverIfNeeded()
        progress.dailyUsage.lessonsCompleted += 1
        save()
    }

    @discardableResult
    func unlockExtraLesson() -> Bool {
        rolloverIfNeeded()
        guard progress.livresBalance >= Self.extraLessonCost else { return false }
        progress.livresBalance -= Self.extraLessonCost
        progress.dailyUsage.extraLessonsUnlocked += 1
        save()
        return true
    }

    // MARK: - Reviews quota

    func reviewDailyCap() -> Int {
        Self.freeReviewDailyCap + dailyUsage.extraReviewCardsUnlocked
    }

    func remainingFreeReviewCards(isPremium: Bool) -> Int {
        isPremium ? Int.max : max(0, reviewDailyCap() - dailyUsage.reviewCardsUsed)
    }

    func registerReviewCardsUsed(_ count: Int) {
        guard count > 0 else { return }
        rolloverIfNeeded()
        progress.dailyUsage.reviewCardsUsed += count
        save()
    }

    @discardableResult
    func unlockExtraReviewCards() -> Bool {
        rolloverIfNeeded()
        guard progress.livresBalance >= Self.extraReviewCost else { return false }
        progress.livresBalance -= Self.extraReviewCost
        progress.dailyUsage.extraReviewCardsUnlocked += Self.extraReviewGrant
        save()
        return true
    }

    // MARK: - Rewarded ads

    var rewardedAdsRemainingToday: Int {
        max(0, Self.rewardedAdDailyCap - dailyUsage.rewardedAdsWatched)
    }

    func canWatchRewardedAd() -> Bool { rewardedAdsRemainingToday > 0 }

    func creditRewardedAd() {
        rolloverIfNeeded()
        guard canWatchRewardedAd() else { return }
        progress.dailyUsage.rewardedAdsWatched += 1
        progress.livresBalance += Self.rewardedAdLivres
        save()
    }

    // MARK: - Forced interstitials (duels & training)

    func registerRankedDuelPlayed() {
        progress.duelsSinceLastAd += 1
        save()
    }

    func registerBotMatchPlayed() {
        progress.botMatchesSinceLastAd += 1
        save()
    }

    func shouldShowRankedDuelAd() -> Bool {
        progress.duelsSinceLastAd >= Self.rankedDuelAdInterval
    }

    func shouldShowBotMatchAd() -> Bool {
        progress.botMatchesSinceLastAd >= Self.botMatchAdInterval
    }

    func resetRankedDuelAdCounter() {
        progress.duelsSinceLastAd = 0
        save()
    }

    func resetBotMatchAdCounter() {
        progress.botMatchesSinceLastAd = 0
        save()
    }

    func addXP(_ amount: Int) {
        progress.xp += amount
        save()
    }

    func recordChapterResult(chapterId: String, score: Double) {
        var record = progress.chapterRecords[chapterId] ?? ChapterRecord(bestScore: 0, attempts: 0)
        record.attempts += 1
        record.bestScore = max(record.bestScore, score)
        progress.chapterRecords[chapterId] = record
        save()
    }

    /// Spaced repetition with ease factor (SM-2 inspired).
    /// Correct answers space out: 1 → 6 → interval × easeFactor, capped at 180 days.
    /// Wrong answers reset to due immediately with a lowered ease factor.
    func recordAnswer(questionId: String, disciplineId: String, correct: Bool, date: Date = .now) {
        var item = progress.reviewItems[questionId] ?? ReviewItem(
            questionId: questionId,
            disciplineId: disciplineId,
            intervalDays: 0,
            dueDate: date,
            strength: 0,
            lapses: 0,
            easeFactor: Self.easeDefault,
            consecutiveCorrect: 0
        )
        if correct {
            item.consecutiveCorrect += 1
            switch item.consecutiveCorrect {
            case 1:
                item.intervalDays = Self.firstIntervalDays
            case 2:
                item.intervalDays = Self.secondIntervalDays
            default:
                let projected = Double(item.intervalDays) * item.easeFactor
                item.intervalDays = min(Int(projected.rounded()), Self.intervalCapDays)
            }
            item.easeFactor = min(Self.easeMax, item.easeFactor + Self.easeDeltaCorrect)
            item.strength = min(Self.strengthMax, item.strength + Self.strengthDeltaCorrect)
            item.dueDate = Calendar.current.date(byAdding: .day, value: item.intervalDays, to: date) ?? date
        } else {
            item.consecutiveCorrect = 0
            item.lapses += 1
            item.easeFactor = max(Self.easeMin, item.easeFactor - Self.easeDeltaWrong)
            item.intervalDays = 0
            item.strength = max(Self.strengthMin, item.strength - Self.strengthDeltaWrong)
            item.dueDate = date
        }
        progress.reviewItems[questionId] = item
        save()
    }

    func finalizeDuel(won: Bool, draw: Bool, score: Int, eloChange: Int) {
        progress.duelsPlayed += 1
        if won { progress.duelsWon += 1 }
        progress.elo = max(400, progress.elo + eloChange)
        progress.xp += max(5, score / 10)
        save()
        registerActivity()
    }

    func dueQuestionIds(reference: Date = .now) -> [String] {
        progress.reviewItems.values
            .filter { $0.dueDate <= reference }
            .sorted { $0.dueDate < $1.dueDate }
            .map(\.questionId)
    }

    /// Average retention per discipline, decayed when reviews are overdue.
    func memorizationScore(disciplineId: String, reference: Date = .now) -> Double? {
        let items = progress.reviewItems.values.filter { $0.disciplineId == disciplineId }
        guard !items.isEmpty else { return nil }
        let calendar = Calendar.current
        let total = items.reduce(0.0) { partial, item in
            let overdueDays = max(0, calendar.dateComponents([.day], from: item.dueDate, to: reference).day ?? 0)
            return partial + item.strength * pow(0.85, Double(overdueDays))
        }
        return total / Double(items.count)
    }

    var masteredChaptersCount: Int {
        progress.chapterRecords.values.filter { $0.bestScore >= 0.8 }.count
    }

    // MARK: - Multi-level progression (v2)

    private static func progressKey(disciplineId: String, chapterId: String, level: DifficultyLevel) -> String {
        "\(disciplineId)_\(chapterId)_\(level.rawValue)"
    }

    func chapterProgress(disciplineId: String, chapterId: String, level: DifficultyLevel) -> ChapterProgress? {
        progress.chapterProgress[Self.progressKey(disciplineId: disciplineId, chapterId: chapterId, level: level)]
    }

    func isChapterLevelCompleted(disciplineId: String, chapterId: String, level: DifficultyLevel) -> Bool {
        chapterProgress(disciplineId: disciplineId, chapterId: chapterId, level: level)?.passed ?? false
    }

    func completedChaptersCount(disciplineId: String, level: DifficultyLevel, in discipline: Discipline) -> Int {
        discipline.chapters.filter { chapter in
            isChapterLevelCompleted(disciplineId: disciplineId, chapterId: chapter.id, level: level)
        }.count
    }

    func isLevelUnlocked(_ level: DifficultyLevel, for discipline: Discipline) -> Bool {
        guard let previousLevel = level.previous else { return true }
        return completedChaptersCount(disciplineId: discipline.id, level: previousLevel, in: discipline) >= DifficultyLevel.facile.requiredChaptersToUnlock
    }

    /// Records a partial session result for a chapter/level. The caller
    /// provides the correct count, total answered, and question IDs seen.
    /// If this completes the 20-question chapter (2 sessions of 10), the
    /// result is evaluated against the 80% passing threshold.
    func recordChapterLevelSession(
        disciplineId: String,
        chapterId: String,
        level: DifficultyLevel,
        correct: Int,
        answered: Int,
        seenIds: [String]
    ) {
        let key = Self.progressKey(disciplineId: disciplineId, chapterId: chapterId, level: level)
        var existing = progress.chapterProgress[key] ?? .empty(disciplineId: disciplineId, chapterId: chapterId, level: level.rawValue)
        existing.sessionsDone += 1
        existing.totalCorrect += correct
        existing.totalAnswered += answered
        existing.questionsSeenIds.append(contentsOf: seenIds)

        if existing.totalAnswered >= 20 {
            existing.isCompleted = true
            existing.bestScore = max(existing.bestScore, existing.currentScore)
        }
        progress.chapterProgress[key] = existing
        save()
    }

    /// Resets chapter-level progress so the player can retry from session 1.
    func resetChapterLevelProgress(disciplineId: String, chapterId: String, level: DifficultyLevel) {
        let key = Self.progressKey(disciplineId: disciplineId, chapterId: chapterId, level: level)
        progress.chapterProgress.removeValue(forKey: key)
        save()
    }

    /// Returns the question IDs already seen for a chapter/level so session 2
    /// can avoid repeating them.
    func seenQuestionIds(disciplineId: String, chapterId: String, level: DifficultyLevel) -> [String] {
        chapterProgress(disciplineId: disciplineId, chapterId: chapterId, level: level)?.questionsSeenIds ?? []
    }

    /// Whether the player has done session 1 and needs session 2.
    func needsSecondSession(disciplineId: String, chapterId: String, level: DifficultyLevel) -> Bool {
        guard let cp = chapterProgress(disciplineId: disciplineId, chapterId: chapterId, level: level) else { return false }
        return cp.sessionsDone == 1 && !cp.isCompleted
    }
}
