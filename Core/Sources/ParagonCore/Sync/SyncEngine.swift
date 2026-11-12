import Foundation

/// Two-way sync between task lines in PARA notes and Apple Reminders lists.
///
/// Mapping: `Inbox.md` <-> the configured inbox list; every Project (and Area) note <-> a list named
/// after the note (or its `reminders-list` frontmatter key). Each task line gets a stable `^tXXXXXX` id;
/// the mirrored reminder carries `ams-para:^tXXXXXX` in its notes so links survive across devices.
public final class SyncEngine {
    public static let markerPrefix = "ams-para:"
    static let markerRegex = try! NSRegularExpression(pattern: #"ams-para:\s*\^?(t[0-9a-f]{4,12})"#)

    public let vault: Vault
    public let store: RemindersStore
    public let deviceID: String
    public var config: VaultConfig
    public var now: () -> Date = { Date() }

    public init(vault: Vault, store: RemindersStore, deviceID: String, config: VaultConfig? = nil) {
        self.vault = vault
        self.store = store
        self.deviceID = deviceID
        self.config = config ?? vault.config
    }

    // MARK: Public API

    /// Notes whose tasks are mirrored to Reminders.
    public func syncableNotes(from notes: [Note]) -> [Note] {
        notes.filter { note in
            guard note.kind.isTaskKind, note.isSyncEnabled, !note.isArchived else { return false }
            if note.kind == .area && !config.syncAreas { return false }
            if note.kind == .daily && !config.syncDailyNotes { return false }
            return true
        }
    }

    public func listName(for note: Note) -> String {
        switch note.kind {
        case .inbox: return note.frontmatter.string("reminders-list") ?? config.inboxListName
        case .daily: return note.frontmatter.string("reminders-list") ?? config.dailyNotesListName
        default: return note.remindersListName
        }
    }

    /// Runs a sync. Throws `SyncEngineError.needsConfirmation` when the run would cancel or
    /// delete more than a handful and `allowMassChanges` is false; nothing was changed then.
    @discardableResult
    public func run(allowMassChanges: Bool = false) async throws -> SyncReport {
        switch try await sync(allowMassChanges: allowMassChanges) {
        case .finished(let report): return report
        case .needsConfirmation(let summary): throw SyncEngineError.needsConfirmation(summary)
        }
    }

    /// Runs a sync. When it would cancel tasks or delete open reminders beyond
    /// `MassChangeSummary.needsConfirmation`, it stops before writing anything, to notes or to
    /// Reminders, and says what it would do. Only a run started by a person who then said yes
    /// passes `allowMassChanges: true`; a timed sync never does.
    public func sync(allowMassChanges: Bool = false) async throws -> SyncOutcome {
        var report = SyncReport(startedAt: now())
        var state = try vault.loadSyncState(deviceID: deviceID)
        // A device with no memory of an earlier sync must not call every difference a conflict
        // and let the note win: what was ticked or renamed in Reminders is taken over instead.
        let firstSync = state.links.isEmpty

        // 1. Load notes, assign ids to tasks that have none, and give copies of an id a fresh one.
        // Up to `cloudFetchesPerLoad` waits for iCloud, as before build 261. `run()` is
        // nonisolated async, so this is off the main thread; each wait now ends after
        // `CloudFiles.longestWait`, and a try that brings nothing still counts.
        let allNotes = try vault.allNotes(cloudFetches: Vault.cloudFetchesPerLoad)
        for skipped in vault.skippedFiles {
            report.warnings.append("\(skipped) could not be read and was left alone.")
        }
        for waiting in vault.notesWaitingForCloud {
            report.warnings.append("\(waiting) has not arrived from iCloud yet and was left alone.")
        }
        let loadedPaths = Set(allNotes.map(\.relativePath))
        var allTaskIDs = Set(allNotes.flatMap { $0.tasks.compactMap(\.id) })
        var notesByPath: [String: Note] = [:]
        var dirtyPaths = Set<String>()
        /// Every change made to a note during the run, so it can be applied again to a fresher
        /// copy when the file changed on disk in the meantime.
        var mutations: [String: [(inout Note) -> Bool]] = [:]
        var listForPath: [String: String] = [:]
        /// The note that receives reminders created in a list. All daily notes share one list; today's note receives.
        var pathForList: [String: String] = [:]
        let todayPath = vault.dailyNotePath(for: DateOnly(now()))
        let syncable = syncableNotes(from: allNotes)

        // The note an id belongs to: the one this device linked it to, else the first that has it.
        // A line copied into a second note keeps its text but gets a fresh id there.
        var idOwners: [String: String] = [:]
        for note in syncable {
            for task in note.tasks {
                guard let id = task.id else { continue }
                if idOwners[id] == nil || state.links[id]?.notePath == note.relativePath { idOwners[id] = note.relativePath }
            }
        }

        // A task whose `^t` marker was edited away is recognised by its note and title, so it
        // gets the same marker back and keeps its reminder instead of it being replaced.
        var recoverableIDs: [String: String] = [:]
        for (taskID, link) in state.links where !allTaskIDs.contains(taskID) {
            let title = String(link.lastTaskFingerprint.split(separator: "|", omittingEmptySubsequences: false).first ?? "")
            guard !title.isEmpty else { continue }
            recoverableIDs["\(link.notePath)\n\(title)"] = taskID
        }

        func record(_ path: String, _ mutate: @escaping (inout Note) -> Bool) {
            mutations[path, default: []].append(mutate)
        }

        for var note in syncable {
            for var task in note.tasks where task.id == nil || idOwners[task.id ?? ""] != note.relativePath {
                let previousID = task.id
                if let previousID {
                    report.warnings.append("\(note.relativePath): \"\(task.title)\" had the id of a task in \(idOwners[previousID] ?? "another note") and got a new one.")
                }
                var id: String
                let key = "\(note.relativePath)\n\(Self.reminderTitle(for: task.title, parentPrefix: note.parentPrefix(for: task)))"
                if previousID == nil, let recovered = recoverableIDs.removeValue(forKey: key), !allTaskIDs.contains(recovered) {
                    id = recovered
                    report.warnings.append("\(note.relativePath): restored the Reminders link of \"\(task.title)\".")
                } else {
                    id = TaskItem.makeID()
                    while allTaskIDs.contains(id) { id = TaskItem.makeID() }
                }
                allTaskIDs.insert(id)
                task.id = id
                let assigned = task
                if note.replace(task: assigned, previousID: previousID) {
                    report.idsAssigned += 1
                    dirtyPaths.insert(note.relativePath)
                    record(note.relativePath) { $0.replace(task: assigned, previousID: previousID) }
                }
            }
            let list = listName(for: note)
            if note.kind == .daily {
                if pathForList[list] == nil || note.relativePath == todayPath { pathForList[list] = note.relativePath }
            } else if let existing = pathForList[list] {
                report.warnings.append("\(note.relativePath) and \(existing) both map to the list \"\(list)\"; only \(existing) is synced.")
                continue
            } else {
                pathForList[list] = note.relativePath
            }
            listForPath[note.relativePath] = list
            notesByPath[note.relativePath] = note
        }
        if config.syncDailyNotes, pathForList[config.dailyNotesListName] == nil {
            pathForList[config.dailyNotesListName] = todayPath // fetched even before the first daily note exists
        }
        report.notesSynced = notesByPath.count

        /// Writes the changed notes. A note that changed on disk while the engine worked (the editor,
        /// another device) is reloaded and the engine's changes are applied to the fresh copy.
        func persistNotes() throws {
            for path in dirtyPaths.sorted() {
                guard let note = notesByPath[path] else { continue }
                do {
                    notesByPath[path] = try vault.save(note)
                } catch VaultError.modifiedOnDisk {
                    var fresh = try vault.loadNote(relativePath: path)
                    for mutate in mutations[path] ?? [] { _ = mutate(&fresh) }
                    notesByPath[path] = try vault.save(fresh)
                    report.warnings.append("\(path) changed while syncing; the sync's changes were added to the new version.")
                }
            }
            dirtyPaths = []
        }

        var handledReminderIDs = Set<String>()
        /// Marker writes for imported reminders, done after the notes and state are saved.
        var pendingReminderUpdates: [ReminderRecord] = []

        // 2. Read Reminders; nothing is written yet. Every mapped list that exists, plus lists
        // that linked reminders were last seen in, so a renamed note finds its reminders.
        let listNames = try await store.listNames()
        let existingLists = Set(listNames)
        var remindersByID: [String: ReminderRecord] = [:]
        var remindersByMarker: [String: ReminderRecord] = [:]
        var fetchedLists = Set<String>()
        func fetch(_ list: String) async throws {
            guard fetchedLists.insert(list).inserted else { return }
            for record in try await store.reminders(inList: list) {
                remindersByID[record.identifier] = record
                if let marker = Self.markerTaskID(in: record.notes), remindersByMarker[marker] == nil {
                    remindersByMarker[marker] = record
                }
            }
        }
        let linkedLists = Set(state.links.values.map(\.listName)).filter { existingLists.contains($0) }
        for list in Set(pathForList.keys).union(linkedLists).sorted() where existingLists.contains(list) {
            try await fetch(list)
        }

        // Index tasks by id (rebuilt after reconciliation so later steps see the current lines).
        var taskLocations: [String: (path: String, task: TaskItem)] = [:]
        func indexTasks() {
            taskLocations = [:]
            for (path, note) in notesByPath {
                for task in note.tasks {
                    if let id = task.id { taskLocations[id] = (path, task) }
                }
            }
        }
        indexTasks()

        // 2b. A linked reminder that is in none of those lists is not yet "deleted": the list may
        // have been renamed, or two lists share a name. Look for it everywhere, by its identifier
        // and by its mark, and follow it.
        let strays = state.links.sorted { $0.key < $1.key }.filter { taskID, link in
            taskLocations[taskID] != nil && remindersByID[link.reminderID] == nil && remindersByMarker[taskID] == nil
        }
        var foundElsewhere: [String: ReminderRecord] = [:]
        if !strays.isEmpty {
            foundElsewhere = try await store.findReminders(strays.map { ReminderLookup(taskID: $0.key, identifier: $0.value.reminderID) })
            for (taskID, record) in foundElsewhere {
                remindersByID[record.identifier] = record
                remindersByMarker[taskID] = record
            }
        }

        // 2c. Mapped lists that do not exist. When all of a note's reminders now live together in
        // one other list that no note uses, the list was renamed in Reminders: the note follows it
        // (`reminders-list:` in its frontmatter) and no empty list is made under the old name.
        var listsToCreate: [String] = []
        for list in Set(pathForList.keys).subtracting(existingLists).sorted() {
            guard let path = pathForList[list] else { continue }
            let links = state.links.filter { taskLocations[$0.key]?.path == path }
            let homes = Set(links.keys.compactMap { foundElsewhere[$0]?.listName })
            if let home = homes.first, homes.count == 1, existingLists.contains(home), pathForList[home] == nil,
               notesByPath[path] != nil, notesByPath[path]?.kind != .daily,
               links.values.allSatisfy({ $0.listName == list }) {
                pathForList[list] = nil
                pathForList[home] = path
                listForPath[path] = home
                for taskID in links.keys { state.links[taskID]?.listName = home }
                notesByPath[path]?.frontmatter.set("reminders-list", home)
                dirtyPaths.insert(path)
                record(path) { $0.frontmatter.set("reminders-list", home); return true }
                report.warnings.append("\(path): the Reminders list \"\(list)\" is now called \"\(home)\"; the note follows it.")
                try await fetch(home)
            } else if config.createMissingLists {
                listsToCreate.append(list)
                fetchedLists.insert(list) // made below; a new list is empty
            }
        }

        // 2d. The brake: count what this run would cancel or delete, with the same tests as
        // step 3 uses, and stop before anything is written when that is more than a handful.
        if !allowMassChanges {
            var summary = MassChangeSummary()
            var linkedPerList: [String: Int] = [:]
            var changesPerList: [String: Int] = [:]
            var cancelTitles: [String] = []
            var deleteTitles: [String] = []
            for (taskID, link) in state.links.sorted(by: { $0.key < $1.key }) {
                linkedPerList[link.listName, default: 0] += 1
                let reminder = remindersByID[link.reminderID] ?? remindersByMarker[taskID]
                if let location = taskLocations[taskID] {
                    guard reminder == nil, fetchedLists.contains(link.listName), !location.task.isDone else { continue }
                    summary.tasksToCancel += 1
                    cancelTitles.append(location.task.title)
                } else if let reminder {
                    guard !reminder.isCompleted, !allTaskIDs.contains(taskID), loadedPaths.contains(link.notePath) else { continue }
                    summary.remindersToDelete += 1
                    deleteTitles.append(reminder.title)
                } else {
                    continue
                }
                changesPerList[link.listName, default: 0] += 1
            }
            if MassChangeSummary.needsConfirmation(total: summary.total,
                                                   perList: changesPerList.map { ($0.value, linkedPerList[$0.key] ?? 0) }) {
                summary.exampleTitles = Array((cancelTitles + deleteTitles).prefix(5))
                summary.lists = changesPerList.keys.sorted()
                return .needsConfirmation(summary)
            }
        }

        // Ids are written before Reminders is changed, so a failure later cannot leave
        // reminders carrying ids no note knows about.
        try persistNotes()
        indexTasks()
        /// Paths of notes in Deleted, read once and only when a link points at a missing note.
        var deletedPaths: Set<String>?
        func isInDeleted(_ path: String) -> Bool {
            let paths = deletedPaths ?? Set(vault.deletedNotes().map(\.originalPath))
            deletedPaths = paths
            return paths.contains(path)
        }

        do {
            for list in listsToCreate { try await store.ensureList(named: list) }

            /// `Parent › Child` prefix for subtasks, nil for top-level tasks.
            func parentPrefix(_ path: String, _ task: TaskItem) -> String? {
                notesByPath[path]?.parentPrefix(for: task)
            }

            /// Applies a change to a note in memory and remembers it. Nothing is marked dirty when
            /// the change did not apply (the task is gone) or changed nothing.
            func updateNote(_ path: String, _ mutate: @escaping (inout Note) -> Bool) {
                guard var note = notesByPath[path] else { return }
                let before = note.body
                guard mutate(&note), note.body != before else { return }
                notesByPath[path] = note
                dirtyPaths.insert(path)
                record(path, mutate)
            }

            // 3. Reconcile existing links.
            for (taskID, link) in state.links.sorted(by: { $0.key < $1.key }) {
                let location = taskLocations[taskID]
                let reminder = remindersByID[link.reminderID] ?? remindersByMarker[taskID]

                switch (location, reminder) {
                case let (location?, reminder?):
                    handledReminderIDs.insert(reminder.identifier)
                    let listName = listForPath[location.path] ?? link.listName
                    let outcome = try await reconcile(task: location.task, at: location.path, listName: listName,
                                                      parentPrefix: parentPrefix(location.path, location.task),
                                                      reminder: reminder, link: link, firstLink: false,
                                                      report: &report, updateNote: updateNote)
                    state.links[taskID] = outcome
                case let (location?, nil):
                    guard fetchedLists.contains(link.listName) else {
                        // The list it lived in was not looked at (it is gone, or not readable now):
                        // that is not evidence the reminder was deleted. Leave the task and the link.
                        report.warnings.append("\(location.path): \"\(location.task.title)\" was last seen in the Reminders list \"\(link.listName)\", which is not available; left unchanged.")
                        continue
                    }
                    // Reminder deleted in Apple Reminders: cancel the task instead of deleting the user's text.
                    if !location.task.isDone {
                        let task = location.task
                        updateNote(location.path) { note in
                            var t = task
                            t.markCancelled()
                            return note.replace(task: t)
                        }
                        report.tasksCancelled += 1
                    }
                    state.links[taskID] = nil
                case let (nil, reminder?):
                    handledReminderIDs.insert(reminder.identifier)
                    if allTaskIDs.contains(taskID) {
                        // The task moved to a note that is not synced (archived, sync: false). Leave the reminder alone.
                        state.links[taskID] = nil
                    } else if loadedPaths.contains(link.notePath) {
                        // The note was read and the task line is gone: the user deleted it.
                        try await store.delete(identifier: reminder.identifier)
                        report.remindersDeleted += 1
                        state.links[taskID] = nil
                    } else if isInDeleted(link.notePath) {
                        // The note is in Deleted: keep the reminder, forget the link, say nothing.
                        // Putting the note back links it again through the mark on the reminder.
                        state.links[taskID] = nil
                    } else {
                        // The note itself is missing or unreadable (not downloaded yet, moved away):
                        // keep the reminder and the link until the note is seen again.
                        report.warnings.append("\(link.notePath) is missing or unreadable; its reminder \"\(reminder.title)\" was kept.")
                    }
                case (nil, nil):
                    state.links[taskID] = nil
                }
            }

            indexTasks()

            // 4. Tasks without a link: match by marker, else create a reminder for open tasks.
            for (taskID, location) in taskLocations.sorted(by: { $0.key < $1.key }) where state.links[taskID] == nil {
                let listName = listForPath[location.path] ?? ""
                if let reminder = remindersByMarker[taskID], !handledReminderIDs.contains(reminder.identifier) {
                    handledReminderIDs.insert(reminder.identifier)
                    let provisional = TaskLink(taskID: taskID, reminderID: reminder.identifier, notePath: location.path, listName: listName,
                                               lastTaskFingerprint: "", lastReminderFingerprint: "", lastSyncedAt: now())
                    state.links[taskID] = try await reconcile(task: location.task, at: location.path, listName: listName,
                                                              parentPrefix: parentPrefix(location.path, location.task),
                                                              reminder: reminder, link: provisional, firstLink: firstSync,
                                                              report: &report, updateNote: updateNote)
                    continue
                }
                guard !location.task.isDone else { continue }
                let prefix = parentPrefix(location.path, location.task)
                var draft = ReminderRecord(listName: listName, title: location.task.title)
                apply(task: location.task, to: &draft, listName: listName, parentPrefix: prefix)
                let created = try await store.create(draft)
                handledReminderIDs.insert(created.identifier)
                report.remindersCreated += 1
                state.links[taskID] = TaskLink(taskID: taskID, reminderID: created.identifier, notePath: location.path, listName: listName,
                                               lastTaskFingerprint: Self.fingerprint(location.task, parentPrefix: prefix),
                                               lastReminderFingerprint: Self.fingerprint(created), lastSyncedAt: now())
            }

            // 5. Reminders without a link: import into the note that owns the list.
            for reminder in remindersByID.values.sorted(by: { $0.identifier < $1.identifier }) where !handledReminderIDs.contains(reminder.identifier) {
                guard var path = pathForList[reminder.listName] else { continue }
                if Self.markerTaskID(in: reminder.notes) != nil {
                    // Marked by PARAGON but not linked here and not in any note this device can see.
                    // That happens on a fresh device before the notes arrive; never delete on that basis.
                    continue
                }
                if reminder.isCompleted && !config.importCompletedReminders { continue }

                if config.syncDailyNotes, reminder.listName == config.dailyNotesListName {
                    // Reminders added to the daily list belong in today's note, created on demand.
                    if notesByPath[todayPath] == nil {
                        notesByPath[todayPath] = try vault.dailyNote(for: DateOnly(now()))
                        listForPath[todayPath] = reminder.listName
                    }
                    pathForList[reminder.listName] = todayPath
                    path = todayPath
                }

                var id = TaskItem.makeID()
                while allTaskIDs.contains(id) { id = TaskItem.makeID() }
                allTaskIDs.insert(id)

                var task = TaskItem(title: Self.taskTitle(fromReminderTitle: reminder.title, parentPrefix: nil), id: id)
                apply(reminder: reminder, to: &task)
                task = TaskParser.normalized(task)
                var appended = task
                let toAppend = task
                updateNote(path) { note in
                    appended = note.append(task: toAppend)
                    return true
                }
                report.tasksCreated += 1

                var updated = reminder
                updated.notes = Self.notes(reminder.notes, withMarkerFor: id)
                pendingReminderUpdates.append(updated)

                state.links[id] = TaskLink(taskID: id, reminderID: reminder.identifier, notePath: path, listName: reminder.listName,
                                           lastTaskFingerprint: Self.fingerprint(appended),
                                           lastReminderFingerprint: Self.fingerprint(updated), lastSyncedAt: now())
            }
        } catch {
            // Keep what was achieved so far; the next run continues from here instead of redoing it.
            try? persistNotes()
            try? vault.save(syncState: state, deviceID: deviceID)
            throw error
        }

        // 6. Persist notes and state first, then the marker writes that depend on them.
        try persistNotes()
        state.lastRun = now()
        try vault.save(syncState: state, deviceID: deviceID)
        for updated in pendingReminderUpdates {
            do {
                try await store.update(updated)
            } catch {
                // The link exists; the next run puts the marker on the reminder through reconcile.
                report.warnings.append("Could not tag the reminder \"\(updated.title)\"; it will be retried.")
            }
        }
        report.finishedAt = now()
        return .finished(report)
    }

    // MARK: Notes that go to Deleted

    /// The open reminders that belong to a note, wherever they are in Reminders: the ones this
    /// device linked to it and the ones that carry the mark of one of its tasks. For asking
    /// "delete its reminders too?" only when there is something to delete.
    public func openLinkedReminders(of note: Note) async throws -> [ReminderRecord] {
        let state = try vault.loadSyncState(deviceID: deviceID)
        return try await linkedReminders(of: note, in: state).filter { !$0.isCompleted }
    }

    /// Call when a note goes to Deleted. Deletes its open reminders or keeps them, and in both
    /// cases forgets its links, so later syncs have nothing to warn about. Completed reminders
    /// always stay. A note put back links again through the mark on the reminders that were kept;
    /// its open tasks get new reminders when the old ones were deleted.
    /// Returns how many reminders were deleted.
    @discardableResult
    public func releaseReminders(of note: Note, _ choice: LinkedReminderChoice) async throws -> Int {
        var state = try vault.loadSyncState(deviceID: deviceID)
        var deleted = 0
        if choice == .delete {
            for reminder in try await linkedReminders(of: note, in: state) where !reminder.isCompleted {
                try await store.delete(identifier: reminder.identifier)
                deleted += 1
            }
        }
        let taskIDs = Set(note.tasks.compactMap(\.id))
        let before = state.links.count
        state.links = state.links.filter { $0.value.notePath != note.relativePath && !taskIDs.contains($0.key) }
        if state.links.count != before { try vault.save(syncState: state, deviceID: deviceID) }
        return deleted
    }

    private func linkedReminders(of note: Note, in state: SyncState) async throws -> [ReminderRecord] {
        var wanted: [String: ReminderLookup] = [:]
        for (taskID, link) in state.links where link.notePath == note.relativePath {
            wanted[taskID] = ReminderLookup(taskID: taskID, identifier: link.reminderID)
        }
        for taskID in note.tasks.compactMap(\.id) where wanted[taskID] == nil {
            wanted[taskID] = ReminderLookup(taskID: taskID, identifier: state.links[taskID]?.reminderID ?? "")
        }
        guard !wanted.isEmpty else { return [] }
        let found = try await store.findReminders(wanted.values.sorted { $0.taskID < $1.taskID })
        var seen = Set<String>()
        return found.values.filter { seen.insert($0.identifier).inserted }.sorted { $0.identifier < $1.identifier }
    }

    // MARK: Reconciliation

    private func reconcile(task: TaskItem, at path: String, listName: String, parentPrefix: String?,
                           reminder: ReminderRecord, link: TaskLink, firstLink: Bool,
                           report: inout SyncReport, updateNote: (String, @escaping (inout Note) -> Bool) -> Void) async throws -> TaskLink {
        let taskFP = Self.fingerprint(task, parentPrefix: parentPrefix)
        let reminderFP = Self.fingerprint(reminder)
        let taskChanged = taskFP != link.lastTaskFingerprint
        let reminderChanged = reminderFP != link.lastReminderFingerprint
        let listChanged = reminder.listName != listName
        var newLink = link
        newLink.notePath = path
        newLink.listName = listName
        newLink.lastSyncedAt = now()

        if !taskChanged && !reminderChanged && !listChanged && Self.markerTaskID(in: reminder.notes) == task.id {
            return newLink
        }

        let noteWins: Bool
        if firstLink && taskFP != reminderFP {
            // This device's first sync, linked through the mark: there is no "last time" to
            // compare with. Take over what Reminders has (a tick, a new title) and call nothing
            // a conflict. Only a task already finished in the note stays finished.
            noteWins = task.isDone && !reminder.isCompleted
        } else if taskChanged && reminderChanged && taskFP != reminderFP {
            noteWins = config.conflictPolicy == .noteWins
            report.conflicts.append("\(path): \"\(task.title)\" changed in both places; kept the \(noteWins ? "note" : "reminder") version.")
        } else if taskFP == reminderFP {
            noteWins = true // same content on both sides, only refresh the marker / list
        } else {
            noteWins = taskChanged || (!reminderChanged && listChanged)
        }

        if noteWins {
            var updated = reminder
            apply(task: task, to: &updated, listName: listName, parentPrefix: parentPrefix)
            if updated != reminder {
                try await store.update(updated)
                report.remindersUpdated += 1
            }
            newLink.lastTaskFingerprint = taskFP
            newLink.lastReminderFingerprint = Self.fingerprint(updated)
        } else {
            var t = task
            apply(reminder: reminder, to: &t, parentPrefix: parentPrefix)
            t = TaskParser.normalized(t)
            let replacement = t
            let completedNow = replacement.isDone && !task.isDone
            let completedOn = DateOnly(reminder.completedAt ?? now())
            updateNote(path) { note in
                guard note.replace(task: replacement) else { return false }
                if completedNow, let next = replacement.nextOccurrence(completedOn: completedOn) {
                    let line = note.tasks.first { $0.id != nil && $0.id == replacement.id }?.lineIndex ?? replacement.lineIndex
                    note.insert(task: next, afterLine: line)
                }
                return true
            }
            report.tasksUpdated += 1
            var updated = reminder
            if Self.markerTaskID(in: updated.notes) != task.id || listChanged {
                updated.notes = Self.notes(updated.notes, withMarkerFor: task.id ?? "")
                updated.listName = listName
                try await store.update(updated)
            }
            newLink.lastTaskFingerprint = Self.fingerprint(t, parentPrefix: parentPrefix)
            newLink.lastReminderFingerprint = Self.fingerprint(updated)
        }
        return newLink
    }

    // MARK: Field mapping

    func apply(task: TaskItem, to reminder: inout ReminderRecord, listName: String, parentPrefix: String? = nil) {
        reminder.listName = listName
        reminder.title = Self.reminderTitle(for: task.title, parentPrefix: parentPrefix)
        reminder.dueDate = task.dueDate
        reminder.dueTime = task.dueDate == nil ? nil : task.dueTime
        reminder.priority = task.priority
        if task.isDone {
            if !reminder.isCompleted {
                reminder.completedAt = task.doneDate ?? now()
            }
            reminder.isCompleted = true
        } else {
            reminder.isCompleted = false
            reminder.completedAt = nil
        }
        if let id = task.id {
            reminder.notes = Self.notes(reminder.notes, withMarkerFor: id)
        }
    }

    func apply(reminder: ReminderRecord, to task: inout TaskItem, parentPrefix: String? = nil) {
        task.title = Self.taskTitle(fromReminderTitle: reminder.title, parentPrefix: parentPrefix)
        task.dueDate = reminder.dueDate
        task.dueTime = reminder.dueDate == nil ? nil : reminder.dueTime
        task.priority = reminder.priority
        if reminder.isCompleted && !task.isDone {
            task.markDone(at: reminder.completedAt ?? now())
        } else if !reminder.isCompleted && task.isDone {
            task.markOpen()
        }
    }

    /// Subtasks are mirrored as `Parent › Child` because EventKit has no public subtask API.
    static func reminderTitle(for taskTitle: String, parentPrefix: String?) -> String {
        let base = taskTitle.isEmpty ? "Untitled task" : taskTitle
        guard let parentPrefix, !parentPrefix.isEmpty else { return base }
        return parentPrefix + Note.subtaskSeparator + base
    }

    /// Strips the `Parent › ` prefix again when a subtask's reminder comes back, and removes
    /// `^tXXXXXX` ids and `@done(...)` stamps typed into a reminder title, which would otherwise
    /// be read back as the task's own id or completion.
    static func taskTitle(fromReminderTitle title: String, parentPrefix: String?) -> String {
        var clean = singleLine(title)
        for regex in [TaskParser.idRegex, TaskParser.doneRegex] {
            let ns = clean as NSString
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        }
        clean = TaskParser.collapseWhitespace(clean)
        guard let parentPrefix, !parentPrefix.isEmpty else { return clean }
        let prefix = parentPrefix + Note.subtaskSeparator
        return clean.hasPrefix(prefix) ? String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) : clean
    }

