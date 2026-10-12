import SwiftUI

/// Six-step scale from F− to A+. Every segment carries its grade, so the
/// position reads without color; the active one is filled and lifted.
struct SlopOMeterView: View {
    let rating: SlopRating

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let segments = SlopRating.meterCases

    var body: some View {
        Group {
            if !rating.isGraded {
                Text("Not graded yet")
                    .font(DS.Typeface.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .background(.quaternary, in: .capsule)
            } else {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(segments) { segment in
                        let isActive = segment == rating
                        Text(segment.grade)
                            .font(.system(.caption, design: .rounded, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(isActive ? AnyShapeStyle(DS.Palette.ink) : AnyShapeStyle(.secondary))
                            .frame(maxWidth: .infinity, minHeight: height)
                            .background(
                                isActive ? AnyShapeStyle(segment.color) : AnyShapeStyle(segment.color.opacity(0.18)),
                                in: .capsule
                            )
                            .scaleEffect(isActive ? 1.12 : 1)
                            .zIndex(isActive ? 1 : 0)
                    }
                }
                .animation(reduceMotion ? nil : .snappySlop, value: rating)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation {
            if let index = rating.meterIndex {
                Gauge(value: Double(index), in: 0...Double(segments.count - 1)) {
                    Text("Slop-o-meter")
                } currentValueLabel: {
                    Text(rating.accessibilityLabel)
                }
            } else {
                Text("Slop-o-meter, not graded")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(SlopRating.allCases) { SlopOMeterView(rating: $0) }
    }
    .padding()
}
