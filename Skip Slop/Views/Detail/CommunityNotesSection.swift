import SwiftUI
import SwiftData

struct CommunityNotesSection: View {
    let restaurant: Restaurant?
    let chainSlug: String?

    @Query private var allNotes: [CommunityNote]
    @State private var cloudNotes: [CloudNote] = []
    @State private var isLoadingCloud = false

    private var localNotes: [CommunityNote] {
        allNotes.filter { note in
            if let restaurant, note.restaurant?.id == restaurant.id {
                return true
            }
            if let chainSlug, note.chainSlug == chainSlug {
                return true
            }
            return false
        }
        .sorted { $0.netVotes > $1.netVotes }
    }

    private var publicCloudNotes: [CloudNote] {
        cloudNotes.filter(\.isPublic)
    }

    private var pendingCloudNotes: [CloudNote] {
        cloudNotes.filter { !$0.isPublic }
    }

    private var hasAnyNotes: Bool {
        !localNotes.isEmpty || !cloudNotes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Community Notes", systemImage: "person.2.fill")
                    .font(.headline)

                Spacer()

                if isLoadingCloud {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if !hasAnyNotes {
                emptyState
            } else {
                // Public cloud notes
                if !publicCloudNotes.isEmpty {
                    ForEach(publicCloudNotes) { note in
                        CloudNoteCardView(note: note)
                    }
                }

                // Local notes
                ForEach(localNotes) { note in
                    NoteCardView(note: note, isPending: !note.isPublic)
                }

                // Pending cloud notes
                if !pendingCloudNotes.isEmpty {
                    Text("Pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(pendingCloudNotes) { note in
                        CloudNoteCardView(note: note, isPending: true)
                    }
                }
            }
        }
        .task { await loadCloudNotes() }
    }

    private func loadCloudNotes() async {
        isLoadingCloud = true
        defer { isLoadingCloud = false }

        let service = CloudKitService.shared

        if let chainSlug {
            cloudNotes = await service.fetchNotes(forChainSlug: chainSlug)
        } else if let restaurant {
            cloudNotes = await service.fetchNotes(forRestaurantID: restaurant.id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No community notes yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Be the first to report!")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Local Note Card

struct NoteCardView: View {
    let note: CommunityNote
    let isPending: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NoteCardLayout(
            icon: note.noteType.icon,
            color: note.noteType.color,
            displayName: note.noteType.displayName,
            noteBody: note.body,
            createdAt: note.createdAt,
            upvotes: note.upvotes,
            downvotes: note.downvotes,
            votesNeeded: note.votesNeeded,
            isPending: isPending,
            onUpvote: {
                note.upvotes += 1
                try? modelContext.save()
            },
            onDownvote: {
                note.downvotes += 1
                try? modelContext.save()
            }
        )
    }
}

// MARK: - Cloud Note Card

struct CloudNoteCardView: View {
    let note: CloudNote
    var isPending: Bool = false

    var body: some View {
        NoteCardLayout(
            icon: note.noteType.icon,
            color: note.noteType.color,
            displayName: note.noteType.displayName,
            noteBody: note.body,
            createdAt: note.createdAt,
            upvotes: note.upvotes,
            downvotes: note.downvotes,
            votesNeeded: note.votesNeeded,
            isPending: isPending,
            isCloud: true,
            onUpvote: {
                Task { await CloudKitService.shared.vote(noteRecordID: note.recordID, isUpvote: true) }
            },
            onDownvote: {
                Task { await CloudKitService.shared.vote(noteRecordID: note.recordID, isUpvote: false) }
            }
        )
    }
}

// MARK: - Shared Layout

struct NoteCardLayout: View {
    let icon: String
    let color: Color
    let displayName: String
    let noteBody: String
    let createdAt: Date
    let upvotes: Int
    let downvotes: Int
    let votesNeeded: Int
    let isPending: Bool
    var isCloud: Bool = false
    let onUpvote: () -> Void
    let onDownvote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14, weight: .semibold))

                Text(displayName)
                    .font(.subheadline.weight(.semibold))

                if isCloud {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.5))
                }

                Spacer()

                if isPending {
                    Text("\(votesNeeded) more needed")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1), in: Capsule())
                }
            }

            if !noteBody.isEmpty {
                Text(noteBody)
                    .font(.subheadline)
                    .foregroundStyle(isPending ? .secondary : .primary)
            }

            HStack {
                Text(createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onUpvote()
                    } label: {
                        Label("\(upvotes)", systemImage: "arrow.up")
                            .font(.caption)
                    }

                    Button {
                        onDownvote()
                    } label: {
                        Label("\(downvotes)", systemImage: "arrow.down")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPending ? .secondary.opacity(0.05) : color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isPending ? .secondary.opacity(0.15) : color.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(isPending ? 0.7 : 1.0)
    }
}
