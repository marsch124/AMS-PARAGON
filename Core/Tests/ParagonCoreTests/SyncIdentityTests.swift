import XCTest
@testable import ParagonCore

/// Data-safety rules of the Reminders sync, round 2 (premium review, hardening 10 and 14).
final class SyncIdentityTests: XCTestCase {
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
    private func makeProject(_ title: String, body: String) throws -> Note {
        var note = try vault.createNote(kind: .project, title: title)
        note.body = body
        return try vault.save(note)
    }

    // MARK: hardening-10

    func testTwoRemindersWithOneMarkBecomeOneAndATickIsKept() async throws {
        try makeProject("Shop", body: "- [ ] Buy milk\n")
        try await engine.run()
        let made = try await store.reminders(inList: "Shop")
        let first = try XCTUnwrap(made.first)
        // Another device made its own reminder for the same task, and it was ticked there.
        _ = try await store.create(ReminderRecord(listName: "Shop", title: "Buy milk", isCompleted: true,
                                                  completedAt: Date(), notes: first.notes))

        let report = try await engine.run()
        XCTAssertEqual(report.remindersDeleted, 1)
        let left = try await store.reminders(inList: "Shop")
        XCTAssertEqual(left.map(\.identifier), [first.identifier], "the older one stays")
        XCTAssertEqual(left.first?.isCompleted, true)
        XCTAssertEqual(try vault.loadNote(relativePath: "Projects/Shop.md").tasks.first?.isDone, true)

        let again = try await engine.run()
        XCTAssertEqual(again.changeCount, 0)
    }

    func testATaskFromAnotherDeviceWaitsOneRoundForItsReminder() async throws {
        try makeProject("Shop", body: "- [ ] Buy milk ^t0000aa\n- [ ] Buy bread ^t0000bb\n")
        let first = try await engine.run()
        XCTAssertEqual(first.remindersCreated, 0)
        // The other device's reminder for the milk arrives; nothing comes for the bread.
        _ = try await store.create(ReminderRecord(listName: "Shop", title: "Buy milk", notes: SyncEngine.marker(for: "t0000aa")))

        let second = try await engine.run()
        XCTAssertEqual(second.remindersCreated, 1)
        let titles = try await store.reminders(inList: "Shop").map(\.title).sorted()
        XCTAssertEqual(titles, ["Buy bread", "Buy milk"])
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device").waitingForReminder, [])
    }

    // MARK: hardening-14

    func testANewNoteJoinsAListThatWasAlreadyThereOnlyAfterAYes() async throws {
        try await store.simulateUserCreate(list: "Trip", title: "Renew passport")
        try makeProject("Trip", body: "- [ ] Pack\n")
        let textBefore = try vault.loadNote(relativePath: "Projects/Trip.md").text

        guard case .needsConfirmation(let summary) = try await engine.sync() else { return XCTFail("should ask first") }
        XCTAssertEqual(summary.listsToJoin, [.init(noteTitle: "Trip", listName: "Trip", reminderCount: 1)])
        XCTAssertEqual(try vault.loadNote(relativePath: "Projects/Trip.md").text, textBefore)
        XCTAssertEqual(store.records.count, 1)

        let report = try await engine.run(allowMassChanges: true)
        XCTAssertEqual(report.tasksCreated, 1)
        XCTAssertEqual(try vault.loadSyncState(deviceID: "test-device").listIDs["Trip"], store.listIDs["Trip"])
        guard case .finished = try await engine.sync() else { return XCTFail("linked now: no second question") }

        // The list is deleted and somebody makes another with the same name: not ours any more.
        store.simulateUserDeleteList("Trip")
        try await store.simulateUserCreate(list: "Trip", title: "Something else")
        guard case .needsConfirmation(let asked) = try await engine.sync(), !asked.listsToJoin.isEmpty else {
            return XCTFail("same name, another list: should ask")
        }
    }

    func testASyncMemoryFileFromBeforeStillLoads() throws {
        let old = #"{"version":1,"links":{"t1":{"taskID":"t1","reminderID":"r1","notePath":"Inbox.md","listName":"Reminders","lastTaskFingerprint":"a","lastReminderFingerprint":"a","lastSyncedAt":"2026-11-01T10:00:00Z"}}}"#
        let state = try SyncState.decoder.decode(SyncState.self, from: Data(old.utf8))
        XCTAssertEqual(state.links["t1"]?.reminderID, "r1")
        XCTAssertEqual(state.listIDs, [:])
        XCTAssertEqual(state.waitingForReminder, [])
    }
}
