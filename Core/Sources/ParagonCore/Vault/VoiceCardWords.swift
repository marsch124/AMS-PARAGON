import Foundation

/// Build 365: the words and the times of the Mac's recording card (**Record a Thought** on the
/// Mac). The iPhone's Lock Screen card says the same things (`VoiceLook` in the widget
/// extension); these are here so the Mac's card has one tested place for them.
public enum VoiceCardWords {
    /// The five things the card can be showing. The raw values are the ones the card's state
    /// uses (`VoiceCardState.Stage`).
    public enum Stage: String, Sendable {
        case preparing, listening, writing, saved, nothing
    }

    /// Where the thought goes, in the words the rest of PARAGON uses.
    public static func place(intoToday: Bool) -> String {
        intoToday ? "Today's note" : "Inbox"
    }

    /// The card's first line.
    public static func heading(_ stage: Stage, paused: Bool = false, intoToday: Bool = false) -> String {
        switch stage {
        case .preparing: return "Getting ready"
        case .listening: return (paused ? "Paused" : "Listening") + " \u{00B7} " + place(intoToday: intoToday)
        case .writing: return "Writing it up\u{2026}"
        case .saved: return intoToday ? "Saved to today's note" : "Saved to Inbox"
        case .nothing: return "Nothing saved"
        }
    }

    /// "1 task heard · 2 marked" while recording; empty when there is neither.
    public static func heard(tasks: Int, marks: Int) -> String {
        var parts: [String] = []
        if tasks > 0 { parts.append(tasks == 1 ? "1 task heard" : "\(tasks) tasks heard") }
        if marks > 0 { parts.append(marks == 1 ? "1 marked" : "\(marks) marked") }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The saved card's own line: the title and how many tasks were filed.
    public static func savedLine(title: String, tasks: Int) -> String {
        let found = tasks == 0 ? "no tasks found" : tasks == 1 ? "1 task found" : "\(tasks) tasks found"
        return "\(title) \u{00B7} \(found)"
    }

    /// The second stop button: it stops and files the thought in the OTHER place. The words say
    /// both, because a button that only said "Today" would not say that it stops.
    public static func otherPlaceButton(intoToday: Bool) -> String {
        intoToday ? "Stop to Inbox" : "Stop to Today"
    }

    public static func pauseButton(paused: Bool) -> String {
        paused ? "Go on" : "Pause"
    }

    /// The File menu's item, and the button in the menu bar window.
    public static func menuTitle(recording: Bool) -> String {
        recording ? "Stop Recording" : "Record a Thought"
    }

    /// How long the card stays once the recording is over, in seconds: five minutes for a saved
    /// thought (time to read the summary and press Open), half a minute when nothing was
    /// saved. Nil while it records or writes: then it stays.
    public static func stays(_ stage: Stage) -> Double? {
        switch stage {
        case .saved: return 300
        case .nothing: return 30
        case .preparing, .listening, .writing: return nil
        }
    }

    /// The buttons show while it records, or is about to.
    public static func isRunning(_ stage: Stage) -> Bool {
        stage == .listening || stage == .preparing
    }
}
