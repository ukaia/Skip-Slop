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
            SlopRatingBadge(rating: rating, size: .tile)
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
                Text("Grades work like the health inspection card in a restaurant window, except we're grading where the food comes from.")
                    .font(DS.Typeface.callout)
                    .foregroundStyle(.secondary)
                RatingLegendView()
            }
            .padding(DS.Spacing.l)
        }
        .navigationTitle("Rating Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
