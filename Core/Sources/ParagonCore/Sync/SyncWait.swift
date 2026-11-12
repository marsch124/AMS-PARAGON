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
        let clock = DayWords.time(finishedAt, calendar: calendar)
        if calendar.isDate(finishedAt, inSameDayAs: now) { return "Synced at \(clock)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(finishedAt, inSameDayAs: yesterday) { return "Synced yesterday at \(clock)" }
        return "Synced \(DayWords.plain(finishedAt, calendar: calendar)) at \(clock)"
    }

    /// Orange, not grey: only conflicts, and only when nothing newer is happening.
    public static func isProblem(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int) -> Bool {
        !syncing && !waiting && finishedAt != nil && conflicts > 0
    }
}

/// Build 300, the clock ring: on the iPhone the sync button itself says where the sync
/// stands, and the "Synced at" pill on Today is gone. A ring round the button is full just
/// after a sync and empties over two hours, like a clock running down: green for the first
/// hour, yellow after that (and while a sync waits for iCloud), red when the last sync had
/// conflicts. Under the button a small word: the time, "Yesterday", the day, or what is wrong.
public enum SyncRing {
    public enum Mood: Equatable, Sendable { case none, fresh, aging, problem }

    /// How long a full ring takes to run down, and when green turns yellow.
    public static let span: TimeInterval = 2 * 60 * 60
    public static let freshFor: TimeInterval = 60 * 60

    public static func mood(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int,
                            now: Date = Date()) -> Mood {
        if syncing { return .fresh }
        if SyncStatus.isProblem(syncing: syncing, waiting: waiting, finishedAt: finishedAt, conflicts: conflicts) { return .problem }
        if waiting { return .aging }
        guard let finishedAt else { return .none }
        return now.timeIntervalSince(finishedAt) < freshFor ? .fresh : .aging
    }

    /// How much of the ring is drawn, 0 to 1. Full while syncing and when something is wrong
    /// (a whole red ring), empty when there has never been a sync.
    public static func fill(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int,
                            now: Date = Date()) -> Double {
        if syncing || waiting { return 1 }
        if SyncStatus.isProblem(syncing: syncing, waiting: waiting, finishedAt: finishedAt, conflicts: conflicts) { return 1 }
        guard let finishedAt else { return 0 }
        let age = max(0, now.timeIntervalSince(finishedAt))
        return max(0, min(1, 1 - age / span))
    }

    /// The small word under the button.
    public static func word(syncing: Bool, waiting: Bool, finishedAt: Date?, conflicts: Int,
                            now: Date = Date(), calendar: Calendar = .current) -> String {
        if syncing { return "Syncing" }
        if waiting { return "iCloud" }
        guard let finishedAt else { return "Not yet" }
        if conflicts > 0 { return conflicts == 1 ? "1 conflict" : "\(conflicts) conflicts" }
        if calendar.isDate(finishedAt, inSameDayAs: now) { return DayWords.time(finishedAt, calendar: calendar) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(finishedAt, inSameDayAs: yesterday) { return "Yesterday" }
        return DayWords.plain(finishedAt, calendar: calendar)
    }
}

extension SyncRing {
    /// **Build 304 (his yes to my idea): the number of tasks due today beside the Mac menu bar
    /// ring.** Nothing at all when none are due (an empty "0" would be noise), and "99+" past 99
    /// so the menu bar item never grows wide.
    public static func dueTodayBadge(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : "\(count)"
    }

    /// The menu bar's words: the count first, right beside the ring, then the sync word.
    public static func menuBarTitle(dueToday: Int, word: String) -> String {
        guard let badge = dueTodayBadge(dueToday) else { return word }
        return "\(badge) · \(word)"
    }
}
