import SwiftUI

struct RestaurantRowView: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(restaurant.slopRating.color)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: restaurant.slopRating.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(restaurant.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SlopRatingBadge(rating: restaurant.slopRating, size: .compact)
        }
        .padding(.vertical, 4)
    }
}
