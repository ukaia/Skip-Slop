import SwiftUI
import MapKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var mapResults: [MKMapItem] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map.fill", value: 0) {
                MapContainerView(mapResults: $mapResults)
            }

            Tab("List", systemImage: "list.bullet", value: 1) {
                RestaurantListView(mapResults: mapResults)
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
        }
        .tint(.slopGreen)
    }
}
