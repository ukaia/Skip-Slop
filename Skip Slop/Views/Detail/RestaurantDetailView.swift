import SwiftUI
import SwiftData
import MapKit

struct RestaurantDetailView: View {
    let mapItem: MKMapItem
    let chainMatch: ChainMatchResult?
    let inference: RatingInferenceEngine.InferenceResult
    var distance: String?

    @Environment(\.modelContext) private var modelContext
    @State private var restaurant: Restaurant?
    @State private var showAddNote = false
    @State private var didLoad = false

    private var rating: SlopRating {
        restaurant?.slopRating ?? inference.rating
    }

    private var restaurantName: String {
        mapItem.name ?? "Unnamed restaurant"
    }

    private var address: String {
        mapItem.address?.fullAddress ?? ""
    }

    private var restaurantID: String {
        ChainMatcher.restaurantID(for: mapItem, chainSlug: chainMatch?.chainSlug)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                InspectionCard(rating: rating, isEstimate: inference.confidence.isEstimate)
                    .id(restaurantID)
                SlopOMeterView(rating: rating)
                gradingNotes

                if didLoad {
                    CommunityNotesSection(restaurantID: restaurantID, chainSlug: chainMatch?.chainSlug)
                    addNoteButton
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mapItem.openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                .accessibilityHint("Get directions in Apple Maps")
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView(chainSlug: chainMatch?.chainSlug, resolveRestaurant: persistRestaurant)
                .presentationDetents([.medium, .large])
        }
        .task(id: restaurantID) { loadRestaurant() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(restaurantName)
                .font(DS.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            let facts = [chainMatch != nil ? "Chain" : nil, distance].compactMap { $0 }
            if !facts.isEmpty {
                Text(facts.joined(separator: ", "))
                    .font(DS.Typeface.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !address.isEmpty {
                Text(address)
                    .font(DS.Typeface.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Why we gave this grade, and how sure we are.
    private var gradingNotes: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text("How we graded it")
                .font(DS.Typeface.headline)
                .accessibilityAddTraits(.isHeader)

            Label {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(inference.confidence.displayName)
                        .font(DS.Typeface.callout.weight(.semibold))
                    Text(chainMatch?.chainInfo.ratingReason ?? inference.reason)
                        .font(DS.Typeface.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: confidenceSymbol)
                    .foregroundStyle(inference.confidence.isEstimate ? DS.Palette.fryer : DS.Palette.pickle)
            }
            .accessibilityElement(children: .combine)

            if inference.confidence.isEstimate {
                Label {
                    Text(inference.confidence == .category
                        ? "We haven't graded this chain by hand yet, so its grade comes from the kind of place it is. Notes from people who've eaten here make it better."
                        : "This is a guess from the name and type of place. Notes from people who've eaten here make it better.")
                        .font(DS.Typeface.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: DS.Radius.card))
    }

    private var confidenceSymbol: String {
        switch inference.confidence {
        case .known:    "checkmark.seal.fill"
        case .category: "square.stack.3d.up.fill"
        case .high:     "checkmark.circle.fill"
        case .medium:   "questionmark.circle.fill"
        case .low:      "questionmark.diamond.fill"
        }
    }

    private var addNoteButton: some View {
        Button {
            showAddNote = true
        } label: {
            Label("Add a Note", systemImage: "square.and.pencil")
                .font(DS.Typeface.headline)
                .foregroundStyle(DS.onAccent)
                .frame(maxWidth: .infinity, minHeight: DS.minHitTarget)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityHint("Report Sysco deliveries, prices, or tip screens")
    }

    // MARK: - Data

    /// Loads a previously saved record, if any. Inferred ratings stay transient
    /// until the user contributes (see `persistRestaurant`).
    private func loadRestaurant() {
        let id = restaurantID
        let descriptor = FetchDescriptor(predicate: #Predicate<Restaurant> { $0.id == id })
        restaurant = try? modelContext.fetch(descriptor).first
        didLoad = true
    }

    /// Returns the saved record for this place, inserting it on first contribution.
    private func persistRestaurant() -> Restaurant {
        if let restaurant { return restaurant }

        let coord = ChainMatcher.coordinate(for: mapItem)
        let newRestaurant = Restaurant(
            id: restaurantID,
            name: restaurantName,
            chainSlug: chainMatch?.chainSlug,
            latitude: coord.latitude,
            longitude: coord.longitude,
            address: address,
            slopRating: inference.rating,
            ratingSource: chainMatch != nil ? .seeded : .community
        )

        modelContext.insert(newRestaurant)
        restaurant = newRestaurant
        return newRestaurant
    }
}

// MARK: - Inspection card

/// The hero placard. The grade gets rubber-stamped on when the card appears;
/// with Reduce Motion it fades in instead.
struct InspectionCard: View {
    let rating: SlopRating
    var isEstimate = false

    @ScaledMetric(relativeTo: .largeTitle) private var gradeSize: CGFloat = 76
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var stamped = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.l))

        layout {
            Text(rating.grade)
                .font(.system(size: gradeSize, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minWidth: gradeSize * 1.1)
                .rotationEffect(.degrees(stamped ? -6 : (reduceMotion ? -6 : -18)))
                .scaleEffect(stamped || reduceMotion ? 1 : 2.2)
                .opacity(stamped ? 1 : 0)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label(rating.name, systemImage: rating.symbol)
                    .font(DS.Typeface.title)
                Text(rating.description)
                    .font(DS.Typeface.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if isEstimate {
                    Text("Estimated")
                        .font(DS.Typeface.caption.weight(.bold))
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xxs)
                        .overlay {
                            Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                        }
                        .padding(.top, DS.Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(DS.Palette.ink)
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rating.color, in: .rect(cornerRadius: DS.Radius.hero))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.hero)
                .inset(by: 6)
                .strokeBorder(
                    DS.Palette.ink.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2, dash: isEstimate ? [6, 4] : [])
                )
        }
        .sensoryFeedback(trigger: stamped) { _, new in
            guard new else { return nil }
            return rating.meterIndex.map { $0 >= 3 } == true ? .success : .impact(weight: .heavy)
        }
        .task {
            // Let the push transition settle so the stamp is the thing you notice.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 250))
            withAnimation(reduceMotion ? .easeIn(duration: 0.25) : .spring(duration: 0.38, bounce: 0.45)) {
                stamped = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating.accessibilityLabel)
        .accessibilityValue(rating.description + (isEstimate ? " Estimated." : ""))
    }
}
