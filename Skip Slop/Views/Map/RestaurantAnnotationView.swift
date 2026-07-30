import SwiftUI

struct RestaurantAnnotationView: View {
    let rating: SlopRating
    let confidence: RatingInferenceEngine.InferenceResult.Confidence
    let name: String

    /// Verified ratings get a solid fill, inferred ones a hollow ring, guesses a dashed
    /// one. Confidence reads from the shape of the pin instead of the grey "?" badge that
    /// used to hang off nearly every restaurant and looked like an error state.
    private var isVerified: Bool {
        confidence == .known || confidence == .high
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isVerified ? AnyShapeStyle(rating.color) : AnyShapeStyle(.background))
                .frame(width: 30, height: 30)

            Circle()
                .strokeBorder(
                    isVerified ? Color.white : rating.color,
                    style: StrokeStyle(
                        lineWidth: isVerified ? 2 : 2.5,
                        dash: confidence == .low ? [3, 2.5] : []
                    )
                )
                .frame(width: 30, height: 30)

            symbol
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1.5)
        .accessibilityLabel("\(name), \(rating.subtitle), \(confidence.rawValue)")
    }

    @ViewBuilder
    private var symbol: some View {
        if rating == .grey {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(isVerified ? Color.white : rating.color)
        } else {
            Image(systemName: rating.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isVerified ? Color.white : rating.color)
        }
    }
}
