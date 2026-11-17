import XCTest
@testable import ParagonCore

/// Build 337: templates, snippets, tags and Work notes are read again only when their files
/// are not the ones read last time.
final class FilesStampTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("stamp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ text: String, to name: String, at date: Date) throws {
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func testTheStampStaysWhileNothingChangesAndMovesWithEveryChange() throws {
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        try write("one", to: "Project.md", at: morning)
        let single = folder.appendingPathComponent("tags.json")
        let first = FilesStamp.of(folders: [folder], files: [single])
        XCTAssertEqual(first, FilesStamp.of(folders: [folder], files: [single]),
                       "Two looks at the same files are two different stamps.")

        // The same words length, a later date: a changed file.
        try write("two", to: "Project.md", at: morning.addingTimeInterval(60))
        let dated = FilesStamp.of(folders: [folder], files: [single])
        XCTAssertNotEqual(first, dated, "A file written again keeps the old stamp.")

        // The same date, other length.
        try write("longer", to: "Project.md", at: morning.addingTimeInterval(60))
        let sized = FilesStamp.of(folders: [folder], files: [single])
        XCTAssertNotEqual(dated, sized, "A file of another size keeps the old stamp.")

        // A new file in the folder, and the single file appearing.
        try write("x", to: "Area.md", at: morning)
        let more = FilesStamp.of(folders: [folder], files: [single])
        XCTAssertNotEqual(sized, more, "A new file keeps the old stamp.")
        try write("[]", to: "tags.json", at: morning)
        XCTAssertNotEqual(more, FilesStamp.of(folders: [folder], files: [single]),
                          "The single file appearing keeps the old stamp.")
    }

    func testAFolderThatIsNotThereIsAStampOfItsOwn() throws {
        let missing = folder.appendingPathComponent("Work")
        let before = FilesStamp.of(folders: [missing])
        XCTAssertEqual(before, FilesStamp.of(folders: [missing]))
        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        try "w".write(to: missing.appendingPathComponent("Note.md"), atomically: true, encoding: .utf8)
        XCTAssertNotEqual(before, FilesStamp.of(folders: [missing]),
                          "The Work folder appearing keeps the old stamp.")
    }
}
