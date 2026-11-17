import XCTest
@testable import ParagonCore

/// Build 331: two suspicions from a review, played as iCloud would really deliver them.
final class MovedTaskAcrossNotesTests: XCTestCase {
    var vault: Vault!
    var store: InMemoryRemindersStore!
    var engine: SyncEngine!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        store = InMemoryRemindersStore(lists: ["Reminders"])
        engine = SyncEngine(vault: vault, store: store, deviceID: "test-device")
    }

    override func tearDown() { removeVault(vault) }

    private func setBody(_ title: String, _ body: String) throws {
        var note: Note
        if let existing = try? vault.loadNote(relativePath: "Projects/\(title).md") { note = existing }
        else { note = try vault.createNote(kind: .project, title: title) }
        note.body = body
        try vault.save(note, force: true)
    }

    /// Device A moved "Pack passport" from X to Y. Device B gets X (task gone) first, Y later.
    func testAMovedTaskKeepsItsReminderWhenTheSourceNoteArrivesBeforeTheTarget() async throws {
        try setBody("X", "- [ ] Pack passport ^t0000aa\n- [ ] Other ^t0000bb\n")
        try setBody("Y", "- [ ] Something ^t0000cc\n")
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)

        let before = try await store.reminders(inList: "X").first { $0.title.contains("Pack passport") }
        var original = try XCTUnwrap(before)
        original.notes = (original.notes ?? "") + "\nBring the red folder"
        original.dueDate = DateOnly(year: 2026, month: 12, day: 24)
        original.dueTime = TimeOfDay(hour: 9, minute: 30)
        try await store.update(original)
        let kept = try await store.records[original.identifier]
        let originalNotes = try XCTUnwrap(kept).notes

        // iCloud delivers the changed X first; Y is still the old one.
        try setBody("X", "- [ ] Other ^t0000bb\n")
        let middle = try await engine.run(allowMassChanges: true)
        let afterMiddle = store.records[original.identifier]
        XCTAssertNotNil(afterMiddle, "the reminder must not be deleted while the task is only in transit")
        XCTAssertEqual(middle.remindersDeleted, 0, "no reminder may be deleted between the two notes")

        // Now Y arrives with the task.
        try setBody("Y", "- [ ] Something ^t0000cc\n- [ ] Pack passport ^t0000aa\n")
        _ = try await engine.run(allowMassChanges: true)
        _ = try await engine.run(allowMassChanges: true)

        let all = store.records.values.filter { $0.title.contains("Pack passport") }
        XCTAssertEqual(all.count, 1, "exactly one reminder for the moved task")
        let after = try XCTUnwrap(store.records[original.identifier], "same reminder identifier at the end")
        // The engine writes its own mark back as the last line; his words are what count.
        _ = originalNotes
        XCTAssertTrue(after.notes?.contains("Bring the red folder") ?? false, "notes kept: \(after.notes ?? "none")")
        XCTAssertEqual(after.dueTime, TimeOfDay(hour: 9, minute: 30), "time kept")
        XCTAssertEqual(after.dueDate, DateOnly(year: 2026, month: 12, day: 24), "date kept")
    }

    /// Build 331, the other side of the same rule: a task he really deleted still loses its
    /// reminder — not at the first sync, and not before the wait is over, but then for good.
    func testADeletedTasksReminderGoesAfterTheWaitAndNotBefore() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
        engine.now = { clock.date }
        try setBody("X", "- [ ] Pack passport ^t0000aa\n- [ ] Other ^t0000bb\n")
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)
        let found = try await store.reminders(inList: "X").first { $0.title.contains("Pack passport") }
        let reminder = try XCTUnwrap(found)

        try setBody("X", "- [ ] Other ^t0000bb\n")
        let first = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(first.remindersDeleted, 0)
        XCTAssertEqual(first.remindersWaitingToGo, 1, "the first sync only writes the time down")

        clock.date += SyncEngine.standardGoneGrace - 1
        let early = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(early.remindersDeleted, 0, "not before the wait is over")
        XCTAssertNotNil(store.records[reminder.identifier])

        clock.date += 2
        let late = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(late.remindersDeleted, 1)
        XCTAssertEqual(late.remindersWaitingToGo, 0)
        XCTAssertNil(store.records[reminder.identifier], "gone for good after the wait")
        let state = try vault.loadSyncState(deviceID: "test-device")
        XCTAssertNil(state.links["t0000aa"])
        XCTAssertTrue(state.goneSince.isEmpty, "nothing is left waiting")
    }

    /// Build 332: a task deleted on THIS device does not wait. The app tells the engine
    /// which ids a change made here removed, and the first sync deletes their reminders.
    func testATaskDeletedOnThisDeviceLosesItsReminderInTheFirstSync() async throws {
        try setBody("X", "- [ ] Pack passport ^t0000aa\n- [ ] Other ^t0000bb\n")
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)
        let found = try await store.reminders(inList: "X").first { $0.title.contains("Pack passport") }
        let reminder = try XCTUnwrap(found)
        let before = try vault.loadNote(relativePath: "Projects/X.md")

        try setBody("X", "- [ ] Other ^t0000bb\n")
        let after = try vault.loadNote(relativePath: "Projects/X.md")
        engine.removedHere = RemovedHere.ids(before: before, after: after, all: try vault.allNotes())
        XCTAssertEqual(engine.removedHere, ["t0000aa"])

        let first = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(first.remindersDeleted, 1, "deleted here: gone in the first sync")
        XCTAssertEqual(first.remindersWaitingToGo, 0)
        XCTAssertNil(store.records[reminder.identifier])
        let state = try vault.loadSyncState(deviceID: "test-device")
        XCTAssertNil(state.links["t0000aa"])
        XCTAssertTrue(state.goneSince.isEmpty)
    }

    /// Build 332: the wait of build 331 stays for a line that went by ANOTHER device's
    /// change — the engine was told nothing, so the first sync only writes the time down.
    func testATaskGoneByAnotherDevicesChangeStillWaits() async throws {
        try setBody("X", "- [ ] Pack passport ^t0000aa\n- [ ] Other ^t0000bb\n")
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)
        let found = try await store.reminders(inList: "X").first { $0.title.contains("Pack passport") }
        let reminder = try XCTUnwrap(found)

        try setBody("X", "- [ ] Other ^t0000bb\n")
        engine.removedHere = ["t0000zz"] // something else was deleted here; this task was not
        let first = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(first.remindersDeleted, 0)
        XCTAssertEqual(first.remindersWaitingToGo, 1)
        XCTAssertNotNil(store.records[reminder.identifier])
    }

    /// Build 332: a task MOVED here is not a delete, even if the app wrongly named it: its
    /// id is still in a note, so the reminder stays and follows the task.
    func testATaskMovedOnThisDeviceIsNeverTakenForADelete() async throws {
        try setBody("X", "- [ ] Pack passport ^t0000aa\n- [ ] Other ^t0000bb\n")
        try setBody("Y", "- [ ] Something ^t0000cc\n")
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)
        let found = try await store.reminders(inList: "X").first { $0.title.contains("Pack passport") }
        let reminder = try XCTUnwrap(found)
        let before = try vault.loadNote(relativePath: "Projects/X.md")

        try setBody("Y", "- [ ] Something ^t0000cc\n- [ ] Pack passport ^t0000aa\n")
        try setBody("X", "- [ ] Other ^t0000bb\n")
        let after = try vault.loadNote(relativePath: "Projects/X.md")
        XCTAssertTrue(RemovedHere.ids(before: before, after: after, all: try vault.allNotes()).isEmpty,
                      "moved to another note: not removed")

        engine.removedHere = ["t0000aa"] // even when named by mistake
        let report = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(report.remindersDeleted, 0)
        XCTAssertEqual(store.records.values.filter { $0.title.contains("Pack passport") }.count, 1)
        _ = reminder
    }

    /// Build 332: an id that is back in a note (Undo) is forgotten, and the list has an end.
    func testWhatWasRemovedHereIsForgottenWhenItComesBack() {
        let kept = RemovedHere.remembered(["t1", "t2"], adding: ["t3"], nowInNotes: ["t2", "t9"])
        XCTAssertEqual(kept, ["t1", "t3"])
        let many = Set((0..<600).map { "t\($0)" })
        XCTAssertEqual(RemovedHere.remembered(many, adding: [], nowInNotes: []).count, RemovedHere.limit)
    }
}

