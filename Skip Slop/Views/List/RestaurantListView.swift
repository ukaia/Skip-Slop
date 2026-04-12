import SwiftUI
import SwiftData

struct RestaurantListView: View {
    @Query(sort: \Restaurant.updatedAt, order: .reverse) private var restaurants: [Restaurant]
    @State private var searchText = ""
    @State private var filterRating: SlopRating?

    private var filteredRestaurants: [Restaurant] {
        var result = restaurants

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let filterRating {
            result = result.filter { $0.slopRating == filterRating }
        }

        return result
    }

    var body: some View {
        Group {
            if restaurants.isEmpty {
                emptyState
            } else {
                List {
                    filterSection

                    ForEach(filteredRestaurants) { restaurant in
                        RestaurantRowView(restaurant: restaurant)
                    }
                }
                .searchable(text: $searchText, prompt: "Search saved restaurants")
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
            "No Restaurants Yet",
            systemImage: "fork.knife",
            description: Text("Visit the map tab to find restaurants and check their slop ratings.")
        )
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
