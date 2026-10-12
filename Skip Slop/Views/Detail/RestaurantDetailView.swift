import SwiftUI
import SwiftData
import MapKit

struct RestaurantDetailView: View {
    let entry: RatedMapItem
    var distance: String?

    @Environment(\.modelContext) private var modelContext
    @State private var restaurant: Restaurant?
    @State private var showAddNote = false
    @State private var showWhy = false
    @State private var reportVerdict: PrepVerdict?
    @State private var didLoad = false

    private var prepReports: PrepReportStore { .shared }
    private var mapItem: MKMapItem { entry.item }
    private var chainMatch: ChainMatchResult? { entry.chainMatch }

    private var assessment: GradeAssessment {
        GradeResolver.resolve(cited: entry.cited, community: prepReports.rollup(for: entry.placeKey))
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
        let assessment = assessment
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    InspectionCard(assessment: assessment)
                        .id(restaurantID)
                    gradeProvenance(assessment)
                }
                if assessment.isGraded {
                    SlopOMeterView(rating: assessment.rating)
                }
                PrepReportSection(
                    placeKey: entry.placeKey,
                    isGraded: assessment.isGraded,
                    onReport: { reportVerdict = $0 }
                )

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
        .sheet(isPresented: $showWhy) {
            WhyThisGradeView(placeName: restaurantName, assessment: assessment)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $reportVerdict) { verdict in
            ReportPrepView(
                placeName: restaurantName,
                placeKey: entry.placeKey,
                chainSlug: chainMatch?.chainSlug,
                initialVerdict: verdict
            )
            .presentationDetents([.large])
        }
        .task(id: restaurantID) {
            loadRestaurant()
            await prepReports.load(placeKey: entry.placeKey)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(restaurantName)
                .font(DS.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            let facts = [chainMatch.map { "\($0.chainInfo.name) chain" } ?? "Independent", distance].compactMap { $0 }
            Text(facts.joined(separator: ", "))
                .font(DS.Typeface.callout.weight(.semibold))
                .foregroundStyle(.secondary)

            if !address.isEmpty {
                Text(address)
                    .font(DS.Typeface.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Where the grade came from, with a way to see the evidence.
    @ViewBuilder
    private func gradeProvenance(_ assessment: GradeAssessment) -> some View {
        switch assessment.kind {
        case .cited, .community:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.m) {
                    provenanceLabel(assessment)
                    Spacer(minLength: 0)
                    whyButton
                }
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    provenanceLabel(assessment)
                    whyButton
                }
            }
        case .notGraded:
            Text(entry.chainMatch == nil
                 ? "We don't guess grades for independent restaurants. Been here? Tell us how the food is made below."
                 : "We haven't found evidence on how this chain makes its food yet. Been here? Tell us below.")
                .font(DS.Typeface.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func provenanceLabel(_ assessment: GradeAssessment) -> some View {
        Label {
            Text(assessment.label)
                .font(DS.Typeface.callout.weight(.semibold))
        } icon: {
            Image(systemName: assessment.isCommunity ? "person.2.fill" : "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
        }
    }

    private var whyButton: some View {
        Button {
            showWhy = true
        } label: {
            Label("Why this grade", systemImage: "info.circle")
                .font(DS.Typeface.callout.weight(.semibold))
                .frame(minHeight: DS.minHitTarget)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityHint("Shows the evidence and sources behind this grade")
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
        .accessibilityHint("Share prices, tipping, or anything else about this place")
    }

    // MARK: - Data

    /// Loads a previously saved record, if any. Records stay transient until the
    /// user contributes (see `persistRestaurant`).
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
            slopRating: assessment.rating,
            ratingSource: assessment.isCommunity ? .community : .seeded
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
    let assessment: GradeAssessment

    @ScaledMetric(relativeTo: .largeTitle) private var gradeSize: CGFloat = 76
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var stamped = false

    private var rating: SlopRating { assessment.rating }
    private var style: PlacardStyle { PlacardStyle(assessment) }

    private var tag: String? {
        switch assessment.kind {
        case .cited: nil
        case .community: "Community grade"
        case .notGraded: "Not graded yet"
        }
    }

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
                if let tag {
                    Text(tag)
                        .font(DS.Typeface.caption.weight(.bold))
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xxs)
                        .overlay {
                            Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: style.dash))
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
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: style.dash.map { $0 * 2 })
                )
        }
        .sensoryFeedback(trigger: stamped) { _, new in
            guard new, rating.isGraded else { return nil }
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
        .accessibilityLabel(rating.accessibilityLabel + style.accessibilitySuffix)
        .accessibilityValue(rating.description)
    }
}
