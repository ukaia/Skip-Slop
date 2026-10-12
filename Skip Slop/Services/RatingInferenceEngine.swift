import MapKit

/// Makes educated guesses about restaurant quality when not in the chain database.
///
/// Core insight: independent restaurants are far more likely to cook real food.
/// Chains use Sysco/US Foods because they need consistency at scale.
/// An unknown sit-down restaurant is NOT the same as fast food — don't grey it out.
enum RatingInferenceEngine {

    struct InferenceResult {
        let rating: SlopRating
        let confidence: Confidence
        let reason: String

        enum Confidence: String {
            case known     = "Known"       // hand-graded chain in the DB
            case category  = "Category"    // chain in the DB, grade from its category
            case high      = "Likely"      // strong signals
            case medium    = "Estimated"   // moderate signals
            case low       = "Guess"       // weak signals

            var sortOrder: Int {
                switch self {
                case .known:    0
                case .category: 1
                case .high:     2
                case .medium:   3
                case .low:      4
                }
            }
        }
    }

    // MARK: - Main Entry Point

    static func infer(mapItem: MKMapItem, chainMatch: ChainMatchResult?) -> InferenceResult {
        // 1. Known chain — highest confidence, unless its grade is a category estimate
        if let match = chainMatch {
            return InferenceResult(
                rating: match.slopRating,
                confidence: match.chainInfo.isCategoryEstimate ? .category : .known,
                reason: match.chainInfo.isCategoryEstimate
                    ? "Chain: \(match.chainInfo.name). Grade estimated from its category."
                    : "Known chain: \(match.chainInfo.name)"
            )
        }

        let name = Words(mapItem.name ?? "")
        let category = mapItem.pointOfInterestCategory

        // 2. Check if it's likely a chain we don't have in our DB
        if let chainSignal = detectUnknownChain(name: name) {
            return chainSignal
        }

        // 3. Fast food / drive-thru detection
        if isFastFood(name: name, category: category) {
            return InferenceResult(
                rating: .grey,
                confidence: .high,
                reason: "Fast food / quick service"
            )
        }

        // 4. Coffee shop / juice bar
        if isCoffeeOrDrinks(name: name, category: category) {
            return InferenceResult(
                rating: .grey,
                confidence: .high,
                reason: "Coffee / drinks"
            )
        }

        // 5. Upscale indicators — could be real food OR expensive slop
        if let upscaleResult = checkUpscaleSignals(name: name) {
            return upscaleResult
        }

        // 6. Independent restaurant indicators — lean positive
        if let independentResult = checkIndependentSignals(name: name, category: category) {
            return independentResult
        }

        // 7. Generic sit-down restaurant — benefit of the doubt
        if category == .restaurant {
            return InferenceResult(
                rating: .yellow,
                confidence: .low,
                reason: "Sit-down restaurant — unverified"
            )
        }

        // 8. Bakery / food market — usually more legit
        if category == .bakery || category == .foodMarket {
            return InferenceResult(
                rating: .green,
                confidence: .medium,
                reason: "Bakery / food market — likely real food"
            )
        }

        // 9. Brewery / winery — food varies but beer is real
        if category == .brewery {
            return InferenceResult(
                rating: .yellow,
                confidence: .low,
                reason: "Brewery — food quality varies"
            )
        }

        // 10. Default for anything else — yellow, not grey
        return InferenceResult(
            rating: .yellow,
            confidence: .low,
            reason: "Not enough information — needs community input"
        )
    }

    // MARK: - Chain Detection Heuristics

    /// Detects patterns that suggest this is a chain even if not in our DB.
    /// Chains tend to have specific naming patterns.
    private static func detectUnknownChain(name: Words) -> InferenceResult? {

        // Franchise suffixes/patterns
        let chainPatterns = [
            "pizza", "burger", "wing", "taco", "sub", "chicken",
            "grill & bar", "bar & grill", "bar and grill",
            "grill and bar", "sports bar", "pub & grill"
        ]

        // Known franchise naming: "[Name]'s Pizza", "[City] Pizza Company", etc.
        // These are LESS likely to be Sysco — local pizza joints often make their own
        let localFoodPatterns = [
            "pizzeria", "trattoria", "ristorante", "osteria",
            "taqueria", "cocina", "cantina", "panaderia",
            "boulangerie", "patisserie", "brasserie",
            "dim sum", "dumpling", "noodle house", "ramen",
            "pho", "sushi", "hibachi", "teriyaki",
            "kebab", "shawarma", "falafel", "gyro",
            "deli", "delicatessen", "smokehouse", "bbq",
            "barbecue", "creamery", "gelato"
        ]

        // Local/ethnic food patterns → likely real food (Green)
        for pattern in localFoodPatterns {
            if name.contains(pattern) {
                return InferenceResult(
                    rating: .green,
                    confidence: .medium,
                    reason: "Specialty restaurant — likely cooks in-house"
                )
            }
        }

        // Generic chain-style names with "& bar/grill" → suspicious (Orange)
        for pattern in chainPatterns {
            if name.contains(pattern) && !looksIndependent(name: name) {
                return InferenceResult(
                    rating: .orange,
                    confidence: .low,
                    reason: "Chain-style name pattern — unverified"
                )
            }
        }

        return nil
    }

