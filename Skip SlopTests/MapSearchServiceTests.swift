import Testing
import MapKit
@testable import Skip_Slop

@Suite("MapSearchService")
struct MapSearchServiceTests {
    @Test func mergeDropsSamePlaceFromDifferentRequests() {
        let a = makeMapItem("Joe's Pizza", latitude: 40.7580, longitude: -73.9855)
        let sameSpot = makeMapItem("JOE'S PIZZA", latitude: 40.75802, longitude: -73.98552)
        let elsewhere = makeMapItem("Joe's Pizza", latitude: 40.7680, longitude: -73.9855)
        let other = makeMapItem("Xi'an Famous Foods", latitude: 40.7580, longitude: -73.9855)

        let merged = MapSearchService.merge([[a, other], [sameSpot, elsewhere]])
        #expect(merged.count == 3)
        #expect(merged.contains { $0 === a })
        #expect(merged.contains { $0 === elsewhere })
        #expect(!merged.contains { $0 === sameSpot })
    }

    @Test func searchRegionIsClampedToUsefulSize() {
        let center = CLLocationCoordinate2D(latitude: 45.5231, longitude: -122.6765)
        let tiny = MapSearchService.searchRegion(for: MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.001, longitudeDelta: 0.001)))
        #expect(tiny.span.latitudeDelta == 0.01)
        let huge = MapSearchService.searchRegion(for: MKCoordinateRegion(center: center, span: .init(latitudeDelta: 5, longitudeDelta: 5)))
        #expect(huge.span.latitudeDelta == 0.4)
        let normal = MapSearchService.searchRegion(for: MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.03, longitudeDelta: 0.03)))
        #expect(normal.span.latitudeDelta == 0.03)
    }

    @Test func nonFoodPlacesAreFilteredOut() {
        #expect(MapSearchService.isRestaurant(makeMapItem("A", category: .restaurant)))
        #expect(MapSearchService.isRestaurant(makeMapItem("A", category: .bakery)))
        #expect(!MapSearchService.isRestaurant(makeMapItem("A", category: .hotel)))
        // Browsing nearby skips grocery and convenience stores ("7-Eleven" was graded A).
        #expect(!MapSearchService.isNearbyFood(makeMapItem("7-Eleven", category: .foodMarket)))
        #expect(MapSearchService.isNearbyFood(makeMapItem("A", category: .cafe)))
    }

    @Test func smallCameraNudgesDoNotTriggerANewSearch() {
        let center = CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
        let base = MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.03, longitudeDelta: 0.03))
        let nudged = MKCoordinateRegion(
            center: .init(latitude: 30.2702, longitude: -97.7431),
            span: base.span
        )
        let panned = MKCoordinateRegion(
            center: .init(latitude: 30.2872, longitude: -97.7431),
            span: base.span
        )
        let zoomedOut = MKCoordinateRegion(center: center, span: .init(latitudeDelta: 0.09, longitudeDelta: 0.09))
        #expect(ExploreModel.isNearlySame(nudged, as: base))
        #expect(!ExploreModel.isNearlySame(panned, as: base))
        #expect(!ExploreModel.isNearlySame(zoomedOut, as: base))
    }
}
