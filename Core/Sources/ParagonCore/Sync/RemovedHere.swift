import Foundation

/// Build 332: which tasks a change made ON THIS DEVICE took away for good.
///
/// Build 331 made every reminder wait two minutes after its task line disappeared, because
/// a task moved between two notes on ANOTHER device looks, for a few seconds, exactly like a
/// deleted one (iCloud brings the note it left before the note it went to). That wait is
/// right for what arrives from elsewhere and pointless for what he did here: when he deletes
/// a task on this device, the app saw it happen and nothing is in transit.
///
/// So the app writes down the ids a save of its own removed, and hands them to the sync
/// (`SyncEngine.removedHere`), which deletes those reminders without the wait.
///
/// A task counts as removed here when
/// - it was in the note before the change made here and is not in it afterwards, and
/// - it is in no other note either — a task MOVED to another note is not a delete.
public enum RemovedHere {
    /// - Parameters:
    ///   - before: the ids in the note as it was before the change made here.
    ///   - after: the ids in the note as the change left it.
    ///   - elsewhere: the ids in every other note this device holds.
    public static func ids(before: Set<String>, after: Set<String>, elsewhere: Set<String>) -> Set<String> {
        before.subtracting(after).subtracting(elsewhere)
    }

    /// The same from notes: `before` and `after` are one note at two moments, `all` is every
    /// note on the device (the changed one may be among them, in either version).
    public static func ids(before: Note, after: Note, all notes: [Note]) -> Set<String> {
        var elsewhere = Set<String>()
        for note in notes where note.relativePath != after.relativePath {
            elsewhere.formUnion(note.tasks.compactMap(\.id))
        }
        return ids(before: Set(before.tasks.compactMap(\.id)),
                   after: Set(after.tasks.compactMap(\.id)), elsewhere: elsewhere)
    }

    /// What is still worth remembering after more changes: an id that is back in a note
    /// (Undo, a line pasted back) is no longer removed. Never more than `limit`, so a
    /// forgotten list cannot grow without end.
    public static func remembered(_ ids: Set<String>, adding fresh: Set<String>, nowInNotes present: Set<String>,
                                  limit: Int = RemovedHere.limit) -> Set<String> {
        let kept = ids.union(fresh).subtracting(present)
        guard kept.count > limit else { return kept }
        return Set(kept.sorted().prefix(limit))
    }

    public static let limit = 500
}
