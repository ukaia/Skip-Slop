import Foundation
import MapKit
import Testing
@testable import Skip_Slop

/// Runs well-known places through the real matcher and grade resolver and
/// compares the result with the grade a reviewer assigned by reading the
/// cited evidence (docs/verification/grading-validation.md).
///
/// Set TEST_RUNNER_SKIPSLOP_VALIDATION=<dir> to also write the results to
/// <dir>/grading-validation.csv.
@Suite("Grading validation")
struct GradingValidationTests {
    nonisolated struct Case: Sendable, CustomStringConvertible {
        let name: String
        let latitude: Double
        let longitude: Double
        /// Letter grade a reviewer expects from the evidence, or "–" for not graded.
        let expected: String
        var description: String { name }
    }

    // Chains are placed in Austin; MapKit-style names on purpose.
    nonisolated static let cases: [Case] = [
        // Independents with cited evidence
        Case(name: "Chez Panisse", latitude: 37.87960, longitude: -122.26897, expected: "A+"),
        Case(name: "Blue Hill", latitude: 40.73204, longitude: -73.99957, expected: "A+"),
        Case(name: "Le Pigeon", latitude: 45.52280, longitude: -122.65784, expected: "A"),
        Case(name: "Ava Gene's", latitude: 45.50502, longitude: -122.62989, expected: "A+"),
        Case(name: "Screen Door", latitude: 45.52303, longitude: -122.64168, expected: "A"),
        Case(name: "Husk", latitude: 32.77802, longitude: -79.93214, expected: "A+"),
        Case(name: "Zuni Café", latitude: 37.77356, longitude: -122.42165, expected: "A+"),
        Case(name: "Franklin Barbecue", latitude: 30.27015, longitude: -97.73128, expected: "A"),
        // Independents with no evidence collected: must not be guessed or mismatched to a chain
        Case(name: "Pine State Biscuits", latitude: 45.51230, longitude: -122.61344, expected: "–"),
        Case(name: "Joe's Pizza", latitude: 40.73060, longitude: -74.00213, expected: "–"),
        Case(name: "Veracruz All Natural", latitude: 30.25700, longitude: -97.72600, expected: "–"),
        // Sit-down chains
        Case(name: "The Cheesecake Factory", latitude: 30.2655, longitude: -97.7389, expected: "A"),
        Case(name: "Applebee's Grill + Bar", latitude: 30.2611, longitude: -97.7461, expected: "F"),
        Case(name: "Chili's Grill & Bar", latitude: 30.2620, longitude: -97.7470, expected: "F"),
        Case(name: "Olive Garden Italian Restaurant", latitude: 30.2701, longitude: -97.7462, expected: "C"),
        Case(name: "Texas Roadhouse", latitude: 30.2600, longitude: -97.7400, expected: "A"),
        Case(name: "Red Lobster", latitude: 30.2610, longitude: -97.7410, expected: "F"),
        Case(name: "Outback Steakhouse", latitude: 30.2630, longitude: -97.7430, expected: "B"),
        Case(name: "Cracker Barrel Old Country Store", latitude: 30.2640, longitude: -97.7440, expected: "A"),
        Case(name: "Denny's", latitude: 30.2650, longitude: -97.7450, expected: "F"),
        Case(name: "IHOP", latitude: 30.2660, longitude: -97.7460, expected: "B"),
        Case(name: "P.F. Chang's", latitude: 30.2684, longitude: -97.7370, expected: "A"),
        Case(name: "TGI Fridays", latitude: 30.2670, longitude: -97.7470, expected: "F"),
        Case(name: "Waffle House", latitude: 30.2680, longitude: -97.7480, expected: "B"),
        // Fast casual and fast food
        Case(name: "McDonald's", latitude: 30.2690, longitude: -97.7490, expected: "F"),
        Case(name: "In-N-Out Burger", latitude: 30.2700, longitude: -97.7500, expected: "A"),
        Case(name: "Chipotle Mexican Grill", latitude: 30.2689, longitude: -97.7415, expected: "B"),
        Case(name: "Panera Bread", latitude: 30.2638, longitude: -97.7448, expected: "F"),
        Case(name: "Subway", latitude: 30.2710, longitude: -97.7510, expected: "F"),
        Case(name: "Taco Bell", latitude: 30.2627, longitude: -97.7420, expected: "F"),
        Case(name: "Wendy's", latitude: 30.2720, longitude: -97.7520, expected: "C"),
        Case(name: "Burger King", latitude: 30.2730, longitude: -97.7530, expected: "F"),
        Case(name: "Chick-fil-A", latitude: 30.2740, longitude: -97.7540, expected: "B"),
        Case(name: "Starbucks Coffee Company", latitude: 30.2750, longitude: -97.7550, expected: "F"),
        Case(name: "Domino's Pizza", latitude: 30.2760, longitude: -97.7560, expected: "C"),
        Case(name: "Five Guys", latitude: 30.2770, longitude: -97.7570, expected: "A"),
        Case(name: "Shake Shack", latitude: 30.2712, longitude: -97.7398, expected: "B"),
        Case(name: "sweetgreen", latitude: 30.2780, longitude: -97.7580, expected: "A+"),
        Case(name: "CAVA", latitude: 30.2790, longitude: -97.7590, expected: "B"),
        Case(name: "Popeyes Louisiana Kitchen", latitude: 30.2800, longitude: -97.7600, expected: "B"),
        Case(name: "KFC", latitude: 30.2810, longitude: -97.7610, expected: "B"),
        Case(name: "Raising Cane's Chicken Fingers", latitude: 30.2820, longitude: -97.7620, expected: "B"),
        Case(name: "Dunkin'", latitude: 30.2830, longitude: -97.7630, expected: "F"),
        Case(name: "Jersey Mike's Subs", latitude: 30.2840, longitude: -97.7640, expected: "C"),
        Case(name: "Panda Express", latitude: 30.2850, longitude: -97.7650, expected: "B"),
        Case(name: "Buffalo Wild Wings", latitude: 30.2860, longitude: -97.7660, expected: "F"),
        Case(name: "Dutch Bros Coffee", latitude: 30.2870, longitude: -97.7670, expected: "–"),
    ]

