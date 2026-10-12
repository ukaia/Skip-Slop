import SwiftUI
import SwiftData

struct AddNoteView: View {
    let chainSlug: String?
    /// Fetches or creates the restaurant record; only called when a note is submitted.
    let resolveRestaurant: () -> Restaurant

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedType: NoteType = .syscoVerified
    @State private var noteBody = ""
    @State private var showFilterWarning = false
    @State private var didPost = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you spot?") {
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
                    Text("Your note goes public once it gets \(selectedType.thresholdToPublish) net upvotes.")
                }

                Section {
                    if chainSlug != nil {
                        Label("Applies to every location of this chain", systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label("Notes are public and filtered for abuse. Stick to the food.", systemImage: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .sensoryFeedback(.success, trigger: didPost)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        attemptSubmit()
                    }
                    .fontWeight(.semibold)
                    .disabled(didPost || (selectedType.requiresBody && noteBody.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .alert("Note Not Posted", isPresented: $showFilterWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It contains language we don't allow. Edit it to stick to facts about the food, price, or tipping.")
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
        didPost = true
        Task {
            // Give the success haptic a beat before the sheet goes away.
            try? await Task.sleep(for: .milliseconds(150))
            dismiss()
        }
    }

    private func submitNote(body: String) {
        let note = CommunityNote(
            noteType: selectedType,
            body: body,
            restaurant: resolveRestaurant(),
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
