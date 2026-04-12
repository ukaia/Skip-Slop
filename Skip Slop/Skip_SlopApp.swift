import SwiftUI
import SwiftData

@main
struct Skip_SlopApp: App {
    let chainDatabase = ChainDatabase()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chainDatabase)
                .task {
                    await CloudKitService.shared.initializeSchemaIfNeeded()
                }
        }
        .modelContainer(for: [Restaurant.self, CommunityNote.self])
    }
}
