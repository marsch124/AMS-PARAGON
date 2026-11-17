import Foundation

/// Build 334: when the one quiet sync runs after a task was removed on this device.
///
/// A delete starts no sync of its own, so its reminder (`RemovedHere`, build 332) stayed in
/// Apple Reminders until the next timed or manual sync. Now the app plans one quiet sync
/// shortly after the LAST removal: each further delete pushes it back, so deleting through a
/// list makes one sync, not ten. Two waits:
/// - 12 seconds after a delete by a button, menu or swipe: the Undo offer (about 8 seconds)
///   is over by then, so Undo never finds its reminder already gone.
/// - 60 seconds after a task line taken out by typing: that may be a cut on its way to
///   another note, and a pasted line must keep its reminder (once it is pasted the id is in a
///   note again and nothing is waiting any more).
/// Never while a sync is running (it runs once after that one), and nothing at all when no
/// removed task is waiting.
public enum QuietSyncAfterRemoval {
    /// Seconds after the last delete by a button, menu or swipe.
    public static let waitAfterDelete: TimeInterval = 12
    /// Seconds after the last task line taken out by typing.
    public static let waitAfterTyping: TimeInterval = 60

    public enum Plan: Equatable {
        case none
        case run(at: Date)
        /// A sync is running: plan again when it ends.
        case afterRunningSync
    }

    /// When the quiet sync is due after this removal: its own wait, and never earlier than
    /// what was planned so far (a delete by button does not cut short a typed line's minute).
    public static func due(removalAt: Date, byTyping: Bool, plannedFor: Date?) -> Date {
        let mine = removalAt.addingTimeInterval(byTyping ? waitAfterTyping : waitAfterDelete)
        return max(mine, plannedFor ?? mine)
    }

    public static func plan(due: Date?, removedHereIsEmpty: Bool, syncRunning: Bool) -> Plan {
        guard let due, !removedHereIsEmpty else { return .none }
        if syncRunning { return .afterRunningSync }
        return .run(at: due)
    }
}
