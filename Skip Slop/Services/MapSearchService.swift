import MapKit

enum MapSearchService {

    /// Result of a search — either restaurants to display, or a region to navigate to (then load nearby)
    enum SearchResult {
        case restaurants([MKMapItem])
        case region(MKCoordinateRegion)
    }

    /// Smart search: detects zip codes / city names and geocodes them, otherwise searches restaurants
    static func smartSearch(query: String, region: MKCoordinateRegion) async throws -> SearchResult {
        if isLocationQuery(query) {
            if let geoRegion = try await geocodeToRegion(query) {
                return .region(geoRegion)
            }
        }
        let results = try await search(query: query, region: region)
        return .restaurants(results)
    }

    private static func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.filter { item in
            isRestaurant(item)
        }
    }

    /// Food categories asked for directly from MapKit's points of interest, one
    /// request per group (each request is capped, so restaurants get their own).
    static let nearbyCategoryGroups: [[MKPointOfInterestCategory]] = [
        [.restaurant],
        [.cafe, .bakery, .brewery, .winery],
    ]
    static let nearbyQueries = ["restaurant", "cafe", "food"]

    /// Each MapKit request returns a capped number of places (25 for a keyword
    /// search), mostly well-known ones, so a single "restaurant" query hid most
    /// independents. This merges points-of-interest requests for food categories
    /// with a few keyword searches, then de-duplicates. Fails only if every
    /// request fails.
    static func searchNearby(region: MKCoordinateRegion) async throws -> [MKMapItem] {
        let region = searchRegion(for: region)
        var batches: [[MKMapItem]] = []
        var lastError: (any Error)?

        for categories in nearbyCategoryGroups {
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
            do {
                batches.append(try await MKLocalSearch(request: request).start().mapItems)
            } catch {
                lastError = error
            }
        }
        for query in nearbyQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            do {
                batches.append(try await MKLocalSearch(request: request).start().mapItems)
            } catch {
                lastError = error
            }
        }

        if batches.isEmpty, let lastError { throw lastError }
        return merge(batches).filter(isNearbyFood)
    }

    /// Places worth grading when browsing: no grocery or convenience stores
    /// (the "food" keyword search returns them), which a text search still allows.
    static func isNearbyFood(_ item: MKMapItem) -> Bool {
        guard let category = item.pointOfInterestCategory else { return true }
        return nearbyCategoryGroups.joined().contains(category)
    }

    /// Clamps the visible region to a searchable size: at least ~1 km across
    /// (MapKit returns little for tiny regions) and at most ~40 km (beyond that
    /// results are sparse and arbitrary).
    static func searchRegion(for region: MKCoordinateRegion) -> MKCoordinateRegion {
        let minDelta = 0.01, maxDelta = 0.4
        var span = region.span
        span.latitudeDelta = min(max(span.latitudeDelta, minDelta), maxDelta)
        span.longitudeDelta = min(max(span.longitudeDelta, minDelta), maxDelta)
        return MKCoordinateRegion(center: region.center, span: span)
    }

    /// Concatenates batches, dropping repeats of the same place: same MapKit
    /// identifier, or same normalized name within ~50 m.
    static func merge(_ batches: [[MKMapItem]]) -> [MKMapItem] {
        var seenIDs = Set<String>()
        var seenNames: [String: [CLLocation]] = [:]
        var result: [MKMapItem] = []
        for item in batches.joined() {
            if let id = item.identifier?.rawValue {
                guard seenIDs.insert(id).inserted else { continue }
            }
            let name = ChainDatabase.normalize(item.name ?? "")
            if seenNames[name, default: []].contains(where: { $0.distance(from: item.location) < 50 }) {
                continue
            }
            seenNames[name, default: []].append(item.location)
            result.append(item)
        }
        return result
    }

    // MARK: - Location Detection

    /// Detects if query looks like a location rather than a restaurant name
    private static func isLocationQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // Zip code (US 5-digit or 5+4)
        if trimmed.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil {
            return true
        }

        // Common location keywords
        let locationKeywords = ["city", "town", "county", "state", "neighborhood", "district"]
        let lower = trimmed.lowercased()
        for keyword in locationKeywords {
            if lower.contains(keyword) { return true }
        }

        // State abbreviations with comma (e.g. "Austin, TX")
        if trimmed.range(of: #",\s*[A-Za-z]{2}$"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Geocode a location string into a map region
    private static func geocodeToRegion(_ query: String) async throws -> MKCoordinateRegion? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else { return nil }
        let coord = item.location.coordinate
        // City-level zoom
        return MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )
    }

    static func isRestaurant(_ item: MKMapItem) -> Bool {
        guard let category = item.pointOfInterestCategory else { return true }
        let foodCategories: Set<MKPointOfInterestCategory> = [
            .restaurant, .cafe, .bakery, .brewery, .foodMarket
        ]
        return foodCategories.contains(category)
    }
}
