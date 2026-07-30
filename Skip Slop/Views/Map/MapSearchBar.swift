import SwiftUI

struct MapSearchBar: View {
    @Binding var text: String
    var onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Restaurants, cities, ZIP", text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit { onCommit() }

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // `.ultraThinMaterial` let the beige map bleed through and the placeholder was
        // barely legible. `.regularMaterial` gives the field an actual surface.
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}
