import Foundation

/// Build 334: when the one quiet sync runs after a task was removed on this device.
///
/// A delete starts no sync of its own, so its reminder (`RemovedHere`, build 332) stayed in
/// Apple Reminders until the next timed or manual sync. Now the app plans one quiet sync a
/// few seconds after the LAST removal: each further delete pushes it back, so ticking through
/// a list makes one sync, not ten. Never while a sync is running (it runs once after that
/// one), and nothing at all when no removed task is waiting.
public enum QuietSyncAfterRemoval {
    /// Seconds after the last removal here.
    public static let wait: TimeInterval = 8

    public enum Plan: Equatable {
        case none
        case run(at: Date)
        /// A sync is running: plan again when it ends.
        case afterRunningSync
    }

    public static func plan(lastRemoval: Date?, removedHereIsEmpty: Bool, syncRunning: Bool) -> Plan {
        guard let lastRemoval, !removedHereIsEmpty else { return .none }
        if syncRunning { return .afterRunningSync }
        return .run(at: lastRemoval.addingTimeInterval(wait))
    }
}
