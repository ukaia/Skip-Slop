import SwiftUI

struct RestaurantAnnotationView: View {
    let rating: SlopRating
    let confidence: RatingInferenceEngine.InferenceResult.Confidence
    let name: String

    var body: some View {
        ZStack {
            Circle()
                .fill(rating.color)
                .frame(width: 32, height: 32)
                .shadow(color: rating.color.opacity(0.4), radius: 4, y: 2)
                .opacity(confidenceOpacity)

            if rating != .grey {
                Image(systemName: rating.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Show "?" for low confidence guesses
            if confidence == .low {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Text("?")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                    .offset(x: 12, y: -12)
            }
        }
    }

    private var confidenceOpacity: Double {
        switch confidence {
        case .known: 1.0
        case .high:  0.95
        case .medium: 0.8
        case .low:   0.65
        }
    }
}
