import XCTest
@testable import ParagonCore

/// Build 308: the outside copy (hardening-13), the look at a folder before anything is written
/// (hardening-16), and long or capitals-only titles (hardening-18).
final class FilesRoundTwoTests: XCTestCase {
    var vault: Vault!
    var place: URL!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        place = FileManager.default.temporaryDirectory.appendingPathComponent("ams-para-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
    }

    override func tearDown() {
        removeVault(vault)
        try? FileManager.default.removeItem(at: place)
    }

    // MARK: hardening-13

    func testOutsideCopyHoldsNotesAndPicturesAndSitsOutsideTheVault() throws {
        _ = try vault.createNote(kind: .project, title: "Race")
        try vault.writeFile(Data([1, 2, 3]), at: "Photos/Photo 1.jpg")
        try vault.writeFile(Data([4, 5]), at: "Sketches/Sketch 1.png")
        try vault.writeFile(Data([6]), at: "Sketches/Sketch 1.drawing")

        let copy = try XCTUnwrap(try vault.makeOutsideCopy(in: place, reason: "daily"))
        let folder = Vault.outsideBackupsURL(in: place).appendingPathComponent(copy.folderName)
        XCTAssertFalse(folder.path.hasPrefix(vault.rootURL.path), "outside the vault")
        for path in ["Projects/Race.md", "Photos/Photo 1.jpg", "Sketches/Sketch 1.png", "Sketches/Sketch 1.drawing"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path), path)
        }
        XCTAssertNil(try vault.makeOutsideCopy(in: place, now: Date().addingTimeInterval(60)), "nothing changed")
        // The copies inside the vault stay as they were: notes only.
        let inside = try XCTUnwrap(try vault.makeBackup(reason: "manual"))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: vault.backupsURL.appendingPathComponent(inside.folderName).appendingPathComponent("Photos/Photo 1.jpg").path))
    }

    func testOutsideCopiesAreClearedByTheSameTiersAndNothingElseIsTouched() throws {
        let home = Vault.outsideBackupsURL(in: place)
        let keepsake = home.appendingPathComponent("2020-01-01 0900~mine", isDirectory: true)
        try FileManager.default.createDirectory(at: keepsake, withIntermediateDirectories: true)
        let start = Date()
        let old = start.addingTimeInterval(-200 * 86_400)
        _ = try vault.makeOutsideCopy(in: place, now: old)
        _ = try vault.createNote(kind: .project, title: "Later")
        try vault.writeFile(Data([9, 9]), at: "Pictures/Kept.png")
        _ = try vault.makeOutsideCopy(in: place, now: start.addingTimeInterval(-86_400 * 3))
        // An unchanged picture is carried over from the copy before.
        _ = try vault.createNote(kind: .project, title: "Latest")
        let last = try XCTUnwrap(try vault.makeOutsideCopy(in: place, now: start))
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent(last.folderName).appendingPathComponent("Pictures/Kept.png").path))
        XCTAssertEqual(vault.outsideCopies(in: place).count, 2, "the 200-day-old copy is gone")
        XCTAssertTrue(FileManager.default.fileExists(atPath: keepsake.path), "a folder that is not a finished copy is left alone")
    }

    // MARK: hardening-16

    func testLookingAtAFolderWritesNothing() throws {
        let empty = place.appendingPathComponent("Fresh", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try "x".write(to: empty.appendingPathComponent("Shopping.md"), atomically: true, encoding: .utf8)
        let look = FolderLook.look(at: empty)
        XCTAssertEqual(look.finding(settled: false), .notAVault(notes: 1))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: empty.path), ["Shopping.md"], "nothing was written")

        _ = try vault.createNote(kind: .project, title: "Race")
        _ = try vault.createNote(kind: .area, title: "Health")
        // Inbox + two notes; the templates are not notes.
        XCTAssertEqual(FolderLook.look(at: vault.rootURL).finding(settled: false), .vault(notes: 3))
    }

    func testAnICloudFolderThatLooksEmptyWaitsBeforeItIsCalledEmpty() {
        let look = FolderLook(inCloud: true, isEmpty: true)
        XCTAssertEqual(look.finding(settled: false), .stillListing)
        XCTAssertEqual(look.finding(settled: true), .notAVault(notes: 0))
        XCTAssertEqual(FolderLook(noteCount: 0, isVault: true, inCloud: true).finding(settled: false), .stillListing)
        XCTAssertEqual(FolderLook(noteCount: 5, isVault: true, foldersNotListed: 1).finding(settled: false), .stillListing)
        XCTAssertEqual(FolderLook(isEmpty: true).finding(settled: false), .notAVault(notes: 0), "a plain folder never waits")
    }

    // MARK: hardening-18

    func testAVeryLongTitleGetsAShortFileNameAndKeepsItsWords() throws {
        let long = String(repeating: "Ångström över älven ", count: 18) + "end"   // 363 characters
        let note = try vault.createNote(kind: .project, title: long)
        XCTAssertEqual(note.title, long, "the whole title stays in the note")
        XCTAssertLessThanOrEqual(note.fileName.decomposedStringWithCanonicalMapping.utf8.count, Vault.longestFileNameBytes)
        XCTAssertEqual(try vault.loadNote(relativePath: note.relativePath).title, long)
        XCTAssertEqual(NoteIndex(notes: [note]).note(matching: long)?.relativePath, note.relativePath, "[[links]] go by the title")

        // The same long title again is "already there"; a different one with the same start
        // gets a name of its own.
        XCTAssertThrowsError(try vault.createNote(kind: .project, title: long))
        let other = try vault.createNote(kind: .project, title: long + " two")
        XCTAssertNotEqual(other.relativePath, note.relativePath)
        XCTAssertEqual(other.title, long + " two")

        // And a rename to a long title works the same way.
        let short = try vault.createNote(kind: .project, title: "Short")
        let renamed = try vault.rename(short, to: long + " three")
        XCTAssertEqual(renamed.title, long + " three")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.url(for: renamed.relativePath).path))
        XCTAssertEqual(Vault.sanitizeFileName("Plan: A/B test?"), "Plan A B test", "short names are untouched")
    }

    func testARenameThatOnlyChangesCapitalsGoesThrough() throws {
        var note = try vault.createNote(kind: .project, title: "Trip")
        note.body = "# Trip\n\n- [ ] Pack\n"
        note = try vault.save(note)
        let renamed = try vault.rename(note, to: "TRIP")
        XCTAssertEqual(renamed.relativePath, "Projects/TRIP.md")
        XCTAssertEqual(renamed.title, "TRIP")
        let names = try FileManager.default.contentsOfDirectory(atPath: vault.url(for: "Projects").path)
        XCTAssertEqual(names.filter { $0.lowercased() == "trip.md" }, ["TRIP.md"], "one file, with the new capitals")
        XCTAssertTrue(try vault.loadNote(relativePath: "Projects/TRIP.md").body.contains("- [ ] Pack"))
        // Another note's name is still refused.
        _ = try vault.createNote(kind: .project, title: "Other")
        XCTAssertThrowsError(try vault.rename(renamed, to: "other"))
    }
}
