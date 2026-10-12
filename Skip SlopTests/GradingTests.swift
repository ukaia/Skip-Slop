import Foundation
import CoreLocation
import MapKit
import Testing
@testable import Skip_Slop

/// Builds a prep report for roll-up tests.
func makeReport(
    _ verdict: PrepVerdict,
    _ evidence: PrepEvidence? = .sawPrep,
    reporter: String = UUID().uuidString,
    place: String = "place-1",
    note: String = "",
    dailyCount: Int = 1,
    reporterSince: Date = .now.addingTimeInterval(-30 * 24 * 3600),
    flagCount: Int = 0,
    updatedAt: Date = .now
) -> PrepReport {
    PrepReport(
        id: PrepReport.recordName(placeKey: place, reporterID: reporter),
        placeKey: place, reporterID: reporter, chainSlug: nil,
        verdict: verdict, evidence: evidence, note: note,
        createdAt: updatedAt, updatedAt: updatedAt,
        dayStamp: PrepReport.dayStamp(for: updatedAt), dailyCount: dailyCount,
        reporterSince: reporterSince, flagCount: flagCount
    )
}

@Suite("Community roll-up")
struct CommunityRollupTests {
    private func rollup(_ reports: [PrepReport], flagged: Set<String> = []) -> CommunityRollup {
        CommunityRollup.compute(reports: reports, flaggedReporters: flagged)
    }

    @Test func noGradeBelowFiveReports() {
        let r = rollup((0..<4).map { _ in makeReport(.scratch) })
        #expect(r.counted == 4)
        #expect(!r.qualifies)
        #expect(r.rating == nil)
        #expect(r.reportsNeeded == 1)
    }

    @Test func fiveFirsthandScratchReportsGradeA() {
        let r = rollup((0..<5).map { _ in makeReport(.scratch) })
        #expect(r.qualifies)
        // (5 + 1) / (5 + 2) = 0.857
        #expect(abs(r.scratchShare - 6.0 / 7.0) < 0.0001)
        #expect(r.rating == .green)
    }

    @Test func unsureReportsDontCount() {
        let reports = (0..<4).map { _ in makeReport(.scratch) } + (0..<3).map { _ in makeReport(.unsure, nil) }
        let r = rollup(reports)
        #expect(r.counted == 4)
        #expect(r.unsureCount == 3)
        #expect(!r.qualifies)
    }

    @Test func weakEvidenceNeedsMoreReports() {
        // Five "just my impression" reports weigh 2.5, under the 3.0 minimum.
        let r = rollup((0..<5).map { _ in makeReport(.scratch, .impression) })
        #expect(r.counted == 5)
        #expect(abs(r.totalWeight - 2.5) < 0.0001)
        #expect(!r.qualifies)
    }

    @Test(arguments: [
        (0.85, SlopRating.green), (0.8, .green), (0.7, .yellow), (0.6, .yellow),
        (0.5, .orange), (0.4, .orange), (0.3, .red), (0.1, .red),
    ])
    func shareMapsToGrade(share: Double, rating: SlopRating) {
        #expect(CommunityRollup.rating(forScratchShare: share, distributorShare: 0) == rating)
    }

    @Test func distributorEvidenceCanMakeFMinus() {
        #expect(CommunityRollup.rating(forScratchShare: 0.1, distributorShare: 0.6) == .redMinus)
        #expect(CommunityRollup.rating(forScratchShare: 0.1, distributorShare: 0.4) == .red)
        #expect(CommunityRollup.rating(forScratchShare: 0.2, distributorShare: 1) == .red)

        let r = rollup((0..<10).map { _ in makeReport(.reheated, .distributorBoxes) })
        #expect(r.rating == .redMinus)
    }

    @Test func communityNeverAwardsAPlus() {
        let r = rollup((0..<50).map { _ in makeReport(.scratch) })
        #expect(r.rating == .green)
    }

    @Test func loneDissenterIsDampedByConsensus() {
        // 8 scratch vs 1 reheated: the dissenter counts half.
        let reports = (0..<8).map { _ in makeReport(.scratch) } + [makeReport(.reheated)]
        let r = rollup(reports)
        #expect(abs(r.totalWeight - 8.5) < 0.0001)
        #expect(abs(r.scratchShare - 9.0 / 10.5) < 0.0001)
    }

    @Test func evenSplitIsNotDamped() {
        let reports = (0..<3).map { _ in makeReport(.scratch) } + (0..<3).map { _ in makeReport(.reheated) }
        let r = rollup(reports)
        #expect(abs(r.totalWeight - 6) < 0.0001)
        #expect(abs(r.scratchShare - 0.5) < 0.0001)
        #expect(r.rating == .orange)
    }

