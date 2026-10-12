import SwiftUI

/// Full rating guide: placard, name, and what it means. Used in Settings and onboarding.
struct RatingLegendView: View {
    var ratings: [SlopRating] = SlopRating.allCases
    var showsDescriptions = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            ForEach(ratings) { rating in
                RatingLegendRow(rating: rating, showsDescription: showsDescriptions)
            }
        }
    }
}

struct RatingLegendRow: View {
    let rating: SlopRating
    var showsDescription = true

    var body: some View {
        HStack(alignment: showsDescription ? .top : .center, spacing: DS.Spacing.m) {
            SlopRatingBadge(rating: rating, size: .tile, style: rating.isGraded ? .cited : .notGraded)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(rating.name)
                    .font(DS.Typeface.headline)
                if showsDescription {
                    Text(rating.description)
                        .font(DS.Typeface.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating.accessibilityLabel)
        .accessibilityValue(showsDescription ? rating.description : "")
    }
}

/// Settings destination wrapping the legend in a scroll view.
struct RatingGuideScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                Text("Grades work like the health inspection card in a restaurant window, except we're grading how the food is made: cooked from scratch, or reheated from bags and boxes.")
                    .font(DS.Typeface.callout)
                    .foregroundStyle(.secondary)
                RatingLegendView()
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("Where grades come from")
                        .font(DS.Typeface.headline)
                        .accessibilityAddTraits(.isHeader)
                    Label("Chains: researched evidence such as company filings, menus, news reports and former employees, each with sources and a confidence level.", systemImage: "doc.text.magnifyingglass")
                    Label("Community: five or more diner reports on whether the food is made from scratch or reheated.", systemImage: "person.2.fill")
                    Label("Everything else is Not Graded Yet. We never guess, especially for independents.", systemImage: "questionmark.circle")
                }
                .font(DS.Typeface.callout)
                .padding(.top, DS.Spacing.s)
            }
            .padding(DS.Spacing.l)
        }
        .navigationTitle("Rating Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
