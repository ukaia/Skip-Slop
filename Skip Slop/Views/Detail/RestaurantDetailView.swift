import SwiftUI
import SwiftData
import MapKit

struct RestaurantDetailView: View {
    let mapItem: MKMapItem
    let chainMatch: ChainMatchResult?
    let inference: RatingInferenceEngine.InferenceResult

    @Environment(\.modelContext) private var modelContext
    @Environment(ChainDatabase.self) private var chainDB
    @State private var restaurant: Restaurant?
    @State private var showAddNote = false

    private var rating: SlopRating {
        restaurant?.slopRating ?? inference.rating
    }

    private var restaurantName: String {
        mapItem.name ?? "Unknown Restaurant"
    }

    private var address: String {
        mapItem.address?.fullAddress ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                meterSection
                badgeSection
                confidenceSection
                infoSection
                communityNotesSection
                addNoteButton
            }
            .padding()
        }
        .onAppear { loadOrCreateRestaurant() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(restaurantName)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if chainMatch != nil {
                Label("Chain Restaurant", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }

            if !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var meterSection: some View {
        SlopOMeterView(rating: rating)
            .padding(.horizontal, 8)
    }

    private var badgeSection: some View {
        SlopRatingBadge(rating: rating, size: .large)
    }

    private var confidenceSection: some View {
        Group {
            if inference.confidence != .known {
                HStack(spacing: 6) {
                    Image(systemName: confidenceIcon)
                        .font(.caption)
                        .foregroundStyle(confidenceColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(inference.confidence.rawValue) Rating")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(confidenceColor)

                        Text(inference.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(confidenceColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(confidenceColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var confidenceIcon: String {
        switch inference.confidence {
        case .known:  "checkmark.seal.fill"
        case .high:   "checkmark.circle"
        case .medium: "questionmark.circle"
        case .low:    "questionmark.diamond"
        }
    }

    private var confidenceColor: Color {
        switch inference.confidence {
        case .known:  .slopGreen
        case .high:   .slopGreen
        case .medium: .slopYellow
        case .low:    .slopOrange
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Label {
                Text(rating.description)
                    .font(.subheadline)
            } icon: {
                Image(systemName: rating.icon)
                    .foregroundStyle(rating.color)
            }

            if let source = restaurant?.ratingSource {
                Label {
                    Text("Source: \(source.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }

    private var communityNotesSection: some View {
        CommunityNotesSection(
            restaurant: restaurant,
            chainSlug: chainMatch?.chainSlug
        )
    }

    private var addNoteButton: some View {
        Button {
            showAddNote = true
        } label: {
            Label("Add Community Note", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showAddNote) {
            if let restaurant {
                AddNoteView(restaurant: restaurant, chainSlug: chainMatch?.chainSlug)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Data

    private func loadOrCreateRestaurant() {
        let id = ChainMatcher.restaurantID(for: mapItem, chainSlug: chainMatch?.chainSlug)

        let predicate = #Predicate<Restaurant> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let existing = try? modelContext.fetch(descriptor).first {
            restaurant = existing
            return
        }

        let coord = ChainMatcher.coordinate(for: mapItem)
        let newRestaurant = Restaurant(
            id: id,
            name: restaurantName,
            chainSlug: chainMatch?.chainSlug,
            latitude: coord.latitude,
            longitude: coord.longitude,
            address: address,
            slopRating: inference.rating,
            ratingSource: chainMatch != nil ? .seeded : .community
        )

        modelContext.insert(newRestaurant)
        try? modelContext.save()
        restaurant = newRestaurant
    }
}
