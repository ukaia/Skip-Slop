import SwiftUI

nonisolated enum SlopRating: String, Codable, CaseIterable, Identifiable {
    case greenPlus  = "green_plus"
    case green      = "green"
    case yellow     = "yellow"
    case orange     = "orange"
    case red        = "red"
    case redMinus   = "red_minus"
    case grey       = "grey"

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
        case .grey:      "N/A"
        }
    }

    /// Grade as VoiceOver should speak it.
    var spokenGrade: String {
        switch self {
        case .greenPlus: "A plus"
        case .redMinus:  "F minus"
        case .grey:      "not graded"
        default:         grade
        }
    }

    var name: String {
        switch self {
        case .greenPlus: "Real & Local"
        case .green:     "Real Food"
        case .yellow:    "Some Slop"
        case .orange:    "Low Grade"
        case .red:       "Sysco Slop"
        case .redMinus:  "Pricey Slop"
        case .grey:      "Fast Food"
        }
    }

    var description: String {
        switch self {
        case .greenPlus: "Locally sourced, cooked from real ingredients."
        case .green:     "Real food, not frozen and reheated."
        case .yellow:    "The mains are real. The sides came off a truck."
        case .orange:    "Not Sysco, but still processed and forgettable."
        case .red:       "Sysco or US Foods supplied. Microwaved slop."
        case .redMinus:  "Sysco slop at steakhouse prices."
        case .grey:      "Fast food. It is what it is, so we don't grade it."
        }
    }

    /// SF Symbol with a shape unique to this rating, so ratings stay distinguishable without color.
    var symbol: String {
        switch self {
        case .greenPlus: "leaf.fill"
        case .green:     "checkmark.seal.fill"
        case .yellow:    "exclamationmark.triangle.fill"
        case .orange:    "hand.thumbsdown.fill"
        case .red:       "xmark.octagon.fill"
        case .redMinus:  "dollarsign.circle.fill"
        case .grey:      "takeoutbag.and.cup.and.straw.fill"
        }
    }

    /// e.g. "Grade F, Sysco Slop".
    var accessibilityLabel: String {
        self == .grey ? "Not graded, \(name)" : "Grade \(spokenGrade), \(name)"
    }

    var color: Color {
        switch self {
        case .greenPlus: .slopGreenPlus
        case .green:     .slopGreen
        case .yellow:    .slopYellow
        case .orange:    .slopOrange
        case .red:       .slopRed
        case .redMinus:  .slopRedMinus
        case .grey:      .slopGrey
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
        case .grey:      6
        }
    }

    /// Segment index for the slop-o-meter (excludes grey)
    var meterIndex: Int? {
        switch self {
        case .redMinus:  0
        case .red:       1
        case .orange:    2
        case .yellow:    3
        case .green:     4
        case .greenPlus: 5
        case .grey:      nil
        }
    }

    static var meterCases: [SlopRating] {
        [.redMinus, .red, .orange, .yellow, .green, .greenPlus]
    }
}

nonisolated enum RatingSource: String, Codable {
    case seeded    = "seeded"
    case community = "community"
    case verified  = "verified"
}
