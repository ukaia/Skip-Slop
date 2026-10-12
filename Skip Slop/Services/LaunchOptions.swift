import Foundation

/// Launch arguments for screenshots and UI tests. DEBUG builds only; Release
/// builds always see `false`.
///
/// - `-UITestScreenshots YES` — shorthand for `-skipOnboarding YES -mockData YES`
/// - `-skipOnboarding YES` — mark onboarding as seen
/// - `-showOnboarding YES` — show onboarding even if seen
/// - `-mockData YES` — sample restaurants around Austin, TX; no location or network search
/// - `-openDetail YES` — open the first restaurant's detail card
/// - `-openSettings YES` — open Settings
nonisolated enum LaunchOptions {
    static var screenshots: Bool { flag("UITestScreenshots") }
    static var skipOnboarding: Bool { flag("skipOnboarding") || screenshots }
    static var showOnboarding: Bool { flag("showOnboarding") }
    static var mockData: Bool { flag("mockData") || screenshots }
    static var openDetail: Bool { flag("openDetail") }
    static var openSettings: Bool { flag("openSettings") }

    private static func flag(_ name: String) -> Bool {
        #if DEBUG
        // `-name YES` lands in the argument domain; a bare `-name` is accepted too.
        UserDefaults.standard.bool(forKey: name) || ProcessInfo.processInfo.arguments.last == "-\(name)"
        #else
        false
        #endif
    }
}
