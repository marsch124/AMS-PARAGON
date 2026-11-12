import Foundation
import EventKit
import ParagonCore

/// Apple Reminders through EventKit. Each Reminders list is a "calendar" of type `.reminder`.
final class EventKitRemindersStore: RemindersStore {
    private let eventStore = EKEventStore()

    func requestAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        default:
            return try await eventStore.requestFullAccessToReminders()
        }
    }

    /// The list with this name. Two lists may share a name: the one with `id` wins when it is
    /// among them, so a new reminder goes into the list PARAGON is linked to.
    private func calendar(named name: String, id: String = "") -> EKCalendar? {
        let named = eventStore.calendars(for: .reminder).filter { $0.title == name }
        return named.first { $0.calendarIdentifier == id } ?? named.first
    }

    func lists() async throws -> [ReminderList] {
        eventStore.calendars(for: .reminder).map { ReminderList(id: $0.calendarIdentifier, name: $0.title) }
    }

    func listNames() async throws -> [String] {
        eventStore.calendars(for: .reminder).map(\.title)
    }

    func ensureList(named name: String) async throws {
        guard calendar(named: name) == nil else { return }
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = name
        guard let source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .calDAV })
            ?? eventStore.sources.first(where: { $0.sourceType == .local }) else {
            throw RemindersStoreError.underlying("No Reminders account is available to create the list \"\(name)\".")
        }
        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)
    }

    /// Every list with this name: two lists may share one, and the reminders may be in either.
    /// A missing list or a fetch that gives no answer throws, so neither is ever read as
    /// "the list is empty" and from there as "everything was deleted".
    func reminders(inList name: String) async throws -> [ReminderRecord] {
        let calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
        guard !calendars.isEmpty else { throw RemindersStoreError.listNotFound(name) }
        return try await fetch(in: calendars, failure: "The Reminders list \"\(name)\" could not be read. Nothing was changed in it.")
            .map(record(from:))
    }

    private func fetch(in calendars: [EKCalendar]?, failure: String) async throws -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: calendars)
        let items: [EKReminder]? = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { continuation.resume(returning: $0) }
        }
        guard let items else { throw RemindersStoreError.underlying(failure) }
        return items
    }

    func findReminders(_ wanted: [ReminderLookup]) async throws -> [String: ReminderRecord] {
        var found: [String: ReminderRecord] = [:]
        var byMark: [ReminderLookup] = []
        for lookup in wanted {
            if !lookup.identifier.isEmpty,
               let reminder = eventStore.calendarItem(withIdentifier: lookup.identifier) as? EKReminder,
               [nil, lookup.taskID].contains(SyncEngine.markerTaskID(in: reminder.notes)) {
                found[lookup.taskID] = record(from: reminder)
            } else {
                byMark.append(lookup)
            }
        }
        guard !byMark.isEmpty else { return found }
        let all = try await fetch(in: nil, failure: "Apple Reminders could not be read. Nothing was changed.")
        var marked: [String: EKReminder] = [:]
        for reminder in all {
            if let taskID = SyncEngine.markerTaskID(in: reminder.notes), marked[taskID] == nil { marked[taskID] = reminder }
        }
        for lookup in byMark {
            if let reminder = marked[lookup.taskID] { found[lookup.taskID] = record(from: reminder) }
        }
        return found
    }

    func create(_ draft: ReminderRecord) async throws -> ReminderRecord {
        try await ensureList(named: draft.listName)
        guard let calendar = calendar(named: draft.listName, id: draft.listID) else {
            throw RemindersStoreError.listNotFound(draft.listName)
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        apply(draft, to: reminder)
        try eventStore.save(reminder, commit: true)
        return record(from: reminder)
    }

    func update(_ record: ReminderRecord) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: record.identifier) as? EKReminder else {
            throw RemindersStoreError.reminderNotFound(record.identifier)
        }
        if reminder.calendar?.title != record.listName {
            try await ensureList(named: record.listName)
            if let calendar = calendar(named: record.listName, id: record.listID) {
                reminder.calendar = calendar
            }
        }
        apply(record, to: reminder)
        try eventStore.save(reminder, commit: true)
    }

    func delete(identifier: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try eventStore.remove(reminder, commit: true)
    }

    // MARK: Mapping

    private func apply(_ record: ReminderRecord, to reminder: EKReminder) {
        reminder.title = record.title
        reminder.notes = record.notes
        reminder.priority = Self.ekPriority(from: record.priority)
        if let due = record.dueDate {
            var components = due.dateComponents(at: record.dueTime)
            components.calendar = Calendar.current
            reminder.dueDateComponents = components
            // A timed due date only notifies when the reminder carries an alarm at that moment.
            let alarms = reminder.alarms ?? []
            if record.dueTime != nil, let moment = components.date {
                if let alarm = alarms.first {
                    if alarm.absoluteDate != moment { alarm.absoluteDate = moment }
                } else {
                    reminder.addAlarm(EKAlarm(absoluteDate: moment))
                }
            } else {
                for alarm in alarms where alarm.absoluteDate != nil { reminder.removeAlarm(alarm) }
            }
        } else {
            reminder.dueDateComponents = nil
            for alarm in reminder.alarms ?? [] { reminder.removeAlarm(alarm) }
        }
        if record.isCompleted {
            reminder.completionDate = record.completedAt ?? reminder.completionDate ?? Date()
        } else {
            reminder.isCompleted = false
        }
    }

    private func record(from reminder: EKReminder) -> ReminderRecord {
        ReminderRecord(identifier: reminder.calendarItemIdentifier,
                       listName: reminder.calendar?.title ?? "",
                       listID: reminder.calendar?.calendarIdentifier ?? "",
                       title: reminder.title ?? "",
                       isCompleted: reminder.isCompleted,
                       completedAt: reminder.completionDate,
                       dueDate: reminder.dueDateComponents.flatMap { DateOnly(components: $0) },
                       dueTime: reminder.dueDateComponents.flatMap { TimeOfDay(components: $0) },
                       priority: Self.priority(fromEK: reminder.priority),
                       notes: reminder.notes,
                       lastModified: reminder.lastModifiedDate,
                       createdAt: reminder.creationDate)
    }

    /// EventKit: 0 none, 1 high … 9 low. Notes: 0 none, 1 `!` … 3 `!!!`.
    static func priority(fromEK value: Int) -> Int {
        switch value {
        case 0: return 0
        case 1...4: return 3
        case 5: return 2
        default: return 1
        }
    }

    static func ekPriority(from priority: Int) -> Int {
        switch priority {
        case 3: return 1
        case 2: return 5
        case 1: return 9
        default: return 0
        }
    }
}
