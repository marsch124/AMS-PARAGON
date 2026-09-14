import Foundation

/// How a note stands: the one place the `status:` line is understood.
///
/// **Build 165, and it started with a word he rejected.** Until now a goal or a project only
/// had **done**, so a goal you gave up on and a goal you reached were written the same way,
/// and your history said you reached everything you ever stopped working on. He asked for
/// three endings — **Done**, **Missed**, **Dropped** — and chose *Done* over *Reached*
/// because it is the word already in his notes, so nothing has to be rewritten.
///
/// Before this, ten places in the app compared `status` to a raw string, each with its own
/// idea of what counted as finished (`Review` knew four spellings of on hold, `GoalProgress`
/// knew three of done, `NoteIndex` knew "on hold" with a space that nothing ever wrote). They
/// all go through this now. **A word with meaning attached belongs in one type, or the fifth
/// place to check it will get it wrong.**
public enum NoteStatus: String, CaseIterable, Sendable {
    case active
    case onHold = "on-hold"
    /// Finished, and it delivered what it was for.
    case done
    /// It is over and it did not happen. A date passed, or you decided it had not worked.
    case missed
    /// You decided not to do it. Nothing failed; it was called off.
    case dropped
    case archived

    /// Reads what is really written in vaults, including every older spelling. `achieved` and
    /// `completed` both became `done` in build 165 and keep working for ever: a note written
    /// in 2026 must still read the same in 2030.
    public init(reading raw: String?) {
        let word = (raw ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        switch word {
        case "done", "completed", "achieved", "reached", "complete": self = .done
        case "missed", "failed", "not-done", "not done": self = .missed
        case "dropped", "abandoned", "cancelled", "canceled", "given-up", "given up": self = .dropped
        case "on-hold", "onhold", "on hold", "paused", "someday", "later": self = .onHold
        case "archived": self = .archived
        default: self = .active
        }
    }

    /// What the app calls it on screen. Never the raw value: `on-hold` is not a word.
    public var label: String {
        switch self {
        case .active: return "Active"
        case .onHold: return "On hold"
        case .done: return "Done"
        case .missed: return "Missed"
        case .dropped: return "Dropped"
        case .archived: return "Archived"
        }
    }

    /// One plain line saying what choosing this means, for the menu that writes it.
    public var meaning: String {
        switch self {
        case .active: return "You are working on it."
        case .onHold: return "Not now, but not given up."
        case .done: return "Finished, and it did what it was for."
        case .missed: return "It is over and it did not happen."
        case .dropped: return "You decided not to do it."
        case .archived: return "Put away."
        }
    }

    /// It is over, whichever way it ended. Nothing that is ended belongs in a list of work.
    public var isEnded: Bool { self == .done || self == .missed || self == .dropped }

    /// It is over **and** it delivered. Only `done`. This is what a goal's progress counts,
    /// and the difference between this and `isEnded` is the whole point of the build.
    public var isDelivered: Bool { self == .done }

    public var isOnHold: Bool { self == .onHold }

    /// The three ways a thing can end, in the order the menu offers them.
    public static let endings: [NoteStatus] = [.done, .missed, .dropped]
}

public extension Note {
    /// How this note stands. `active` when it says nothing, which is what an untouched note is.
    var noteStatus: NoteStatus { NoteStatus(reading: status) }

    /// It is over, whichever way it ended.
    var isEnded: Bool { noteStatus.isEnded }
}
