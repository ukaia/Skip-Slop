import SwiftUI

enum NoteType: String, Codable, CaseIterable, Identifiable {
    case syscoVerified      = "sysco_verified"
    case expensiveConfirmed = "expensive_confirmed"
    case stupidTipOptions   = "stupid_tip_options"
    case syscoContested     = "sysco_contested"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .syscoVerified:      "Sysco Verified"
        case .expensiveConfirmed: "Expensive Confirmed"
        case .stupidTipOptions:   "Stupid Tip Options"
        case .syscoContested:     "Sysco Contested"
        }
    }

    var icon: String {
        switch self {
        case .syscoVerified:      "truck.box.fill"
        case .expensiveConfirmed: "dollarsign.circle.fill"
        case .stupidTipOptions:   "percent"
        case .syscoContested:     "hand.raised.fill"
        }
    }

    var prompt: String {
        switch self {
        case .syscoVerified:      "I work there or saw the Sysco/US Foods delivery"
        case .expensiveConfirmed: "How much did you pay? (e.g. $30 for a burger)"
        case .stupidTipOptions:   "What did the tip options start at? (e.g. 18%)"
        case .syscoContested:     "Why do you think this place isn't Sysco slop?"
        }
    }

    var requiresBody: Bool {
        switch self {
        case .syscoVerified:      false
        case .expensiveConfirmed: true
        case .stupidTipOptions:   true
        case .syscoContested:     true
        }
    }

    var thresholdToPublish: Int {
        switch self {
        case .syscoVerified:      3
        case .expensiveConfirmed: 3
        case .stupidTipOptions:   3
        case .syscoContested:     5
        }
    }

    var color: Color {
        switch self {
        case .syscoVerified:      .slopRed
        case .expensiveConfirmed: .slopOrange
        case .stupidTipOptions:   .slopYellow
        case .syscoContested:     .blue
        }
    }
}
