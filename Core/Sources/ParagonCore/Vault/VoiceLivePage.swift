import Foundation

/// Build 366: the rules and the words of **the live page**, the large recording page inside
/// PARAGON on the iPhone and the iPad.
///
/// The Lock Screen card is small (iOS allows 160 points) and iOS turns a locked screen dark
/// after some seconds. His words, 24 November 2026: "I want the panel to be larger and I want
/// it to be persistent. And when I press stop, I still want it to be persistent and show …
/// what is suggested as an action and so on." Only a page inside the app can do both, so
/// these are the rules of that page: when it comes up, how long it keeps the screen lit, and
/// what it says once the thought is filed.
public enum VoiceLivePage {
    public typealias Stage = VoiceCardWords.Stage

    /// How many letters of what was said the page shows (the Lock Screen card shows 110).
    public static let lettersShown = 700

    /// Seconds the screen is kept lit once the recording is over (saved, or nothing saved).
    /// After that the iPhone's own Auto-Lock decides again; the page itself stays.
    public static let litAfterEnd: Double = 120

    /// Whether this state brings the page up. Only a recording that runs does, and not once he
    /// pressed **Hide** for it. The later states never bring it up: they are shown where the
    /// page already is, and otherwise the check card takes the thought as before.
    public static func comesUp(_ stage: Stage, hidden: Bool) -> Bool {
        VoiceCardWords.isRunning(stage) && !hidden
    }

    /// Whether the page keeps the screen lit: always while it records and writes, and for
    /// `litAfterEnd` seconds once it is over.
    public static func keepsScreenLit(_ stage: Stage, secondsSinceEnd: Double) -> Bool {
        switch stage {
        case .preparing, .listening, .writing: return true
        case .saved, .nothing: return secondsSinceEnd < litAfterEnd
        }
    }

    /// The first line of the result: "Recorded 1:12 · saved to the Inbox". The same words as
    /// the check card's.
    public static func recordedLine(length: String, intoToday: Bool) -> String {
        let place = intoToday ? "today\u{2019}s note" : "the Inbox"
        return length.isEmpty ? "Saved to \(place)" : "Recorded \(length) \u{00B7} saved to \(place)"
    }

    /// The heading over the tasks: "Tasks found" with their number, never a bare zero.
    public static func tasksHeading(_ count: Int) -> String {
        count == 0 ? "No tasks found" : count == 1 ? "1 task found" : "\(count) tasks found"
    }

    /// Under the task switches: where a switched-off task is taken out of.
    public static func tasksHint(intoToday: Bool) -> String {
        "Switch off a task you do not want. It is taken out of \(intoToday ? "today\u{2019}s note" : "the Inbox")."
    }

    /// What stands in for the summary when there is none to show.
    public static func summaryStandIn(late: Bool) -> String {
        late ? "The summary is still being written. PARAGON adds it to the note when it is ready."
             : "No summary. It needs Apple Intelligence."
    }

    /// The small line while it records.
    public static let screenNote = "The screen stays on while this page is open and you record."
    /// The small line once it is over.
    public static let staysNote = "This page stays until you press Done."
}
