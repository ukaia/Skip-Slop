import MapKit
@testable import Skip_Slop

func makeMapItem(
    _ name: String?,
    category: MKPointOfInterestCategory? = nil,
    latitude: Double = 37.3349,
    longitude: Double = -122.0090
) -> MKMapItem {
    let item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
    item.name = name
    item.pointOfInterestCategory = category
    return item
}
