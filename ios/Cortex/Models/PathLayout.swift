import Foundation

/// One slot in a sub-chapter's ring timeline, as configured from the admin
/// "Parcours" tool. `source` points at the index of a default-built normal
/// ring; recap slots ignore it.
nonisolated struct RingSlot: Codable, Hashable {
    let kind: RingKind
    /// Index of the default normal ring this slot plays. Nil for recap slots.
    let source: Int?

    init(kind: RingKind, source: Int? = nil) {
        self.kind = kind
        self.source = source
    }
}

/// Ordering of the whole learning path, editable from the admin back-office
/// and published alongside the content catalog.
///
/// Everything is optional: a missing entry falls back to
/// `PathLayout.fallbackChapterOrder` / natural catalog order, so the app keeps
/// working if the layout has never been published.
nonisolated struct PathLayout: Codable, Hashable {
    var disciplineOrder: [String]
    /// disciplineId → ordered chapter ids.
    var chapterOrder: [String: [String]]
    /// chapterId → explicit ring timeline. Absent means "default layout".
    var ringLayout: [String: [RingSlot]]

    static let empty = PathLayout(disciplineOrder: [], chapterOrder: [:], ringLayout: [:])

    private enum CodingKeys: String, CodingKey {
        case disciplineOrder, chapterOrder, ringLayout
    }

    init(disciplineOrder: [String], chapterOrder: [String: [String]], ringLayout: [String: [RingSlot]]) {
        self.disciplineOrder = disciplineOrder
        self.chapterOrder = chapterOrder
        self.ringLayout = ringLayout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        disciplineOrder = try c.decodeIfPresent([String].self, forKey: .disciplineOrder) ?? []
        chapterOrder = try c.decodeIfPresent([String: [String]].self, forKey: .chapterOrder) ?? [:]
        ringLayout = try c.decodeIfPresent([String: [RingSlot]].self, forKey: .ringLayout) ?? [:]
    }

    /// Reorders `values` to match `order`, keeping unknown ids at the end in
    /// their original position. Never drops or duplicates an entry, so a stale
    /// published layout can't make content disappear.
    static func apply<T>(order: [String], to values: [T], id: (T) -> String) -> [T] {
        guard !order.isEmpty else { return values }
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return values.enumerated().sorted { lhs, rhs in
            let l = rank[id(lhs.element)] ?? Int.max
            let r = rank[id(rhs.element)] ?? Int.max
            return l == r ? lhs.offset < rhs.offset : l < r
        }.map(\.element)
    }
}

/// Sensible built-in ordering used until an admin publishes their own.
/// History is chronological; other disciplines go from the most familiar or
/// concrete to the most specialised.
nonisolated enum PathDefaults {
    static let disciplineOrder: [String] = [
        "histoire", "geographie", "sciences", "litterature",
        "arts", "nature", "technologie", "football",
    ]

    static let chapterOrder: [String: [String]] = [
        "histoire": [
            "histoire_antiquite", "histoire_moyen_age", "histoire_decouvertes",
            "histoire_revolution", "histoire_guerres_mondiales",
        ],
        "geographie": [
            "geo_france", "geo_europe", "geo_capitales", "geo_oceans_continents",
            "geo_amerique", "geo_asie", "geo_afrique", "geo_fleuves_montagnes",
            "geo_climats",
        ],
        "sciences": [
            "sciences_systeme_solaire", "sciences_terre", "sciences_corps_humain",
            "sciences_evolution", "sciences_genetique", "sciences_chimie",
            "sciences_atome", "sciences_energie", "sciences_gravite",
        ],
        "litterature": [
            "litt_theatre_antique", "litt_contes_legendes", "litt_ecrivains",
            "litt_poesie_theatre", "litt_heros", "litt_femmes_ecrivaines",
            "litt_prix_litteraires", "litt_contemporaine", "litt_bd_comics",
        ],
        "arts": [
            "arts_peinture", "arts_monuments", "arts_musique", "arts_instruments",
            "arts_opera", "arts_danse", "arts_photographie", "arts_cinema",
            "arts_mode_design",
        ],
        "nature": [
            "nature_animaux_domestiques", "nature_mammiferes", "nature_oiseaux",
            "nature_ocean", "nature_reptiles_amphibiens", "nature_insectes",
            "nature_plantes", "nature_ecosystemes", "nature_records",
            "nature_dinosaures",
        ],
        "technologie": [
            "tech_inventions", "tech_espace", "tech_telescopes_astronomie",
            "tech_informatique", "tech_internet_reseaux", "tech_jeux_video",
            "tech_robots_ia", "tech_medecine", "tech_energie_environnement",
        ],
        "football": [
            "football_cm_internationaux", "football_euro_2024", "football_ligue1",
            "football_pl_2023_2025", "football_liga_seriea", "football_cdm_2023_2025",
            "football_ballon_or", "football_transferts", "football_stars_records",
        ],
    ]

    /// The built-in layout, used when nothing has been published yet.
    static var layout: PathLayout {
        PathLayout(disciplineOrder: disciplineOrder, chapterOrder: chapterOrder, ringLayout: [:])
    }
}
