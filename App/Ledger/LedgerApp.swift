import SwiftUI
import SwiftData
import LedgerCore
import LedgerIntents
import UserNotifications

@main
struct LedgerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try LedgerSchema.container()
            try DefaultCategories.seedIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Failed to set up data store: \(error)")
        }
        // Registers the App Shortcut so the intent appears in the Shortcuts app immediately after first launch.
        LedgerShortcuts.updateAppShortcutParameters()
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
