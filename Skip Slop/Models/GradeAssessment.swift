import Foundation

/// How sure a cited grade is, from the sources behind it (docs/data/RATING_METHOD.md).
nonisolated enum GradeConfidence: String, Codable, Sendable, CaseIterable {
    case high, medium, low

    var displayName: String {
        switch self {
        case .high:   "High confidence"
        case .medium: "Medium confidence"
        case .low:    "Low confidence"
        }
    }
}

/// A citation behind a grade.
nonisolated struct GradeSource: Codable, Hashable, Sendable {
    let title: String
    let url: URL
    /// 1: the company itself, 2: independent reporting, 3: aggregated insider accounts.
    let tier: Int?

    var tierName: String {
        switch tier {
        case 1: "Company source"
        case 2: "Independent reporting"
        case 3: "Insider and diner accounts"
        default: "Source"
        }
    }
}

/// The grade shown for a place, and where it came from.
nonisolated struct GradeAssessment: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Researched and cited (a chain, or an independent with evidence).
        case cited(GradeConfidence)
        /// From community prep reports.
        case community(reports: Int)
        /// No evidence yet.
        case notGraded
    }

    let rating: SlopRating
    let kind: Kind
    /// Why this grade, in a sentence or two.
    let basis: String?
    let sources: [GradeSource]
    /// Community numbers shown alongside a cited grade they didn't override.
    var supplement: CommunityRollup?

    static let notGraded = GradeAssessment(rating: .notGraded, kind: .notGraded, basis: nil, sources: [])

    var isGraded: Bool { kind != .notGraded }

    var isCommunity: Bool {
        if case .community = kind { return true }
        return false
    }

    /// Short label: "High confidence", "Community grade · 7 reports", "Not graded yet".
    var label: String {
        switch kind {
        case .cited(let confidence): confidence.displayName
        case .community(let reports): "Community grade · \(reports) reports"
        case .notGraded: "Not graded yet"
        }
    }

    /// Sort key for lists: cited (by confidence), then community, then not graded.
    var sortOrder: Int {
        switch kind {
        case .cited(.high): 0
        case .cited(.medium): 1
        case .cited(.low): 2
        case .community: 3
        case .notGraded: 4
        }
    }
}
