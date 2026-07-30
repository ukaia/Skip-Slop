import XCTest
@testable import Skip_Slop

/// Pins the behaviour of `ChainDatabase.match(name:)`.
///
/// The rating a restaurant shows is the whole product. A wrong red on an
/// independent is the failure that loses users, so the false positives below
/// are regression tests, not examples.
final class ChainDatabaseTests: XCTestCase {

    private var db: ChainDatabase!

    override func setUpWithError() throws {
        db = ChainDatabase(seedURL: try Self.seedURL())
        XCTAssertFalse(db.chains.isEmpty, "seed database failed to load")
    }

    /// Unit tests are hosted in the app, so the seed ships in `Bundle.main`.
    /// Fall back to the test bundle in case the host is ever removed.
    private static func seedURL() throws -> URL {
        let bundles = [Bundle.main, Bundle(for: ChainDatabaseTests.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: "SeedChains", withExtension: "json") {
                return url
            }
        }
        throw XCTSkip("SeedChains.json not found in host or test bundle")
    }

    // MARK: - False reds

    /// Each of these normalised to a string *containing* a chain name under the
    /// old substring matcher and inherited that chain's red rating.
    func testIndependentsAreNotStampedWithChainRatings() {
        for name in ["Longhorn Cafe", "Outback Trading Post Cafe", "Fridays Fish Fry"] {
            XCTAssertNil(
                db.match(name: name),
                "\(name) is an independent and must not match a chain"
            )
        }
    }

    /// The general rule behind those cases: a single shared token is too weak to
    /// justify asserting a supply chain about a named business.
    func testSingleTokenEvidenceNeverAssignsAnAccusatoryRating() {
        for (_, chain) in db.chains where chain.slopRating.isAccusatory {
            let tokens = ChainDatabase.tokenize(chain.name)
            guard tokens.count > 1, let first = tokens.first else { continue }
            let probe = "\(first) Cafe"
            // Skip probes that happen to spell a real chain name, e.g. Rainforest Cafe.
            guard ChainDatabase.tokenize(probe) != tokens else { continue }

            if let matched = db.match(name: probe) {
                XCTAssertFalse(
                    matched.slopRating.isAccusatory,
                    "\(probe) matched \(matched.slug) with accusatory rating \(matched.rating)"
                )
            }
        }
    }

    // MARK: - Chains must still match

    func testKnownChainsStillMatch() {
        let cases: [(String, String)] = [
            ("Olive Garden", "olive-garden"),
            ("Olive Garden Italian Restaurant", "olive-garden"),
            ("LongHorn Steakhouse", "longhorn-steakhouse"),
            ("Outback Steakhouse", "outback-steakhouse"),
            ("Red Lobster", "red-lobster"),
            ("Chipotle Mexican Grill", "chipotle"),
            ("McDonald's", "mcdonalds"),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(db.match(name: name)?.slug, expected, "lookup of \(name)")
        }
    }

    /// Guards the tokenizer against a change that silently breaks exact lookups.
    func testEveryChainMatchesItsOwnName() {
        for (slug, chain) in db.chains {
            XCTAssertEqual(db.match(name: chain.name)?.slug, slug, "self-match for \(chain.name)")
        }
    }

    // MARK: - Determinism

    /// The alias fallback used to iterate a Swift Dictionary, so a name matching
    /// two aliases could resolve differently between launches.
    func testMatchingIsDeterministic() {
        for name in ["Outback Steakhouse", "Olive Garden Italian Restaurant", "Longhorn Cafe"] {
            let results = Set((0..<200).map { _ in db.match(name: name)?.slug ?? "nil" })
            XCTAssertEqual(results.count, 1, "\(name) resolved inconsistently: \(results)")
        }
    }

    // MARK: - Tokenizer

    func testTokenizeSplitsOnWordBoundariesAndFoldsPossessives() {
        XCTAssertEqual(ChainDatabase.tokenize("Longhorn Cafe"), ["longhorn", "cafe"])
        XCTAssertEqual(ChainDatabase.tokenize("McDonald's"), ["mcdonalds"])
        XCTAssertEqual(ChainDatabase.tokenize("The Cheesecake Factory, Inc."), ["cheesecake", "factory"])
    }

    func testContiguousRunRequiresWholeTokensInOrder() {
        XCTAssertTrue(ChainDatabase.tokens(["olive", "garden"], formContiguousRunIn: ["olive", "garden", "italian"]))
        XCTAssertFalse(ChainDatabase.tokens(["olive", "garden"], formContiguousRunIn: ["garden", "olive"]))
        XCTAssertFalse(ChainDatabase.tokens(["longhorn", "steakhouse"], formContiguousRunIn: ["longhorn", "cafe"]))
        XCTAssertFalse(ChainDatabase.tokens([], formContiguousRunIn: ["anything"]))
    }
}
