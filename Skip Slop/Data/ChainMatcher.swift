import MapKit

struct ChainMatchResult {
    let chainInfo: ChainInfo
    let slopRating: SlopRating
    let chainSlug: String
}

enum ChainMatcher {
    /// MapKit categories a chain restaurant can be filed under. Places in other
    /// categories (a hotel, a store) only match a chain by exact name.
    static let foodCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .cafe, .bakery, .brewery, .winery, .distillery, .foodMarket, .nightlife,
    ]

    static func match(mapItem: MKMapItem, using database: ChainDatabase) -> ChainMatchResult? {
        guard let name = mapItem.name else { return nil }
        let allowPrefix = mapItem.pointOfInterestCategory.map(foodCategories.contains) ?? true

        if let info = database.match(name: name, allowPrefix: allowPrefix) {
            return ChainMatchResult(
                chainInfo: info,
                slopRating: info.slopRating,
                chainSlug: info.slug
            )
        }

        return nil
    }

    static func coordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D {
        mapItem.location.coordinate
    }

    static func restaurantID(for mapItem: MKMapItem, chainSlug: String?) -> String {
        let coord = Self.coordinate(for: mapItem)
        return Restaurant.makeID(
            chainSlug: chainSlug,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }
}
