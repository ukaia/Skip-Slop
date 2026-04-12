import CloudKit
import SwiftData
import Observation

@Observable
final class CloudKitService {
    private let container: CKContainer
    private let publicDB: CKDatabase
    var isSyncing = false
    var lastSyncError: String?

    static let shared = CloudKitService()

    private init() {
        container = CKContainer.default()
        publicDB = container.publicCloudDatabase
    }

    // MARK: - Upload Note

    func uploadNote(_ note: CommunityNote) async {
        let record = CKRecord(recordType: "CommunityNote")
        record["noteID"] = note.id.uuidString as CKRecordValue
        record["restaurantID"] = note.restaurant?.id as CKRecordValue?
        record["chainSlug"] = note.chainSlug as CKRecordValue?
        record["noteType"] = note.noteTypeRaw as CKRecordValue
        record["body"] = note.body as CKRecordValue
        record["upvotes"] = note.upvotes as CKRecordValue
        record["downvotes"] = note.downvotes as CKRecordValue
        record["createdAt"] = note.createdAt as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            lastSyncError = error.localizedDescription
            print("CloudKit upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Notes for Chain

    func fetchNotes(forChainSlug slug: String) async -> [CloudNote] {
        let predicate = NSPredicate(format: "chainSlug == %@", slug)
        let query = CKQuery(recordType: "CommunityNote", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return CloudNote(from: record)
            }
        } catch {
            lastSyncError = error.localizedDescription
            print("CloudKit fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Fetch Notes for Restaurant

    func fetchNotes(forRestaurantID id: String) async -> [CloudNote] {
        let predicate = NSPredicate(format: "restaurantID == %@", id)
        let query = CKQuery(recordType: "CommunityNote", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return CloudNote(from: record)
            }
        } catch {
            lastSyncError = error.localizedDescription
            return []
        }
    }

    // MARK: - Vote

    func vote(noteRecordID: CKRecord.ID, isUpvote: Bool) async {
        do {
            let record = try await publicDB.record(for: noteRecordID)
            let key = isUpvote ? "upvotes" : "downvotes"
            let current = record[key] as? Int ?? 0
            record[key] = (current + 1) as CKRecordValue
            try await publicDB.save(record)
        } catch {
            lastSyncError = error.localizedDescription
            print("CloudKit vote failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Check Account Status

    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Initialize Schema

    /// Seeds a dummy record then deletes it to auto-create the CommunityNote
    /// record type in the development CloudKit environment. Only needed once.
    func initializeSchemaIfNeeded() async {
        let key = "cloudkit_schema_initialized_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let record = CKRecord(recordType: "CommunityNote")
        record["noteID"] = "__schema_seed__" as CKRecordValue
        record["restaurantID"] = "" as CKRecordValue
        record["chainSlug"] = "" as CKRecordValue
        record["noteType"] = "sysco_verified" as CKRecordValue
        record["body"] = "" as CKRecordValue
        record["upvotes"] = 0 as CKRecordValue
        record["downvotes"] = 0 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        do {
            let saved = try await publicDB.save(record)
            // Delete the seed record immediately
            try await publicDB.deleteRecord(withID: saved.recordID)
            UserDefaults.standard.set(true, forKey: key)
            print("CloudKit schema initialized successfully")
        } catch {
            print("CloudKit schema init: \(error.localizedDescription)")
            // Non-fatal — schema may already exist or user not signed into iCloud
        }
    }

    // MARK: - Upload Restaurant Rating

    func uploadRestaurantRating(_ restaurant: Restaurant) async {
        let record = CKRecord(recordType: "RestaurantRating")
        record["restaurantID"] = restaurant.id as CKRecordValue
        record["name"] = restaurant.name as CKRecordValue
        record["chainSlug"] = restaurant.chainSlug as CKRecordValue?
        record["slopRating"] = restaurant.slopRatingRaw as CKRecordValue
        record["ratingSource"] = restaurant.ratingSourceRaw as CKRecordValue
        record["latitude"] = restaurant.latitude as CKRecordValue
        record["longitude"] = restaurant.longitude as CKRecordValue
        record["address"] = restaurant.address as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            print("CloudKit restaurant upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Chain Rating (community consensus)

    func fetchChainRating(slug: String) async -> String? {
        let predicate = NSPredicate(format: "chainSlug == %@", slug)
        let query = CKQuery(recordType: "RestaurantRating", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            if let (_, result) = results.first,
               let record = try? result.get() {
                return record["slopRating"] as? String
            }
        } catch {
            print("CloudKit chain fetch failed: \(error.localizedDescription)")
        }
        return nil
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
    let upvotes: Int
    let downvotes: Int
    let createdAt: Date

    var netVotes: Int { upvotes - downvotes }

    var isPublic: Bool {
        netVotes >= noteType.thresholdToPublish
    }

    var votesNeeded: Int {
        max(0, noteType.thresholdToPublish - netVotes)
    }

    init?(from record: CKRecord) {
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
        self.upvotes = record["upvotes"] as? Int ?? 0
        self.downvotes = record["downvotes"] as? Int ?? 0
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .now
    }
}
