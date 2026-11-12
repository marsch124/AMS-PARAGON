import Foundation

/// A reminder as seen by the sync engine. Priority is normalized to 0 (none) ... 3 (highest),
/// matching `!`, `!!`, `!!!` in notes.
public struct ReminderRecord: Equatable, Sendable {
    public var identifier: String
    public var listName: String
    /// The list's own identity in Reminders (`calendarIdentifier`), "" when not known. Two lists
    /// may share a name; this tells them apart.
    public var listID: String
    public var title: String
    public var isCompleted: Bool
    public var completedAt: Date?
    public var dueDate: DateOnly?
    public var dueTime: TimeOfDay?
    public var priority: Int
    public var notes: String?
    public var lastModified: Date?
    /// When the reminder was made, when Reminders says so. Of two reminders with one mark the older stays.
    public var createdAt: Date?

    public init(identifier: String = "",
                listName: String,
                listID: String = "",
                title: String,
                isCompleted: Bool = false,
                completedAt: Date? = nil,
                dueDate: DateOnly? = nil,
                dueTime: TimeOfDay? = nil,
                priority: Int = 0,
                notes: String? = nil,
                lastModified: Date? = nil,
                createdAt: Date? = nil) {
        self.identifier = identifier
        self.listName = listName
        self.listID = listID
        self.createdAt = createdAt
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.dueTime = dueDate == nil ? nil : dueTime
        self.priority = min(max(priority, 0), 3)
        self.notes = notes
        self.lastModified = lastModified
    }
}

public enum RemindersStoreError: Error, LocalizedError {
    case accessDenied
    case listNotFound(String)
    case reminderNotFound(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Access to Reminders was not granted."
        case .listNotFound(let name): return "Reminders list not found: \(name)"
        case .reminderNotFound(let id): return "Reminder not found: \(id)"
        case .underlying(let message): return message
        }
    }
}

/// A reminder the engine is looking for: the identifier it had on this device, and the task whose mark it carries.
public struct ReminderLookup: Equatable, Sendable {
    public var taskID: String
    public var identifier: String

    public init(taskID: String, identifier: String) {
        self.taskID = taskID
        self.identifier = identifier
    }
}

/// A Reminders list: its own identity and the name it has now.
public struct ReminderList: Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Abstraction over Apple Reminders (EventKit in the app, in-memory in tests).
public protocol RemindersStore: AnyObject {
    func listNames() async throws -> [String]
    /// Every list with its identity. Two lists may have the same name.
    func lists() async throws -> [ReminderList]
    func ensureList(named name: String) async throws
    /// Throws when the list is not there or could not be fetched: an empty answer always means
    /// "the list is empty", never "the fetch failed".
    func reminders(inList name: String) async throws -> [ReminderRecord]
    /// Looks in ALL lists, by identifier first and then by the PARAGON mark for the task.
    /// The answer is keyed by task id; a reminder that exists nowhere is simply not in it.
    /// A reminder found by identifier that carries another task's mark does not count.
    func findReminders(_ wanted: [ReminderLookup]) async throws -> [String: ReminderRecord]
    /// Creates a reminder and returns it with its store identifier filled in. It goes into the
    /// list with the draft's `listID` when that list is there under the draft's name, else into
    /// the first list with that name.
    func create(_ draft: ReminderRecord) async throws -> ReminderRecord
    func update(_ record: ReminderRecord) async throws
    func delete(identifier: String) async throws
}

/// Simple store used by tests and previews.
public final class InMemoryRemindersStore: RemindersStore {
    public private(set) var lists: [String] = []
    /// The identity of each list, by name. (This store has no two lists with one name.)
    public private(set) var listIDs: [String: String] = [:]
    public private(set) var records: [String: ReminderRecord] = [:]
    public var now: () -> Date = { Date() }
    private var counter = 0
    private var listCounter = 0
    /// Test hooks: something that happens while the engine waits on Reminders, and simulated failures.
    public var beforeFetch: (() throws -> Void)?
    public var failNextCreate = false
    public var failNextUpdate = false
    /// Simulates Apple Reminders failing to answer: every fetch throws while this is set.
    public var failFetches = false

    public init(lists: [String] = []) {
        self.lists = lists
        for name in lists { listIDs[name] = newListID() }
    }

    private func newListID() -> String {
        listCounter += 1
        return "list-\(listCounter)"
    }

    public func listNames() async throws -> [String] { lists }

    public func lists() async throws -> [ReminderList] {
        lists.map { ReminderList(id: listIDs[$0] ?? "", name: $0) }
    }

