import Foundation

/// One step of the unified learning path. Each stage mixes questions
/// from several disciplines so lessons never feel repetitive.
struct PathStage: Identifiable, Hashable {
    let id: String
    let index: Int
    let title: String
    let items: [LessonItem]
    /// Discipline ids featured in this stage, in order of appearance.
    let disciplineIds: [String]
}
