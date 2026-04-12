import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map.fill", value: 0) {
                NavigationStack {
                    MapContainerView()
                        .navigationTitle("Skip Slop")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }

            Tab("List", systemImage: "list.bullet", value: 1) {
                NavigationStack {
                    RestaurantListView()
                        .navigationTitle("Restaurants")
                }
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
