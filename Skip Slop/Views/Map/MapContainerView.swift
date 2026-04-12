import SwiftUI
import SwiftData
import MapKit

struct MapContainerView: View {
    @Environment(ChainDatabase.self) private var chainDB
    @Environment(\.modelContext) private var modelContext

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var searchText = ""
    @State private var showDetail = false
    @State private var searchTask: Task<Void, Never>?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasLoadedInitial = false

    private let locationManager = LocationManager()

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: $selectedItem) {
                UserAnnotation()

                ForEach(searchResults, id: \.self) { item in
                    let chainMatch = ChainMatcher.match(mapItem: item, using: chainDB)
                    let inference = RatingInferenceEngine.infer(mapItem: item, chainMatch: chainMatch)

                    Annotation(item.name ?? "Restaurant", coordinate: ChainMatcher.coordinate(for: item)) {
                        RestaurantAnnotationView(
                            rating: inference.rating,
                            confidence: inference.confidence,
                            name: item.name ?? "?"
                        )
                    }
                    .tag(item)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                if hasLoadedInitial {
                    loadNearbyRestaurants()
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                if newValue != nil {
                    showDetail = true
                }
            }

            VStack(spacing: 8) {
                MapSearchBar(text: $searchText) {
                    performSearch()
                }

                HStack {
                    Spacer()
                    Button {
                        centerOnUser()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                    .padding(.trailing, 16)
                }
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showDetail, onDismiss: { selectedItem = nil }) {
            if let item = selectedItem {
                let chainMatch = ChainMatcher.match(mapItem: item, using: chainDB)
                RestaurantDetailView(
                    mapItem: item,
                    chainMatch: chainMatch,
                    inference: RatingInferenceEngine.infer(mapItem: item, chainMatch: chainMatch)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            hasLoadedInitial = true
            loadNearbyRestaurants()
        }
    }

    private func centerOnUser() {
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .userLocation(fallback: .automatic)
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task {
            guard let region = visibleRegion else { return }
            do {
                let result = try await MapSearchService.smartSearch(query: searchText, region: region)
                if Task.isCancelled { return }

                switch result {
                case .restaurants(let items):
                    searchResults = items
                case .region(let newRegion):
                    // Navigate to location, then load restaurants there
                    withAnimation(.easeInOut(duration: 0.5)) {
                        position = .region(newRegion)
                    }
                    // Brief pause for map to settle, then load nearby
                    try? await Task.sleep(for: .seconds(1.0))
                    if !Task.isCancelled {
                        let nearby = try await MapSearchService.searchNearby(region: newRegion)
                        if !Task.isCancelled {
                            searchResults = nearby
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("Search failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadNearbyRestaurants() {
        searchTask?.cancel()
        searchTask = Task {
            guard let region = visibleRegion else { return }
            do {
                let results = try await MapSearchService.searchNearby(region: region)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    print("Nearby search failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