/// An iCloud duplicate "Name 2.md" is made when two devices write "Name.md" at once.
final class ICloudDuplicateFileSyncTests: XCTestCase {
    var vault: Vault!
    var store: InMemoryRemindersStore!
    var engine: SyncEngine!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        store = InMemoryRemindersStore(lists: ["Reminders"])
        engine = SyncEngine(vault: vault, store: store, deviceID: "test-device")
    }

    override func tearDown() { removeVault(vault) }

    func testADuplicateFileNameTwoDoesNotDoubleOrStealOrDeleteReminders() async throws {
        var note = try vault.createNote(kind: .project, title: "Name")
        note.body = "- [ ] Buy milk ^t0000aa\n- [ ] Buy bread ^t0000bb\n"
        let saved = try vault.save(note)
        try await engine.run(allowMassChanges: true)
        try await engine.run(allowMassChanges: true)
        let idsBefore = Set(store.records.keys)
        XCTAssertEqual(idsBefore.count, 2)

        // iCloud's duplicate: same text, same ids.
        try vault.writeFile(Data(saved.text.utf8), at: "Projects/Name 2.md")
        let report = try await engine.run(allowMassChanges: true)
        _ = try await engine.run(allowMassChanges: true)

        XCTAssertEqual(store.records.count, 2, "no doubled reminders; warnings: \(report.warnings)")
        XCTAssertEqual(Set(store.records.keys), idsBefore, "none deleted, none added")
        XCTAssertEqual(report.remindersDeleted, 0)
        let state = try vault.loadSyncState(deviceID: "test-device")
        XCTAssertEqual(state.links["t0000aa"]?.notePath, "Projects/Name.md", "not stolen by the copy")
        XCTAssertEqual(state.links["t0000bb"]?.notePath, "Projects/Name.md")
        let original = try vault.loadNote(relativePath: "Projects/Name.md")
        XCTAssertEqual(original.tasks.compactMap(\.id).sorted(), ["t0000aa", "t0000bb"], "the original keeps its ids")
    }

    /// "Test work 2.md" with no "Test work.md" beside it is the owner's own note.
    func testANoteNamedWithATwoAndNoOriginalBesideItStaysAnOrdinaryNote() async throws {
        var note = try vault.createNote(kind: .project, title: "Test work 2")
        note.body = "- [ ] Write report\n"
        try vault.save(note)
        let report = try await engine.run(allowMassChanges: true)
        _ = report
        let titles = store.records.values.map(\.title)
        XCTAssertEqual(titles, ["Write report"], "an ordinary note: its task has a reminder")
        XCTAssertEqual(store.records.values.first?.listName, "Test work 2")
    }
}

private final class TestClock: @unchecked Sendable {
    var date: Date
    init(_ date: Date) { self.date = date }
}
