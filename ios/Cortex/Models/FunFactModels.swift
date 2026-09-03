import Foundation

/// One short revision point shown inside a `StudyCard`, derived from a real
/// question's explanation so it actually helps the player answer the quiz.
nonisolated struct StudyPoint: Identifiable, Hashable {
    let id: String
    let text: String
}

/// A single swipeable page of the pre-quiz revision sheet.
nonisolated struct StudyCard: Identifiable, Hashable {
    let id: String
    let points: [StudyPoint]
}

/// Builds the pre-quiz "revision sheet" for a ring: short cards distilled
/// from the explanations of the questions that are actually about to be
/// asked, so the teaser gives genuine hints instead of unrelated trivia.
nonisolated enum StudyGuide {
    /// Cards are capped so the sheet never turns into a wall of text, and
    /// grouped so a small ring still gets at least a couple of points per card.
    private static let maxCards = 4
    private static let minPointsPerCard = 2

    /// Groups the ring's question explanations into a handful of short,
    /// swipeable cards. Returns an empty array if no question has usable
    /// explanation text.
    static func cards(for questions: [Question]) -> [StudyCard] {
        let points = questions.compactMap { question -> String? in
            let text = question.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        guard !points.isEmpty else { return [] }

        let chunkSize = max(minPointsPerCard, Int(ceil(Double(points.count) / Double(maxCards))))
        var cards: [StudyCard] = []
        var index = 0
        var cardNumber = 1
        while index < points.count {
            let end = min(index + chunkSize, points.count)
            let chunk = points[index..<end]
            let cardPoints = chunk.enumerated().map { offset, text in
                StudyPoint(id: "study_\(cardNumber)_\(offset)", text: text)
            }
            cards.append(StudyCard(id: "study_card_\(cardNumber)", points: cardPoints))
            index = end
            cardNumber += 1
        }
        return cards
    }
}
