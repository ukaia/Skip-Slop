import SwiftUI
import SwiftData
import MapKit
import os

struct MapContainerView: View {
    @Environment(ChainDatabase.self) private var chainDB
    @Environment(\.modelContext) private var modelContext
    @Binding var mapResults: [MKMapItem]

    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "Map")

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedItem: MKMapItem?
    @State private var searchText = ""
    @State private var showDetail = false
    @State private var searchTask: Task<Void, Never>?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasLoadedInitial = false

    private let locationManager = LocationManager()

    var body: some View {
        Map(position: $position, selection: $selectedItem) {
            UserAnnotation()

            ForEach(mapResults, id: \.self) { item in
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
        .safeAreaInset(edge: .top) {
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
            .padding(.bottom, 4)
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
                    mapResults = items
                case .region(let newRegion):
                    withAnimation(.easeInOut(duration: 0.5)) {
                        position = .region(newRegion)
                    }
                    try? await Task.sleep(for: .seconds(1.0))
                    if !Task.isCancelled {
                        let nearby = try await MapSearchService.searchNearby(region: newRegion)
                        if !Task.isCancelled {
                            mapResults = nearby
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
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
                    mapResults = results
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Nearby search failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
