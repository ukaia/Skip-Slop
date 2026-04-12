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

    static func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem] {
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

    static func searchNearby(region: MKCoordinateRegion) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
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

    private static func isRestaurant(_ item: MKMapItem) -> Bool {
        guard let category = item.pointOfInterestCategory else { return true }
        let foodCategories: Set<MKPointOfInterestCategory> = [
            .restaurant, .cafe, .bakery, .brewery, .foodMarket
        ]
        return foodCategories.contains(category)
    }
}
