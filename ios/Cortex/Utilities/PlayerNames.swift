import Foundation

/// Player-style handles for locally simulated opponents (Flash mode), built
/// from the bundled first-name list so they read like real nicknames.
nonisolated enum PlayerNames {
    private static let firstNames: [String] = {
        guard let url = Bundle.main.url(forResource: "player_names", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String].self, from: data),
              !names.isEmpty else {
            return ["Léa", "Hugo", "Emma", "Nolan", "Chloé", "Liam", "Inès", "Adam"]
        }
        return names
    }()

    private static let words = ["Panda", "Ninja", "Tigre", "Comete", "Pixel", "Faucon", "Renard", "Loup", "Nova", "Lynx", "Orage", "Onyx"]
    private static let initials = Array("ABCDEFGHJKLMNOPRSTVW")

    /// A random nickname such as "Inès", "Lucas27", "Camille R." or "theo_05".
    static func random(excluding used: Set<String> = []) -> String {
        for _ in 0..<20 {
            let first = firstNames.randomElement() ?? "Joueur"
            let roll = Double.random(in: 0..<1)
            let candidate: String
            switch roll {
            case ..<0.4: candidate = first
            case ..<0.65: candidate = "\(first)\(Int.random(in: 1...99))"
            case ..<0.8: candidate = "\(first) \(initials.randomElement() ?? "M")."
            case ..<0.9: candidate = "\(first.lowercased())_\(["92", "95", "98", "01", "03", "05", "07", "09", "11"].randomElement() ?? "05")"
            default: candidate = "\(first)\(words.randomElement() ?? "Nova")"
            }
            if !used.contains(candidate.lowercased()) { return candidate }
        }
        return "Joueur\(Int.random(in: 100...9999))"
    }
}