    @Test func evidenceWeightsFollowTheMethod() {
        #expect(PrepEvidence.workedHere.weight == 1)
        #expect(PrepEvidence.menuSays.weight == 0.75)
        #expect(PrepEvidence.impression.weight == 0.5)
        // Missing evidence counts as an impression.
        let r = rollup([makeReport(.scratch, nil)])
        #expect(abs(r.totalWeight - 0.5) < 0.0001)
    }

    @Test func percentDisplayUsesRawCounts() {
        let reports = (0..<6).map { _ in makeReport(.scratch) } + [makeReport(.reheated)]
        #expect(rollup(reports).scratchPercent == 86)
    }
}

@Suite("Community abuse rules")
struct AbuseRuleTests {
    @Test func oneReportPerReporter() {
        let old = makeReport(.reheated, reporter: "alice", updatedAt: .now.addingTimeInterval(-60))
        var new = makeReport(.scratch, reporter: "alice")
        new = PrepReport(id: old.id, placeKey: new.placeKey, reporterID: "alice", chainSlug: nil, verdict: .scratch,
                         evidence: .sawPrep, note: "", createdAt: old.createdAt, updatedAt: .now,
                         dayStamp: old.dayStamp, dailyCount: 1, reporterSince: old.reporterSince)
        let r = CommunityRollup.compute(reports: [old, new])
        #expect(r.counted == 1)
        #expect(r.scratchCount == 1)
        #expect(old.id == PrepReport.recordName(placeKey: "place-1", reporterID: "alice"))
    }

    @Test func recordNameIsDeterministicAndSafe() {
        let a = PrepReport.recordName(placeKey: "I6D1:6 4/x", reporterID: "_abc123")
        #expect(a == PrepReport.recordName(placeKey: "I6D1:6 4/x", reporterID: "_abc123"))
        #expect(a == "prep_I6D1-6-4-x__abc123")
        #expect(a.count <= 255)
    }

    @Test func flaggedReportersAreIgnored() {
        let reports = (0..<5).map { makeReport(.reheated, reporter: "bot\($0)") }
        let r = CommunityRollup.compute(reports: reports, flaggedReporters: ["bot0", "bot1"])
        #expect(r.counted == 3)
        #expect(r.ignoredCount == 2)
        #expect(!r.qualifies)
    }

    @Test func reportsPastTheDailyLimitAreIgnored() {
        let reports = (0..<5).map { makeReport(.reheated, dailyCount: 20 + $0) }
        let r = CommunityRollup.compute(reports: reports)
        #expect(r.counted == 1)
        #expect(r.ignoredCount == 4)
    }

    @Test func heavilyFlaggedReportsAreDropped() {
        let reports = [makeReport(.reheated, flagCount: 3), makeReport(.reheated, flagCount: 2)]
        let r = CommunityRollup.compute(reports: reports)
        #expect(r.counted == 1)
    }

    @Test func newReportersCountHalf() {
        let fresh = makeReport(.scratch, reporterSince: .now.addingTimeInterval(-3600))
        let r = CommunityRollup.compute(reports: [fresh])
        #expect(abs(r.totalWeight - 0.5) < 0.0001)
    }

    @Test func localRateLimiterStopsAtTwentyPerDay() throws {
        let defaults = try #require(UserDefaults(suiteName: "RateLimiterTests-\(UUID().uuidString)"))
        let limiter = ReportRateLimiter(defaults: defaults)
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for n in 1...20 {
            #expect(limiter.canFileNewReport(now: day))
            #expect(limiter.recordNewReport(now: day) == n)
        }
        #expect(!limiter.canFileNewReport(now: day))
        #expect(limiter.canFileNewReport(now: day.addingTimeInterval(24 * 3600)))
        #expect(limiter.firstReport == day)
    }

    @Test func dayStampIsUTC() {
        #expect(PrepReport.dayStamp(for: Date(timeIntervalSince1970: 0)) == "1970-01-01")
    }
}

@Suite("Grade resolver")
struct GradeResolverTests {
    private func cited(_ rating: SlopRating, _ confidence: GradeConfidence) -> GradeAssessment {
        GradeAssessment(rating: rating, kind: .cited(confidence), basis: "basis", sources: [])
    }

    private func community(_ verdict: PrepVerdict, count: Int) -> CommunityRollup {
        CommunityRollup.compute(reports: (0..<count).map { _ in makeReport(verdict) })
    }

    @Test func nothingMeansNotGraded() {
        let a = GradeResolver.resolve(cited: nil, community: nil)
        #expect(a.kind == .notGraded)
        #expect(a.rating == .notGraded)
        #expect(a.label == "Not graded yet")
    }