    let database = ChainDatabase()

    private func evaluate(_ c: Case) -> (grade: String, label: String, matched: String) {
        let item = MKMapItem(location: CLLocation(latitude: c.latitude, longitude: c.longitude), address: nil)
        item.name = c.name
        item.pointOfInterestCategory = .restaurant
        let rated = RatedMapItem.rate(item, database: database, independents: .shared)
        let assessment = GradeResolver.resolve(cited: rated.cited, community: nil)
        let matched = rated.chainMatch?.chainSlug ?? rated.independent.map { "independent:\($0.id)" } ?? ""
        return (assessment.isGraded ? assessment.rating.grade.replacingOccurrences(of: "−", with: "-") : "–", assessment.label, matched)
    }

    @Test func accuracyMeetsTheBar() throws {
        var rows = ["name,expected,app_grade,label,matched,agrees"]
        var agree = 0
        for c in Self.cases {
            let result = evaluate(c)
            let ok = result.grade == c.expected
            if ok { agree += 1 }
            rows.append([c.name, c.expected, result.grade, result.label, result.matched, ok ? "yes" : "no"]
                .map(PlaceVerificationTests.csvField).joined(separator: ","))
        }
        if let dir = ProcessInfo.processInfo.environment["SKIPSLOP_VALIDATION"] {
            let url = URL(filePath: dir, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try rows.joined(separator: "\n").write(to: url.appending(path: "grading-validation.csv"), atomically: true, encoding: .utf8)
        }
        let accuracy = Double(agree) / Double(Self.cases.count)
        #expect(accuracy >= 0.85, "Agreement \(agree)/\(Self.cases.count)")
    }

    /// Wrong-place matches are worse than disagreements on a letter: a place
    /// must never pick up another restaurant's grade.
    @Test(arguments: cases)
    func matchesTheRightPlace(_ c: Case) {
        let matched = evaluate(c).matched
        if c.expected == "–" {
            #expect(!matched.hasPrefix("independent:"), "\(c.name) matched \(matched)")
        } else {
            #expect(!matched.isEmpty, "\(c.name) matched nothing")
        }
    }
}
