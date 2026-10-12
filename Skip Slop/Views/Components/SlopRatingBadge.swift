import SwiftUI

/// How a placard is drawn for where its grade came from: a solid outline for a
/// cited grade, dashed for a community grade, dotted for not graded yet.
enum PlacardStyle {
    case cited, community, notGraded

    init(_ assessment: GradeAssessment) {
        switch assessment.kind {
        case .cited: self = .cited
        case .community: self = .community
        case .notGraded: self = .notGraded
        }
    }

    var dash: [CGFloat] {
        switch self {
        case .cited: []
        case .community: [3, 2.5]
        case .notGraded: [1, 3]
        }
    }

    /// Spoken after the grade, e.g. "Grade A, Scratch Kitchen, community grade".
    var accessibilitySuffix: String {
        switch self {
        case .cited: ""
        case .community: ", community grade"
        case .notGraded: ""
        }
    }
}

/// The inspection placard: letter grade + unique symbol on a condiment fill.
/// Readable without color (grade text + symbol shape), sized with Dynamic Type.
struct SlopRatingBadge: View {
    let rating: SlopRating
    var size: BadgeSize = .regular
    var style: PlacardStyle = .cited

    enum BadgeSize {
        /// Inline capsule: symbol + grade + name.
        case regular
        /// Square tile for list rows.
        case tile
    }

    @ScaledMetric(relativeTo: .title3) private var tileSide: CGFloat = 48

    var body: some View {
        content
            .foregroundStyle(DS.Palette.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rating.accessibilityLabel + style.accessibilitySuffix)
    }

    @ViewBuilder
    private var content: some View {
        switch size {
        case .regular:
            Label {
                Text(rating.isGraded ? "\(rating.grade) \(rating.name)" : rating.name)
            } icon: {
                Image(systemName: rating.symbol)
            }
            .font(DS.Typeface.caption.weight(.bold))
            .fontDesign(.rounded)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .background(rating.color, in: .capsule)
            .overlay { outline(Capsule()) }
        case .tile:
            VStack(spacing: 0) {
                Image(systemName: style == .community ? "person.2.fill" : rating.symbol)
                    .font(.caption2.weight(.bold))
                Text(rating.grade)
                    .font(DS.Typeface.grade)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: tileSide, height: tileSide)
            .background(rating.color, in: .rect(cornerRadius: DS.Radius.placard))
            .overlay { outline(RoundedRectangle(cornerRadius: DS.Radius.placard)) }
        }
    }

    private func outline(_ shape: some InsettableShape) -> some View {
        shape
            .inset(by: 2)
            .strokeBorder(
                DS.Palette.ink.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: style.dash)
            )
    }
}

/// Map pin version of the placard: compact capsule with a pointer.
struct RatingPin: View {
    let rating: SlopRating
    var style: PlacardStyle = .cited
    var isSelected = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: -1) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: style == .community ? "person.2.fill" : rating.symbol)
                    .font(.caption2.weight(.black))
                Text(rating.grade)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(DS.Palette.ink)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .frame(minWidth: 44, minHeight: 30)
            .background(rating.color, in: .capsule)
            .overlay {
                Capsule()
                    .inset(by: 1.5)
                    .strokeBorder(
                        DS.Palette.ink.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: style.dash)
                    )
            }
            // Ungraded pins step back so graded ones stand out.
            .opacity(style == .notGraded && !isSelected ? 0.85 : 1)

            Triangle()
                .rotation(.degrees(180))
                .fill(rating.color)
                .frame(width: 10, height: 6)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .scaleEffect(isSelected ? 1.25 : (style == .notGraded ? 0.85 : 1), anchor: .bottom)
        .animation(reduceMotion ? nil : .snappySlop, value: isSelected)
    }
}

nonisolated struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Placards") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(SlopRating.allCases) { rating in
            HStack {
                SlopRatingBadge(rating: rating, size: .tile, style: rating.isGraded ? .cited : .notGraded)
                SlopRatingBadge(rating: rating, size: .tile, style: .community)
                SlopRatingBadge(rating: rating)
                RatingPin(rating: rating, style: rating.isGraded ? .cited : .notGraded)
            }
        }
    }
    .padding()
}
