import Foundation

/// The answer to "How is the food made here?"
nonisolated enum PrepVerdict: String, Codable, CaseIterable, Identifiable, Sendable {
    case scratch
    case reheated
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scratch:  "Made from scratch"
        case .reheated: "Reheated"
        case .unsure:   "Not sure"
        }
    }

    var symbol: String {
        switch self {
        case .scratch:  "frying.pan.fill"
        case .reheated: "microwave.fill"
        case .unsure:   "questionmark.circle"
        }
    }
}

/// What the reporter based their answer on. Firsthand evidence counts more.
nonisolated enum PrepEvidence: String, Codable, CaseIterable, Identifiable, Sendable {
    case workedHere = "worked_here"
    case sawPrep = "saw_prep"
    case frozenBoxes = "frozen_boxes"
    case distributorBoxes = "distributor_boxes"
    case staffTold = "staff_told"
    case menuSays = "menu_says"
    case impression

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workedHere:       "I work or worked here"
        case .sawPrep:          "Saw the food being prepared"
        case .frozenBoxes:      "Saw frozen or pre-made boxes"
        case .distributorBoxes: "Saw Sysco or US Foods packaging"
        case .staffTold:        "Staff told me"
        case .menuSays:         "Menu or website says house-made"
        case .impression:       "Just my impression"
        }
    }

    var symbol: String {
        switch self {
        case .workedHere:       "person.badge.key.fill"
        case .sawPrep:          "eye.fill"
        case .frozenBoxes:      "snowflake"
        case .distributorBoxes: "shippingbox.fill"
        case .staffTold:        "bubble.left.fill"
        case .menuSays:         "menucard.fill"
        case .impression:       "hand.thumbsup.fill"
        }
    }

    /// Roll-up weight (docs/data/RATING_METHOD.md).
    var weight: Double {
        switch self {
        case .workedHere, .sawPrep, .frozenBoxes, .distributorBoxes, .staffTold: 1.0
        case .menuSays: 0.75
        case .impression: 0.5
        }
    }

    /// Evidence that fits each verdict, for the report form.
    static func options(for verdict: PrepVerdict) -> [PrepEvidence] {
        switch verdict {
        case .scratch:  [.sawPrep, .menuSays, .staffTold, .workedHere, .impression]
        case .reheated: [.frozenBoxes, .distributorBoxes, .sawPrep, .staffTold, .workedHere, .impression]
        case .unsure:   []
        }
    }
}

/// One user's report for one place. Stored in CloudKit as a `PrepReport` record
/// named `prep_<placeKey>_<userRecordName>`, so a user has one report per place.
nonisolated struct PrepReport: Identifiable, Equatable, Sendable {
    /// CloudKit record name.
    let id: String
    let placeKey: String
    /// The reporter's iCloud user record name (or a local ID in sample-data mode).
    let reporterID: String
    var chainSlug: String?
    var verdict: PrepVerdict
    var evidence: PrepEvidence?
    var note: String
    var createdAt: Date
    var updatedAt: Date
    /// UTC day the report was first filed ("2026-10-12"), and which report of
    /// that day it was for this reporter. Used by the daily limit.
    var dayStamp: String
    var dailyCount: Int
    /// When this reporter filed their first report anywhere (tenure).
    var reporterSince: Date?
    /// Flags from other users on the evidence note.
    var flagCount = 0

    static func recordName(placeKey: String, reporterID: String) -> String {
        "prep_\(sanitized(placeKey))_\(sanitized(reporterID))"
    }

    /// CloudKit record names allow ASCII letters, digits, and a few symbols; keep
    /// them short enough for the 255-character limit.
    static func sanitized(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        return String(String(value.map { allowed.contains($0) ? $0 : "-" }).prefix(110))
    }

    static func dayStamp(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