    @Test func communityGradesAnUngradedPlace() {
        let a = GradeResolver.resolve(cited: nil, community: community(.scratch, count: 5))
        #expect(a.kind == .community(reports: 5))
        #expect(a.rating == .green)
        #expect(a.label == "Community grade · 5 reports")
    }

    @Test func tooFewReportsStayNotGradedButKeepProgress() {
        let a = GradeResolver.resolve(cited: nil, community: community(.scratch, count: 3))
        #expect(a.kind == .notGraded)
        #expect(a.supplement?.counted == 3)
    }

    @Test func communityNeverOverridesHighConfidence() {
        let a = GradeResolver.resolve(cited: cited(.red, .high), community: community(.scratch, count: 40))
        #expect(a.kind == .cited(.high))
        #expect(a.rating == .red)
        #expect(a.supplement?.counted == 40)
    }

    @Test func mediumConfidenceNeedsTenReports() {
        let nine = GradeResolver.resolve(cited: cited(.red, .medium), community: community(.scratch, count: 9))
        #expect(nine.rating == .red)
        let ten = GradeResolver.resolve(cited: cited(.red, .medium), community: community(.scratch, count: 10))
        #expect(ten.kind == .community(reports: 10))
        #expect(ten.rating == .green)
    }

    @Test func lowConfidenceYieldsToFiveReports() {
        let a = GradeResolver.resolve(cited: cited(.red, .low), community: community(.scratch, count: 5))
        #expect(a.isCommunity)
        #expect(a.rating == .green)
    }

    @Test func sortOrderPutsEvidenceFirst() {
        let order = [cited(.red, .high), cited(.red, .low), GradeResolver.resolve(cited: nil, community: community(.scratch, count: 5)), .notGraded]
        #expect(order.map(\.sortOrder) == order.map(\.sortOrder).sorted())
    }
}

@Suite("Chain data integrity")
struct ChainDataIntegrityTests {
    let database = ChainDatabase()

    @Test func everyGradeHasCitationsConfidenceAndBasis() {
        let graded = database.chains.values.filter(\.isGraded)
        #expect(graded.count > 100)
        for chain in graded {
            #expect(chain.confidence != nil, "\(chain.slug) has no confidence")
            #expect(chain.basis?.isEmpty == false, "\(chain.slug) has no basis")
            #expect(chain.sources?.isEmpty == false, "\(chain.slug) has no sources")
            for source in chain.sources ?? [] {
                #expect(source.url.scheme == "https", "\(chain.slug): \(source.url)")
                #expect([1, 2, 3].contains(source.tier ?? 0), "\(chain.slug): bad tier")
                #expect(!source.title.isEmpty)
            }
        }
    }

    @Test func ungradedChainsCarryNoGradeFields() {
        for chain in database.chains.values where !chain.isGraded {
            #expect(chain.confidence == nil && chain.basis == nil && chain.sources == nil, "\(chain.slug)")
        }
    }

    @Test func noChainIsGradedNotGraded() {
        #expect(!database.chains.values.contains { $0.grade == SlopRating.notGraded.rawValue })
    }

    /// Spot checks that the evidence made it through the pipeline.
    @Test(arguments: [
        ("texas-roadhouse", SlopRating.green), ("mcdonalds", .red), ("chipotle", .yellow),
        ("cheesecake-factory", .green), ("applebees", .red), ("sweetgreen", .greenPlus),
        ("olive-garden", .orange), ("taco-bell", .red), ("in-n-out", .green),
    ])
    func knownGrades(slug: String, rating: SlopRating) throws {
        let chain = try #require(database.lookup(slug: slug))
        #expect(chain.citedRating == rating, "\(slug)")
    }

    @Test func everyIndependentGradeIsCitedAndLocated() {
        let store = IndependentGradeStore.shared
        #expect(store.entries.count >= 5)
        for entry in store.entries {
            #expect(entry.rating.isGraded, "\(entry.id)")
            #expect(!entry.sources.isEmpty && !entry.basis.isEmpty, "\(entry.id)")
            #expect(abs(entry.latitude) > 0.1 && abs(entry.longitude) > 0.1, "\(entry.id)")
        }
    }
}

@Suite("Independent matching")
struct IndependentMatchingTests {
    let store = IndependentGradeStore.shared

    @Test func matchesByNameAndLocation() throws {
        let match = try #require(store.match(name: "Chez Panisse", coordinate: .init(latitude: 37.87962, longitude: -122.26895)))
        #expect(match.id == "chez-panisse")
        #expect(match.rating == .greenPlus)
    }

    @Test func toleratesDescriptorsAndAliases() {
        #expect(store.match(name: "Screen Door Restaurant", coordinate: .init(latitude: 45.52303, longitude: -122.64168))?.id == "screen-door-eastside")
        #expect(store.match(name: "Zuni Cafe", coordinate: .init(latitude: 37.77356, longitude: -122.42164))?.id == "zuni-cafe")
    }

