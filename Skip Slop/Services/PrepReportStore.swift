import Foundation
import Observation
import os

/// Where prep reports live: CloudKit in normal builds, memory in sample-data
/// mode and tests.
protocol PrepReportBackend: AnyObject {
    /// The current user's stable ID (iCloud user record name).
    func reporterID() async throws -> String
    func fetchReports(placeKey: String) async throws -> [PrepReport]
    func save(_ report: PrepReport) async throws
    /// Records one flag per user per report.
    func flag(reportID: String, reporterID: String) async throws
    /// Reporter IDs the developer has flagged. Their reports are ignored.
    func flaggedReporters() async -> Set<String>
}

enum PrepReportError: LocalizedError, Equatable {
    case dailyLimitReached
    case notAllowed

    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            "You've filed \(CommunityRollup.dailyLimit) new reports today. Try again tomorrow."
        case .notAllowed:
            "That note has language we don't allow. Stick to how the food is made."
        }
    }
}

/// Local daily limit on new reports (editing a report doesn't count). The
/// count is also written to each report so the roll-up can enforce it.
nonisolated struct ReportRateLimiter {
    private let defaults: UserDefaults
    private static let dayKey = "prep_report_day"
    private static let countKey = "prep_report_count"
    private static let firstKey = "prep_report_first"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func count(on day: String) -> Int {
        defaults.string(forKey: Self.dayKey) == day ? defaults.integer(forKey: Self.countKey) : 0
    }

    func canFileNewReport(now: Date = .now) -> Bool {
        count(on: PrepReport.dayStamp(for: now)) < CommunityRollup.dailyLimit
    }

    /// Records a new report and returns its number for the day (1-based).
    @discardableResult
    func recordNewReport(now: Date = .now) -> Int {
        let day = PrepReport.dayStamp(for: now)
        let next = count(on: day) + 1
        defaults.set(day, forKey: Self.dayKey)
        defaults.set(next, forKey: Self.countKey)
        if defaults.object(forKey: Self.firstKey) == nil {
            defaults.set(now, forKey: Self.firstKey)
        }
        return next
    }

    /// When this device filed its first report.
    var firstReport: Date? {
        defaults.object(forKey: Self.firstKey) as? Date
    }
}

/// Community prep reports per place, their roll-ups, and the current user's own reports.
@Observable
final class PrepReportStore {
    static let shared = PrepReportStore(backend: PrepReportStore.defaultBackend())

    private(set) var reports: [String: [PrepReport]] = [:]
    private(set) var rollups: [String: CommunityRollup] = [:]
    private(set) var loading: Set<String> = []
    private(set) var flaggedByMe: Set<String>
    private(set) var reporterID: String?
    var lastError: String?

