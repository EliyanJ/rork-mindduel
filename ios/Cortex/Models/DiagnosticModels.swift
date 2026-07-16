import Foundation

/// Performance tier for a single discipline in the optional onboarding diagnostic.
/// Based on a small sample (3 questions), so it is deliberately modest in wording.
enum DiagnosticTier: String, Codable, CaseIterable {
    case faible, moyen, solide

    var label: String {
        switch self {
        case .faible: return "À explorer"
        case .moyen: return "En progrès"
        case .solide: return "À l'aise"
        }
    }

    var color: String {
        switch self {
        case .faible: return "#FF6B6B"
        case .moyen: return "#FCC419"
        case .solide: return "#37B24D"
        }
    }

    var systemImage: String {
        switch self {
        case .faible: return "arrow.up.circle"
        case .moyen: return "bolt.circle"
        case .solide: return "checkmark.circle"
        }
    }
}

/// Per-discipline result of the optional onboarding diagnostic.
struct DisciplineDiagnosticResult: Codable, Identifiable {
    var id: String { disciplineId }
    let disciplineId: String
    let disciplineName: String
    let correctCount: Int
    let totalCount: Int
    let tier: DiagnosticTier

    var ratio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(correctCount) / Double(totalCount)
    }
}

/// Tracks whether the user completed, skipped, or never started the optional
/// onboarding diagnostic. Stored once per profile.
struct OnboardingDiagnostic: Codable {
    var completed: Bool
    var skipped: Bool
    var completedAt: Date?
    var results: [DisciplineDiagnosticResult]

    static var empty: OnboardingDiagnostic {
        OnboardingDiagnostic(completed: false, skipped: false, completedAt: nil, results: [])
    }
}

func diagnosticTier(correctCount: Int) -> DiagnosticTier {
    switch correctCount {
    case 0, 1: return .faible
    case 2: return .moyen
    default: return .solide
    }
}
