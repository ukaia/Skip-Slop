import SwiftUI
import SwiftData
import MapKit
import os

struct MapContainerView: View {
    @Environment(ChainDatabase.self) private var chainDB
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Binding var mapResults: [MKMapItem]

    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "Map")

    @State private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedItem: MKMapItem?
    @State private var searchText = ""
    @State private var showDetail = false
    @State private var searchTask: Task<Void, Never>?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasLoadedInitial = false
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var dismissedLocationPrompt = false

    private var isLocationBlocked: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

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

                if let searchMessage {
                    Text(searchMessage)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
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
        .overlay {
            if isLocationBlocked && !dismissedLocationPrompt {
                locationDeniedView
            } else if isSearching && mapResults.isEmpty {
                ProgressView("Finding restaurants…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
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
        .task {
            locationManager.requestPermission()
            await loadInitialRestaurants()
        }
    }

    private var locationDeniedView: some View {
        ContentUnavailableView {
            Label("Location Access Off", systemImage: "location.slash.fill")
        } description: {
            Text("Skip Slop needs your location to show nearby restaurants. You can still search for a city or zip code.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Continue Without Location") {
                dismissedLocationPrompt = true
            }
        }
        .background(.regularMaterial)
    }

    /// Waits briefly for the first location fix (or a denial), then runs the first search.
    private func loadInitialRestaurants() async {
        isSearching = true
        let deadline = ContinuousClock.now + .seconds(5)
        while locationManager.location == nil,
              !isLocationBlocked,
              ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
        }

        if let location = locationManager.location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 3000,
                longitudinalMeters: 3000
            )
            visibleRegion = region
            position = .region(region)
        }
        hasLoadedInitial = true
        loadNearbyRestaurants()
    }

    private func centerOnUser() {
        if isLocationBlocked {
            dismissedLocationPrompt = false
            return
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .userLocation(fallback: .automatic)
        }
    }

    private func showSearchMessage(_ message: String) {
        withAnimation { searchMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                if searchMessage == message { searchMessage = nil }
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task {
            guard let region = visibleRegion else { return }
            isSearching = true
            defer { if !Task.isCancelled { isSearching = false } }
            do {
                let result = try await MapSearchService.smartSearch(query: query, region: region)
                if Task.isCancelled { return }

                switch result {
                case .restaurants(let items):
                    if items.isEmpty {
                        showSearchMessage("No restaurants found for “\(query)”")
                    } else {
                        mapResults = items
                    }
                case .region(let newRegion):
                    withAnimation(.easeInOut(duration: 0.5)) {
                        position = .region(newRegion)
                    }
                    try? await Task.sleep(for: .seconds(1.0))
                    if !Task.isCancelled {
                        let nearby = try await MapSearchService.searchNearby(region: newRegion)
                        if !Task.isCancelled {
                            mapResults = nearby
                            if nearby.isEmpty {
                                showSearchMessage("No restaurants found near “\(query)”")
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
                    showSearchMessage("No results for “\(query)”")
                }
            }
        }
    }

    private func loadNearbyRestaurants() {
        searchTask?.cancel()
        searchTask = Task {
            guard let region = visibleRegion else {
                isSearching = false
                return
            }
            isSearching = true
            defer { if !Task.isCancelled { isSearching = false } }
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
