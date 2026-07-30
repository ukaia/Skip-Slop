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

    /// All known alternate names mapping to a canonical slug, keyed on joined tokens
    private var aliases: [String: String] = [:]

    /// The same aliases retaining word boundaries, for contiguous-run matching.
    /// Sorted by slug so iteration order is stable.
    private var aliasTokens: [(tokens: [String], slug: String)] = []

    /// - Parameter seedURL: Overrides the bundled `SeedChains.json`. Only used by
    ///   tests, which run outside an app bundle.
    init(seedURL: URL? = nil) {
        loadChains(from: seedURL)
        buildAliases()
    }

    private func loadChains(from seedURL: URL?) {
        guard let url = seedURL ?? Bundle.main.url(forResource: "SeedChains", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ChainInfo].self, from: data) else {
            return
        }

        for item in items {
            chains[item.slug] = item
            // Keyed with `tokenize` so exact lookups agree with `match`.
            normalizedLookup[Self.tokenize(item.name).joined()] = item
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
                let tokens = Self.tokenize(name)
                aliases[tokens.joined()] = slug
                aliasTokens.append((tokens, slug))
            }
        }
        aliasTokens.sort { $0.slug < $1.slug }
    }

    func lookup(slug: String) -> ChainInfo? {
        chains[slug]
    }

    /// Matches a MapKit place name against the chain database.
    ///
    /// Matching is token-based rather than substring-based. The previous
    /// implementation compared names with all separators stripped, so
    /// "Longhorn Cafe" normalised to `longhorncafe`, which *contains*
    /// `longhorn`, and an independent restaurant was stamped with LongHorn
    /// Steakhouse's red rating. "Outback" and "Fridays" failed the same way.
    /// It was also non-deterministic: the alias fallback iterated a Swift
    /// `Dictionary`, so when two aliases matched, the winner varied between
    /// launches and the same restaurant could show a different rating.
    ///
    /// Evidence strength now gates what a match is allowed to assert:
    ///
    /// - **Exact** name or alias, or a **multi-token** run ("Olive Garden" inside
    ///   "Olive Garden Italian Restaurant") — trusted for any rating.
    /// - **Single-token** run ("longhorn" inside "Longhorn Cafe") — weak evidence.
    ///   Allowed to assign a neutral or positive rating, never an accusatory one.
    ///   A weak match against a negative chain returns `nil` so the caller falls
    ///   through to `RatingInferenceEngine`, which treats it as an unknown
    ///   independent rather than asserting a supply chain we cannot support.
    ///
    /// A wrong red on a local restaurant is the failure that destroys trust in
    /// the app, so weak evidence is never allowed to produce one.
    func match(name: String) -> ChainInfo? {
        let queryTokens = Self.tokenize(name)
        guard !queryTokens.isEmpty else { return nil }
        let queryKey = queryTokens.joined()

        // Tier 1 — exact name, then exact alias. Strongest evidence.
        if let info = normalizedLookup[queryKey] {
            return info
        }
        if let slug = aliases[queryKey], let info = chains[slug] {
            return info
        }

        // Tier 2/3 — the candidate's tokens appear as a contiguous run inside
        // the query. Collect every candidate, then pick deterministically:
        // most tokens matched wins, slug breaks ties alphabetically.
        var candidates: [(info: ChainInfo, matchedTokens: Int)] = []

        for (_, info) in chains {
            let chainTokens = Self.tokenize(info.name)
            if Self.tokens(chainTokens, formContiguousRunIn: queryTokens) {
                candidates.append((info, chainTokens.count))
            }
        }
        for entry in aliasTokens {
            guard let info = chains[entry.slug] else { continue }
            if Self.tokens(entry.tokens, formContiguousRunIn: queryTokens) {
                candidates.append((info, entry.tokens.count))
            }
        }

        let best = candidates
            .sorted { lhs, rhs in
                lhs.matchedTokens != rhs.matchedTokens
                    ? lhs.matchedTokens > rhs.matchedTokens
                    : lhs.info.slug < rhs.info.slug
            }
            .first

        guard let best else { return nil }

        // Weak evidence may not assert an accusatory rating.
        if best.matchedTokens < 2 && best.info.slopRating.isAccusatory {
            return nil
        }
        return best.info
    }

    /// True when `needle` appears as a contiguous run of whole tokens in `haystack`.
    /// Empty needles never match.
    static func tokens(_ needle: [String], formContiguousRunIn haystack: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle {
                return true
            }
        }
        return false
    }

    /// Splits a name into comparable lowercase word tokens, folding possessives
    /// and dropping corporate suffixes. Unlike `normalize` this preserves word
    /// boundaries, which is what stops `longhorncafe` matching `longhorn`.
    static func tokenize(_ name: String) -> [String] {
        let folded = name
            .lowercased()
            .replacingOccurrences(of: "'s", with: "s")
            .replacingOccurrences(of: "\u{2019}s", with: "s")

        let dropped: Set<String> = ["the", "inc", "llc", "corp"]

        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !dropped.contains($0) }
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
