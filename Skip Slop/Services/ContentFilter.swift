import Foundation

enum ContentFilter {
    // Blocked patterns — slurs, hate speech, explicit content, personal attacks
    private static let blockedPatterns: [String] = [
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

        // Check all blocked patterns
        for pattern in blockedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowered.startIndex..., in: lowered)
                if regex.firstMatch(in: lowered, range: range) != nil {
                    return true
                }
            }
        }

        // All caps screaming (more than 80% uppercase with 10+ chars)
        if text.count >= 10 {
            let uppercaseCount = text.filter(\.isUppercase).count
            let letterCount = text.filter(\.isLetter).count
            if letterCount > 0 && Double(uppercaseCount) / Double(letterCount) > 0.8 {
                return true
            }
        }

        // Excessive repeated characters (like "nooooooo" or "!!!!!!")
        let repeatedPattern = try? NSRegularExpression(pattern: "(.)\\1{4,}")
        if let repeatedPattern {
            let range = NSRange(text.startIndex..., in: text)
            if repeatedPattern.firstMatch(in: text, range: range) != nil {
                return true
            }
        }

        return false
    }
}
