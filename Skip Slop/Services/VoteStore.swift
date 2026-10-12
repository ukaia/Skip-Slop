import Foundation
import Observation
import os

nonisolated enum VoteDirection: Int, Codable, Sendable {
    case up = 1
    case down = -1
}

/// Up/down counts for a note, with helpers for swapping one user's vote.
nonisolated struct VoteTally: Equatable, Sendable {
    var upvotes = 0
    var downvotes = 0

    var netVotes: Int { upvotes - downvotes }

    func isPublic(for type: NoteType) -> Bool {
        netVotes >= type.thresholdToPublish
    }

    func votesNeeded(for type: NoteType) -> Int {
        max(0, type.thresholdToPublish - netVotes)
    }

    /// Removes `old` (if any) and adds `new` (if any).
    func replacing(_ old: VoteDirection?, with new: VoteDirection?) -> VoteTally {
        var result = self
        switch old {
        case .up:   result.upvotes = max(0, result.upvotes - 1)
        case .down: result.downvotes = max(0, result.downvotes - 1)
        case nil:   break
        }
        switch new {
        case .up:   result.upvotes += 1
        case .down: result.downvotes += 1
        case nil:   break
        }
        return result
    }
}

/// The current user's vote per note ID, persisted in UserDefaults and mirrored
/// to CloudKit as one deterministic `NoteVote` record per user per note.
@Observable
final class VoteStore {
    static let shared = VoteStore()

    private static let defaultsKey = "note_votes_v1"
    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "Votes")
    private let defaults: UserDefaults

    private(set) var votes: [String: VoteDirection]
    private(set) var inFlight: Set<String> = []
    var lastError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: Int] ?? [:]
        votes = raw.compactMapValues(VoteDirection.init(rawValue:))
    }

    func vote(for noteID: String) -> VoteDirection? {
        votes[noteID]
    }

    /// Tapping the same direction again undoes the vote; tapping the other switches it.
    static func toggled(current: VoteDirection?, tapped: VoteDirection) -> VoteDirection? {
        current == tapped ? nil : tapped
    }

    func set(_ direction: VoteDirection?, for noteID: String) {
        votes[noteID] = direction
        defaults.set(votes.mapValues(\.rawValue), forKey: Self.defaultsKey)
    }

    /// Adopts the server's view of this user's vote (e.g. after reinstall or another device).
    func reconcile(noteID: String, serverVote: VoteDirection?) {
        guard !inFlight.contains(noteID), votes[noteID] != serverVote else { return }
        set(serverVote, for: noteID)
    }

    /// Optimistically applies the toggled vote, persists it to CloudKit, and reverts on failure.
    /// `apply(old, new)` is called immediately, and `apply(new, old)` if the save fails.
    func toggle(
        _ tapped: VoteDirection,
        noteID: String,
        apply: (VoteDirection?, VoteDirection?) -> Void = { _, _ in }
    ) async {
        guard !inFlight.contains(noteID) else { return }
        let old = votes[noteID]
        let new = Self.toggled(current: old, tapped: tapped)

        inFlight.insert(noteID)
        defer { inFlight.remove(noteID) }

        set(new, for: noteID)
        apply(old, new)

        do {
            try await CloudKitService.shared.setVote(new, noteID: noteID)
            lastError = nil
        } catch {
            logger.error("Vote save failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            set(old, for: noteID)
            apply(new, old)
        }
    }
}
