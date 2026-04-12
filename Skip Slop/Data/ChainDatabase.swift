import Foundation
import Observation

struct ChainInfo: Codable {
    let slug: String
    let name: String
    let rating: String
    let category: String
    let distributor: String?
    let parentCompany: String?
    let source: String?

    var slopRating: SlopRating {
        SlopRating(rawValue: rating) ?? .grey
    }

    /// Human-readable explanation of why this chain has this rating
    var ratingReason: String {
        if let distributor, !distributor.isEmpty {
            switch slopRating {
            case .greenPlus:
                return "Verified locally sourced"
            case .green:
                return "Independent supply chain — not Sysco/US Foods"
            case .yellow:
                return "Mixed sourcing — some real, some distributed"
            case .orange:
                return "Low quality but not confirmed Sysco/US Foods"
            case .red:
                return "Supplied by \(distributor)"
            case .redMinus:
                return "Supplied by \(distributor) — premium prices for distributor food"
            case .grey:
                return "Fast food / quick service"
            }
        }
        return slopRating.description
    }
}

@Observable
final class ChainDatabase {
    private(set) var chains: [String: ChainInfo] = [:]
    private var normalizedLookup: [String: ChainInfo] = [:]

    /// All known alternate names mapping to a canonical slug
    private var aliases: [String: String] = [:]

    init() {
        loadChains()
        buildAliases()
    }

    private func loadChains() {
        guard let url = Bundle.main.url(forResource: "SeedChains", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ChainInfo].self, from: data) else {
            return
        }

        for item in items {
            chains[item.slug] = item
            let normalized = Self.normalize(item.name)
            normalizedLookup[normalized] = item
        }
    }

    /// Build common aliases — MapKit often returns different names than we store
    private func buildAliases() {
        let aliasMap: [String: [String]] = [
            "mcdonalds": ["mcd", "mickey d"],
            "chick-fil-a": ["chickfila", "chick fil a"],
            "taco-bell": ["tacobell"],
            "dunkin": ["dunkin donuts"],
            "dominos": ["dominos pizza"],
            "pizza-hut": ["pizzahut"],
            "kfc": ["kentucky fried chicken"],
            "olive-garden": ["olive garden italian restaurant"],
            "cheesecake-factory": ["cheesecake factory"],
            "buffalo-wild-wings": ["bdubs", "b dubs", "bww"],
            "tgi-fridays": ["tgi fridays", "fridays"],
            "pf-changs": ["pf changs", "p f changs"],
            "ruth-chris": ["ruths chris"],
            "carls-jr": ["carls junior"],
            "longhorn-steakhouse": ["longhorn"],
            "red-lobster": ["redlobster"],
            "outback-steakhouse": ["outback"],
            "texas-roadhouse": ["texas road house"],
            "chipotle": ["chipotle mexican grill"],
            "in-n-out": ["in n out", "innout"],
        ]

        for (slug, names) in aliasMap {
            for name in names {
                aliases[Self.normalize(name)] = slug
            }
        }
    }

    func lookup(slug: String) -> ChainInfo? {
        chains[slug]
    }

    func match(name: String) -> ChainInfo? {
        let normalized = Self.normalize(name)

        // Exact normalized match
        if let info = normalizedLookup[normalized] {
            return info
        }

        // Alias match
        if let slug = aliases[normalized], let info = chains[slug] {
            return info
        }

        // Contains match — chain name in search or vice versa
        // Sort by key length descending to prefer longer (more specific) matches
        let sortedKeys = normalizedLookup.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if key.count >= 4 && (normalized.contains(key) || key.contains(normalized)) {
                return normalizedLookup[key]
            }
        }

        // Alias contains match
        for (aliasNorm, slug) in aliases {
            if aliasNorm.count >= 4 && (normalized.contains(aliasNorm) || aliasNorm.contains(normalized)) {
                return chains[slug]
            }
        }

        return nil
    }

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "'s", with: "s")
            .replacingOccurrences(of: "\u{2019}s", with: "s")
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: " inc", with: "")
            .replacingOccurrences(of: " llc", with: "")
            .replacingOccurrences(of: " corp", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
