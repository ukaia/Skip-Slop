import CloudKit
import SwiftData
import Observation
import os

@Observable
final class CloudKitService {
    private let container: CKContainer
    private let publicDB: CKDatabase
    private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "CloudKit")
    var isSyncing = false
    var lastSyncError: String?
    private var cachedUserRecordName: String?

    static let shared = CloudKitService()

    private init() {
        container = CKContainer.default()
        publicDB = container.publicCloudDatabase
    }

    // MARK: - Upload Note

    func uploadNote(_ note: CommunityNote) async {
        // Deterministic record name so a retried upload can't create a duplicate note.
        let record = CKRecord(
            recordType: "CommunityNote",
            recordID: CKRecord.ID(recordName: "note_\(note.id.uuidString)")
        )
        let noteID = note.id.uuidString
        let restaurantID = note.restaurant?.id
        let chainSlug = note.chainSlug
        let noteType = note.noteTypeRaw
        let body = note.body
        let createdAt = note.createdAt

        do {
            let saved = try await save(record) { record in
                record["noteID"] = noteID as CKRecordValue
                record["restaurantID"] = restaurantID as CKRecordValue?
                record["chainSlug"] = chainSlug as CKRecordValue?
                record["noteType"] = noteType as CKRecordValue
                record["body"] = body as CKRecordValue
                record["createdAt"] = createdAt as CKRecordValue
            }
            logger.info("Uploaded note \(saved.recordID.recordName, privacy: .public)")
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("CloudKit upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Fetch Notes

    func fetchNotes(forChainSlug slug: String) async -> [CloudNote] {
        await fetchNotes(matching: NSPredicate(format: "chainSlug == %@", slug))
    }

    func fetchNotes(forRestaurantID id: String) async -> [CloudNote] {
        await fetchNotes(matching: NSPredicate(format: "restaurantID == %@", id))
    }

    private func fetchNotes(matching predicate: NSPredicate) async -> [CloudNote] {
        let query = CKQuery(recordType: "CommunityNote", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let records: [CKRecord]
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            records = results.compactMap { _, result in try? result.get() }
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("CloudKit fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        let noteIDs = records.compactMap { $0["noteID"] as? String }
        let votes = await fetchVotes(forNoteIDs: noteIDs)
        let myName = try? await currentUserRecordName()

        return records.compactMap { record in
            guard let noteID = record["noteID"] as? String else { return nil }
            var tally = VoteTally()
            var myVote: VoteDirection?
            let myRecordName = myName.map { Self.voteRecordName(noteID: noteID, userRecordName: $0) }
            for vote in votes[noteID] ?? [] {
                if vote.recordName == myRecordName {
                    myVote = vote.direction
                } else {
                    tally = tally.replacing(nil, with: vote.direction)
                }
            }
            if myName != nil {
                VoteStore.shared.reconcile(noteID: noteID, serverVote: myVote)
            }
            return CloudNote(from: record, othersTally: tally)
        }
    }

    // MARK: - Votes

    /// One `NoteVote` record per user per note. The record name is derived from the
    /// note ID and the user's record name, so a user can never hold two votes on a note.
    nonisolated static func voteRecordName(noteID: String, userRecordName: String) -> String {
        "vote_\(noteID)_\(userRecordName)"
    }

    private func currentUserRecordName() async throws -> String {
        if let cachedUserRecordName { return cachedUserRecordName }
        let name = try await container.userRecordID().recordName
        cachedUserRecordName = name
        return name
    }

    /// Sets (or clears, when `direction` is nil) the current user's vote on a note.
    func setVote(_ direction: VoteDirection?, noteID: String) async throws {
        let userName = try await currentUserRecordName()
        let recordID = CKRecord.ID(recordName: Self.voteRecordName(noteID: noteID, userRecordName: userName))

        guard let direction else {
            for attempt in 1...Self.maxSaveAttempts {
                do {
                    try await publicDB.deleteRecord(withID: recordID)
                    return
                } catch let error as CKError where error.code == .unknownItem {
                    return // Already gone — nothing to undo.
                } catch let error as CKError where Self.isTransient(error) && attempt < Self.maxSaveAttempts {
                    try await Task.sleep(for: .seconds(error.retryAfterSeconds ?? Double(attempt)))
                }
            }
            return
        }

        let record = CKRecord(recordType: "NoteVote", recordID: recordID)
        // Blind write of only our keys: the record belongs to this user alone, so the
        // last write wins. If the server still reports a conflict, the fields are
        // re-applied to the server's copy and saved again.
        try await save(record, savePolicy: .changedKeys) { record in
            record["noteID"] = noteID as CKRecordValue
            record["direction"] = direction.rawValue as CKRecordValue
        }
    }

    // MARK: - Saving

    static let maxSaveAttempts = 3

    /// Saves a single record, checking its per-record result. On `serverRecordChanged`
    /// the changes are re-applied to the server's record and retried; transient errors
    /// are retried after the server-suggested delay. Bounded to `maxSaveAttempts`.
    @discardableResult
    private func save(
        _ record: CKRecord,
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged,
        applyChanges: (CKRecord) -> Void
    ) async throws -> CKRecord {
        var record = record
        var policy = savePolicy
        applyChanges(record)

        for attempt in 1...Self.maxSaveAttempts {
            do {
                let (saveResults, _) = try await publicDB.modifyRecords(
                    saving: [record], deleting: [], savePolicy: policy
                )
                guard let result = saveResults[record.recordID] else {
                    throw CKError(.internalError)
                }
                return try result.get()
            } catch let error as CKError where attempt < Self.maxSaveAttempts {
                if error.code == .serverRecordChanged, let serverRecord = error.serverRecord {
                    logger.info("Conflict saving \(record.recordType, privacy: .public); re-applying to server record")
                    applyChanges(serverRecord)
                    record = serverRecord
                    policy = .ifServerRecordUnchanged
                } else if Self.isTransient(error) {
                    try await Task.sleep(for: .seconds(error.retryAfterSeconds ?? Double(attempt)))
                } else {
                    throw error
                }
            }
        }
        throw CKError(.internalError)
    }

    nonisolated static func isTransient(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy:
            true
        default:
            false
        }
    }

    private struct FetchedVote {
        let recordName: String
        let direction: VoteDirection
    }

    private func fetchVotes(forNoteIDs noteIDs: [String]) async -> [String: [FetchedVote]] {
        guard !noteIDs.isEmpty else { return [:] }
        let query = CKQuery(recordType: "NoteVote", predicate: NSPredicate(format: "noteID IN %@", noteIDs))

        var grouped: [String: [FetchedVote]] = [:]
        func collect(_ results: [(CKRecord.ID, Result<CKRecord, any Error>)]) {
            for (_, result) in results {
                guard let record = try? result.get(),
                      let noteID = record["noteID"] as? String,
                      let raw = record["direction"] as? Int,
                      let direction = VoteDirection(rawValue: raw) else { continue }
                grouped[noteID, default: []].append(
                    FetchedVote(recordName: record.recordID.recordName, direction: direction)
                )
            }
        }

        do {
            var (results, cursor) = try await publicDB.records(matching: query)
            collect(results)
            var pages = 1
            while let next = cursor, pages < 20 {
                (results, cursor) = try await publicDB.records(continuingMatchFrom: next)
                collect(results)
                pages += 1
            }
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("CloudKit vote fetch failed: \(error.localizedDescription, privacy: .public)")
        }
        return grouped
    }

    // MARK: - Initialize Schema

    /// Seeds dummy records then deletes them to auto-create the CommunityNote and
    /// NoteVote record types in the development CloudKit environment. Only needed once.
    func initializeSchemaIfNeeded() async {
        let key = "cloudkit_schema_initialized_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let record = CKRecord(recordType: "CommunityNote")
        record["noteID"] = "__schema_seed__" as CKRecordValue
        record["restaurantID"] = "" as CKRecordValue
        record["chainSlug"] = "" as CKRecordValue
        record["noteType"] = "sysco_verified" as CKRecordValue
        record["body"] = "" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        let vote = CKRecord(recordType: "NoteVote")
        vote["noteID"] = "__schema_seed__" as CKRecordValue
        vote["direction"] = VoteDirection.up.rawValue as CKRecordValue

        do {
            let saved = try await publicDB.save(record)
            let savedVote = try await publicDB.save(vote)
            // Delete the seed records immediately
            try await publicDB.deleteRecord(withID: saved.recordID)
            try await publicDB.deleteRecord(withID: savedVote.recordID)
            UserDefaults.standard.set(true, forKey: key)
            logger.info("CloudKit schema initialized successfully")
        } catch {
            logger.error("CloudKit schema init: \(error.localizedDescription, privacy: .public)")
            // Non-fatal — schema may already exist or user not signed into iCloud
        }
    }

}

// MARK: - CloudNote (lightweight struct for cloud data)

struct CloudNote: Identifiable {
    let id: String
    let recordID: CKRecord.ID
    let restaurantID: String?
    let chainSlug: String?
    let noteType: NoteType
    let body: String
    /// Votes from everyone except the current user (derived from `NoteVote` records).
    let othersTally: VoteTally
    let createdAt: Date

    /// Total tally including the current user's vote, if any.
    func tally(with myVote: VoteDirection?) -> VoteTally {
        othersTally.replacing(nil, with: myVote)
    }

    init?(from record: CKRecord, othersTally: VoteTally = VoteTally()) {
        guard let noteID = record["noteID"] as? String,
              let typeRaw = record["noteType"] as? String,
              let type = NoteType(rawValue: typeRaw) else {
            return nil
        }

        self.id = noteID
        self.recordID = record.recordID
        self.restaurantID = record["restaurantID"] as? String
        self.chainSlug = record["chainSlug"] as? String
        self.noteType = type
        self.body = record["body"] as? String ?? ""
        self.othersTally = othersTally
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .now
    }
}
