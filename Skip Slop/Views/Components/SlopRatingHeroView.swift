import SwiftUI

/// The single place a rating states what it is and what it means.
///
/// Replaces the old pairing of `SlopOMeterView` plus a large `SlopRatingBadge`, which
/// rendered the same fact twice with no hierarchy between them.
struct SlopRatingHeroView: View {
    let rating: SlopRating

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: rating.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(rating.color, in: Circle())

            Text(rating.subtitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(rating.color)

            Text(rating.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
