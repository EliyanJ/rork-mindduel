import Foundation

extension Discipline {
    /// Name of the generated illustrated badge for this discipline in
    /// `Assets.xcassets`, if one exists. Falls back to the SF Symbol `icon`
    /// wherever this is `nil` so any future discipline without artwork yet still renders fine.
    var illustratedIconName: String? {
        switch id {
        case "histoire": return "SubjectHistoire"
        case "sciences": return "SubjectSciences"
        case "geographie": return "SubjectGeographie"
        case "litterature": return "SubjectLitterature"
        case "arts": return "SubjectArts"
        case "nature": return "SubjectNature"
        case "technologie": return "SubjectTechnologie"
        case "football": return "SubjectFootball"
        default: return nil
        }
    }
}
