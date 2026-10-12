import Testing
import MapKit
@testable import Skip_Slop

@Suite("RatingInferenceEngine")
struct RatingInferenceEngineTests {
    typealias Confidence = RatingInferenceEngine.InferenceResult.Confidence

    private func infer(_ name: String, category: MKPointOfInterestCategory? = nil) -> RatingInferenceEngine.InferenceResult {
        RatingInferenceEngine.infer(mapItem: makeMapItem(name, category: category), chainMatch: nil)
    }

    @Test func knownChainUsesChainRatingWithKnownConfidence() throws {
        let database = ChainDatabase()
        let item = makeMapItem("The Cheesecake Factory")
        let match = try #require(ChainMatcher.match(mapItem: item, using: database))
        let result = RatingInferenceEngine.infer(mapItem: item, chainMatch: match)
        #expect(result.rating == .redMinus)
        #expect(result.confidence == .known)
    }

    @Test(arguments: [
        ("Luigi's Trattoria", SlopRating.green, Confidence.medium),
        ("Golden Dragon Dim Sum", .green, .medium),
        ("Speedy Express", .grey, .high),
        ("Blue Bottle Coffee", .grey, .high),
        ("Generic Burger", .orange, .low),
        ("Prime Cuts", .orange, .low),
        ("Chef Table", .green, .medium),
        ("Mama Rosa", .green, .medium),
        ("Joe's", .green, .low),
        ("Downtown Burger", .yellow, .low),
    ])
    func nameHeuristics(name: String, rating: SlopRating, confidence: Confidence) {
        let result = infer(name)
        #expect(result.rating == rating)
        #expect(result.confidence == confidence)
    }

    @Test func cafeCategoryIsGrey() {
        let result = infer("Morning Spot", category: .cafe)
        #expect(result.rating == .grey)
        #expect(result.confidence == .high)
    }

    @Test func plainSitDownRestaurantGetsBenefitOfDoubt() {
        let result = infer("Zzyzx", category: .restaurant)
        #expect(result.rating == .yellow)
        #expect(result.confidence == .low)
    }

    @Test func bakeryLeansGreen() {
        let result = infer("Zzyzx", category: .bakery)
        #expect(result.rating == .green)
        #expect(result.confidence == .medium)
    }

    @Test func unknownDefaultsToYellowNotGrey() {
        let result = infer("Zzyzx")
        #expect(result.rating == .yellow)
        #expect(result.confidence == .low)
    }

    @Test func confidenceSortOrderIsAscending() {
        let ordered: [Confidence] = [.known, .high, .medium, .low]
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3])
    }
}
