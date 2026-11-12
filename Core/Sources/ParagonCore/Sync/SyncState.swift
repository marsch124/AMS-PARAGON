import Foundation

/// The link between one task line and one reminder, plus what both looked like after the last sync.
public struct TaskLink: Codable, Equatable, Sendable {
    public var taskID: String
    public var reminderID: String
    public var notePath: String
    public var listName: String
    public var lastTaskFingerprint: String
    public var lastReminderFingerprint: String
    public var lastSyncedAt: Date

    public init(taskID: String, reminderID: String, notePath: String, listName: String,
                lastTaskFingerprint: String, lastReminderFingerprint: String, lastSyncedAt: Date) {
        self.taskID = taskID
        self.reminderID = reminderID
        self.notePath = notePath
        self.listName = listName
        self.lastTaskFingerprint = lastTaskFingerprint
        self.lastReminderFingerprint = lastReminderFingerprint
        self.lastSyncedAt = lastSyncedAt
    }
}

/// Persisted per device (reminder identifiers are device local in EventKit).
public struct SyncState: Codable, Equatable, Sendable {
    public var version = 1
    public var links: [String: TaskLink] = [:]
    public var lastRun: Date?
    /// The Reminders lists PARAGON is linked to: list name → the list's own identity. A list
    /// with the same name but another identity is not ours until its reminders say so.
    public var listIDs: [String: String] = [:]
    /// Tasks that had a mark but no link and no reminder at the last sync. They came from
    /// another device, whose reminder may still be on its way: a reminder is made for them
    /// only when the next sync still finds none.
    public var waitingForReminder: Set<String> = []

    public init() {}

    /// Files written before a field existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        links = try c.decode([String: TaskLink].self, forKey: .links)
        lastRun = try c.decodeIfPresent(Date.self, forKey: .lastRun)
        listIDs = try c.decodeIfPresent([String: String].self, forKey: .listIDs) ?? [:]
        waitingForReminder = try c.decodeIfPresent(Set<String>.self, forKey: .waitingForReminder) ?? []
    }

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Why a device's sync memory could not be used. The sync stops; nothing is changed.
public enum SyncStateError: Error, LocalizedError, Equatable {
    /// The file is in iCloud and its contents are not on this device yet. A download was asked for.
    case notDownloaded(String)
    /// The file is there but cannot be read or understood.
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .notDownloaded(let name):
            return "The sync was not started: this device's sync memory (\(name)) has not arrived from iCloud yet. Nothing was changed. Try again in a moment."
        case .unreadable(let name):
            return "The sync was not started: this device's sync memory (\(name)) cannot be read. Nothing was changed."
        }
    }
}

/// One `sync-state-….json` file in the vault's state folder.
public struct SyncStateFile: Equatable, Sendable, Identifiable {
    public let fileName: String
    /// The part of the file name that names the device.
    public let deviceName: String
    public let modifiedAt: Date?
    public let url: URL
    public var id: String { fileName }

    /// "sync-state-mac-1.json" → "mac-1"; nil for any other file.
    public static func deviceName(fromFileName name: String) -> String? {
        let prefix = "sync-state-", suffix = ".json"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix), name.count > prefix.count + suffix.count else { return nil }
        return String(name.dropFirst(prefix.count).dropLast(suffix.count))
    }
}

/// What a sync would cancel or delete when that is more than a handful. Nothing was changed.
public struct MassChangeSummary: Equatable, Sendable {
    /// Open tasks in notes that would be marked cancelled because their reminder is gone.
    public var tasksToCancel = 0
    /// Open reminders that would be deleted because their task line is gone.
    public var remindersToDelete = 0
    /// A few of the titles, tasks first.
    public var exampleTitles: [String] = []
    /// The Reminders lists the changes are in.
    public var lists: [String] = []
    /// New notes named like a Reminders list that PARAGON did not make and that has reminders in it.
    public var listsToJoin: [ListJoin] = []

    /// A note that would be joined to a list that was already there.
    public struct ListJoin: Equatable, Sendable {
        public var noteTitle: String
        public var listName: String
        /// The reminders in that list now.
        public var reminderCount: Int

        public init(noteTitle: String, listName: String, reminderCount: Int) {
            self.noteTitle = noteTitle
            self.listName = listName
            self.reminderCount = reminderCount
        }
    }

    public init() {}

