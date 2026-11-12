import XCTest
@testable import ParagonCore

/// Review round 2: a re-read opens only the notes whose date changed (hardening-17), and a
/// version iCloud parked is kept beside its note (hardening-09).
final class VaultRereadTests: XCTestCase {
    func testARereadOpensOnlyTheNotesWhoseDateChanged() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let a = try vault.createNote(kind: .project, title: "Alpha")
        _ = try vault.createNote(kind: .project, title: "Beta")
        let first = try vault.allNotes()
        XCTAssertEqual(Set(vault.notesReadAfresh), Set(first.map(\.relativePath)), "nothing held: everything is read")

        // Changed outside the app, with a date of its own.
        let url = vault.url(for: a.relativePath)
        try "---\ntitle: Alpha\n---\nnew words\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: url.path)
        _ = try vault.createNote(kind: .area, title: "Gamma")

        let second = try vault.allNotes(reusing: first)
        XCTAssertEqual(Set(vault.notesReadAfresh), ["Projects/Alpha.md", "Areas/Gamma.md"])
        XCTAssertEqual(second, try vault.allNotes(), "the same list as a read of every file")
        XCTAssertTrue(second.first { $0.relativePath == a.relativePath }?.body.contains("new words") == true)

        // An older date is a change too: a backup put back over the note.
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: url.path)
        _ = try vault.allNotes(reusing: second)
        XCTAssertEqual(vault.notesReadAfresh, ["Projects/Alpha.md"])

        // A note that is gone is gone, held or not.
        try FileManager.default.removeItem(at: url)
        XCTAssertFalse(try vault.allNotes(reusing: second).contains { $0.relativePath == a.relativePath })
    }

    func testAParkedVersionIsKeptBesideItsNoteAndNeverWrittenOverAnother() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let note = try vault.createNote(kind: .project, title: "Trip")
        let when = Date(timeIntervalSince1970: 1_794_000_000)
        let phone = note.text + "typed on the phone\n"
        let pad = note.text + "typed on the iPad\n"

        let copies = try vault.keepParkedCopies(of: note.relativePath, versions: [
            ParkedVersion(text: note.text, modifiedAt: when),   // says what the note says: no copy
            ParkedVersion(text: phone, modifiedAt: when),
            ParkedVersion(text: phone, modifiedAt: when),       // twice the same: one copy
            ParkedVersion(text: pad, modifiedAt: when),         // same minute, other words: " 2"
        ])
        let first = Vault.conflictCopyPath(for: note.relativePath, at: when)
        let second = Vault.conflictCopyPath(for: note.relativePath, at: when, number: 2)
        XCTAssertEqual(copies.map(\.relativePath), [first, second])
        XCTAssertTrue(first.hasPrefix("Projects/Trip (conflict "))
        XCTAssertEqual(try vault.loadNote(relativePath: first).text, phone)
        XCTAssertEqual(try vault.loadNote(relativePath: second).text, pad)
        XCTAssertEqual(try vault.loadNote(relativePath: note.relativePath).text, note.text, "the note itself is untouched")

        // A second try after one that was cut short writes nothing new.
        let again = try vault.keepParkedCopies(of: note.relativePath, versions: [ParkedVersion(text: phone, modifiedAt: when)])
        XCTAssertEqual(again.map(\.relativePath), [first])
        XCTAssertEqual(try vault.notes(kind: .project).count, 3)

        var found = ParkedVersionsFound()
        XCTAssertNil(found.message)
        found.kept = [.init(note: note.relativePath, noteTitle: "Trip", copy: first, copyTitle: "Trip (conflict 2026-11-06 2040)")]
        XCTAssertEqual(found.message, "\"Trip\" was changed on two devices at the same time. The other version is saved as \"Trip (conflict 2026-11-06 2040)\" next to it.")
        // No file with parked versions here: asking is harmless and finds nothing.
        XCTAssertEqual(vault.settleParkedVersions(of: [note.relativePath, "Projects/Nothing.md"]), ParkedVersionsFound())
    }

    func testTimingOfARereadOfFiveThousandNotes() throws {
        guard ProcessInfo.processInfo.environment["PARAGON_TIMING"] != nil else { throw XCTSkip("timing only on request") }
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let body = String(repeating: "- [ ] a task with some words in it #tag\nSome text for the note, a line of ordinary length.\n", count: 12)
        for i in 0..<5000 {
            let kind = ["Projects", "Areas", "Resources", "Archive"][i % 4]
            try "---\ntitle: Note \(i)\ntype: note\ntags: [a, b]\n---\n# Note \(i)\n\(body)".write(
                to: vault.rootURL.appendingPathComponent("\(kind)/Note \(i).md"), atomically: true, encoding: .utf8)
        }
        func time(_ what: String, _ work: () throws -> Void) rethrows {
            let start = Date()
            try work()
            print("TIMING \(what): \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        }
        var all: [Note] = []
        try time("read every note") { all = try vault.allNotes() }
        try time("re-read, nothing changed") { _ = try vault.allNotes(reusing: all) }
        time("ask iCloud about 5000 notes") { _ = vault.settleParkedVersions(of: all.map(\.relativePath)) }
    }
}
