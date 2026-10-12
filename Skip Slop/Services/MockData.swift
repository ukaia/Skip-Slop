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

    /// Place key the app computes for a sample place (no MapKit identifier, so
    /// it's the chain slug or "independent" plus coordinates).
    static func placeKey(_ name: String, chainSlug: String? = nil) -> String {
        guard let place = places.first(where: { $0.name == name }) else { return name }
        return Restaurant.makeID(chainSlug: chainSlug, latitude: place.lat, longitude: place.lon)
    }

    /// Community prep reports so the sample places show every grade state:
    /// Veracruz Taqueria has a community grade, Mama Fern's needs more reports,
    /// and Applebee's has reports that sit under its cited grade.
    static func prepReports() -> [PrepReport] {
        let weekAgo = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        func report(_ place: String, slug: String? = nil, _ n: Int, _ verdict: PrepVerdict,
                    _ evidence: PrepEvidence?, _ note: String = "") -> PrepReport {
            let key = placeKey(place, chainSlug: slug)
            let reporter = "sample-reporter-\(n)"
            return PrepReport(
                id: PrepReport.recordName(placeKey: key, reporterID: reporter),
                placeKey: key, reporterID: reporter, chainSlug: slug,
                verdict: verdict, evidence: evidence, note: note,
                createdAt: weekAgo, updatedAt: weekAgo.addingTimeInterval(Double(n) * 3600),
                dayStamp: PrepReport.dayStamp(for: weekAgo), dailyCount: 1, reporterSince: weekAgo
            )
        }
        return [
            report("Veracruz Taqueria", 1, .scratch, .sawPrep, "Tortillas pressed to order on the truck's flat-top."),
            report("Veracruz Taqueria", 2, .scratch, .sawPrep),
            report("Veracruz Taqueria", 3, .scratch, .staffTold, "Cook said the salsas are made every morning."),
            report("Veracruz Taqueria", 4, .scratch, .menuSays),
            report("Veracruz Taqueria", 5, .scratch, .impression),
            report("Veracruz Taqueria", 6, .scratch, .sawPrep),
            report("Veracruz Taqueria", 7, .reheated, .impression),
            report("Mama Fern's Homestyle", 1, .scratch, .staffTold),
            report("Mama Fern's Homestyle", 2, .unsure, nil),
            report("Applebee's", slug: "applebees", 1, .reheated, .frozenBoxes, "Riblets came out of a bag in the microwave."),
            report("Applebee's", slug: "applebees", 2, .reheated, .workedHere),
        ]
    }
}
#endif
