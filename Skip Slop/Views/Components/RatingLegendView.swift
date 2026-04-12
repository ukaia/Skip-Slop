import SwiftUI

struct RatingLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SlopRating.allCases) { rating in
                HStack(spacing: 12) {
                    Circle()
                        .fill(rating.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: rating.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rating.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(rating.color)

                        Text(rating.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}
