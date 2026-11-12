import XCTest
@testable import ParagonCore

/// Data-safety rules of the Reminders sync (premium review, hardening 04, 05, 11, 12).
final class SyncSafetyTests: XCTestCase {
    var vault: Vault!
    var store: InMemoryRemindersStore!
    var engine: SyncEngine!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        store = InMemoryRemindersStore(lists: ["Reminders"])
        engine = SyncEngine(vault: vault, store: store, deviceID: "test-device")
    }

    override func tearDown() {
        removeVault(vault)
    }

    @discardableResult
    private func makeProject(_ title: String, tasks: [String]) throws -> Note {
        var note = try vault.createNote(kind: .project, title: title)
        note.body = tasks.map { "- [ ] \($0)\n" }.joined()
        return try vault.save(note)
    }

    private func project(_ title: String) throws -> Note { try vault.loadNote(relativePath: "Projects/\(title).md") }

    // MARK: hardening-04

    func testRenamingAListInRemindersCancelsNothingAndTheNoteFollows() async throws {
        try makeProject("Trip", tasks: ["Book flights", "Book hotel", "Pack"])
        try await engine.run()
        store.simulateUserRenameList("Trip", to: "Trip 2027")

        let report = try await engine.run()
        XCTAssertEqual(report.tasksCancelled, 0)
        XCTAssertEqual(report.remindersCreated, 0)
        XCTAssertFalse(store.lists.contains("Trip"), "no empty list under the old name")
        let note = try project("Trip")
        XCTAssertEqual(note.tasks.filter(\.isDone).count, 0)
        XCTAssertEqual(note.remindersListName, "Trip 2027")
        let kept = try await store.reminders(inList: "Trip 2027").count
        XCTAssertEqual(kept, 3)

        let again = try await engine.run()
        XCTAssertEqual(again.changeCount, 0)
        XCTAssertEqual(again.warnings, [])
    }

    // MARK: hardening-05

    func testMassChangeStopsBeforeWritingAndRunsAfterAYes() async throws {
        try makeProject("Trip", tasks: ["One", "Two", "Three", "Four"])
        try await engine.run()
        let textBefore = try project("Trip").text
        let stateBefore = try vault.loadSyncState(deviceID: "test-device")
        for reminder in try await store.reminders(inList: "Trip").prefix(2) {
            try await store.delete(identifier: reminder.identifier)
        }

        guard case .needsConfirmation(let summary) = try await engine.sync() else { return XCTFail("the brake did not stop the run") }
        XCTAssertEqual(summary.tasksToCancel, 2)
        XCTAssertEqual(summary.remindersToDelete, 0)
        XCTAssertEqual(summary.exampleTitles.count, 2)
        XCTAssertEqual(try project("Trip").text, textBefore)
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device"), stateBefore)

        guard case .finished(let report) = try await engine.sync(allowMassChanges: true) else { return XCTFail("the allowed run stopped") }
        XCTAssertEqual(report.tasksCancelled, 2)
    }

    func testTheBrakeRule() {
        XCTAssertFalse(MassChangeSummary.needsConfirmation(total: 5, perList: [(5, 15)]))
        XCTAssertTrue(MassChangeSummary.needsConfirmation(total: 6, perList: [(6, 100)]))
        XCTAssertFalse(MassChangeSummary.needsConfirmation(total: 1, perList: [(1, 3)]))
        XCTAssertTrue(MassChangeSummary.needsConfirmation(total: 2, perList: [(2, 3)]))
        XCTAssertFalse(MassChangeSummary.needsConfirmation(total: 2, perList: [(2, 2)]), "a list of two is too small for the share rule")
    }

    func testAFailedFetchIsAnErrorNotAnEmptyList() async throws {
        try makeProject("Trip", tasks: ["One"])
        try await engine.run()
        store.failFetches = true
        do {
            _ = try await engine.sync(allowMassChanges: true)
            XCTFail("a failed fetch must stop the sync")
        } catch {}
        XCTAssertEqual(try project("Trip").tasks.filter(\.isDone).count, 0)
    }

    // MARK: hardening-11

    func testMissingStateIsEmptyButUnreadableStateThrows() throws {
        XCTAssertEqual(try vault.loadSyncState(deviceID: "new-device"), SyncState())
        try FileManager.default.createDirectory(at: vault.stateFolderURL, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: vault.syncStateURL(deviceID: "broken"))
        XCTAssertThrowsError(try vault.loadSyncState(deviceID: "broken")) { error in
            XCTAssertEqual(error as? SyncStateError, .unreadable("sync-state-broken.json"))
        }
        // An iCloud stub beside where the file belongs: it exists, its contents are not here.
        try Data().write(to: CloudFiles.placeholderURL(for: vault.syncStateURL(deviceID: "away")))
        XCTAssertThrowsError(try vault.loadSyncState(deviceID: "away")) { error in
            XCTAssertEqual(error as? SyncStateError, .notDownloaded("sync-state-away.json"))
        }
        XCTAssertEqual(vault.otherSyncStateFiles(currentDeviceID: "broken").map(\.deviceName), ["away"])
    }

    func testFirstSyncOfADeviceTakesOverTheReminderTickAndTitle() async throws {
        try makeProject("Trip", tasks: ["Book flights", "Book hotel"])
        try await engine.run()
        let reminders = try await store.reminders(inList: "Trip")
        store.simulateUserEdit(identifier: reminders[0].identifier) { $0.isCompleted = true; $0.completedAt = Date() }
        store.simulateUserEdit(identifier: reminders[1].identifier) { $0.title = "Book a hotel by the sea" }

        let fresh = SyncEngine(vault: vault, store: store, deviceID: "new-device")
        let report = try await fresh.run()
        XCTAssertEqual(report.conflicts, [])
        XCTAssertEqual(report.remindersUpdated, 0)
        let tasks = try project("Trip").tasks
        XCTAssertEqual(tasks.filter(\.isDone).count, 1)
        XCTAssertTrue(tasks.contains { $0.title == "Book a hotel by the sea" })
        XCTAssertEqual(vault.otherSyncStateFiles(currentDeviceID: "new-device").map(\.deviceName), ["test-device"])
    }

    // MARK: hardening-12

    func testDeletedNoteDropsItsLinksAndDeletesItsOpenReminders() async throws {
        let note = try makeProject("Trip", tasks: ["One", "Two"])
        try await engine.run()
        let synced = try project("Trip")
        let open = try await engine.openLinkedReminders(of: synced).count
        XCTAssertEqual(open, 2)
        try vault.trash(synced)
        let deleted = try await engine.releaseReminders(of: synced, .delete)
        XCTAssertEqual(deleted, 2)
        XCTAssertEqual(store.records.count, 0)
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device").links.count, 0)
        let report = try await engine.run()
        XCTAssertEqual(report.warnings, [])
        _ = note
    }

    func testDeletedNoteKeepsItsRemindersWithoutWarningsAndLinksAgainWhenPutBack() async throws {
        try makeProject("Trip", tasks: ["One", "Two"])
        try await engine.run()
        let synced = try project("Trip")
        try vault.trash(synced)

        // Even when the app never asked: a note in Deleted warns about nothing and loses no reminder.
        let untold = try await engine.run()
        XCTAssertEqual(untold.warnings, [])
        XCTAssertEqual(untold.remindersDeleted, 0)

        try await engine.releaseReminders(of: synced, .keep)
        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device").links.count, 0)

        try vault.restore(XCTUnwrap(vault.deletedNotes().first))
        let back = try await engine.run()
        XCTAssertEqual(back.remindersCreated, 0, "put back: linked again through the mark")
        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device").links.count, 2)
    }
}
