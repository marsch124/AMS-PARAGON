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

    /// The calm line at the foot of the Mac's sidebar and at the top of the phone's Today while
    /// a sync waits (build 284), so it is plain the sync has not been forgotten.
    public static let waitingLine = "Sync waiting for iCloud…"

    /// The short note shown when a sync someone pressed has to wait. Not an error.
    public static let message =
        "Notes are still arriving from iCloud. The sync starts by itself as soon as they are here."
}

/// The sync line that is always there (build 285): at the foot of the sidebar on the Mac and
/// the iPad, at the top of Today on the iPhone. Build 284 showed it only while a sync waited;
/// now it says, quietly, where the sync stands, and a press on it opens Settings at the
/// Reminders sync part. Grey while all is well, orange only when the last sync had conflicts.
public enum SyncStatus {
    /// What the line says. The first that applies wins: a running sync, then a waiting one,
    /// then the last one's outcome.
    public static func line(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int,
                            now: Date = Date(), calendar: Calendar = .current) -> String {
        if syncing { return "Syncing…" }
        if waiting { return SyncWait.waitingLine }
        guard let finishedAt else { return "Not synced yet" }
        if conflicts > 0 { return "Last sync: \(conflicts) conflict\(conflicts == 1 ? "" : "s")" }
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.dateFormat = "HH:mm"
        let clock = time.string(from: finishedAt)
        if calendar.isDate(finishedAt, inSameDayAs: now) { return "Synced at \(clock)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(finishedAt, inSameDayAs: yesterday) { return "Synced yesterday at \(clock)" }
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_GB")
        day.dateFormat = "d MMM"
        return "Synced \(day.string(from: finishedAt)) at \(clock)"
    }

    /// Orange, not grey: only conflicts, and only when nothing newer is happening.
    public static func isProblem(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int) -> Bool {
        !syncing && !waiting && finishedAt != nil && conflicts > 0
    }
}