    @Test func sameNameElsewhereIsNotMatched() {
        // A different "Blue Hill" across the country stays ungraded.
        #expect(store.match(name: "Blue Hill", coordinate: .init(latitude: 44.41, longitude: -68.59)) == nil)
    }

    @Test func differentNameNearbyIsNotMatched() {
        #expect(store.match(name: "Le Petit Pigeon Cafe", coordinate: .init(latitude: 45.52280, longitude: -122.65784)) == nil)
    }

    @Test func independentsWithoutEvidenceAreNotGraded() {
        let database = ChainDatabase()
        for name in ["Luigi's Trattoria", "Mama Rosa", "Golden Dragon Dim Sum", "Joe's", "Farm to Table Kitchen"] {
            let rated = RatedMapItem.rate(makeMapItem(name, category: .restaurant), database: database, independents: store)
            #expect(rated.cited == nil, "\(name)")
            #expect(GradeResolver.resolve(cited: rated.cited, community: nil).kind == .notGraded, "\(name)")
        }
    }
}

@Suite("Prep report store")
struct PrepReportStoreTests {
    private func makeStore(seed: [PrepReport] = []) throws -> PrepReportStore {
        let defaults = try #require(UserDefaults(suiteName: "PrepStoreTests-\(UUID().uuidString)"))
        return PrepReportStore(backend: InMemoryPrepReportBackend(seed: seed, reporterID: "me"), defaults: defaults)
    }

    @Test func submittingTwiceEditsTheSameReport() async throws {
        let store = try makeStore()
        try await store.submit(placeKey: "p", chainSlug: nil, verdict: .reheated, evidence: .frozenBoxes, note: "")
        try await store.submit(placeKey: "p", chainSlug: nil, verdict: .scratch, evidence: .sawPrep, note: "Saw them roll the dough")
        let reports = store.reports["p"] ?? []
        #expect(reports.count == 1)
        #expect(reports.first?.verdict == .scratch)
        #expect(reports.first?.id == PrepReport.recordName(placeKey: "p", reporterID: "me"))
        #expect(store.myReport(for: "p")?.note == "Saw them roll the dough")
    }

    @Test func blockedLanguageIsRejected() async throws {
        let store = try makeStore()
        await #expect(throws: PrepReportError.notAllowed) {
            try await store.submit(placeKey: "p", chainSlug: nil, verdict: .scratch, evidence: nil, note: "what a load of shit")
        }
        #expect(store.reports["p"] == nil)
    }

    @Test func unsureDropsEvidence() async throws {
        let store = try makeStore()
        try await store.submit(placeKey: "p", chainSlug: nil, verdict: .unsure, evidence: .sawPrep, note: "")
        #expect(store.myReport(for: "p")?.evidence == nil)
    }

    @Test func rollupUpdatesAfterLoadAndSubmit() async throws {
        let seed = (0..<4).map { makeReport(.scratch, reporter: "r\($0)", place: "p") }
        let store = try makeStore(seed: seed)
        await store.load(placeKey: "p")
        #expect(store.rollup(for: "p")?.qualifies == false)
        try await store.submit(placeKey: "p", chainSlug: nil, verdict: .scratch, evidence: .menuSays, note: "")
        #expect(store.rollup(for: "p")?.qualifies == true)
        #expect(store.rollup(for: "p")?.rating == .green)
    }

    @Test func flaggingIsOncePerUserAndNotOwnNotes() async throws {
        let other = makeReport(.reheated, reporter: "someone", place: "p", note: "Spam spam")
        let store = try makeStore(seed: [other])
        await store.load(placeKey: "p")
        await store.flag(other)
        await store.flag(other)
        #expect(store.flaggedByMe.contains(other.id))
        await store.load(placeKey: "p")
        #expect(store.reports["p"]?.first?.flagCount == 1)

        try await store.submit(placeKey: "p", chainSlug: nil, verdict: .scratch, evidence: nil, note: "Mine")
        let mine = try #require(store.myReport(for: "p"))
        await store.flag(mine)
        #expect(!store.flaggedByMe.contains(mine.id))
    }

    @Test func notesHideAfterThreeFlags() async throws {
        let hidden = makeReport(.reheated, reporter: "a", place: "p", note: "bad", flagCount: 3)
        let shown = makeReport(.scratch, reporter: "b", place: "p", note: "good")
        let store = try makeStore(seed: [hidden, shown])
        await store.load(placeKey: "p")
        #expect(store.notes(for: "p").map(\.note) == ["good"])
    }
}
