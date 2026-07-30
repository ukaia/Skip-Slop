import Foundation

enum ContentFilter {
    // Precompiled blocked patterns — slurs, hate speech, explicit content, personal attacks
    private static let blockedRegexes: [NSRegularExpression] = {
        let patterns = [
            // Slurs and hate speech (abbreviated patterns to catch variations)
            "\\bn[i1]g+[aer]",
            "\\bf[a@]g+[oi]t",
            "\\bk[i1]ke\\b",
            "\\bsp[i1]c\\b",
            "\\bch[i1]nk\\b",
            "\\bwetback",
            "\\bretard",

            // Explicit / sexual content
            "\\bf+u+c+k+",
            "\\bs+h+[i1]+t+(?!ake)",  // allow "shiitake"
            "\\ba+s+s+h+o+l+e",
            "\\bd[i1]ck(?!ens)",       // allow "Dickens"
            "\\bpussy\\b",
            "\\bcunt\\b",
            "\\bbitc?h\\b",

            // Threats and violence
            "\\bkill\\s+(you|them|him|her)",
            "\\bbomb\\s+threat",
            "\\bshoot",
            "\\bdie\\b.*\\bdie\\b",

            // Spam patterns
            "\\b(buy|click|subscribe|follow me)\\b.*\\b(now|here|link)\\b",
            "(https?://|www\\.)",      // no external links
            "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b", // phone numbers (doxxing)

            // Personal info / doxxing
            "\\b\\d+\\s+[a-z]+\\s+(st|street|ave|avenue|rd|road|dr|drive|ln|lane|blvd)\\b",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    // Precompiled repeated-character pattern
    private static let repeatedPattern: NSRegularExpression? = try? NSRegularExpression(pattern: "(.)\\1{4,}")

    // Currency pattern to exclude from all-caps check (legitimate price notes like "I PAID $30")
    private static let currencyPattern: NSRegularExpression? = try? NSRegularExpression(pattern: "\\$\\d+")

    static let maxLength = 500

    /// Why a note was rejected. The filter used to return a bare `Bool`, so a
    /// note that was merely too long was reported to the author as containing
    /// "language that isn't allowed" — accusing someone of writing a slur when
    /// they had written a long, careful note. Each case now carries its own
    /// explanation.
    enum Rejection: Equatable {
        case tooLong(limit: Int)
        case blockedLanguage
        case shouting
        case repeatedCharacters

        /// Alert title shown to the author.
        var title: String {
            switch self {
            case .tooLong:            "Note Too Long"
            case .blockedLanguage:    "Inappropriate Content"
            case .shouting:           "Turn Off Caps Lock"
            case .repeatedCharacters: "Too Many Repeated Characters"
            }
        }

        /// Actionable explanation. Says what to change, not just what is wrong.
        var message: String {
            switch self {
            case .tooLong(let limit):
                "Notes are limited to \(limit) characters. Trim it down and try again."
            case .blockedLanguage:
                "Your note contains language that isn't allowed. Please keep notes factual and relevant to food quality."
            case .shouting:
                "Your note is almost entirely capital letters. Please write it normally."
            case .repeatedCharacters:
                "Your note repeats a character several times in a row. Please write it normally."
            }
        }
    }

    /// Returns why `text` should be rejected, or `nil` when it is acceptable.
    static func rejectionReason(for text: String) -> Rejection? {
        // Length first: a long note is the most common rejection and has
        // nothing to do with its content.
        if text.count > maxLength {
            return .tooLong(limit: maxLength)
        }

        // Empty is fine (some note types don't need body)
        if text.isEmpty {
            return nil
        }

        // Check all precompiled blocked patterns
        let lowered = text.lowercased()
        let loweredRange = NSRange(lowered.startIndex..., in: lowered)
        for regex in blockedRegexes {
            if regex.firstMatch(in: lowered, range: loweredRange) != nil {
                return .blockedLanguage
            }
        }

        let textRange = NSRange(text.startIndex..., in: text)

        // All caps screaming (more than 95% uppercase with 20+ chars, excluding currency notes)
        if text.count >= 20 {
            let hasCurrency = currencyPattern?.firstMatch(in: text, range: textRange) != nil
            if !hasCurrency {
                let uppercaseCount = text.filter(\.isUppercase).count
                let letterCount = text.filter(\.isLetter).count
                if letterCount > 0 && Double(uppercaseCount) / Double(letterCount) > 0.95 {
                    return .shouting
                }
            }
        }

        // Excessive repeated characters (like "nooooooo" or "!!!!!!")
        if let repeatedPattern,
           repeatedPattern.firstMatch(in: text, range: textRange) != nil {
            return .repeatedCharacters
        }

        return nil
    }

    static func containsInappropriateContent(_ text: String) -> Bool {
        rejectionReason(for: text) != nil
    }
}
