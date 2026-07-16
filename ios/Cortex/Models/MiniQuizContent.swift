import Foundation

/// A tiny, fixed set of deliberately easy general-knowledge questions used
/// only during onboarding, so every new user can experience a taste of the
/// game and succeed on their very first try. Independent from the main
/// `content.json` catalog, but reuses the same `Question` QCM shape so it
/// renders with the identical visual style.
nonisolated enum MiniQuizContent {
    static let questions: [Question] = [
        Question(
            id: "onboarding-quiz-1",
            type: .multipleChoice,
            prompt: "Quelle est la capitale de la France ?",
            options: ["Paris", "Lyon", "Marseille", "Bruxelles"],
            answer: "Paris",
            explanation: "Paris est la capitale de la France depuis des siècles.",
            familiarity: .commun
        ),
        Question(
            id: "onboarding-quiz-2",
            type: .multipleChoice,
            prompt: "Combien y a-t-il de continents sur Terre ?",
            options: ["5", "6", "7", "9"],
            answer: "7",
            explanation: "On compte généralement 7 continents : Afrique, Amérique du Nord, Amérique du Sud, Antarctique, Asie, Europe, Océanie.",
            familiarity: .commun
        ),
        Question(
            id: "onboarding-quiz-3",
            type: .multipleChoice,
            prompt: "Quelle planète est surnommée la \"planète rouge\" ?",
            options: ["Vénus", "Mars", "Jupiter", "Saturne"],
            answer: "Mars",
            explanation: "Mars doit sa couleur rouge à l'oxyde de fer présent à sa surface.",
            familiarity: .commun
        ),
        Question(
            id: "onboarding-quiz-4",
            type: .multipleChoice,
            prompt: "Qui a peint la Joconde ?",
            options: ["Léonard de Vinci", "Picasso", "Van Gogh", "Monet"],
            answer: "Léonard de Vinci",
            explanation: "Léonard de Vinci l'a peinte au début du XVIe siècle.",
            familiarity: .commun
        ),
        Question(
            id: "onboarding-quiz-5",
            type: .multipleChoice,
            prompt: "Quel est le plus grand océan du monde ?",
            options: ["Atlantique", "Indien", "Arctique", "Pacifique"],
            answer: "Pacifique",
            explanation: "L'océan Pacifique couvre à lui seul près d'un tiers de la surface du globe.",
            familiarity: .commun
        )
    ]
}
