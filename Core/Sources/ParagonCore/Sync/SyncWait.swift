import Foundation

/// What a sync does while iCloud is still bringing notes (build 283).
///
/// Until build 282 a sync asked for while a note was still coming from iCloud, or being
/// updated from it, was refused with an alert ("Something went wrong … Try again in a
/// moment"), and nothing tried again: the person had to press Sync once more, and a sync
/// started by the timer put the same alert up on its own. Nothing had gone wrong — the refusal
/// is the safety rule of builds 106 and 261. Now the sync waits: the app remembers that one
/// was asked for, and the first re-read that finds the whole vault here starts it.
public enum SyncWait {
    public enum Step: Equatable, Sendable {
        /// Every note is here and current: start the waiting sync now.
        case start
        /// Something is still on its way from iCloud: keep waiting, say nothing more.
        case keepWaiting
    }

    /// The one decision, apart from the app so it can be tested.
    public static func step(waiting: Int, updating: Int) -> Step {
        waiting == 0 && updating == 0 ? .start : .keepWaiting
    }

    /// The short note shown when a sync someone pressed has to wait. Not an error.
    public static let message =
        "Notes are still arriving from iCloud. The sync starts by itself as soon as they are here."
}
