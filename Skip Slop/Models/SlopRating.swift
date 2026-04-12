import SwiftUI

enum SlopRating: String, Codable, CaseIterable, Identifiable {
    case greenPlus  = "green_plus"
    case green      = "green"
    case yellow     = "yellow"
    case orange     = "orange"
    case red        = "red"
    case redMinus   = "red_minus"
    case grey       = "grey"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .greenPlus: "Green+"
        case .green:     "Green"
        case .yellow:    "Yellow"
        case .orange:    "Orange"
        case .red:       "Red"
        case .redMinus:  "Red -"
        case .grey:      "Grey"
        }
    }

    var subtitle: String {
        switch self {
        case .greenPlus: "Real Local Food"
        case .green:     "Real Food"
        case .yellow:    "Some Slop"
        case .orange:    "Low Quality"
        case .red:       "Sysco Slop"
        case .redMinus:  "Sysco Slop & Expensive"
        case .grey:      "Not Applicable"
        }
    }

    var description: String {
        switch self {
        case .greenPlus: "Verified locally sourced, real ingredients"
        case .green:     "Real food — not frozen/reheated mass-produced stuff"
        case .yellow:    "Some items are real, but sides and extras are slop"
        case .orange:    "Not Sysco, but still low quality processed food"
        case .red:       "Sysco/US Foods supplied — microwaved slop"
        case .redMinus:  "Sysco slop AND they charge premium prices for it"
        case .grey:      "Fast food / not applicable — it is what it is"
        }
    }

    var icon: String {
        switch self {
        case .greenPlus: "leaf.fill"
        case .green:     "checkmark.seal.fill"
        case .yellow:    "exclamationmark.triangle.fill"
        case .orange:    "arrow.down.circle.fill"
        case .red:       "xmark.octagon.fill"
        case .redMinus:  "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .grey:      "minus.circle.fill"
        }
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

enum RatingSource: String, Codable {
    case seeded    = "seeded"
    case community = "community"
    case verified  = "verified"
}
