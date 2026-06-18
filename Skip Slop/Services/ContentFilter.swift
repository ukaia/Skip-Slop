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

    private static let maxLength = 500

    static func containsInappropriateContent(_ text: String) -> Bool {
        let lowered = text.lowercased()

        // Length check
        if text.count > maxLength {
            return true
        }

        // Empty is fine (some note types don't need body)
        if text.isEmpty {
            return false
        }

        // Check all precompiled blocked patterns
        let range = NSRange(lowered.startIndex..., in: lowered)
        for regex in blockedRegexes {
            if regex.firstMatch(in: lowered, range: range) != nil {
                return true
            }
        }

        // All caps screaming (more than 95% uppercase with 20+ chars, excluding currency notes)
        if text.count >= 20 {
            let hasCurrency = currencyPattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
            if !hasCurrency {
                let uppercaseCount = text.filter(\.isUppercase).count
                let letterCount = text.filter(\.isLetter).count
                if letterCount > 0 && Double(uppercaseCount) / Double(letterCount) > 0.95 {
                    return true
                }
            }
        }

        // Excessive repeated characters (like "nooooooo" or "!!!!!!")
        if let repeatedPattern {
            let range = NSRange(text.startIndex..., in: text)
            if repeatedPattern.firstMatch(in: text, range: range) != nil {
                return true
            }
        }

        return false
    }
}
