import Testing
import MapKit
@testable import Skip_Slop

@Suite("ChainMatcher")
struct ChainMatcherTests {
    let database = ChainDatabase()

    private func slug(_ name: String, category: MKPointOfInterestCategory? = .restaurant) -> String? {
        ChainMatcher.match(mapItem: makeMapItem(name, category: category), using: database)?.chainSlug
    }

    @Test func databaseLoadsSeedChains() {
        #expect(database.chains.count > 900)
    }

    @Test(arguments: [
        ("McDonald's", "mcdonalds"),
        ("MCDONALDS", "mcdonalds"),
        ("Olive Garden Italian Restaurant", "olive-garden"),
        ("The Cheesecake Factory", "cheesecake-factory"),
        ("Chipotle", "chipotle"),
        ("Chick fil A", "chick-fil-a"),
        ("BDubs", "buffalo-wild-wings"),
    ])
    func matchesKnownChains(name: String, expectedSlug: String) {
        #expect(slug(name, category: nil) == expectedSlug)
    }

    /// Names as MapKit returned them in the verification run (docs/verification).
    @Test(arguments: [
        ("Starbucks Coffee Company", "starbucks"),
        ("Taco Bell Cantina", "taco-bell"),
        ("Shake Shack West End Portland", "shake-shack"),
        ("Popeyes Louisiana Kitchen", "popeyes"),
        ("Raising Cane's Chicken Fingers", "raising-canes"),
        ("Jersey Mike's Subs", "jersey-mikes"),
        ("Lou Malnati's Pizzeria", "lou-malnatis"),
        ("Dunkin'", "dunkin"),
        ("Krispy Kreme Doughnuts", "krispy-kreme"),
        ("Smashburger", "smashburger"),
        ("Paris Baguette", "paris-baguette"),
        ("Insomnia Cookies", "insomnia-cookies"),
        ("Cinnabon", "cinnabon"),
        ("Dickey's Barbecue Pit", "dickeys-barbecue-pit"),
        ("Le Pain Quotidien", "le-pain-quotidien"),
        ("Tous Les Jours", "tous-les-jours"),
        ("Xi'an Famous Foods", "xian-famous-foods"),
        ("Intelligentsia", "intelligentsia-coffee-and-tea"),
        ("La Colombe Coffee Roasters", "la-colombe-coffee-roasters"),
        ("Pizza Patrón", "pizza-patron"),
        ("Gino’s East", "ginos-east"),
    ])
    func matchesRealWorldVariants(name: String, expectedSlug: String) {
        #expect(slug(name) == expectedSlug)
    }

    @Test(arguments: [
        ("Wendy's #4512", "wendys"),
        ("Chipotle Mexican Grill - Downtown", "chipotle"),
        ("Subway (Inside Walmart)", "subway"),
        ("KFC/Taco Bell", "kfc"),
        ("Sonic Drive-In", "sonic"),
        ("PIZZA HUT EXPRESS", "pizza-hut"),
        ("Café Rio Mexican Grill", "cafe-rio"),
        ("McDonald's Restaurant", "mcdonalds"),
        ("Jack's", "jacks"),
    ])
    func stripsSuffixesStoreNumbersAndCombos(name: String, expectedSlug: String) {
        #expect(slug(name) == expectedSlug)
    }

    /// The old substring matcher matched all of these (see docs/verification).
    @Test(arguments: [
        "Palmer House",          // was The Palm
        "Palmieri Cafe",         // was The Palm
        "The Star",              // was Starbucks
        "Ca Va Marche",          // was CAVA
        "The Village",           // was Village Inn
        "Taqueria El Torito",    // was El Torito
        "Pizza",
        "Burger Bar",
        "Coffee Shop",
        "Joe's",
        "Paul Martin's American Grill",
        "Moe's Original BBQ",
        "Longhorn Cafe",
        "Dig Deep Cafe",
        "Wing Squad",
        "Subs & Suds",
        "Jack's Pizza",            // matched Jack's (burger chain) in the verification run
        "La Salsa Verde Taqueria", // matched La Salsa
    ])
    func doesNotMatchLookalikes(name: String) {
        #expect(slug(name) == nil)
    }

    @Test func prefixMatchesOnlyFoodCategories() {
        #expect(slug("Shake Shack West End", category: .restaurant) == "shake-shack")
        #expect(slug("Shake Shack West End", category: .hotel) == nil)
        // Exact names still match whatever MapKit filed them under.
        #expect(slug("Starbucks", category: .store) == "starbucks")
    }

    @Test func normalizeFoldsCaseDiacriticsAndPunctuation() {
        #expect(ChainDatabase.normalize("Café Rio") == "cafe rio")
        #expect(ChainDatabase.normalize("McDonald’s") == "mcdonalds")
        #expect(ChainDatabase.normalize("P.F. Chang's") == "p f changs")
        #expect(ChainDatabase.normalize("The Cheesecake Factory") == "cheesecake factory")
        #expect(ChainDatabase.normalize("Noodles & Company") == "noodles and company")
    }

    @Test func researchedChainCarriesCitedGrade() throws {
        let olive = try #require(database.lookup(slug: "olive-garden"))
        #expect(olive.citedRating == .orange)
        #expect(olive.provenance == "curated")
        #expect(olive.confidence != nil)
        #expect(olive.sources?.isEmpty == false)
    }

    @Test func unresearchedChainsAreNotGraded() throws {
        let sitDown = try #require(database.lookup(slug: "lazy-dog-restaurant-and-bar"))
        #expect(sitDown.provenance != "curated")
        #expect(!sitDown.isGraded)
        #expect(GradeResolver.assessment(for: sitDown) == nil)
    }

    @Test func matchCarriesChainInfo() throws {
        let result = try #require(ChainMatcher.match(mapItem: makeMapItem("Olive Garden"), using: database))
        #expect(result.chainInfo.slug == "olive-garden")
        #expect(GradeResolver.assessment(for: result.chainInfo)?.rating == .orange)
    }

    @Test func unknownRestaurantDoesNotMatch() {
        #expect(ChainMatcher.match(mapItem: makeMapItem("Zzyzx Noodle Cart"), using: database) == nil)
    }

    @Test func itemWithoutNameDoesNotMatch() {
        #expect(ChainMatcher.match(mapItem: makeMapItem(nil), using: database) == nil)
    }

    @Test func restaurantIDIsDeterministicAndIncludesSlug() {
        let a = ChainMatcher.restaurantID(for: makeMapItem("Olive Garden"), chainSlug: "olive-garden")
        let b = ChainMatcher.restaurantID(for: makeMapItem("Olive Garden"), chainSlug: "olive-garden")
        #expect(a == b)
        #expect(a.hasPrefix("olive-garden_"))

        let independent = ChainMatcher.restaurantID(for: makeMapItem("Joe's"), chainSlug: nil)
        #expect(independent.hasPrefix("independent_"))
    }

    @Test func restaurantIDDiffersByLocation() {
        let a = ChainMatcher.restaurantID(for: makeMapItem("X", latitude: 37.0), chainSlug: nil)
        let b = ChainMatcher.restaurantID(for: makeMapItem("X", latitude: 38.0), chainSlug: nil)
        #expect(a != b)
    }
}