    public var total: Int { tasksToCancel + remindersToDelete + listsToJoin.reduce(0) { $0 + $1.reminderCount } }

    public var message: String {
        var sentences: [String] = []
        var parts: [String] = []
        if tasksToCancel > 0 { parts.append("cancel \(tasksToCancel) task\(tasksToCancel == 1 ? "" : "s") in your notes") }
        if remindersToDelete > 0 { parts.append("delete \(remindersToDelete) reminder\(remindersToDelete == 1 ? "" : "s")") }
        if !parts.isEmpty {
            var text = "This sync would " + parts.joined(separator: " and ") + "."
            if !exampleTitles.isEmpty {
                text += " For example: " + exampleTitles.map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ") + "."
            }
            sentences.append(text)
        }
        for join in listsToJoin {
            let n = join.reminderCount
            sentences.append("Reminders already has a list called \u{201C}\(join.listName)\u{201D} with \(n) reminder\(n == 1 ? "" : "s") that PARAGON did not make. This sync would join it to the note \u{201C}\(join.noteTitle)\u{201D} and add \(n == 1 ? "that reminder" : "those reminders") to the note as tasks.")
        }
        if !listsToJoin.isEmpty { sentences.append("To keep them apart, cancel and rename the note or the list.") }
        return sentences.joined(separator: " ") + " Nothing was changed."
    }

    /// More than this many cancelled tasks and deleted reminders in one run needs a yes.
    public static let mostWithoutAsking = 5
    /// A list with at least this many linked items needs a yes when more than a third would go.
    public static let smallestListForShare = 3

    /// The rule, apart from the engine: more than 5 in all, or more than a third of one list
    /// that had at least 3 linked items.
    public static func needsConfirmation(total: Int, perList: [(changes: Int, linked: Int)]) -> Bool {
        if total > mostWithoutAsking { return true }
        return perList.contains { $0.linked >= smallestListForShare && $0.changes * 3 > $0.linked }
    }
}

/// How a sync ended.
public enum SyncOutcome: Equatable, Sendable {
    case finished(SyncReport)
    /// The run stopped before changing anything; run again with `allowMassChanges: true` after a yes.
    case needsConfirmation(MassChangeSummary)
}

/// Thrown by `SyncEngine.run` when the mass-change brake stops it.
public enum SyncEngineError: Error, LocalizedError, Equatable {
    case needsConfirmation(MassChangeSummary)

    public var errorDescription: String? {
        switch self {
        case .needsConfirmation(let summary): return "The sync stopped to ask first. " + summary.message
        }
    }
}

/// What happens to a note's open reminders when the note goes to Deleted.
public enum LinkedReminderChoice: Sendable {
    case delete
    case keep
}

/// What one sync run did.
public struct SyncReport: Equatable, Sendable {
    public var startedAt: Date
    public var finishedAt: Date?
    public var remindersCreated = 0
    public var remindersUpdated = 0
    public var remindersDeleted = 0
    public var tasksCreated = 0
    public var tasksUpdated = 0
    public var tasksCancelled = 0
    public var idsAssigned = 0
    public var notesSynced = 0
    public var conflicts: [String] = []
    public var warnings: [String] = []

    public init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }

    public var changeCount: Int {
        remindersCreated + remindersUpdated + remindersDeleted + tasksCreated + tasksUpdated + tasksCancelled
    }

    public var summary: String {
        var parts: [String] = []
        if remindersCreated > 0 { parts.append("\(remindersCreated) reminder\(remindersCreated == 1 ? "" : "s") created") }
        if remindersUpdated > 0 { parts.append("\(remindersUpdated) updated") }
        if remindersDeleted > 0 { parts.append("\(remindersDeleted) deleted") }
        if tasksCreated > 0 { parts.append("\(tasksCreated) task\(tasksCreated == 1 ? "" : "s") added to notes") }
        if tasksUpdated > 0 { parts.append("\(tasksUpdated) task\(tasksUpdated == 1 ? "" : "s") updated in notes") }
        if tasksCancelled > 0 { parts.append("\(tasksCancelled) cancelled") }
        if !conflicts.isEmpty { parts.append("\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s")") }
        if !warnings.isEmpty { parts.append("\(warnings.count) warning\(warnings.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "Everything in sync (\(notesSynced) notes)" : parts.joined(separator: ", ")
    }
}