    @ObservationIgnored private let backend: any PrepReportBackend
    @ObservationIgnored private let limiter: ReportRateLimiter
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var flaggedReporters: Set<String> = []
    @ObservationIgnored private var loadedFlaggedReporters = false
    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "PrepReports")
    private static let flaggedKey = "prep_reports_flagged_v1"

    init(backend: any PrepReportBackend, defaults: UserDefaults = .standard) {
        self.backend = backend
        self.defaults = defaults
        self.limiter = ReportRateLimiter(defaults: defaults)
        self.flaggedByMe = Set(defaults.stringArray(forKey: Self.flaggedKey) ?? [])
    }

    private static func defaultBackend() -> any PrepReportBackend {
        #if DEBUG
        if LaunchOptions.mockData { return InMemoryPrepReportBackend(seed: MockData.prepReports()) }
        #endif
        if LaunchOptions.noCloudKit { return InMemoryPrepReportBackend() }
        return CloudKitService.shared
    }

    func rollup(for placeKey: String) -> CommunityRollup? {
        rollups[placeKey]
    }

    func myReport(for placeKey: String) -> PrepReport? {
        guard let reporterID else { return nil }
        return reports[placeKey]?.first { $0.reporterID == reporterID }
    }

    /// Reports with evidence notes others can read: not hidden by flags.
    func notes(for placeKey: String) -> [PrepReport] {
        (reports[placeKey] ?? [])
            .filter { !$0.note.isEmpty && $0.flagCount < CommunityRollup.flagsToHide }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(placeKey: String) async {
        guard !loading.contains(placeKey) else { return }
        loading.insert(placeKey)
        defer { loading.remove(placeKey) }
        if reporterID == nil {
            reporterID = try? await backend.reporterID()
        }
        if !loadedFlaggedReporters {
            flaggedReporters = await backend.flaggedReporters()
            loadedFlaggedReporters = true
        }
        do {
            let fetched = try await backend.fetchReports(placeKey: placeKey)
            reports[placeKey] = fetched
            recompute(placeKey)
        } catch {
            logger.error("Prep report fetch failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Files or edits the current user's report for a place.
    func submit(
        placeKey: String,
        chainSlug: String?,
        verdict: PrepVerdict,
        evidence: PrepEvidence?,
        note: String,
        now: Date = .now
    ) async throws {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ContentFilter.containsInappropriateContent(note) else { throw PrepReportError.notAllowed }
        let reporter: String
        if let reporterID {
            reporter = reporterID
        } else {
            reporter = try await backend.reporterID()
            reporterID = reporter
        }

        var report: PrepReport
        if let existing = myReport(for: placeKey) {
            report = existing
            report.updatedAt = now
        } else {
            guard limiter.canFileNewReport(now: now) else { throw PrepReportError.dailyLimitReached }
            report = PrepReport(
                id: PrepReport.recordName(placeKey: placeKey, reporterID: reporter),
                placeKey: placeKey,
                reporterID: reporter,
                chainSlug: chainSlug,
                verdict: verdict,
                evidence: evidence,
                note: note,
                createdAt: now,
                updatedAt: now,
                dayStamp: PrepReport.dayStamp(for: now),
                dailyCount: limiter.count(on: PrepReport.dayStamp(for: now)) + 1,
                reporterSince: limiter.firstReport ?? now
            )
        }
        report.verdict = verdict
        report.evidence = verdict == .unsure ? nil : evidence
        report.note = note

        let previous = reports[placeKey]
        var updated = (previous ?? []).filter { $0.id != report.id }
        updated.append(report)
        reports[placeKey] = updated
        recompute(placeKey)

        do {
            try await backend.save(report)
            if previous?.contains(where: { $0.id == report.id }) != true {
                limiter.recordNewReport(now: now)
            }
            lastError = nil
        } catch {
            reports[placeKey] = previous
            recompute(placeKey)
            logger.error("Prep report save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Flags another user's evidence note. One flag per user per report.
    func flag(_ report: PrepReport) async {
        guard !flaggedByMe.contains(report.id), report.reporterID != reporterID else { return }
        flaggedByMe.insert(report.id)
        defaults.set(Array(flaggedByMe), forKey: Self.flaggedKey)
        do {
            let reporter: String
            if let reporterID {
                reporter = reporterID
            } else {
                reporter = try await backend.reporterID()
                reporterID = reporter
            }
            try await backend.flag(reportID: report.id, reporterID: reporter)
        } catch {
            logger.error("Flag failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    private func recompute(_ placeKey: String) {
        rollups[placeKey] = CommunityRollup.compute(reports: reports[placeKey] ?? [], flaggedReporters: flaggedReporters)
    }
}

/// Keeps reports in memory: sample-data mode, `-noCloudKit` runs, and tests.
final class InMemoryPrepReportBackend: PrepReportBackend {
    private var reports: [String: PrepReport]
    private var flags: [String: Set<String>] = [:]
    private let localID: String
    private let flagged: Set<String>

    init(seed: [PrepReport] = [], reporterID: String = "local-user", flaggedReporters: Set<String> = []) {
        reports = Dictionary(seed.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        localID = reporterID
        flagged = flaggedReporters
    }

    func reporterID() async throws -> String { localID }

    func fetchReports(placeKey: String) async throws -> [PrepReport] {
        reports.values.filter { $0.placeKey == placeKey }.map { report in
            var report = report
            report.flagCount += flags[report.id, default: []].subtracting([report.reporterID]).count
            return report
        }
    }

    func save(_ report: PrepReport) async throws {
        reports[report.id] = report
    }

    func flag(reportID: String, reporterID: String) async throws {
        flags[reportID, default: []].insert(reporterID)
    }

    func flaggedReporters() async -> Set<String> { flagged }
}
