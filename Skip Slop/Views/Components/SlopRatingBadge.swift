import SwiftUI

struct SlopRatingBadge: View {
    let rating: SlopRating
    var size: BadgeSize = .regular

    enum BadgeSize {
        case compact, regular, large

        var font: Font {
            switch self {
            case .compact: .caption2.weight(.bold)
            case .regular:  .caption.weight(.bold)
            case .large:    .subheadline.weight(.heavy)
            }
        }

        var hPadding: CGFloat {
            switch self {
            case .compact: 6
            case .regular:  10
            case .large:    14
            }
        }

        var vPadding: CGFloat {
            switch self {
            case .compact: 3
            case .regular:  5
            case .large:    8
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: rating.icon)
                .font(size.font)

            Text(rating.subtitle.uppercased())
                .font(size.font)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, size.hPadding)
        .padding(.vertical, size.vPadding)
        .background(rating.color, in: Capsule())
        .overlay {
            if rating == .redMinus {
                // Stripe pattern overlay for Red-
                Capsule()
                    .strokeBorder(
                        .white.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            }
        }
    }
}
