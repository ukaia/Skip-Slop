import Testing
@testable import Skip_Slop

@Suite("ContentFilter")
struct ContentFilterTests {
    @Test(arguments: [
        "",
        "Fries were clearly frozen, burger was fine.",
        "The shiitake mushrooms tasted fresh",
        "Reading Dickens while waiting for food",
        "I PAID $30 FOR A BURGER",
        "BEST burger in town, made from fresh beef every morning",
        "Sysco truck out back at 7am",
    ])
    func allowsLegitimateNotes(text: String) {
        #expect(!ContentFilter.containsInappropriateContent(text))
    }

    @Test(arguments: [
        "this place is fucking awful",
        "what a load of shit",
        "check out www.example.com for deals",
        "call me at 555-123-4567",
        "THIS PLACE SERVES FROZEN SYSCO GARBAGE",
        "nooooooo not again",
    ])
    func blocksInappropriateNotes(text: String) {
        #expect(ContentFilter.containsInappropriateContent(text))
    }

    @Test func rejectsOverlongNotes() {
        #expect(ContentFilter.containsInappropriateContent(String(repeating: "ab ", count: 200)))
    }

    @Test func screamingIgnoresDigitsAndCurrency() {
        // 15 letters — too short to count as screaming, regardless of digits.
        #expect(!ContentFilter.isScreaming("I PAID $30 FOR A BURGER 12345678901234567890"))
        // 20+ letters, all uppercase.
        #expect(ContentFilter.isScreaming("ABSOLUTELY DISGUSTING FOOD $$$ 100%"))
        // 20+ letters but only mostly uppercase.
        #expect(!ContentFilter.isScreaming("ABSOLUTELY DISGUSTING FOOd and service"))
    }
}
