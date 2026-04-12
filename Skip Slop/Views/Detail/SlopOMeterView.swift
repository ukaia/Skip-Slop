import SwiftUI

struct SlopOMeterView: View {
    let rating: SlopRating?
    var height: CGFloat = 28

    private let segments = SlopRating.meterCases

    var body: some View {
        if let rating, rating == .grey {
            greyMeter
        } else {
            activeMeter
        }
    }

    private var activeMeter: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let segmentWidth = geo.size.width / CGFloat(segments.count)

                ZStack(alignment: .leading) {
                    // Background segments
                    HStack(spacing: 1.5) {
                        ForEach(Array(segments.enumerated()), id: \.element) { index, segment in
                            let isActive = segment == rating

                            RoundedRectangle(cornerRadius: cornerRadius(for: index))
                                .fill(segment.color.opacity(isActive ? 1.0 : 0.3))
                                .overlay {
                                    if isActive {
                                        RoundedRectangle(cornerRadius: cornerRadius(for: index))
                                            .fill(segment.color)
                                            .shadow(color: segment.color.opacity(0.6), radius: 6)
                                    }
                                }
                        }
                    }

                    // Marker triangle
                    if let rating, let idx = rating.meterIndex {
                        let xPos = segmentWidth * (CGFloat(idx) + 0.5)
                        Triangle()
                            .fill(rating.color)
                            .frame(width: 12, height: 8)
                            .offset(x: xPos - 6, y: height + 2)
                            .animation(.spring(duration: 0.5), value: rating)
                    }
                }
            }
            .frame(height: height)
            .clipShape(Capsule())

            // Labels
            HStack {
                Text("R-")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.slopRedMinus)
                Spacer()
                if let rating {
                    Text(rating.subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(rating.color)
                }
                Spacer()
                Text("G+")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.slopGreenPlus)
            }
        }
    }

    private var greyMeter: some View {
        VStack(spacing: 6) {
            ZStack {
                Capsule()
                    .fill(Color.slopGrey.opacity(0.2))
                    .frame(height: height)

                Text("N/A")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.slopGrey)
            }

            Text("Not Applicable — Fast Food")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func cornerRadius(for index: Int) -> CGFloat {
        height / 2
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
