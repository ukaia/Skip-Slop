import SwiftUI

/// Glass search field pinned to the top of the explore sheet.
struct MapSearchBar: View {
    @Binding var text: String
    var isSearching: Bool
    var focus: FocusState<Bool>.Binding
    var onCommit: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search places, cities, or zip codes", text: $text)
                .focused(focus)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(onCommit)
                .accessibilityHint("Filters the list as you type. Search looks beyond this area.")

            if isSearching {
                ProgressView()
                    .accessibilityLabel("Searching")
            } else if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: DS.minHitTarget, height: DS.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, DS.Spacing.m)
        .frame(minHeight: DS.minHitTarget + 4)
        // The sheet is already glass; a fill (not more glass) keeps layers legible.
        .background(.fill.tertiary, in: .capsule)
    }
}
