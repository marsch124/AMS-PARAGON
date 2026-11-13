import XCTest
@testable import ParagonCore

/// Build 315 (review round 8, part A): lists kept apart, restoring the outside copy, and the
/// build number against the newest "What's new" entry.
final class RoundEightATests: XCTestCase {
    /// `Core/Tests/ParagonCoreTests/RoundEightATests.swift` → the repository root.
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: Keep them apart

    func testAListKeptApartIsNeverJoinedAndNeverAskedAbout() async throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let store = InMemoryRemindersStore(lists: ["Reminders"])
        try await store.simulateUserCreate(list: "Trip", title: "Renew passport")
        var note = try vault.createNote(kind: .project, title: "Trip")
        note.body = "- [ ] Pack\n"
        try vault.save(note)
        let textBefore = try vault.loadNote(relativePath: "Projects/Trip.md").text

        guard case .needsConfirmation(let asked) = try await SyncEngine(vault: vault, store: store, deviceID: "d").sync(),
              let join = asked.listsToJoin.first else { return XCTFail("should ask first") }
        XCTAssertEqual(join.listID, store.listIDs["Trip"])

        // His answer: Keep them apart. Kept in the vault's settings, so it survives a restart.
        var config = vault.config
        config.listsKeptApart = ListsKeptApart.adding(id: join.listID, name: join.listName, to: config.listsKeptApart)
        try vault.save(config: config)
        let reopened = try Vault(rootURL: vault.rootURL)
        XCTAssertEqual(reopened.config.listsKeptApart, [KeptApartList(id: join.listID, name: "Trip")])

        guard case .finished(let report) = try await SyncEngine(vault: reopened, store: store, deviceID: "d").sync() else {
            return XCTFail("kept apart: no second question")
        }
        XCTAssertEqual(report.tasksCreated + report.remindersCreated, 0, "nothing copied either way")
        XCTAssertEqual(try reopened.loadNote(relativePath: "Projects/Trip.md").text, textBefore, "the note is untouched")
        XCTAssertEqual(store.records.values.map(\.title), ["Renew passport"], "the list is untouched")

        // The rule itself: by identity; by name only for an identity this device does not have.
        let kept = [KeptApartList(id: "A", name: "Trip")]
        XCTAssertTrue(ListsKeptApart.isKeptApart(name: "Journey", ids: ["A"], deviceListIDs: ["A"], in: kept), "renamed, same list")
        XCTAssertFalse(ListsKeptApart.isKeptApart(name: "Trip", ids: ["B"], deviceListIDs: ["A", "B"], in: kept), "another list took the name")
        XCTAssertTrue(ListsKeptApart.isKeptApart(name: "Trip", ids: ["B"], deviceListIDs: ["B"], in: kept), "remembered on the other device")

        // Connect again: the next sync asks as before.
        config.listsKeptApart = ListsKeptApart.removing(KeptApartList(id: join.listID, name: "Trip"), from: config.listsKeptApart)
        try reopened.save(config: config)
        guard case .needsConfirmation = try await SyncEngine(vault: reopened, store: store, deviceID: "d").sync() else {
            return XCTFail("connected again: should ask")
        }
    }

    // MARK: Restore from the outside copy

    func testRestoringTheOutsideCopyPutsNotesAndPicturesBackAndSavesTheVaultFirst() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("ams-para-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: place) }

        var note = try vault.createNote(kind: .project, title: "Boat")
        note.body = "The first text\n"
        try vault.save(note)
        let picture = vault.rootURL.appendingPathComponent("Projects/boat.png")
        try Data([1, 2, 3]).write(to: picture)
        let start = Date()
        let copy = try XCTUnwrap(try vault.makeOutsideCopy(in: place, now: start))

        // Since the copy: the note changed, the picture was lost, and a new note was made.
        var changed = try vault.loadNote(relativePath: "Projects/Boat.md")
        changed.body = "The later text\n"
        try vault.save(changed)
        try FileManager.default.removeItem(at: picture)
        try vault.createNote(kind: .project, title: "Made later")

        let result = try vault.restoreOutsideCopy(copy, in: place, now: start.addingTimeInterval(120))
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(try vault.loadNote(relativePath: "Projects/Boat.md").body, "The first text\n")
        XCTAssertEqual(try Data(contentsOf: picture), Data([1, 2, 3]), "the picture is back")
        XCTAssertNoThrow(try vault.loadNote(relativePath: "Projects/Made later.md"), "nothing is deleted")

        // What the vault held before the restore is saved twice, and the copy itself is still there.
        let inside = try XCTUnwrap(vault.backups().first { $0.reason == "before restore" })
        let saved = vault.backupsURL.appendingPathComponent(inside.folderName).appendingPathComponent("Projects/Boat.md")
        XCTAssertTrue(try String(contentsOf: saved, encoding: .utf8).contains("The later text"))
        let outside = vault.outsideCopies(in: place)
        XCTAssertEqual(Set(outside.map(\.reason)), ["daily", "before restore"])
        XCTAssertTrue(outside.contains { $0.folderName == copy.folderName })
    }

    // MARK: features-06

    /// The number the app shows and the newest "What's new" entry are one number. A build that
    /// says 314 over a list starting at 315 (or the other way round) fails here.
    func testTheBuildNumberIsTheNewestWhatsNewEntry() throws {
        let model = try String(contentsOf: root.appendingPathComponent("App/Paragon/AppModel.swift"), encoding: .utf8)
        let history = try String(contentsOf: root.appendingPathComponent("Docs/VersionHistory.md"), encoding: .utf8)
        func number(after marker: String, in text: String) -> Int? {
            guard let range = text.range(of: marker) else { return nil }
            return Int(text[range.upperBound...].prefix { $0.isNumber })
        }
        let stamp = try XCTUnwrap(number(after: "static let number = ", in: model), "BuildStamp.number not found in AppModel.swift")
        let newest = try XCTUnwrap(number(after: "\n## Build ", in: history), "no \"## Build N\" heading in Docs/VersionHistory.md")
        XCTAssertEqual(stamp, newest, "BuildStamp.number is \(stamp) but the newest entry in Docs/VersionHistory.md is Build \(newest)")
        XCTAssertTrue(history.contains("1.0 (\(stamp))"), "the first line of Docs/VersionHistory.md should show the version as 1.0 (\(stamp))")
    }
}
