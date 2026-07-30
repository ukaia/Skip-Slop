import XCTest
@testable import Skip_Slop

/// `ContentFilter` used to return a bare `Bool`, so every rejection reached the
/// author as "your note contains language that isn't allowed" — including a note
/// whose only problem was being long. These pin each reason to its own case.
final class ContentFilterTests: XCTestCase {

    func testLongNoteIsRejectedForLengthNotLanguage() {
        let polite = String(repeating: "a", count: ContentFilter.maxLength + 1)
        XCTAssertEqual(
            ContentFilter.rejectionReason(for: polite),
            .tooLong(limit: ContentFilter.maxLength),
            "an over-length note must not be reported as inappropriate language"
        )
    }

    func testNoteAtTheLimitIsAccepted() {
        // Real prose, not a repeated character — a run of one letter trips the
        // repeated-character rule and would test the wrong thing.
        let sentence = "The steaks here are cut in house and it shows on the plate. "
        var atLimit = String(repeating: sentence, count: 20)
        atLimit = String(atLimit.prefix(ContentFilter.maxLength))

        XCTAssertEqual(atLimit.count, ContentFilter.maxLength)
        XCTAssertNil(ContentFilter.rejectionReason(for: atLimit))
    }

    func testEmptyIsAccepted() {
        // Some note types (e.g. "I saw the Sysco truck") carry no body.
        XCTAssertNil(ContentFilter.rejectionReason(for: ""))
    }

    func testOrdinaryNotesPass() {
        let notes = [
            "Paid $32 for a burger that tasted reheated.",
            "Tip options started at 22% before tax.",
            "They butcher in house — the steaks are real.",
        ]
        for note in notes {
            XCTAssertNil(ContentFilter.rejectionReason(for: note), "should accept: \(note)")
        }
    }

    func testShoutingIsReportedAsShouting() {
        XCTAssertEqual(
            ContentFilter.rejectionReason(for: "THIS PLACE IS ABSOLUTELY TERRIBLE FOOD"),
            .shouting
        )
    }

    /// Price notes are legitimately shouty and must not be swallowed by the caps rule.
    func testCurrencyNotesAreExemptFromShoutingRule() {
        XCTAssertNil(ContentFilter.rejectionReason(for: "I PAID $30 FOR THIS SLOP HONESTLY"))
    }

    func testRepeatedCharactersAreReportedSeparately() {
        XCTAssertEqual(ContentFilter.rejectionReason(for: "noooooo way"), .repeatedCharacters)
    }

    func testBlockedLanguageIsStillCaught() {
        XCTAssertEqual(ContentFilter.rejectionReason(for: "what the fuck is this"), .blockedLanguage)
    }

    /// "shiitake" must survive the profanity pattern that guards against "shit".
    func testLegitimateWordsAreNotFalsePositives() {
        XCTAssertNil(ContentFilter.rejectionReason(for: "great shiitake mushrooms here"))
    }

    func testEveryRejectionHasDistinctUserFacingText() {
        let reasons: [ContentFilter.Rejection] = [
            .tooLong(limit: 500), .blockedLanguage, .shouting, .repeatedCharacters,
        ]
        XCTAssertEqual(Set(reasons.map(\.title)).count, reasons.count)
        XCTAssertEqual(Set(reasons.map(\.message)).count, reasons.count)
    }

    func testBoolWrapperStillAgreesWithReason() {
        for text in ["", "fine note", "what the fuck", String(repeating: "a", count: 600)] {
            XCTAssertEqual(
                ContentFilter.containsInappropriateContent(text),
                ContentFilter.rejectionReason(for: text) != nil,
                "wrapper disagreed for: \(text.prefix(20))"
            )
        }
    }
}
