import Foundation

extension String {
    /// Normalized key used to compare user answers with expected answers
    /// (case- and accent-insensitive, whitespace-trimmed).
    var comparisonKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
