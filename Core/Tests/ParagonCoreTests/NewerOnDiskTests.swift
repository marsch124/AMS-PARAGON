import XCTest
@testable import ParagonCore

/// Build 330 (the advisors' data-safety finding): renaming, archiving and deleting never remove
/// a file that is newer than the copy in hand, and a note in Deleted without a readable date is
/// not cleared out at once.
final class NewerOnDiskTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws { vault = try makeTemporaryVault() }
    override func tearDown() { removeVault(vault); vault = nil }

    /// Writes other words into the note's file and dates the file 10 seconds later, as an edit
    /// from another device does.
    private func arriveFromElsewhere(_ note: Note, words: String) throws {
        let url = vault.url(for: note.relativePath)
        try (note.text + "\n" + words + "\n").write(to: url, atomically: true, encoding: .utf8)
        let later = (note.modifiedAt ?? Date()).addingTimeInterval(10)
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: url.path)
    }

    private func words(at path: String) -> String {
        (try? String(contentsOf: vault.url(for: path), encoding: .utf8)) ?? ""
    }

    func testArchiveDeleteAndRenameStopWhenTheFileIsNewer() throws {
        for action in ["archive", "delete", "rename"] {
            let note = try vault.createNote(kind: .project, title: "Trip \(action)")
            try arriveFromElsewhere(note, words: "written on the iPhone")
            XCTAssertThrowsError(try {
                switch action {
                case "archive": _ = try self.vault.archive(note)
                case "delete": try self.vault.trash(note)
                default: _ = try self.vault.rename(note, to: "Trip renamed")
                }
            }(), action) { error in
                guard case VaultError.modifiedOnDisk = error else { return XCTFail("\(action): \(error)") }
            }
            XCTAssertTrue(words(at: note.relativePath).contains("written on the iPhone"),
                          "\(action) removed the newer file")
        }
        XCTAssertTrue(vault.deletedNotes().isEmpty)
    }

    func testTheSameThreeStillWorkOnAnUnchangedNote() throws {
        let a = try vault.createNote(kind: .project, title: "A")
        XCTAssertEqual(try vault.archive(a).kind, .archive)
        let b = try vault.createNote(kind: .project, title: "B")
        try vault.trash(b)
        XCTAssertEqual(vault.deletedNotes().count, 1)
        let c = try vault.createNote(kind: .project, title: "C")
        XCTAssertEqual(try vault.rename(c, to: "C2").displayTitle, "C2")
    }

    func testADeletedNoteWithoutAReadableDateKeepsItsThirtyDays() throws {
        let note = try vault.createNote(kind: .resource, title: "Recipe")
        try vault.trash(note)
        let name = try XCTUnwrap(vault.deletedNotes().first?.fileName)
        let url = vault.deletedFolderURL.appendingPathComponent(name)
        let text = try String(contentsOf: url, encoding: .utf8)
        let broken = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("deleted:") }.joined(separator: "\n")
        try broken.write(to: url, atomically: true, encoding: .utf8)

        vault.purgeDeleted(olderThan: 30)
        XCTAssertEqual(vault.deletedNotes().count, 1, "a note without a date was cleared out at once")
    }
}
