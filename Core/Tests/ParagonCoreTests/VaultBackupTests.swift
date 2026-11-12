import XCTest
@testable import ParagonCore

final class VaultBackupTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    func testBackupCopiesNotesAndSkipsItself() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "- [ ] Book the hotel\n"
        try vault.save(note)

        let backup = try XCTUnwrap(try vault.makeBackup(reason: "manual"))
        XCTAssertEqual(backup.reason, "manual")
        XCTAssertTrue(backup.noteCount >= 2, "the project and the inbox")
        let copied = vault.backupsURL.appendingPathComponent(backup.folderName).appendingPathComponent("Projects/Race.md")
        XCTAssertTrue(try String(contentsOf: copied, encoding: .utf8).contains("Book the hotel"))
        // The backup folder itself is never copied into the next backup.
        let second = try vault.makeBackup(reason: "manual", now: Date().addingTimeInterval(60))
        XCTAssertNil(second, "nothing changed, so no second copy")
        XCTAssertEqual(vault.backups().count, 1)
    }

    func testBackupIsMadeAgainOnceSomethingChanged() throws {
        _ = try vault.makeBackup(reason: "daily")
        var note = try vault.createNote(kind: .project, title: "New")
        note.body = "changed"
        try vault.save(note)
        let second = try vault.makeBackup(reason: "sync", now: Date().addingTimeInterval(120))
        XCTAssertNotNil(second)
        XCTAssertEqual(vault.backups().count, 2)
        XCTAssertEqual(vault.backups().first?.reason, "sync", "newest first")
    }

    /// Build 307 (hardening-06): kept in tiers, not the ten newest of any kind.
    func testBackupsAreKeptInTiers() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func copy(_ hoursAgo: Double, _ reason: String) -> VaultBackup {
            VaultBackup(folderName: "\(hoursAgo)~\(reason)", date: now.addingTimeInterval(-hoursAgo * 3600),
                        noteCount: 1, reason: reason)
        }
        // Twelve before-sync copies in the last 12 hours, one daily copy a day for 90 days.
        let syncs = (0..<12).map { copy(Double($0) * 0.5 + 0.1, "sync") }
        let dailies = (1...90).map { copy(Double($0) * 24, "daily") }
        let removed = Set(VaultBackup.toRemove(from: syncs + dailies, now: now, calendar: calendar).map(\.folderName))
        let kept = (syncs + dailies).filter { !removed.contains($0.folderName) }
        XCTAssertEqual(kept.filter { $0.reason == "sync" }.count, 5, "the 5 newest before-sync copies")
        XCTAssertTrue(kept.contains { $0.folderName == dailies[0].folderName }, "yesterday's daily copy survives a busy day")
        XCTAssertTrue(dailies.prefix(13).allSatisfy { d in kept.contains { $0.folderName == d.folderName } },
                      "one per day for 14 days")
        XCTAssertTrue(kept.contains { $0.date < now.addingTimeInterval(-40 * 86400) }, "weekly copies reach back")
        XCTAssertFalse(kept.contains { $0.date < now.addingTimeInterval(-63 * 86400) }, "nothing older than two months")
    }

    /// Build 307 (hardening-02): restoring the oldest copy of a full list must not delete it first.
    func testRestoringTheOldestBackupKeepsIt() throws {
        var note = try vault.createNote(kind: .project, title: "Oldest")
        note.body = "first version"
        try vault.save(note)
        let start = Date().addingTimeInterval(-30 * 86400)
        let oldest = try XCTUnwrap(try vault.makeBackup(reason: "daily", now: start))
        for i in 1...12 {
            note.body = "version \(i)"
            note.modifiedAt = nil
            try vault.save(note)
            _ = try vault.makeBackup(reason: "sync", now: Date().addingTimeInterval(Double(i) * 60 - 3600))
        }
        let result = try vault.restore(oldest)
        XCTAssertGreaterThan(result.written, 0)
        XCTAssertTrue(try vault.loadNote(relativePath: note.relativePath).body.contains("first version"))
        XCTAssertTrue(vault.backups().contains { $0.folderName == oldest.folderName }, "the restored copy is still there")
    }

    func testRestorePutsTheOldNoteBackAndKeepsNewerOnes() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "first version"
        note = try vault.save(note)
        let backup = try XCTUnwrap(try vault.makeBackup(reason: "manual"))
        let inBackup = vault.backupsURL.appendingPathComponent(backup.folderName).appendingPathComponent("Projects/Race.md")
        XCTAssertTrue(try String(contentsOf: inBackup, encoding: .utf8).contains("first version"), "the backup holds the old text")

        note.body = "second version"
        note.modifiedAt = nil
        try vault.save(note)
        XCTAssertTrue(try vault.loadNote(relativePath: "Projects/Race.md").body.contains("second version"))
        let later = try vault.createNote(kind: .project, title: "Later")

        let result = try vault.restore(backup, now: Date().addingTimeInterval(300))
        XCTAssertTrue(result.written > 0)
        XCTAssertTrue(result.isComplete)
        XCTAssertTrue(try vault.loadNote(relativePath: "Projects/Race.md").body.contains("first version"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.url(for: later.relativePath).path),
                      "a note made after the backup is left alone")
        XCTAssertTrue(vault.backups().contains { $0.reason == "before restore" })
    }

    func testCopyContentsGivesAWorkingVaultCopy() throws {
        var note = try vault.createNote(kind: .project, title: "Race")
        note.body = "- [ ] Book the hotel\n"
        try vault.save(note)
        _ = try vault.makeBackup(reason: "manual")

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("copy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: destination) }
        try vault.copyContents(to: destination)
        let copy = try Vault(rootURL: destination)
        XCTAssertEqual(try copy.allNotes().count, try vault.allNotes().count)
        XCTAssertTrue(copy.backups().isEmpty, "backups are not copied along")
    }
}
