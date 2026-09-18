import Foundation

nonisolated struct AppVersionPolicy: Codable {
    let minVersion: String
    let minVersionParty: String

    enum CodingKeys: String, CodingKey {
        case minVersion = "min_version"
        case minVersionParty = "min_version_party"
    }
}
