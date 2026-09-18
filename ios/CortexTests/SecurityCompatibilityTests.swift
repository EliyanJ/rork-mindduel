import Foundation
import Testing
@testable import Cortex

struct SecurityCompatibilityTests {
    @Test func versionsCompareNumerically() {
        #expect(AppVersion.isOlder("1.0.2", than: "1.0.10"))
        #expect(!AppVersion.isOlder("1.0.10", than: "1.0.2"))
        #expect(!AppVersion.isOlder("1.0.1", than: "1.0.1"))
        #expect(!AppVersion.isOlder("1.0.1", than: "invalid"))
    }

    @Test func requestIncludesTheRealBundleVersion() throws {
        let request = AppVersion.request(url: try #require(URL(string: "https://example.test/api/app/config")))
        #expect(request.value(forHTTPHeaderField: "X-App-Version") == AppVersion.current)
        #expect(!AppVersion.isOlder(AppVersion.current, than: "1.0.0"))
    }

    @Test func serverAndLegacyPickerShareGoldenSequence() throws {
        let json = #"{"disciplines":[{"id":"histoire","name":"Histoire","icon":"book","colorHex":"000000","chapters":[{"id":"chapter","title":"Chapitre","questions":[{"id":"q1","type":"multipleChoice","prompt":"A","answer":"A","explanation":"A"},{"id":"q2","type":"multipleChoice","prompt":"B","answer":"B","explanation":"B"},{"id":"q3","type":"trueFalse","prompt":"C","answer":"Vrai","explanation":"C"},{"id":"q4","type":"multipleChoice","prompt":"D","answer":"D","explanation":"D"},{"id":"excluded","type":"anagram","prompt":"X","answer":"XYZ","explanation":"X"}]}]}]}"#
        let catalog = try JSONDecoder().decode(ContentCatalog.self, from: Data(json.utf8))
        let questions = MatchQuestionPicker.questions(from: catalog, seed: "123", count: 4, themes: ["all"], averageElo: 1000)
        #expect(questions.map(\.id) == ["q2", "q3", "q1", "q4"])
    }
}
