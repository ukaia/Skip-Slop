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
        let ordered: [Confidence] = [.known, .category, .high, .medium, .low]
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3, 4])
    }

    @Test func categoryEstimatedChainIsLabeledEstimated() throws {
        let database = ChainDatabase()
        let item = makeMapItem("Lazy Dog Restaurant & Bar", category: .restaurant)
        let match = try #require(ChainMatcher.match(mapItem: item, using: database))
        let result = RatingInferenceEngine.infer(mapItem: item, chainMatch: match)
        #expect(result.rating == .orange)
        #expect(result.confidence == .category)
        #expect(result.confidence.isEstimate)
    }

    @Test func onlyHandGradedChainsAreNotEstimates() {
        #expect(!Confidence.known.isEstimate)
        for confidence in [Confidence.category, .high, .medium, .low] {
            #expect(confidence.isEstimate)
        }
    }

    /// Keywords used to match inside words: "Breakfast" contained "fast",
    /// "Brewing" contained "wing", "Sacramento" contained "ramen".
    @Test(arguments: [
        ("The Breakfast Club", SlopRating.yellow),
        ("Deschutes Brewing", .yellow),
        ("Sacramento Street Grill", .yellow),
        ("Delicious Bites", .yellow),
        ("Phoenix Lounge", .yellow),
        ("Suburban Social", .yellow),
    ])
    func keywordsMatchWholeWordsOnly(name: String, rating: SlopRating) {
        #expect(infer(name).rating == rating)
    }

    @Test(arguments: [
        ("Pho Hoa", SlopRating.green),
        ("Best Tacos", .orange),
        ("Wings Over", .orange),
        ("Speedy Drive-Thru", .grey),
    ])
    func keywordsStillMatchWholeWordsAndPlurals(name: String, rating: SlopRating) {
        #expect(infer(name).rating == rating)
    }
}
