import Foundation
import MapKit
import Testing
@testable import Skip_Slop

/// Live MapKit verification harness. Off by default; it hits Apple's servers.
///
///     TEST_RUNNER_SKIPSLOP_VERIFY=/tmp/skipslop-verify xcodebuild test \
///       -only-testing:"Skip SlopTests/PlaceVerification" ...
///
/// For each city it writes `<dir>/places-<label>.csv` with every food place
/// found (app fetch plus extra category/keyword queries), the chain match, and
/// the grade. If `<dir>/rescore-input.csv` exists, those rows are re-scored with
/// the current matcher into `<dir>/rescore-<label>.csv`, so before/after runs
/// can be compared on the same places.
nonisolated enum VerificationConfig {
    static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["SKIPSLOP_VERIFY"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    static var label: String {
        ProcessInfo.processInfo.environment["SKIPSLOP_VERIFY_LABEL"] ?? "run"
    }
}

@Suite("PlaceVerification", .serialized, .enabled(if: VerificationConfig.outputDirectory != nil))
struct PlaceVerificationTests {
    static var outputDirectory: URL? { VerificationConfig.outputDirectory }
    static var label: String { VerificationConfig.label }

    nonisolated struct City: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    nonisolated static let cities = [
        City(name: "Portland OR", latitude: 45.5231, longitude: -122.6765),
        City(name: "Austin TX", latitude: 30.2672, longitude: -97.7431),
        City(name: "New York NY", latitude: 40.7580, longitude: -73.9855),
        City(name: "Chicago IL", latitude: 41.8781, longitude: -87.6298),
        City(name: "Plano TX", latitude: 33.0198, longitude: -96.6989),
    ]

    static let foodCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .brewery, .foodMarket, .winery, .nightlife,
    ]

    let database = ChainDatabase()

    @Test(arguments: cities)
    func collect(city: City) async throws {
        let dir = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let center = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 3000, longitudinalMeters: 3000)

        var found: [String: (item: MKMapItem, sources: Set<String>)] = [:]
        func add(_ items: [MKMapItem], source: String) {
            for item in items {
                let key = RatingCache.key(for: item)
                found[key, default: (item, [])].sources.insert(source)
            }
        }

        // What the app itself loads for this region.
        add(try await MapSearchService.searchNearby(region: region), source: "app")

        // Extra probes, to find places the app fetch misses.
        for category in Self.foodCategories {
            let request = MKLocalPointsOfInterestRequest(center: center, radius: 1500)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
            if let response = try? await MKLocalSearch(request: request).start() {
                add(response.mapItems, source: "poi:\(category.rawValue.replacingOccurrences(of: "MKPOICategory", with: ""))")
            }
        }
        for query in ["restaurant", "fast food", "cafe", "food", "pizza", "burger", "coffee"] {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            if let response = try? await MKLocalSearch(request: request).start() {
                add(response.mapItems, source: "q:\(query.replacingOccurrences(of: " ", with: "_"))")
            }
        }

        var rows = [Self.header]
        for (_, entry) in found.sorted(by: { ($0.value.item.name ?? "") < ($1.value.item.name ?? "") }) {
            let item = entry.item
            rows.append(Self.row(city: city.name, item: item, sources: entry.sources.sorted().joined(separator: " "), database: database))
        }
        let slug = city.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let url = dir.appending(path: "places-\(Self.label)-\(slug).csv")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        #expect(found.count > 0, "No places for \(city.name)")
    }

    /// Re-scores a fixed list of places (name, lat, lon, category) with the current code.
    @Test func rescore() throws {
        let dir = try #require(Self.outputDirectory)
        let input = dir.appending(path: "rescore-input.csv")
        guard let text = try? String(contentsOf: input, encoding: .utf8) else { return }
        var rows = [Self.header]
        // `isNewline`, not "\n": a CSV written with "\r\n" is one Character per line break.
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let fields = Self.parseCSVLine(String(line))
            guard fields.count >= 5, let lat = Double(fields[2]), let lon = Double(fields[3]) else { continue }
            let category = fields[4].isEmpty ? nil : MKPointOfInterestCategory(rawValue: "MKPOICategory" + fields[4])
            let item = makeItem(fields[1], category: category, latitude: lat, longitude: lon)
            rows.append(Self.row(city: fields[0], item: item, sources: fields.count > 5 ? fields[5] : "", database: database))
        }
        try rows.joined(separator: "\n").write(to: dir.appending(path: "rescore-\(Self.label).csv"), atomically: true, encoding: .utf8)
    }

    private func makeItem(_ name: String, category: MKPointOfInterestCategory?, latitude: Double, longitude: Double) -> MKMapItem {
        let item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        item.name = name
        item.pointOfInterestCategory = category
        return item
    }

    static let header = "city,name,lat,lon,category,sources,chain_slug,chain_name,grade,confidence,estimated,reason"

    static func row(city: String, item: MKMapItem, sources: String, database: ChainDatabase) -> String {
        let match = ChainMatcher.match(mapItem: item, using: database)
        let inference = RatingInferenceEngine.infer(mapItem: item, chainMatch: match)
        let coord = item.location.coordinate
        let category = item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "MKPOICategory", with: "") ?? ""
        return [
            city, item.name ?? "",
            String(format: "%.5f", coord.latitude), String(format: "%.5f", coord.longitude),
            category, sources,
            match?.chainSlug ?? "", match?.chainInfo.name ?? "",
            inference.rating.grade, inference.confidence.rawValue,
            inference.confidence.isEstimate ? "yes" : "no", inference.reason,
        ].map(csvField).joined(separator: ",")
    }

    static func csvField(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : value
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var quoted = false
        var iterator = line.makeIterator()
        while let char = iterator.next() {
            if quoted {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { current.append("\"") } else {
                            quoted = false
                            if next == "," { fields.append(current); current = "" } else { current.append(next) }
                        }
                    } else {
                        quoted = false
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                quoted = true
            } else if char == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
