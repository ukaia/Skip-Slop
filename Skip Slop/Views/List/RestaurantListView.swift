import SwiftUI
import MapKit

struct RestaurantListView: View {
    let mapResults: [MKMapItem]
    @Environment(ChainDatabase.self) private var chainDB
    @State private var searchText = ""
    @State private var filterRating: SlopRating?
    @State private var selectedItem: MKMapItem?
    @State private var showDetail = false

    private var ratedResults: [(item: MKMapItem, chain: ChainMatchResult?, inference: RatingInferenceEngine.InferenceResult)] {
        mapResults.map { item in
            let chain = ChainMatcher.match(mapItem: item, using: chainDB)
            let inference = RatingInferenceEngine.infer(mapItem: item, chainMatch: chain)
            return (item, chain, inference)
        }
    }

    private var filteredResults: [(item: MKMapItem, chain: ChainMatchResult?, inference: RatingInferenceEngine.InferenceResult)] {
        var result = ratedResults

        if !searchText.isEmpty {
            result = result.filter {
                ($0.item.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        if let filterRating {
            result = result.filter { $0.inference.rating == filterRating }
        }

        // Sort: known/high confidence first, then by rating severity
        return result.sorted { a, b in
            if a.inference.confidence != b.inference.confidence {
                return a.inference.confidence.sortOrder < b.inference.confidence.sortOrder
            }
            return a.inference.rating.sortOrder < b.inference.rating.sortOrder
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if mapResults.isEmpty {
                    emptyState
                } else {
                    List {
                        filterSection

                        ForEach(filteredResults, id: \.item) { entry in
                            Button {
                                selectedItem = entry.item
                                showDetail = true
                            } label: {
                                MapItemRowView(
                                    item: entry.item,
                                    rating: entry.inference.rating,
                                    confidence: entry.inference.confidence,
                                    isChain: entry.chain != nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search nearby restaurants")
                }
            }
            .navigationTitle("Nearby")
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
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: filterRating == nil) {
                    filterRating = nil
                }

                ForEach(SlopRating.allCases) { rating in
                    FilterChip(
                        label: rating.label,
                        color: rating.color,
                        isSelected: filterRating == rating
                    ) {
                        filterRating = filterRating == rating ? nil : rating
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Restaurants Loaded",
            systemImage: "fork.knife",
            description: Text("Head to the Map tab — nearby restaurants will appear here once loaded.")
        )
    }
}

// MARK: - Row View

struct MapItemRowView: View {
    let item: MKMapItem
    let rating: SlopRating
    let confidence: RatingInferenceEngine.InferenceResult.Confidence
    let isChain: Bool

    var body: some View {
        HStack(spacing: 12) {
            SlopRatingBadge(rating: rating, size: .compact)
                .opacity(confidence == .low ? 0.65 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name ?? "Unknown")
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if isChain {
                        Label("Chain", systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if confidence != .known {
                        Text(confidence.rawValue)
                            .font(.caption2)
                            .foregroundStyle(confidence == .low ? .orange : .secondary)
                    }

                    if let addr = item.address?.shortAddress, !addr.isEmpty {
                        Text(addr)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
    }
}

struct FilterChip: View {
    let label: String
    var color: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1), in: Capsule())
                .foregroundStyle(isSelected ? .white : color)
        }
        .buttonStyle(.plain)
    }
}