    // MARK: - Fast Food Detection

    private static func isFastFood(name: Words, category: MKPointOfInterestCategory?) -> Bool {

        let fastFoodKeywords = [
            "drive-thru", "drive thru", "drive-through",
            "express", "to go", "to-go",
            "quick", "fast"
        ]

        // MapKit doesn't have a fast food category — it's all .restaurant
        // So we rely on name patterns
        for keyword in fastFoodKeywords {
            if name.contains(keyword) { return true }
        }

        return false
    }

    // MARK: - Coffee / Drinks

    private static func isCoffeeOrDrinks(name: Words, category: MKPointOfInterestCategory?) -> Bool {
        if category == .cafe { return true }

        let drinkKeywords = [
            "coffee", "espresso", "cafe", "café",
            "tea house", "tea room", "boba", "bubble tea",
            "juice", "smoothie", "açaí", "acai",
            "ice cream", "frozen yogurt", "froyo",
            "donut", "doughnut"
        ]

        return drinkKeywords.contains { name.contains($0) }
    }

    // MARK: - Upscale Signals

    private static func checkUpscaleSignals(name: Words) -> InferenceResult? {

        // High-end independent indicators — these places usually cook real food
        let fineIndependentKeywords = [
            "farm to table", "farm-to-table", "farm to fork",
            "locally sourced", "organic",
            "chef", "kitchen &", "& kitchen"
        ]

        for keyword in fineIndependentKeywords {
            if name.contains(keyword) {
                return InferenceResult(
                    rating: .green,
                    confidence: .medium,
                    reason: "Farm-to-table / chef-driven indicators"
                )
            }
        }

        // Upscale chain-style names — could be Sysco slop at high prices
        let suspiciousUpscale = [
            "steakhouse", "steak house", "chophouse", "chop house",
            "prime", "capital", "metropolitan"
        ]

        for keyword in suspiciousUpscale {
            if name.contains(keyword) {
                return InferenceResult(
                    rating: .orange,
                    confidence: .low,
                    reason: "Upscale — could be real or expensive slop"
                )
            }
        }

        return nil
    }

    // MARK: - Independent Restaurant Signals

    private static func checkIndependentSignals(name: Words, category: MKPointOfInterestCategory?) -> InferenceResult? {

        // Strong independent signals — personal names, ethnic cuisines, family-style
        let independentKeywords = [
            "mama", "mom's", "momma", "nana's", "grandma",
            "papa", "dad's", "uncle", "auntie", "aunt",
            "family", "homestyle", "home style", "homemade",
            "house of", "little", "old town",
            "bistro", "tavern", "inn", "lodge",
            "garden", "harvest", "market",
        ]

        for keyword in independentKeywords {
            if name.contains(keyword) {
                return InferenceResult(
                    rating: .green,
                    confidence: .medium,
                    reason: "Independent restaurant indicators"
                )
            }
        }

        // Possessive names like "Joe's" "Maria's" — usually independent
        if let possessivePattern = Self.possessivePattern {
            let lower = name.raw.lowercased()
            let range = NSRange(lower.startIndex..., in: lower)
            if possessivePattern.firstMatch(in: lower, range: range) != nil {
                return InferenceResult(
                    rating: .green,
                    confidence: .low,
                    reason: "Appears to be independently owned"
                )
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static let possessivePattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^[a-z]+['\u{2019}]s\\b", options: .caseInsensitive
    )

    /// A name split into normalized words, so keywords match whole words:
    /// "Breakfast Club" isn't "fast" food and "Deschutes Brewing" has no "wing".
    struct Words {
        let raw: String
        let tokens: [String]

        init(_ name: String) {
            raw = name
            tokens = ChainDatabase.tokens(name)
        }

        /// True when the phrase's words appear consecutively. The last word may
        /// also appear in plural ("taco" matches "Tacos").
        func contains(_ phrase: String) -> Bool {
            let words = ChainDatabase.tokens(phrase)
            guard let lastWord = words.last, words.count <= tokens.count else { return false }
            for start in 0...(tokens.count - words.count) {
                let window = tokens[start..<(start + words.count)]
                let matches = zip(window, words).enumerated().allSatisfy { index, pair in
                    pair.0 == pair.1 || (index == words.count - 1 && pair.0 == lastWord + "s")
                }
                if matches { return true }
            }
            return false
        }
    }

    /// Checks if a name looks like an independent local restaurant vs a chain.
    private static func looksIndependent(name: Words) -> Bool {
        // Names with a city/neighborhood reference are often local
        let localPatterns = [
            "downtown", "uptown", "neighborhood", "corner",
            "village", "district", "local", "original"
        ]

        return localPatterns.contains { name.contains($0) }
    }
}
