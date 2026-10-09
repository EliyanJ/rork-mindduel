import Foundation
import Observation

/// Persists user progress (XP, streak, ring mastery, energy, ELO) and holds the
/// per-question mastery data that personalises the recap rings.
@Observable
final class ProgressStore {
    private static let storageKey = "cortex.progress.v1"
    private static let firstLessonReviewPromptKey = "cortex.review.firstLessonPrompted.v1"

    // MARK: - Rubis economy tuning
    static let freeLessonDailyLimit = 2
    static let extraLessonCost = 10
    static let rewardedAdLivres = 2
    static let rewardedAdDailyCap = 20
    static let streakLivreReward = 1
    static let ringRubisReward = 5
    static let recapRubisReward = 10
    /// Duel bolts a free player starts with; each rewarded video adds 2.
    static let duelPointsMax = 3
    /// Free nickname changes before rubis are required (the very first pick
    /// during onboarding doesn't count against this).
    static let freeNicknameChanges = 3
    static let nicknameChangeCost = 50

    // MARK: - Energy (hearts) tuning
    static let energyMax = 3
    static let energyRefillCost = 15

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

    /// Mirrors the Premium entitlement (set by `ContentView`); also lifts the
    /// lesson hearts limit. Not persisted:
    /// RevenueCat stays the only source of truth for access.
    var hasUnlimitedDuels = false

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
            progress.energy = Self.energyMax
            progress.energyRegenAt = nil
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

    /// Generic rubis spend used by cosmetic/utility purchases (nickname
    /// renames, etc). Returns false without side effects when too poor.
    @discardableResult
    func spendLivres(_ amount: Int) -> Bool {
        guard amount >= 0, progress.livresBalance >= amount else { return false }
        progress.livresBalance -= amount
        save()
        return true
    }

    var dailyUsage: DailyUsage {
        rolloverIfNeeded()
        return progress.dailyUsage
    }

    // MARK: - Lessons quota

    /// Free lessons left today (extra ones unlocked with rubis or a video
    /// included). Premium players are never limited.
    func remainingFreeLessons() -> Int {
        let usage = dailyUsage
        let allowance = Self.freeLessonDailyLimit + usage.extraLessonsUnlocked
        return max(0, allowance - usage.lessonsCompleted)
    }

    func canStartLesson(isPremium: Bool) -> Bool {
        isPremium || remainingFreeLessons() > 0
    }

    func registerLessonCompleted() {
        rolloverIfNeeded()
        progress.dailyUsage.lessonsCompleted += 1
        save()
    }

