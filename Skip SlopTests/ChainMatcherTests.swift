import Testing
import MapKit
@testable import Skip_Slop

@Suite("ChainMatcher")
struct ChainMatcherTests {
    let database = ChainDatabase()

    @Test func databaseLoadsSeedChains() {
        #expect(database.chains.count > 100)
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
        let result = ChainMatcher.match(mapItem: makeMapItem(name), using: database)
        #expect(result?.chainSlug == expectedSlug)
    }

    @Test func matchCarriesChainRating() throws {
        let result = try #require(ChainMatcher.match(mapItem: makeMapItem("Olive Garden"), using: database))
        #expect(result.slopRating == .red)
        #expect(result.slopRating == result.chainInfo.slopRating)
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
