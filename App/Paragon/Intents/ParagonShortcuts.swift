import AppIntents

/// The actions PARAGON hands to Shortcuts, Siri and Spotlight **without any setting up**
/// (build 317, features-07). Each phrase carries the app's name, as Apple requires; that name is
/// what Siri listens for.
///
/// **The pictures are Apple's symbols by name** — a shortcut's tile can show nothing else. Each
/// name is one the app already draws its own mark for (`Marks.byName`), so the tile and the
/// app show the same idea: the tray for the Inbox, the sun for Today.
///
/// Apple allows ten; these are six. A phrase is never changed lightly: he learns them by heart.
struct ParagonShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToInboxIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "Add to \(.applicationName) Inbox",
                "Add to Inbox in \(.applicationName)",
                "Add a task to \(.applicationName)",
                "Capture in \(.applicationName)",
            ],
            shortTitle: "Add to Inbox",
            systemImageName: "tray.and.arrow.down")
        AppShortcut(
            intent: DueTodayIntent(),
            phrases: [
                "What is due today in \(.applicationName)",
                "What is due in \(.applicationName)",
                "What is due today \(.applicationName)",
                "\(.applicationName) what is due today",
            ],
            shortTitle: "Due Today",
            systemImageName: "checklist")
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open Today in \(.applicationName)",
                "Open \(.applicationName) Today",
                "Show Today in \(.applicationName)",
            ],
            shortTitle: "Open Today",
            systemImageName: "sun.max")
        AppShortcut(
            intent: StartTheDayIntent(),
            phrases: [
                "Start the day in \(.applicationName)",
                "Start my day in \(.applicationName)",
                "Start the day with \(.applicationName)",
            ],
            shortTitle: "Start the Day",
            systemImageName: "cup.and.saucer.fill")
        AppShortcut(
            intent: CloseTheDayIntent(),
            phrases: [
                "Close the day in \(.applicationName)",
                "Close my day in \(.applicationName)",
                "Close the day with \(.applicationName)",
            ],
            shortTitle: "Close the Day",
            systemImageName: "moon.fill")
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Start a focus in \(.applicationName)",
                "Start the focus clock in \(.applicationName)",
                "Focus with \(.applicationName)",
            ],
            shortTitle: "Start Focus",
            systemImageName: "timer")
    }
}
