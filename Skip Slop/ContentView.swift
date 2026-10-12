import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(ChainDatabase.self) private var chainDB
    @State private var selectedTab = 0
    @State private var mapResults: [MKMapItem] = []
    @State private var ratedResults: [RatedMapItem] = []
    @State private var ratingCache = RatingCache()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map.fill", value: 0) {
                MapContainerView(mapResults: $mapResults, ratedResults: ratedResults)
            }

            Tab("List", systemImage: "list.bullet", value: 1) {
                RestaurantListView(ratedResults: ratedResults)
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
        }
        .tint(.slopGreen)
        .onChange(of: mapResults) { _, newValue in
            ratedResults = ratingCache.rate(newValue, using: chainDB)
        }
    }
}
