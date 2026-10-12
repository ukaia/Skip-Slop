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

    private static let maxLength = 500
    private static let screamingMinLetters = 20
    private static let screamingUppercaseRatio = 0.95

    static func isScreaming(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter)
        guard letters.count >= screamingMinLetters else { return false }
        let uppercase = letters.filter(\.isUppercase).count
        return Double(uppercase) / Double(letters.count) > screamingUppercaseRatio
    }

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

        // All caps screaming: 20+ letters and more than 95% of them uppercase.
        // Digits, currency, spaces, and punctuation are ignored, so short shouty
        // notes like "I PAID $30 FOR A BURGER" pass.
        if isScreaming(text) {
            return true
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