    static func singleLine(_ text: String) -> String {
        TaskParser.collapseWhitespace(text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " "))
    }

    /// The part of a task or reminder that both sides share.
    public static func fingerprint(_ task: TaskItem, parentPrefix: String? = nil) -> String {
        fingerprint(title: reminderTitle(for: task.title, parentPrefix: parentPrefix), done: task.isDone,
                    due: task.dueDate, time: task.dueDate == nil ? nil : task.dueTime, priority: task.priority)
    }

    public static func fingerprint(_ reminder: ReminderRecord) -> String {
        fingerprint(title: singleLine(reminder.title), done: reminder.isCompleted,
                    due: reminder.dueDate, time: reminder.dueDate == nil ? nil : reminder.dueTime, priority: reminder.priority)
    }

    private static func fingerprint(title: String, done: Bool, due: DateOnly?, time: TimeOfDay?, priority: Int) -> String {
        "\(TaskParser.collapseWhitespace(title))|\(done ? 1 : 0)|\(due?.description ?? "")\(time.map { "T\($0)" } ?? "")|\(priority)"
    }

    // MARK: Marker in the reminder notes

    public static func markerTaskID(in notes: String?) -> String? {
        guard let notes else { return nil }
        let ns = notes as NSString
        guard let m = markerRegex.firstMatch(in: notes, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    public static func marker(for taskID: String) -> String {
        "\(markerPrefix)^\(taskID)"
    }

    /// Keeps the user's own notes text and makes sure exactly one marker line for `taskID` is present.
    public static func notes(_ existing: String?, withMarkerFor taskID: String) -> String {
        let keep = (existing ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains(markerPrefix) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return keep.isEmpty ? marker(for: taskID) : keep + "\n\n" + marker(for: taskID)
    }
}
