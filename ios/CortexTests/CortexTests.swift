//
//  CortexTests.swift
//  CortexTests
//
//  Created by Rork on July 3, 2026.
//

import Testing
import Foundation
@testable import Cortex

struct CortexTests {

    // MARK: - Helpers

    /// Creates a fresh ProgressStore with empty UserDefaults so tests are isolated.
    private func freshStore() -> ProgressStore {
        UserDefaults.standard.removeObject(forKey: "cortex.progress.v1")
        return ProgressStore()
    }

    private let testDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed reference

    // MARK: - Ease-factor interval sequences

    @Test func fourCorrectAnswersProduceExpectedIntervals() async throws {
        let store = freshStore()
        let qid = "test_q1"

        // 1st correct → interval 1
        store.recordAnswer(questionId: qid, disciplineId: "hist", correct: true, date: testDate)
        var item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 1, "1st correct: expected 1, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 1)
        #expect(item.easeFactor == 2.6, "ease after 1st correct: expected 2.6, got \(item.easeFactor)")

        // 2nd correct → interval 6
        store.recordAnswer(questionId: qid, disciplineId: "hist", correct: true, date: testDate)
        item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 6, "2nd correct: expected 6, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 2)
        #expect(item.easeFactor == 2.7, "ease after 2nd correct: expected 2.7, got \(item.easeFactor)")

        // 3rd correct → interval = round(6 * 2.7) = 16
        store.recordAnswer(questionId: qid, disciplineId: "hist", correct: true, date: testDate)
        item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 16, "3rd correct: expected 16, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 3)
        #expect(item.easeFactor == 2.8, "ease after 3rd correct: expected 2.8, got \(item.easeFactor)")

        // 4th correct → interval = round(16 * 2.8) = 45
        store.recordAnswer(questionId: qid, disciplineId: "hist", correct: true, date: testDate)
        item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 45, "4th correct: expected 45, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 4)
        #expect(item.easeFactor == 2.8, "ease capped at 2.8, got \(item.easeFactor)")
    }

    @Test func wrongAnswerResetsAndNextCorrectStartsOver() async throws {
        let store = freshStore()
        let qid = "test_q2"

        // Two correct answers to build up streak
        store.recordAnswer(questionId: qid, disciplineId: "sci", correct: true, date: testDate)
        store.recordAnswer(questionId: qid, disciplineId: "sci", correct: true, date: testDate)
        var item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 6)
        #expect(item.consecutiveCorrect == 2)
        #expect(item.easeFactor == 2.7)

        // Wrong answer resets
        store.recordAnswer(questionId: qid, disciplineId: "sci", correct: false, date: testDate)
        item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 0, "wrong: interval should be 0")
        #expect(item.consecutiveCorrect == 0, "wrong: streak should reset to 0")
        #expect(item.lapses == 1)
        #expect(item.easeFactor == 2.5, "wrong: ease should drop by 0.2 → 2.5, got \(item.easeFactor)")
        // Due immediately
        let calendar = Calendar.current
        #expect(calendar.isDate(item.dueDate, inSameDayAs: testDate))

        // Next correct starts from interval 1 again
        store.recordAnswer(questionId: qid, disciplineId: "sci", correct: true, date: testDate)
        item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 1, "after reset, 1st correct: expected 1, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 1)
        #expect(item.easeFactor == 2.6, "ease rebuilds: expected 2.6, got \(item.easeFactor)")
    }

    @Test func intervalCapsAt180Days() async throws {
        let store = freshStore()
        let qid = "test_q3"

        // Drive the card through many correct answers to reach the cap.
        // Sequence: 1, 6, 16, 45, 126, 180 (capped)
        for _ in 0..<7 {
            store.recordAnswer(questionId: qid, disciplineId: "geo", correct: true, date: testDate)
        }
        let item = store.progress.reviewItems[qid]!
        #expect(item.intervalDays == 180, "expected cap at 180, got \(item.intervalDays)")
        #expect(item.consecutiveCorrect == 7)

        // One more correct should stay at 180
        store.recordAnswer(questionId: qid, disciplineId: "geo", correct: true, date: testDate)
        let item2 = store.progress.reviewItems[qid]!
        #expect(item2.intervalDays == 180, "should remain at 180, got \(item2.intervalDays)")
    }

    // MARK: - Migration

    @Test func migrationReconstructsConsecutiveCorrectFromOldInterval() async throws {
        // Build a raw JSON dict for an old-style ReviewItem (no easeFactor/consecutiveCorrect).
        let oldItemJson: [String: Any] = [
            "questionId": "migrate_q1",
            "disciplineId": "hist",
            "intervalDays": 16,
            "dueDate": ISO8601DateFormatter().string(from: testDate),
            "strength": 0.8,
            "lapses": 0
        ]
        let progressDict: [String: Any] = [
            "xp": 100,
            "streak": 3,
            "lastActiveDay": ISO8601DateFormatter().string(from: testDate),
            "activeDays": [],
            "chapterRecords": [:] as [String: Any],
            "reviewItems": ["migrate_q1": oldItemJson],
            "elo": 1000,
            "duelsPlayed": 0,
            "duelsWon": 0
        ]

        let data = try JSONSerialization.data(withJSONObject: progressDict)
        UserDefaults.standard.set(data, forKey: "cortex.progress.v1")

        // Init store → triggers decode + migration
        let store = ProgressStore()
        let item = store.progress.reviewItems["migrate_q1"]

        #expect(item != nil, "migrated item should exist")
        #expect(item?.intervalDays == 16, "intervalDays should be preserved at 16")
        #expect(item?.easeFactor == 2.5, "easeFactor should default to 2.5")
        #expect(item?.consecutiveCorrect == 3, "16 days → consecutiveCorrect 3, got \(item?.consecutiveCorrect ?? -1)")
    }

    @Test func migrationDoesNotTouchZeroIntervalItems() async throws {
        let oldItemJson: [String: Any] = [
            "questionId": "migrate_q2",
            "disciplineId": "sci",
            "intervalDays": 0,
            "dueDate": ISO8601DateFormatter().string(from: testDate),
            "strength": 0.1,
            "lapses": 2
        ]
        let progressDict: [String: Any] = [
            "xp": 0,
            "streak": 0,
            "lastActiveDay": NSNull(),
            "activeDays": [],
            "chapterRecords": [:] as [String: Any],
            "reviewItems": ["migrate_q2": oldItemJson],
            "elo": 1000,
            "duelsPlayed": 0,
            "duelsWon": 0
        ]

        let data = try JSONSerialization.data(withJSONObject: progressDict)
        UserDefaults.standard.set(data, forKey: "cortex.progress.v1")

        let store = ProgressStore()
        let item = store.progress.reviewItems["migrate_q2"]

        #expect(item?.intervalDays == 0)
        #expect(item?.consecutiveCorrect == 0, "0 interval → cc stays 0")
        #expect(item?.easeFactor == 2.5)
        #expect(item?.lapses == 2, "lapses should be preserved")
    }

    // MARK: - dueDate calculation

    @Test func dueDateIsIntervalDaysAhead() async throws {
        let store = freshStore()
        let qid = "test_due"

        store.recordAnswer(questionId: qid, disciplineId: "hist", correct: true, date: testDate)
        let item = store.progress.reviewItems[qid]!
        let expectedDue = Calendar.current.date(byAdding: .day, value: 1, to: testDate)!
        #expect(Calendar.current.isDate(item.dueDate, inSameDayAs: expectedDue))
    }
}
