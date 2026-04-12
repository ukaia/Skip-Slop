import SwiftUI
import SwiftData

struct AddNoteView: View {
    let restaurant: Restaurant
    let chainSlug: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedType: NoteType = .syscoVerified
    @State private var noteBody = ""
    @State private var showFilterWarning = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you notice?") {
                    Picker("Note Type", selection: $selectedType) {
                        ForEach(NoteType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    if selectedType.requiresBody {
                        TextField(selectedType.prompt, text: $noteBody, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        Text(selectedType.prompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Details")
                } footer: {
                    Text("Notes become visible after \(selectedType.thresholdToPublish) community votes.")
                        .font(.caption)
                }

                Section {
                    if chainSlug != nil {
                        Label("This note applies to all locations of this chain", systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label("Notes are shared with the community and moderated for appropriate content.", systemImage: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        attemptSubmit()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedType.requiresBody && noteBody.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Inappropriate Content", isPresented: $showFilterWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your note contains language that isn't allowed. Please keep notes factual and relevant to food quality.")
            }
        }
    }

    private func attemptSubmit() {
        let cleaned = noteBody.trimmingCharacters(in: .whitespaces)

        if ContentFilter.containsInappropriateContent(cleaned) {
            showFilterWarning = true
            return
        }

        submitNote(body: cleaned)
        dismiss()
    }

    private func submitNote(body: String) {
        let note = CommunityNote(
            noteType: selectedType,
            body: body,
            restaurant: restaurant,
            chainSlug: chainSlug
        )
        modelContext.insert(note)
        try? modelContext.save()

        // Upload to CloudKit
        Task {
            await CloudKitService.shared.uploadNote(note)
        }
    }
}
