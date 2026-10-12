import Foundation

/// Community prep reports for one place, rolled up into a grade.
/// The rules are documented in docs/data/RATING_METHOD.md ("Community reports").
nonisolated struct CommunityRollup: Equatable, Sendable {
    /// Reports needed (excluding "not sure") before a community grade shows.
    static let minimumReports = 5
    /// Total weight needed as well, so five "just my impression" reports aren't enough.
    static let minimumWeight = 3.0
    /// New reports allowed per reporter per UTC day.
    static let dailyLimit = 20
    /// Flags from other users that hide a note and drop its report.
    static let flagsToHide = 3
    /// Reporters newer than this count half.
    static let newReporterInterval: TimeInterval = 24 * 60 * 60
    /// When one side holds this share of the weight, the other side counts half.
    static let consensusShare = 0.8
    /// For a chain with a cited grade, reports needed to override it.
    static let reportsToOverrideMedium = 10

    /// Qualifying reports that said scratch or reheated.
    let counted: Int
    let scratchCount: Int
    let reheatedCount: Int
    let unsureCount: Int
    /// Reports dropped by abuse rules (flags, flagged reporters, daily limit).
    let ignoredCount: Int
    let totalWeight: Double
    /// Smoothed, weighted share of scratch answers (0...1).
    let scratchShare: Double
    /// Share of the reheated weight that cites distributor packaging.
    let distributorShare: Double

    var qualifies: Bool {
        counted >= Self.minimumReports && totalWeight >= Self.minimumWeight
    }

    var reportsNeeded: Int { max(0, Self.minimumReports - counted) }

    /// The community grade, when there are enough reports.
    var rating: SlopRating? {
        guard qualifies else { return nil }
        return Self.rating(forScratchShare: scratchShare, distributorShare: distributorShare)
    }

    /// Raw (unsmoothed) percentage of qualifying reports that said scratch, for display.
    var scratchPercent: Int {
        counted == 0 ? 0 : Int((Double(scratchCount) / Double(counted) * 100).rounded())
    }

    static func rating(forScratchShare share: Double, distributorShare: Double) -> SlopRating {
        switch share {
        case 0.8...: .green
        case 0.6..<0.8: .yellow
        case 0.4..<0.6: .orange
        default: (share < 0.15 && distributorShare >= 0.5) ? .redMinus : .red
        }
    }

    static let empty = CommunityRollup(
        counted: 0, scratchCount: 0, reheatedCount: 0, unsureCount: 0, ignoredCount: 0,
        totalWeight: 0, scratchShare: 0.5, distributorShare: 0
    )

    /// Rolls up every report for one place.
    /// - Parameters:
    ///   - flaggedReporters: reporter IDs the developer has flagged; their reports are ignored.
    static func compute(reports: [PrepReport], flaggedReporters: Set<String> = [], now: Date = .now) -> CommunityRollup {
        var unsure = 0
        var ignored = 0
        var votes: [(scratch: Bool, weight: Double, distributor: Bool)] = []
        var seenReporters = Set<String>()

        for report in reports.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            // One report per reporter (record names guarantee it; this guards bad data).
            guard seenReporters.insert(report.reporterID).inserted else { continue }
            if flaggedReporters.contains(report.reporterID)
                || report.dailyCount > dailyLimit
                || report.flagCount >= flagsToHide {
                ignored += 1
                continue
            }
            switch report.verdict {
            case .unsure:
                unsure += 1
            case .scratch, .reheated:
                let evidenceWeight = (report.evidence ?? .impression).weight
                let since = report.reporterSince ?? report.createdAt
                let tenure = now.timeIntervalSince(since) < newReporterInterval ? 0.5 : 1.0
                votes.append((report.verdict == .scratch, evidenceWeight * tenure, report.evidence == .distributorBoxes))
            }
        }

        // Weight by agreement: with a strong consensus, dissenting reports count half.
        let rawTotal = votes.reduce(0) { $0 + $1.weight }
        let raw = rawTotal == 0 ? 0.5 : votes.filter(\.scratch).reduce(0) { $0 + $1.weight } / rawTotal
        if raw >= consensusShare || raw <= 1 - consensusShare {
            let majorityIsScratch = raw >= consensusShare
            votes = votes.map { vote in
                vote.scratch == majorityIsScratch ? vote : (vote.scratch, vote.weight * 0.5, vote.distributor)
            }
        }
        let total = votes.reduce(0) { $0 + $1.weight }
        let scratchWeight = votes.filter(\.scratch).reduce(0) { $0 + $1.weight }
        // Shrink toward 50% with one virtual report on each side.
        let smoothed = (scratchWeight + 1) / (total + 2)
        let reheatedWeight = total - scratchWeight
        let distributorWeight = votes.filter { !$0.scratch && $0.distributor }.reduce(0) { $0 + $1.weight }

        return CommunityRollup(
            counted: votes.count,
            scratchCount: votes.filter(\.scratch).count,
            reheatedCount: votes.filter { !$0.scratch }.count,
            unsureCount: unsure,
            ignoredCount: ignored,
            totalWeight: total,
            scratchShare: smoothed,
            distributorShare: reheatedWeight > 0 ? distributorWeight / reheatedWeight : 0
        )
    }
}

/// Combines a cited grade (chain or independent evidence) with community reports.
nonisolated enum GradeResolver {
    static func assessment(for chain: ChainInfo) -> GradeAssessment? {
        guard let rating = chain.citedRating, let confidence = chain.confidence else { return nil }
        return GradeAssessment(rating: rating, kind: .cited(confidence), basis: chain.basis, sources: chain.sources ?? [])
    }

    static func assessment(for independent: IndependentGrade) -> GradeAssessment {
        GradeAssessment(rating: independent.rating, kind: .cited(independent.confidence),
                        basis: independent.basis, sources: independent.sources)
    }

    /// The grade to show. Community reports never override a high-confidence
    /// cited grade, need 10 reports to override a medium one, and the usual 5
    /// for a low one or an ungraded place.
    static func resolve(cited: GradeAssessment?, community: CommunityRollup?) -> GradeAssessment {
        let communityGrade: GradeAssessment? = community.flatMap { rollup in
            rollup.rating.map {
                GradeAssessment(rating: $0, kind: .community(reports: rollup.counted), basis: nil, sources: [])
            }
        }

        guard var cited, case .cited(let confidence) = cited.kind else {
            if var communityGrade {
                communityGrade.supplement = community
                return communityGrade
            }
            var none = GradeAssessment.notGraded
            none.supplement = community
            return none
        }

        if var communityGrade, let community {
            let overrides = switch confidence {
            case .high: false
            case .medium: community.counted >= CommunityRollup.reportsToOverrideMedium
            case .low: true
            }
            if overrides {
                communityGrade.supplement = community
                return communityGrade
            }
        }
        cited.supplement = community
        return cited
    }
}
