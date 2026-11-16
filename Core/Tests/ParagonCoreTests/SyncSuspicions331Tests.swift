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
        XCTAssertEqual(after.notes, originalNotes, "notes kept")
        XCTAssertEqual(after.dueTime, TimeOfDay(hour: 9, minute: 30), "time kept")
        XCTAssertEqual(after.dueDate, DateOnly(year: 2026, month: 12, day: 24), "date kept")
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
