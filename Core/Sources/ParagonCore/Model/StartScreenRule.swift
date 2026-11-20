import Foundation

/// **The start screen: when it shows, and what it says** (build 329). At a fresh start PARAGON
/// shows one calm page in the app icon's look — the slate ground, the white drawing, the name,
/// the day and what is waiting — and it stays until he taps it (his pick, 2026-11-16: "Only
/// when I tap", look 3 of the picture `round10/start-screen-choice.png`).
///
/// It must never stand between him and a place he asked for by name: a widget line, a Siri
/// action, a reminder or a note from the system search goes straight there.
public enum StartScreenRule {
    /// What brought the app up, or what arrived while the start screen was still up.
    public enum Opening: Equatable, Sendable, CaseIterable {
        /// The app's icon, the Dock, the app switcher after the app was closed.
        case byHand
        /// A widget's line or number, a note link, any `amspara://` link.
        case link
        /// A Siri or Shortcuts action that opens the app (Open Today, Start the day …).
        case shortcut
        /// A press on one of PARAGON's own reminders (evening, morning, weekly review).
        case reminder
        /// A note pressed in the system search.
        case systemSearch
        /// The screen tests and the launch check: nobody is there to tap.
        case test
    }

    /// Only a start by hand shows it; everything else goes where it was sent.
    public static func shows(_ opening: Opening) -> Bool { opening == .byHand }

    /// The day, as everywhere in the app: "Monday 2026-11-16".
    public static func dayLine(_ day: DateOnly) -> String { DayWords.withWeekday(day) }

    /// Build 346, his picture: the weekday on its own line ("Friday") …
    public static func weekdayLine(_ day: DateOnly) -> String { DayWords.weekday(day) }

    /// … and the date on the line under it ("2026-11-20").
    public static func dateLine(_ day: DateOnly) -> String { DayWords.plain(day) }

    /// Build 346: what is due, on its own line with the calendar mark. `due` is the open tasks
    /// due today or earlier (`SidebarCounts.dueByToday`). A zero is said in words, never "0".
    public static func dueLine(_ due: Int) -> String {
        due > 0 ? "\(due) due today" : "Nothing due today"
    }

    /// Build 346: the Inbox, on its own line with the Inbox mark.
    public static func inboxLine(_ inbox: Int) -> String {
        inbox > 0 ? "\(inbox) in the Inbox" : "Inbox empty"
    }

    /// "1.0 (329)", as Settings › About says it.
    public static func versionLine(version: String, build: Int) -> String { "\(version) (\(build))" }
}
