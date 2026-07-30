import SwiftUI

/// The six-step slop scale. Position on the scale is the only thing this component
/// communicates — the rating's name and meaning live in `SlopRatingHeroView`, so the two
/// are no longer saying the same thing twice. The active step is taller and ringed rather
/// than just more saturated, which is what made the old bar hard to read at a glance and
/// unreadable for anyone colourblind.
struct SlopOMeterView: View {
    let rating: SlopRating?
    var height: CGFloat = 10

    private let segments = SlopRating.meterCases

    var body: some View {
        if let rating, rating == .grey {
            greyMeter
        } else {
            activeMeter
        }
    }

    private var activeMeter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(segments) { segment in
                    let isActive = segment == rating

                    Capsule()
                        .fill(segment.color.opacity(isActive ? 1.0 : 0.18))
                        .frame(height: isActive ? height + 6 : height)
                        .overlay {
                            if isActive {
                                Capsule().strokeBorder(.background, lineWidth: 2)
                            }
                        }
                }
            }
            .frame(height: height + 6)
            .animation(.spring(duration: 0.4), value: rating)

            HStack {
                Text("Slop")
                    .foregroundStyle(.slopRedMinus)
                Spacer()
                Text("Real food")
                    .foregroundStyle(.slopGreenPlus)
            }
            .font(.caption2.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scaleAccessibilityLabel)
    }

    private var greyMeter: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.slopGrey.opacity(0.18))
                .frame(height: height)

            Text("Off the scale — fast food")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var scaleAccessibilityLabel: String {
        guard let rating, let index = rating.meterIndex else {
            return "Slop scale, not rated"
        }
        return "Slop scale, step \(index + 1) of \(segments.count): \(rating.subtitle)"
    }
}
