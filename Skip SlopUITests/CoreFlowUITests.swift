import XCTest

/// Core user flows. Most run on sample data (`-mockData YES`), which keeps notes
/// and votes on the device so the tests work in unsigned builds without iCloud.
/// The location tests use the real map, search, and the simulator's location.
final class CoreFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private func button(in app: XCUIApplication, labelPrefix prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private var springboardAlert: XCUIElement {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
    }

    /// Answers the location prompt if it shows up.
    @MainActor
    private func answerLocationPrompt(allow: Bool) {
        let alert = springboardAlert
        guard alert.waitForExistence(timeout: 5) else { return }
        let label = allow ? "Allow While Using App" : "Don"
        alert.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch.tap()
    }

    // MARK: - Onboarding

    @MainActor
    func testOnboardingWalksThroughToTheMap() {
        XCUIApplication().resetAuthorizationStatus(for: .location)
        let app = launch(["-showOnboarding", "YES", "-mockData", "YES"])

        XCTAssertTrue(app.staticTexts["Grade the slop before you eat it"].waitForExistence(timeout: timeout))
        app.buttons["Next"].tap()

        XCTAssertTrue(app.staticTexts["See what's around you"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Allow Location"].exists)
        app.buttons["Not Now"].tap()

        XCTAssertTrue(app.staticTexts["Snitch on the slop"].waitForExistence(timeout: timeout))
        app.buttons["Start Exploring"].tap()

        XCTAssertTrue(app.textFields["Search places, cities, or zip codes"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testOnboardingCanBeSkipped() {
        let app = launch(["-showOnboarding", "YES", "-mockData", "YES"])
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: timeout))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.textFields["Search places, cities, or zip codes"].waitForExistence(timeout: timeout))
    }

    // MARK: - Search, filter, detail

    @MainActor
    func testTypingFiltersTheList() {
        let app = launch(["-UITestScreenshots", "YES"])
        let field = app.textFields["Search places, cities, or zip codes"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("Olive")

        XCTAssertTrue(button(in: app, labelPrefix: "Olive Garden").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["1 place nearby"].waitForExistence(timeout: timeout))
        XCTAssertFalse(button(in: app, labelPrefix: "Taco Bell").exists)
    }

    @MainActor
    func testGradeFilterShowsOnlyThatGrade() {
        let app = launch(["-UITestScreenshots", "YES"])
        let field = app.textFields["Search places, cities, or zip codes"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap() // focusing search expands the sheet

        let chip = app.switches["Grade F, Sysco Slop"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: timeout))
        chip.tap()

        XCTAssertTrue(button(in: app, labelPrefix: "Olive Garden").waitForExistence(timeout: timeout))
        XCTAssertFalse(button(in: app, labelPrefix: "Taco Bell").exists)
        XCTAssertFalse(button(in: app, labelPrefix: "Shake Shack").exists)
    }

    @MainActor
    func testDetailShowsGradeAndHowItWasGraded() {
        let app = launch(["-UITestScreenshots", "YES"])
        let field = app.textFields["Search places, cities, or zip codes"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("Olive")
        // The map pin has the same label; tap the list row.
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Olive Garden"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: timeout))
        let row = rows.allElementsBoundByIndex.first { $0.isHittable } ?? rows.firstMatch
        row.tap()

        XCTAssertTrue(app.staticTexts["How we graded it"].waitForExistence(timeout: timeout))
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any.matching(NSPredicate(format: "label CONTAINS %@", "Known chain")).firstMatch.exists)
        XCTAssertTrue(any.matching(NSPredicate(format: "label CONTAINS %@", "Sysco Slop")).firstMatch.exists)
    }

    // MARK: - Notes and votes

    @MainActor
    func testPostNoteThenVoteOnIt() {
        let app = launch(["-UITestScreenshots", "YES", "-openDetail", "YES"])
        let addNote = app.buttons["Add a Note"]
        XCTAssertTrue(addNote.waitForExistence(timeout: timeout))
        addNote.tap()

        XCTAssertTrue(app.navigationBars["New Note"].waitForExistence(timeout: timeout))
        app.buttons["Post"].tap()
        XCTAssertTrue(app.navigationBars["New Note"].waitForNonExistence(timeout: timeout))

        let upvote = app.buttons["Upvote"].firstMatch
        XCTAssertTrue(upvote.waitForExistence(timeout: timeout))
        XCTAssertEqual(upvote.value as? String, "0 votes")
        upvote.tap()
        XCTAssertTrue(waitForValue(upvote, "1 vote"))

        // Tapping again removes the vote: one vote per person.
        upvote.tap()
        XCTAssertTrue(waitForValue(upvote, "0 votes"))
    }

    @MainActor
    func testNoteWithBlockedLanguageIsNotPosted() {
        let app = launch(["-UITestScreenshots", "YES", "-openDetail", "YES"])
        XCTAssertTrue(app.buttons["Add a Note"].waitForExistence(timeout: timeout))
        app.buttons["Add a Note"].tap()

        app.buttons["Expensive Confirmed"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("what a load of shit")
        app.buttons["Post"].tap()

        XCTAssertTrue(app.alerts["Note Not Posted"].waitForExistence(timeout: timeout))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsOpensAndShowsGuide() {
        let app = launch(["-UITestScreenshots", "YES"])
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Notes posted"].exists)
        app.buttons["Rating Guide"].tap()
        XCTAssertTrue(app.navigationBars.element(boundBy: 0).waitForExistence(timeout: timeout))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForNonExistence(timeout: timeout))
    }

    // MARK: - Location (real map search)

    @MainActor
    func testLocationDeniedShowsFallback() {
        XCUIApplication().resetAuthorizationStatus(for: .location)
        let app = launch(["-skipOnboarding", "YES", "-noCloudKit", "YES"])
        answerLocationPrompt(allow: false)

        let card = app.staticTexts["Location is off"]
        if !card.waitForExistence(timeout: timeout) {
            app.buttons["Show my location"].tap() // raises the sheet when location is off
        }
        XCTAssertTrue(card.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.textFields["Search places, cities, or zip codes"].exists)
    }

    /// Needs network and a simulated location (`xcrun simctl location <udid> set 30.2672,-97.7431`).
    @MainActor
    func testRealLocationLoadsNearbyPlaces() {
        XCUIApplication().resetAuthorizationStatus(for: .location)
        let app = launch(["-skipOnboarding", "YES", "-noCloudKit", "YES"])
        answerLocationPrompt(allow: true)
        let field = app.textFields["Search places, cities, or zip codes"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap() // focusing search raises the sheet so the list is on screen

        let header = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'nearby'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 30), "No places loaded from MapKit")
        let count = Int(header.label.split(separator: " ").first ?? "") ?? 0
        XCTAssertGreaterThan(count, 25, "Nearby search should return more than one MapKit page")
    }
}
