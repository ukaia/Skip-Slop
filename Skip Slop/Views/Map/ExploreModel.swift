import SwiftUI
import MapKit
import os

/// State for the map-first explore screen: camera, nearby/search results,
/// grade filter, the selected place, and the bottom sheet's detent.
@Observable
final class ExploreModel {
    let locationManager = LocationManager()

    var position: MapCameraPosition = .userLocation(fallback: .automatic)
    var detent: PresentationDetent = .peek
    /// Drives both map selection and the detail push in the sheet.
    var selectedItem: MKMapItem? {
        didSet {
            selectedEntry = selectedItem.flatMap(entry(for:))
            if selectedItem != nil, detent == .peek { detent = .medium }
        }
    }
    /// Snapshot of the selected place, so the detail card survives result refreshes.
    private(set) var selectedEntry: RatedMapItem?
    var query = ""
    var filter: SlopRating?
    var showSettings = false

    private(set) var ratedResults: [RatedMapItem] = []
    private(set) var isSearching = false
    private(set) var hasLoadedInitial = false
    private(set) var searchMessage: String?
    private(set) var isMock = false

    private var visibleRegion: MKCoordinateRegion?
    private var searchTask: Task<Void, Never>?
    private let ratingCache = RatingCache()
    private var chainDB: ChainDatabase?
    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "Map")

    var isLocationBlocked: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

    /// Results after the grade filter and the live text filter, best-known first.
    var displayedResults: [RatedMapItem] {
        var result = ratedResults
        if let filter {
            result = result.filter { $0.inference.rating == filter }
        }
        let text = query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            result = result.filter { ($0.item.name ?? "").localizedCaseInsensitiveContains(text) }
        }
        return result.sorted { a, b in
            if a.inference.confidence != b.inference.confidence {
                return a.inference.confidence.sortOrder < b.inference.confidence.sortOrder
            }
            return a.inference.rating.sortOrder < b.inference.rating.sortOrder
        }
    }

    func entry(for item: MKMapItem) -> RatedMapItem? {
        ratedResults.first { $0.item == item }
    }

    /// Distance from the user, formatted for the current locale ("0.4 mi").
    func distanceText(to item: MKMapItem) -> String? {
        guard let here = locationManager.location else { return nil }
        let meters = here.distance(from: item.location)
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    // MARK: - Loading

    /// Requests location (only after onboarding has primed it), then runs the first search.
    func start(using database: ChainDatabase) async {
        chainDB = database
        guard !hasLoadedInitial else { return }

        #if DEBUG
        if LaunchOptions.mockData {
            isMock = true
            position = .region(MockData.region)
            visibleRegion = MockData.region
            setResults(MockData.mapItems())
            hasLoadedInitial = true
            // Wait for the explore sheet to finish presenting before stacking on it.
            try? await Task.sleep(for: .milliseconds(800))
            if LaunchOptions.openDetail { selectedItem = displayedResults.first?.item }
            if LaunchOptions.openSettings { showSettings = true }
            return
        }
        #endif

        locationManager.requestPermission()
        isSearching = true
        let deadline = ContinuousClock.now + .seconds(5)
        while locationManager.location == nil, !isLocationBlocked, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
        }

        if let location = locationManager.location {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
            visibleRegion = region
            position = .region(region)
        }
        hasLoadedInitial = true
        loadNearby()

        #if DEBUG
        if LaunchOptions.openSettings { showSettings = true }
        #endif
    }

    func cameraChanged(to region: MKCoordinateRegion) {
        visibleRegion = region
        guard hasLoadedInitial, !isMock else { return }
        loadNearby(debounce: true)
    }

    func centerOnUser(reduceMotion: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
            position = .userLocation(fallback: .automatic)
        }
    }

    private func setResults(_ items: [MKMapItem]) {
        guard let chainDB else { return }
        var items = items
        // Keep the selected place (same instance) so its pin and detail card stay put.
        if let selected = selectedItem {
            let key = RatingCache.key(for: selected)
            if let index = items.firstIndex(where: { RatingCache.key(for: $0) == key }) {
                items[index] = selected
            } else {
                items.append(selected)
            }
        }
        ratedResults = ratingCache.rate(items, using: chainDB)
    }

    private func loadNearby(debounce: Bool = false) {
        searchTask?.cancel()
        searchTask = Task {
            if debounce {
                // Coalesce rapid pans: a newer camera change cancels this task.
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled { return }
            }
            guard let region = visibleRegion else {
                isSearching = false
                return
            }
            isSearching = true
            defer { if !Task.isCancelled { isSearching = false } }
            do {
                let results = try await MapSearchService.searchNearby(region: region)
                if !Task.isCancelled { setResults(results) }
            } catch {
                if !Task.isCancelled {
                    logger.error("Nearby search failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - Search

    /// Searches beyond the loaded results: a place name, or a city/zip to fly to.
    func performSearch() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isMock else { return }
        searchTask?.cancel()
        searchTask = Task {
            guard let region = visibleRegion else { return }
            isSearching = true
            defer { if !Task.isCancelled { isSearching = false } }
            do {
                switch try await MapSearchService.smartSearch(query: text, region: region) {
                case .restaurants(let items):
                    guard !Task.isCancelled else { return }
                    if items.isEmpty {
                        showMessage("Nothing called “\(text)” around here.")
                    } else {
                        setResults(items)
                    }
                case .region(let newRegion):
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.5)) { position = .region(newRegion) }
                    query = ""
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    let nearby = try await MapSearchService.searchNearby(region: newRegion)
                    guard !Task.isCancelled else { return }
                    setResults(nearby)
                    if nearby.isEmpty { showMessage("No restaurants found near “\(text)”.") }
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
                    showMessage("Search didn't go through. Check your connection and try again.")
                }
            }
        }
    }

    private func showMessage(_ message: String) {
        withAnimation { searchMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation {
                if searchMessage == message { searchMessage = nil }
            }
        }
    }
}

extension RatingInferenceEngine.InferenceResult.Confidence {
    /// Heuristic guesses, shown with dashed placard outlines.
    var isEstimate: Bool { self == .medium || self == .low }

    /// User-facing description of how sure we are.
    var displayName: String {
        switch self {
        case .known:  "Known chain"
        case .high:   "Likely"
        case .medium: "Estimate"
        case .low:    "Rough guess"
        }
    }
}

// MARK: - Sheet detents

/// The collapsed sheet: just tall enough for the search field at the current text size.
nonisolated struct PeekDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.dynamicTypeSize.isAccessibilitySize ? 150 : 96
    }
}

extension PresentationDetent {
    static let peek = Self.custom(PeekDetent.self)
}
