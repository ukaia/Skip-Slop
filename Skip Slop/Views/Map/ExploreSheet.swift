import SwiftUI
import MapKit

/// Contents of the persistent bottom sheet: search, grade chips, and nearby
/// results. Selecting a row or a map pin pushes the detail card in place.
struct ExploreSheet: View {
    @Bindable var model: ExploreModel
    @FocusState private var searchFocused: Bool
    @Namespace private var zoom
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.m) {
                    if model.isLocationBlocked && !model.isMock {
                        locationOffCard
                    }
                    GradeFilterBar(selection: $model.filter)
                    results
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $model.selectedItem) { item in
                if let entry = model.selectedEntry {
                    RestaurantDetailView(
                        entry: entry,
                        distance: model.distanceText(to: entry.item)
                    )
                    .navigationTransition(.zoom(sourceID: item, in: zoom))
                }
            }
        }
        .onChange(of: searchFocused) { _, focused in
            if focused { model.detent = .large }
        }
        .sheet(isPresented: $model.showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            MapSearchBar(
                text: $model.query,
                isSearching: model.isSearching && model.hasLoadedInitial,
                focus: $searchFocused,
                onCommit: model.performSearch
            )

            if let message = model.searchMessage {
                Text(message)
                    .font(DS.Typeface.meta)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.s)
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        let displayed = model.displayedResults
        if !model.hasLoadedInitial || (model.isSearching && model.ratedResults.isEmpty) {
            HStack(spacing: DS.Spacing.m) {
                ProgressView()
                Text("Sniffing out restaurants…")
                    .font(DS.Typeface.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .accessibilityElement(children: .combine)
        } else if model.ratedResults.isEmpty {
            ContentUnavailableView(
                "No restaurants here",
                systemImage: "fork.knife",
                description: Text("Move the map, or search for a city or zip code.")
            )
        } else if displayed.isEmpty {
            noMatches
        } else {
            Text(displayed.count == 1 ? "1 place nearby" : "\(displayed.count) places nearby")
                .font(DS.Typeface.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, DS.Spacing.xs)

            ForEach(displayed) { entry in
                Button {
                    searchFocused = false
                    model.selectedItem = entry.item
                } label: {
                    RestaurantRow(entry: entry, assessment: model.assessment(for: entry), distance: model.distanceText(to: entry.item))
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: entry.item, in: zoom)
                .accessibilityHint("Shows details")

                if entry.id != displayed.last?.id {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private var noMatches: some View {
        let text = model.query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            ContentUnavailableView {
                Label("Nothing nearby matches “\(text)”", systemImage: "magnifyingglass")
            } description: {
                Text("Press Search to look beyond this area.")
            } actions: {
                if !model.isMock {
                    Button("Search", action: model.performSearch)
                        .buttonStyle(.bordered)
                }
            }
        } else if let filter = model.filter {
            ContentUnavailableView {
                Label("No \(filter.name) here", systemImage: filter.symbol)
            } description: {
                Text("Try another grade, or move the map.")
            } actions: {
                Button("Show All Grades") { model.filter = nil }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var locationOffCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Label("Location is off", systemImage: "location.slash.fill")
                .font(DS.Typeface.headline)
            Text("Turn it on to see what's around you, or search for a city or zip code.")
                .font(DS.Typeface.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: DS.minHitTarget)
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: DS.Radius.card))
    }
}

// MARK: - Row

struct RestaurantRow: View {
    let entry: RatedMapItem
    let assessment: GradeAssessment
    var distance: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var rating: SlopRating { assessment.rating }
    private var name: String { entry.item.name ?? "Unnamed restaurant" }

    private var details: String {
        var parts: [String] = []
        if let distance { parts.append(distance) }
        if assessment.isGraded { parts.append(assessment.label) }
        if let address = entry.item.address?.shortAddress, !address.isEmpty {
            parts.append(address)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.m))

        layout {
            SlopRatingBadge(rating: rating, size: .tile, style: PlacardStyle(assessment))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typeface.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(isLarge ? nil : 2)
                Text(rating.name)
                    .font(DS.Typeface.callout.weight(.semibold))
                    .foregroundStyle(rating.isGraded ? AnyShapeStyle(rating.color) : AnyShapeStyle(.secondary))
                Text(details)
                    .font(DS.Typeface.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(isLarge ? nil : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DS.Spacing.s)
        .frame(minHeight: DS.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(rating.accessibilityLabel)\(PlacardStyle(assessment).accessibilitySuffix)")
        .accessibilityValue(details)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Grade filter

/// Horizontal grade chips. Each chip behaves as a toggle for assistive tech.
struct GradeFilterBar: View {
    @Binding var selection: SlopRating?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Spacing.s) {
                GradeChip(title: "All", symbol: nil, tint: nil, isOn: selection == nil) {
                    selection = nil
                }
                ForEach(SlopRating.allCases) { rating in
                    GradeChip(
                        title: rating.grade,
                        symbol: rating.symbol,
                        tint: rating.color,
                        accessibilityName: rating.accessibilityLabel,
                        isOn: selection == rating
                    ) {
                        selection = selection == rating ? nil : rating
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by grade")
    }
}

private struct GradeChip: View {
    let title: String
    let symbol: String?
    let tint: Color?
    var accessibilityName: String?
    let isOn: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(isOn ? AnyShapeStyle(DS.Palette.ink) : AnyShapeStyle(tint ?? .primary))
                }
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(isOn ? AnyShapeStyle(DS.Palette.ink) : AnyShapeStyle(.primary))
            }
            .padding(.horizontal, DS.Spacing.m)
            .frame(minWidth: DS.minHitTarget, minHeight: DS.minHitTarget)
            .background(
                isOn ? AnyShapeStyle(tint ?? DS.accent) : AnyShapeStyle(.fill.tertiary),
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(accessibilityName ?? "All grades", isOn: Binding(get: { isOn }, set: { _ in action() }))
        }
    }
}
