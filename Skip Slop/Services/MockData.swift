#if DEBUG
import MapKit

/// Sample restaurants for screenshots and simulators without location.
/// Only used with the `-mockData YES` launch argument (see `LaunchOptions`).
enum MockData {
    /// Downtown Austin, TX.
    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        latitudinalMeters: 2600,
        longitudinalMeters: 2600
    )

    private static let places: [(name: String, lat: Double, lon: Double, category: MKPointOfInterestCategory)] = [
        ("Olive Garden", 30.2701, -97.7462, .restaurant),
        ("The Cheesecake Factory", 30.2655, -97.7389, .restaurant),
        ("Chipotle Mexican Grill", 30.2689, -97.7415, .restaurant),
        ("Panera Bread", 30.2638, -97.7448, .restaurant),
        ("Shake Shack", 30.2712, -97.7398, .restaurant),
        ("Taco Bell", 30.2627, -97.7420, .restaurant),
        ("Veracruz Taqueria", 30.2660, -97.7493, .restaurant),
        ("Mama Fern's Homestyle", 30.2724, -97.7441, .restaurant),
        ("Applebee's", 30.2611, -97.7461, .restaurant),
        ("P.F. Chang's", 30.2684, -97.7370, .restaurant),
        ("Lamar Bar & Grill", 30.2742, -97.7480, .restaurant),
        ("Texas Roadhouse", 30.2600, -97.7400, .restaurant),
    ]

    static func mapItems() -> [MKMapItem] {
        places.map { place in
            let item = MKMapItem(location: CLLocation(latitude: place.lat, longitude: place.lon), address: nil)
            item.name = place.name
            item.pointOfInterestCategory = place.category
            return item
        }
    }
}
#endif