    /// Fills the store with a copy of another store's contents, keeping the identifiers.
    /// Used to rehearse a sync without touching Apple Reminders.
    /// A list keeps the identity its reminders came with, so a rehearsal sees the lists it knows.
    public func seed(lists: [String], records: [ReminderRecord]) {
        self.lists = lists
        for record in records { self.records[record.identifier] = record }
        for name in lists {
            listIDs[name] = records.first { $0.listName == name && !$0.listID.isEmpty }?.listID ?? newListID()
        }
    }

    public func ensureList(named name: String) async throws {
        if !lists.contains(name) { lists.append(name) }
        if listIDs[name] == nil { listIDs[name] = newListID() }
    }

    /// Removes a list and everything in it, as if the user did it in the Reminders app.
    public func simulateUserDeleteList(_ name: String) {
        lists.removeAll { $0 == name }
        listIDs[name] = nil
        records = records.filter { $0.value.listName != name }
    }

    public func reminders(inList name: String) async throws -> [ReminderRecord] {
        if let beforeFetch { self.beforeFetch = nil; try beforeFetch() }
        if failFetches { throw RemindersStoreError.underlying("simulated fetch failure") }
        return records.values.filter { $0.listName == name }.sorted { $0.identifier < $1.identifier }
    }

    public func findReminders(_ wanted: [ReminderLookup]) async throws -> [String: ReminderRecord] {
        if failFetches { throw RemindersStoreError.underlying("simulated fetch failure") }
        var found: [String: ReminderRecord] = [:]
        for lookup in wanted {
            if let record = records[lookup.identifier],
               [nil, lookup.taskID].contains(SyncEngine.markerTaskID(in: record.notes)) {
                found[lookup.taskID] = record
            } else if let record = record(withMarkerFor: lookup.taskID) {
                found[lookup.taskID] = record
            }
        }
        return found
    }

    /// Renames a list as if the user did it in the Reminders app; its reminders stay in it.
    public func simulateUserRenameList(_ old: String, to new: String) {
        lists = lists.map { $0 == old ? new : $0 }
        listIDs[new] = listIDs.removeValue(forKey: old)
        for (id, record) in records where record.listName == old { records[id]?.listName = new }
    }

    public func create(_ draft: ReminderRecord) async throws -> ReminderRecord {
        if failNextCreate { failNextCreate = false; throw RemindersStoreError.reminderNotFound("simulated failure") }
        try await ensureList(named: draft.listName)
        counter += 1
        var record = draft
        record.identifier = "rem-\(counter)"
        record.listID = listIDs[record.listName] ?? ""
        record.lastModified = now()
        record.createdAt = record.createdAt ?? now()
        records[record.identifier] = record
        return record
    }

    public func update(_ record: ReminderRecord) async throws {
        if failNextUpdate { failNextUpdate = false; throw RemindersStoreError.reminderNotFound("simulated failure") }
        guard records[record.identifier] != nil else { throw RemindersStoreError.reminderNotFound(record.identifier) }
        try await ensureList(named: record.listName)
        var updated = record
        updated.listID = listIDs[record.listName] ?? ""
        updated.lastModified = now()
        records[record.identifier] = updated
    }

    public func delete(identifier: String) async throws {
        records[identifier] = nil
    }

    // Test helpers that simulate the user editing in Apple Reminders.

    /// Adds a reminder as if the user created it in the Reminders app.
    @discardableResult
    public func simulateUserCreate(list: String, title: String, dueDate: DateOnly? = nil, dueTime: TimeOfDay? = nil,
                                   priority: Int = 0, completed: Bool = false) async throws -> ReminderRecord {
        try await create(ReminderRecord(listName: list, title: title, isCompleted: completed,
                                        completedAt: completed ? now() : nil, dueDate: dueDate, dueTime: dueTime, priority: priority))
    }

    public func simulateUserEdit(identifier: String, _ edit: (inout ReminderRecord) -> Void) {
        guard var record = records[identifier] else { return }
        edit(&record)
        if !lists.contains(record.listName) { lists.append(record.listName) }
        if listIDs[record.listName] == nil { listIDs[record.listName] = newListID() }
        record.listID = listIDs[record.listName] ?? ""
        record.lastModified = now()
        records[identifier] = record
    }

    public func record(withMarkerFor taskID: String) -> ReminderRecord? {
        records.values.sorted { $0.identifier < $1.identifier }.first { SyncEngine.markerTaskID(in: $0.notes) == taskID }
    }
}
