import SwiftUI

/// How a restaurant's food is made, from A+ (local, from scratch) to F−
/// (distributor meals reheated). See docs/data/RATING_METHOD.md.
nonisolated enum SlopRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case greenPlus  = "green_plus"
    case green      = "green"
    case yellow     = "yellow"
    case orange     = "orange"
    case red        = "red"
    case redMinus   = "red_minus"
    /// No evidence yet. Raw value kept from the old "N/A" grade so saved data still decodes.
    case notGraded  = "grey"

    var id: String { rawValue }

    /// Inspection-style letter grade. Never the only signal: always paired with
    /// `symbol` (a unique shape) and `name`.
    var grade: String {
        switch self {
        case .greenPlus: "A+"
        case .green:     "A"
        case .yellow:    "B"
        case .orange:    "C"
        case .red:       "F"
        case .redMinus:  "F−"
        case .notGraded: "?"
        }
    }

    /// Grade as VoiceOver should speak it.
    var spokenGrade: String {
        switch self {
        case .greenPlus: "A plus"
        case .redMinus:  "F minus"
        case .notGraded: "not graded yet"
        default:         grade
        }
    }

    var name: String {
        switch self {
        case .greenPlus: "Local & Scratch"
        case .green:     "Scratch Kitchen"
        case .yellow:    "Mostly Scratch"
        case .orange:    "Assembled"
        case .red:       "Reheated"
        case .redMinus:  "Truck to Table"
        case .notGraded: "Not Graded Yet"
        }
    }

    var description: String {
        switch self {
        case .greenPlus: "Cooked from scratch with ingredients from named local farms."
        case .green:     "Cooked from scratch on site, mostly from fresh ingredients."
        case .yellow:    "Mostly cooked on site. Some parts arrive pre-made."
        case .orange:    "Part cooked, part assembled from pre-made and frozen parts."
        case .red:       "Mostly pre-made or frozen, reheated or fried on site."
        case .redMinus:  "Whole meals off a Sysco-style truck, reheated."
        case .notGraded: "No evidence yet. Tell us how the food is made."
        }
    }

    /// SF Symbol with a shape unique to this rating, so ratings stay distinguishable without color.
    var symbol: String {
        switch self {
        case .greenPlus: "leaf.fill"
        case .green:     "checkmark.seal.fill"
        case .yellow:    "frying.pan.fill"
        case .orange:    "square.stack.3d.up.fill"
        case .red:       "microwave.fill"
        case .redMinus:  "box.truck.fill"
        case .notGraded: "questionmark.circle"
        }
    }

    var isGraded: Bool { self != .notGraded }

    /// e.g. "Grade F, Reheated".
    var accessibilityLabel: String {
        isGraded ? "Grade \(spokenGrade), \(name)" : name
    }

    var color: Color {
        switch self {
        case .greenPlus: .slopGreenPlus
        case .green:     .slopGreen
        case .yellow:    .slopYellow
        case .orange:    .slopOrange
        case .red:       .slopRed
        case .redMinus:  .slopRedMinus
        case .notGraded: .slopGrey
        }
    }

    var sortOrder: Int {
        switch self {
        case .greenPlus: 0
        case .green:     1
        case .yellow:    2
        case .orange:    3
        case .red:       4
        case .redMinus:  5
        case .notGraded: 6
        }
    }

    /// Segment index for the slop-o-meter (excludes not graded)
    var meterIndex: Int? {
        switch self {
        case .redMinus:  0
        case .red:       1
        case .orange:    2
        case .yellow:    3
        case .green:     4
        case .greenPlus: 5
        case .notGraded: nil
        }
    }

    static var meterCases: [SlopRating] {
        [.redMinus, .red, .orange, .yellow, .green, .greenPlus]
    }

    /// Parses a letter grade ("A+", "F-", "F−").
    init?(letter: String) {
        let normalized = letter.replacingOccurrences(of: "-", with: "−")
        guard let match = Self.allCases.first(where: { $0.isGraded && $0.grade == normalized }) else { return nil }
        self = match
    }
}

nonisolated enum RatingSource: String, Codable {
    case seeded    = "seeded"
    case community = "community"
    case verified  = "verified"
}
