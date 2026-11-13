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
        XCTAssertEqual(try JSONDecoder().decode(KeptApartList.self, from: Data(#"{"id":"A","name":"Trip"}"#.utf8)).device, nil)

        guard case .finished(let report) = try await SyncEngine(vault: reopened, store: store, deviceID: "d").sync() else {
            return XCTFail("kept apart: no second question")
        }
        XCTAssertEqual(report.tasksCreated + report.remindersCreated, 0, "nothing copied either way")
        XCTAssertEqual(try reopened.loadNote(relativePath: "Projects/Trip.md").text, textBefore, "the note is untouched")
        XCTAssertEqual(store.records.values.map(\.title), ["Renew passport"], "the list is untouched")

        // The rule itself: by identity; by name only on another device than the one that
        // remembered it, for an identity that device does not have (review round 8).
        let kept = [KeptApartList(id: "A", name: "Trip", device: "mac")]
        func apart(_ name: String, _ ids: [String], _ here: Set<String>, on device: String) -> Bool {
            ListsKeptApart.isKeptApart(name: name, ids: ids, deviceListIDs: here, deviceID: device, in: kept)
        }
        XCTAssertTrue(apart("Journey", ["A"], ["A"], on: "mac"), "renamed, same list")
        XCTAssertFalse(apart("Trip", ["B"], ["A", "B"], on: "mac"), "another list took the name")
        XCTAssertTrue(apart("Trip", ["B"], ["B"], on: "phone"), "remembered on the other device")
        XCTAssertFalse(apart("Trip", ["B"], ["B"], on: "mac"),
                       "its own list was deleted: a later list with the same name is asked about again")
        // And the entry for the deleted list is dropped on the device that made it, only there.
        XCTAssertEqual(ListsKeptApart.droppingDeleted(deviceID: "mac", deviceListIDs: ["B"], from: kept), [])
        XCTAssertEqual(ListsKeptApart.droppingDeleted(deviceID: "mac", deviceListIDs: ["A"], from: kept), kept)
        XCTAssertEqual(ListsKeptApart.droppingDeleted(deviceID: "phone", deviceListIDs: ["B"], from: kept), kept)
        XCTAssertEqual(ListsKeptApart.droppingDeleted(deviceID: "mac", deviceListIDs: [], from: kept), kept,
                       "Reminders could not be read: nothing is dropped")

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

    /// Review round 8: a file of the copy that cannot be read leaves the vault's file as it is
    /// (it used to be taken out first, and was gone when the copy then failed).
    func testAFileThatCannotBeCopiedLeavesTheVaultFileUnchanged() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        var note = try vault.createNote(kind: .project, title: "Boat")
        note.body = "The first text\n"
        try vault.save(note)
        var other = try vault.createNote(kind: .project, title: "Car")
        other.body = "Car, first\n"
        try vault.save(other)
        let start = Date()
        let backup = try XCTUnwrap(try vault.makeBackup(now: start))

        var changed = try vault.loadNote(relativePath: "Projects/Boat.md")
        changed.body = "The later text\n"
        try vault.save(changed)
        var changedOther = try vault.loadNote(relativePath: "Projects/Car.md")
        changedOther.body = "Car, later\n"
        try vault.save(changedOther)

        // The copy's Boat cannot be read (as a file still in Dropbox, offline).
        let unreadable = vault.backupsURL.appendingPathComponent(backup.folderName).appendingPathComponent("Projects/Boat.md")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadable.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadable.path) }

        let result = try vault.restore(backup, now: start.addingTimeInterval(120))
        XCTAssertEqual(result.failed, ["Projects/Boat.md"])
        XCTAssertEqual(try vault.loadNote(relativePath: "Projects/Boat.md").body, "The later text\n",
                       "the vault file is still there, as it was")
        XCTAssertEqual(try vault.loadNote(relativePath: "Projects/Car.md").body, "Car, first\n", "the rest is restored")
        let left = try FileManager.default.contentsOfDirectory(atPath: vault.rootURL.appendingPathComponent("Projects").path)
        XCTAssertFalse(left.contains { $0.hasPrefix(Vault.restoreTempPrefix) }, "no half-written file is left behind")
    }

    /// Review round 8: only this vault's outside copies are offered for a restore; a copy of
    /// another vault in the same place is not, and one from before build 315 says so.
    func testOnlyThisVaultsOutsideCopiesAreOfferedForRestore() throws {
        let mine = try makeTemporaryVault()
        let other = try makeTemporaryVault()
        defer { removeVault(mine); removeVault(other) }
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("ams-para-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: place) }
        try mine.createNote(kind: .project, title: "Mine")
        try other.createNote(kind: .project, title: "Theirs")
        let start = Date()
        let old = try XCTUnwrap(try mine.makeOutsideCopy(in: place, now: start.addingTimeInterval(-7200)))
        // As a copy made before build 315: no mark.
        try FileManager.default.removeItem(at: mine.outsideCopyURL(old, in: place).appendingPathComponent(Vault.ownerFileName))
        let theirs = try XCTUnwrap(try other.makeOutsideCopy(in: place, now: start.addingTimeInterval(-3600)))
        try mine.createNote(kind: .project, title: "Mine too")
        let own = try XCTUnwrap(try mine.makeOutsideCopy(in: place, now: start))

        XCTAssertNil(try mine.makeOutsideCopy(in: place, now: start.addingTimeInterval(60)), "the identity does not make the vault look changed")
        let offered = mine.outsideCopiesForRestore(in: place)
        XCTAssertEqual(offered.map(\.id), [own.id, old.id], "newest first, the other vault's left out")
        XCTAssertFalse(offered.contains { $0.backup.folderName == theirs.folderName })
        XCTAssertTrue(offered[0].isMarked)
        XCTAssertEqual(offered[1].unmarkedFolders?.contains("Projects"), true, "an unmarked copy shows its top folders")
        XCTAssertEqual(mine.identity()?.name, mine.rootURL.lastPathComponent)

        // The mark never lands in the vault.
        _ = try mine.restoreOutsideCopy(own, in: place, now: start.addingTimeInterval(120))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mine.rootURL.appendingPathComponent(Vault.ownerFileName).path))
    }

    /// Review round 8: the settings are read again when the other device changed them.
    func testSettingsChangedOnTheOtherDeviceAreReadAgain() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        try vault.save(config: vault.config)
        let otherDevice = try Vault(rootURL: vault.rootURL)
        var theirs = otherDevice.config
        theirs.listsKeptApart = [KeptApartList(id: "A", name: "Trip", device: "phone")]
        try otherDevice.save(config: theirs)
        XCTAssertTrue(vault.config.listsKeptApart.isEmpty)
        XCTAssertEqual(vault.configOnDisk()?.listsKeptApart, theirs.listsKeptApart)
        XCTAssertTrue(vault.reloadConfigIfChanged())
        XCTAssertEqual(vault.config.listsKeptApart, theirs.listsKeptApart)
        XCTAssertFalse(vault.reloadConfigIfChanged())
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