    /// True exactly once, the first time it is called after a lesson
    /// completes — the ideal moment to surface Apple's native "rate the
    /// app" prompt (right after a first small win, never interrupting a
    /// failure or a mid-session moment). Every later call returns false.
    func shouldPromptReviewAfterFirstLesson() -> Bool {
        guard !UserDefaults.standard.bool(forKey: Self.firstLessonReviewPromptKey) else { return false }
        UserDefaults.standard.set(true, forKey: Self.firstLessonReviewPromptKey)
        return true
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

    // MARK: - Energy (hearts)

    /// Hearts left today (3 per day, shared by every lesson). At zero no
    /// lesson can start, even with lesson bolts left.
    var energy: Int {
        rolloverIfNeeded()
        regenEnergyIfNeeded()
        return min(progress.energy, Self.energyMax)
    }

    /// Hearts no longer refill over time: they come back in full at
    /// midnight (see `rolloverIfNeeded`), or sooner with diamonds / a video.
    /// Only clears a stale timer left by older builds.
    private func regenEnergyIfNeeded(reference: Date = .now) {
        guard progress.energyRegenAt != nil, progress.energy >= Self.energyMax else { return }
        progress.energyRegenAt = nil
        save()
    }

    /// Spends one heart (wrong answer in a lesson). Starts the regen timer
    /// when dropping below the cap.
    func consumeEnergy(reference: Date = .now) {
        guard !hasUnlimitedDuels else { return }
        regenEnergyIfNeeded(reference: reference)
        progress.energy = min(progress.energy, Self.energyMax)
        guard progress.energy > 0 else { return }
        if progress.energy == Self.energyMax { progress.energyRegenAt = reference }
        progress.energy -= 1
        save()
    }

    /// Buys a full energy refill with rubis. Returns false when too poor.
    @discardableResult
    func refillEnergyWithRubis() -> Bool {
        regenEnergyIfNeeded()
        guard progress.livresBalance >= Self.energyRefillCost else { return false }
        progress.livresBalance -= Self.energyRefillCost
        progress.energy = Self.energyMax
        progress.energyRegenAt = nil
        save()
        return true
    }

    /// Grants energy for watching a rewarded ad (shares the daily ad cap).
    func grantEnergyFromAd(_ amount: Int = 1) {
        rolloverIfNeeded()
        guard canWatchRewardedAd() else { return }
        regenEnergyIfNeeded()
        progress.dailyUsage.rewardedAdsWatched += 1
        progress.energy = min(Self.energyMax, progress.energy + amount)
        if progress.energy >= Self.energyMax {
            progress.energyRegenAt = nil
        } else if progress.energyRegenAt == nil {
            progress.energyRegenAt = .now
        }
        save()
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

    // MARK: - Duel points (free tier)

    /// Duel bolts left. Starts at `duelPointsMax`; videos stack on top.
    var duelPoints: Int { max(0, progress.duelPoints) }

    /// Duel bolts granted by one rewarded video.
    static let duelPointsPerAd = 2

    /// Whether a new duel may start right now.
    func canStartDuel() -> Bool {
        hasUnlimitedDuels || duelPoints > 0
    }

    /// Spends one point when a duel actually begins. No-op with Premium.
    func consumeDuelPoint() {
        guard !hasUnlimitedDuels, progress.duelPoints > 0 else { return }
        progress.duelPoints -= 1
        save()
    }

    /// Rewarded video: +2 duel bolts (two more duels). Shares the daily
    /// rewarded-ad cap.
    func grantDuelPointsFromAd() {
        rolloverIfNeeded()
        guard canWatchRewardedAd() else { return }
        progress.dailyUsage.rewardedAdsWatched += 1
        progress.duelPoints = max(0, progress.duelPoints) + Self.duelPointsPerAd
        save()
    }

    // MARK: - Free daily ranked match

    /// Free players may play this many ranked matches per day. It cannot be
    /// refilled with videos — only Premium removes the limit.
    static let freeRankedPerDay = 1

    /// Whether a ranked match may start right now.
    func canPlayRanked(isPremium: Bool) -> Bool {
        isPremium || remainingFreeRanked() > 0
    }

    /// Free ranked matches left today.
    func remainingFreeRanked() -> Int {
        max(0, Self.freeRankedPerDay - dailyUsage.rankedPlayed)
    }

    /// Spends today's free ranked match once a real opponent is found.
    func recordRankedStarted() {
        rolloverIfNeeded()
        progress.dailyUsage.rankedPlayed += 1
        save()
    }

    // MARK: - Daily missions

    /// Counts a party or Flash game (they don't go through `finalizeDuel`)
    /// toward today's missions and the lifetime duel stats.
    func recordCasualDuel(won: Bool) {
        rolloverIfNeeded()
        progress.duelsPlayed += 1
        if won { progress.duelsWon += 1 }
        progress.dailyUsage.duelsPlayed += 1
        if won { progress.dailyUsage.duelsWon += 1 }
        save()
        registerActivity()
    }

    func isMissionClaimed(_ id: String) -> Bool {
        dailyUsage.claimedMissionIds.contains(id)
    }

    /// Credits a finished mission's rewards once per day. Returns what was
    /// actually granted (nil when already claimed).
    func claimMission(_ id: String, rewards: [Reward]) -> [Reward]? {
        rolloverIfNeeded()
        guard !progress.dailyUsage.claimedMissionIds.contains(id) else { return nil }
        progress.dailyUsage.claimedMissionIds.append(id)
        save()
        return grant(rewards)
    }

    // MARK: - Rewards

    /// Diamonds given instead of a heart / bolt the player can't use
    /// (hearts already full, or Premium where everything is unlimited).
    static let rewardConversionDiamonds = 5
    /// Small bonus for winning any duel.
    static let duelWinDiamonds = 3

    /// Applies rewards and returns what the player really received, so the
    /// reveal screen never promises something that was silently dropped.
    /// Display-only kinds (`xp`, `rankPoints`) pass through untouched.
    @discardableResult
    func grant(_ rewards: [Reward]) -> [Reward] {
        rolloverIfNeeded()
        var applied: [Reward] = []
        var converted = 0
        for reward in rewards where reward.amount > 0 {
            switch reward.kind {
            case .diamonds:
                progress.livresBalance += reward.amount
                applied.append(reward)
            case .heart:
                let room = hasUnlimitedDuels ? 0 : max(0, Self.energyMax - min(progress.energy, Self.energyMax))
                let added = min(room, reward.amount)
                if added > 0 {
                    progress.energy = min(Self.energyMax, progress.energy + added)
                    if progress.energy >= Self.energyMax { progress.energyRegenAt = nil }
                    applied.append(Reward(kind: .heart, amount: added))
                }
                converted += (reward.amount - added) * Self.rewardConversionDiamonds
            case .duelBolt:
                if hasUnlimitedDuels {
                    converted += reward.amount * Self.rewardConversionDiamonds
                } else {
                    progress.duelPoints = max(0, progress.duelPoints) + reward.amount
                    applied.append(reward)
                }
            case .lessonBolt:
                if hasUnlimitedDuels {
                    converted += reward.amount * Self.rewardConversionDiamonds
                } else {
                    progress.dailyUsage.extraLessonsUnlocked += reward.amount
                    applied.append(reward)
                }
            case .xp, .rankPoints:
                applied.append(reward)
            }
        }
        if converted > 0 {
            progress.livresBalance += converted
            if let index = applied.firstIndex(where: { $0.kind == .diamonds }) {
                applied[index] = Reward(kind: .diamonds, amount: applied[index].amount + converted)
            } else {
                applied.append(Reward(kind: .diamonds, amount: converted))
            }
        }
        save()
        return applied
    }

    /// Bonus for a won duel. `xp` was already credited by the match;
    /// `rankPoints` is shown only for ranked games.
    func grantDuelWin(xp: Int?, rankPoints: Int?) -> [Reward] {
        var display: [Reward] = []
        if let rankPoints, rankPoints > 0 { display.append(Reward(kind: .rankPoints, amount: rankPoints)) }
        if let xp, xp > 0 { display.append(Reward(kind: .xp, amount: xp)) }
        return display + grant([Reward(kind: .diamonds, amount: Self.duelWinDiamonds)])
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

    // MARK: - Placement test ("Avancer ici ?")

    private static let testUnlockedKey = "minduel.testUnlockedChapters.v1"
    /// Score required to skip ahead with a placement test.
    static let placementPassScore: Double = 0.8
    static let placementQuestionCount = 15

    private(set) var testUnlockedChapters: Set<String> = Set(UserDefaults.standard.stringArray(forKey: ProgressStore.testUnlockedKey) ?? [])

    /// Whether a chapter was opened early by passing its placement test.
    func isChapterUnlockedByTest(_ chapterId: String) -> Bool {
        testUnlockedChapters.contains(chapterId)
    }

    func unlockChapterByTest(_ chapterId: String) {
        testUnlockedChapters.insert(chapterId)
        UserDefaults.standard.set(Array(testUnlockedChapters), forKey: Self.testUnlockedKey)
    }

    // MARK: - Ring path ("ronds")

    /// Score a ring must reach to unlock the next one.
    static let ringPassScore: Double = 0.6
    /// Score that marks a ring — and a recap — as fully mastered.
    static let ringMasteryScore: Double = 0.8

    func ringRecord(_ ringId: String) -> ChapterRecord? {
        progress.chapterRecords[ringId]
    }

    /// Whether a ring was cleared well enough to open the next one.
    func isRingPassed(_ ringId: String) -> Bool {
        (progress.chapterRecords[ringId]?.bestScore ?? 0) >= Self.ringPassScore
    }

    func isRingMastered(_ ringId: String) -> Bool {
        (progress.chapterRecords[ringId]?.bestScore ?? 0) >= Self.ringMasteryScore
    }

    /// When a failed recap ring becomes playable again, if it is still locked.
    func ringLockedUntil(_ ringId: String, reference: Date = .now) -> Date? {
        guard let until = progress.chapterRecords[ringId]?.lockedUntil, until > reference else { return nil }
        return until
    }

    /// Records the outcome of a ring. A failed recap locks itself until the
    /// next calendar day so the player revises before retrying, exactly like
    /// the chapter-level cooldown but expressed in days rather than hours.
    /// The first successful pass of a ring awards rubis.
    @discardableResult
    func recordRingResult(ringId: String, kind: RingKind, score: Double, reference: Date = .now) -> Int {
        var diamondsEarned = 0
        var record = progress.chapterRecords[ringId] ?? ChapterRecord(bestScore: 0, attempts: 0)
        record.attempts += 1
        let previousBest = record.bestScore
        record.bestScore = max(previousBest, score)
        let passThreshold = kind == .recap ? Self.ringMasteryScore : Self.ringPassScore
        if previousBest < passThreshold, score >= passThreshold {
            diamondsEarned = kind == .recap ? Self.recapRubisReward : Self.ringRubisReward
            progress.livresBalance += diamondsEarned
        }
        rolloverIfNeeded()
        progress.dailyUsage.ringsCompleted += 1
        if kind == .recap {
            record.lockedUntil = score >= Self.ringMasteryScore ? nil : Self.startOfNextDay(after: reference)
        }
        progress.chapterRecords[ringId] = record
        save()
        return diamondsEarned
    }

    private static func startOfNextDay(after date: Date) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        return calendar.startOfDay(for: tomorrow)
    }

    /// Question ids the player has recently got wrong, hardest lapses first.
    /// Drives the personalised content of a recap ring.
    /// Kept purely as internal mastery data — there is no standalone review
    /// tab anymore, only the recap rings on the path.
    func laspedQuestionIds(among candidates: [String]) -> [String] {
        let candidateSet = Set(candidates)
        return progress.reviewItems.values
            .filter { candidateSet.contains($0.questionId) && $0.lapses > 0 }
            .sorted {
                $0.lapses == $1.lapses ? $0.strength < $1.strength : $0.lapses > $1.lapses
            }
            .map(\.questionId)
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
            rolloverIfNeeded()
            progress.dailyUsage.correctAnswers += 1
        }
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
        rolloverIfNeeded()
        progress.dailyUsage.duelsPlayed += 1
        if won { progress.dailyUsage.duelsWon += 1 }
        progress.elo = max(400, progress.elo + eloChange)
        progress.xp += max(5, score / 10)
        save()
        registerActivity()
    }

    var masteredChaptersCount: Int {
        progress.chapterRecords.values.filter { $0.bestScore >= 0.8 }.count
    }

    // MARK: - Retry cooldown

    /// Time a failed chapter level stays locked before a free retry is available.
    private static let retryCooldownHours: Int = 24

    /// Records that a chapter level was failed and locks free retries until the cooldown passes.
    func markChapterLevelFailed(disciplineId: String, chapterId: String, level: DifficultyLevel) {
        let key = Self.progressKey(disciplineId: disciplineId, chapterId: chapterId, level: level)
        guard var existing = progress.chapterProgress[key] else { return }
        let nextRetry = Calendar.current.date(byAdding: .hour, value: Self.retryCooldownHours, to: .now) ?? .now
        existing.nextRetryAvailableAt = nextRetry
        existing.isCompleted = true
        existing.bestScore = max(existing.bestScore, existing.currentScore)
        progress.chapterProgress[key] = existing
        save()
    }

    /// Whether the player can retry a failed chapter level for free (cooldown elapsed).
    func canRetryFailedChapterLevel(disciplineId: String, chapterId: String, level: DifficultyLevel) -> Bool {
        guard let cp = chapterProgress(disciplineId: disciplineId, chapterId: chapterId, level: level),
              cp.isCompleted, !cp.passed,
              let nextRetry = cp.nextRetryAvailableAt else { return false }
        return .now >= nextRetry
    }

    /// Resets progress if the cooldown has passed, returning true if a reset happened.
    @discardableResult
    func autoResetChapterLevelIfNeeded(disciplineId: String, chapterId: String, level: DifficultyLevel) -> Bool {
        guard canRetryFailedChapterLevel(disciplineId: disciplineId, chapterId: chapterId, level: level) else { return false }
        resetChapterLevelProgress(disciplineId: disciplineId, chapterId: chapterId, level: level)
        return true
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

    /// Returns a fresh question pool for a chapter level, automatically resetting
    /// failed progress if the cooldown has elapsed so the pool is never empty.
    func questionPoolForChapterLevel(
        disciplineId: String,
        chapterId: String,
        level: DifficultyLevel,
        allQuestionIds: [String]
    ) -> [String] {
        autoResetChapterLevelIfNeeded(disciplineId: disciplineId, chapterId: chapterId, level: level)
        let seen = Set(seenQuestionIds(disciplineId: disciplineId, chapterId: chapterId, level: level))
        let fresh = allQuestionIds.filter { !seen.contains($0) }
        return fresh.isEmpty ? allQuestionIds : fresh
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
