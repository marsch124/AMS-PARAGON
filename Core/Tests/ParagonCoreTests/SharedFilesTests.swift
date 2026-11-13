import XCTest
@testable import ParagonCore

/// Build 318: pictures and PDFs shared into PARAGON.
final class SharedFilesTests: XCTestCase {
    var vault: Vault!
    var staging: URL!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
        staging = FileManager.default.temporaryDirectory.appendingPathComponent("paragon-staging-\(UUID().uuidString)")
    }

    override func tearDown() {
        removeVault(vault)
        try? FileManager.default.removeItem(at: staging)
    }

    private func source(_ name: String, _ words: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + name)
        try Data(words.utf8).write(to: url)
        return url
    }

    /// Naming: safe inside a path and a markdown link, never a name that is taken.
    func testNames() {
        let date = Date(timeIntervalSince1970: 0)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(SharedFiles.safeName("/tmp/x/Scan (1) [final]: #2.PDF"), "Scan 1 final 2.pdf")
        XCTAssertEqual(SharedFiles.safeName("../../IMG_0412.HEIC"), "IMG_0412.heic")
        XCTAssertEqual(SharedFiles.safeName("5F0C9C2E-8D0B-4B5E-9D3A-1F2E3D4C5B6A.png", at: date, calendar: utc),
                       "Shared 1970-01-01 000000.png")
        XCTAssertEqual(SharedFiles.safeName("...", at: date, calendar: utc), "Shared 1970-01-01 000000")
        XCTAssertEqual(SharedFiles.freeName(for: "a.png", taken: []), "a.png")
        XCTAssertEqual(SharedFiles.freeName(for: "a.png", taken: ["A.PNG", "a 2.png"]), "a 3.png")
        // A file iCloud has not sent yet still holds its name.
        XCTAssertEqual(SharedFiles.takenNames(in: [".a.png.icloud", "b.pdf"]), ["a.png", "b.pdf"])
        XCTAssertEqual(SharedFiles.folder(for: "a.pdf"), "Attachments")
        XCTAssertEqual(SharedFiles.folder(for: "a.jpeg"), "Pictures")
        XCTAssertFalse(SharedFiles.accepts("a.zip"))
    }

    /// The line in the note: standard markdown, the path as seen from the note.
    func testLinkLines() {
        XCTAssertEqual(SharedFiles.link(toFile: "My scan.pdf", fromNote: "Inbox.md"),
                       "[My scan.pdf](Attachments/My%20scan.pdf)")
        XCTAssertEqual(SharedFiles.link(toFile: "a.png", fromNote: "Projects/Shed.md", words: "The [roof]"),
                       "![The roof](../Pictures/a.png)")
        let both = CaptureItem(text: "Receipt", files: ["x"])
        XCTAssertEqual(both.fileLines(placed: ["a.png", "b.pdf"], notePath: "Inbox.md"),
                       ["- ![Receipt](Pictures/a.png)", "- [b.pdf](Attachments/b.pdf)"])
        let withLink = CaptureItem(text: "Read", url: URL(string: "https://example.com/a")!, files: ["x"])
        XCTAssertEqual(withLink.fileLines(placed: ["b.pdf"], notePath: "Inbox.md"),
                       ["- Read [example.com](https://example.com/a)", "- [b.pdf](Attachments/b.pdf)"])
        // Read back: the Inbox row and the Read look find the file again.
        XCTAssertEqual(SharedFiles.attachment(inLine: "- ![Receipt](Pictures/a.png)", notePath: "Inbox.md"),
                       SharedFiles.Attachment(path: "Pictures/a.png", label: "Receipt", isPicture: true))
        XCTAssertEqual(SharedFiles.attachment(inLine: "[b.pdf](../Attachments/b.pdf)", notePath: "Areas/Home.md")?.path,
                       "Attachments/b.pdf")
        XCTAssertNil(SharedFiles.attachment(inLine: "- see [b.pdf](Attachments/b.pdf) today", notePath: "Inbox.md"))
        XCTAssertEqual(SharedFiles.pdfMatches(in: "x [b](Attachments/b.pdf) ![p](Pictures/a.png)", notePath: "Inbox.md").map(\.path),
                       ["Attachments/b.pdf"])
        XCTAssertEqual(SharedFiles.pagesWords(3), "PDF · 3 pages")
    }

    /// The outbox item: files ride along, and a line an older build wrote still reads.
    func testOutboxItem() throws {
        let outbox = CaptureOutbox(fileURL: staging.appendingPathComponent("capture-outbox.jsonl"))
        XCTAssertEqual(outbox.filesURL.lastPathComponent, "capture-files")
        let id = UUID()
        let staged = try SharedFiles.stage(try source("Bill (May).pdf", "pdf"), named: "Bill (May).pdf",
                                           itemID: id, index: 0, root: outbox.filesURL)
        XCTAssertEqual(staged, "\(id.uuidString)/0/Bill May.pdf")
        try outbox.append(CaptureItem(id: id, text: "Pay", asTask: false, files: [staged]))
        XCTAssertEqual(outbox.peek().first?.files, [staged])
        let old = #"{"id":"\#(UUID().uuidString)","text":"Old","target":{"inbox":{}},"asTask":true,"createdAt":"2026-11-01T10:00:00Z"}"#
        try Data((old + "\n").utf8).write(to: outbox.fileURL)
        XCTAssertEqual(outbox.peek().map(\.text), ["Old"])
        XCTAssertNil(outbox.peek().first?.files)
        XCTAssertNil(SharedFiles.stagedURL("../x.pdf", root: staging))
    }

    /// Filing: copied into the vault, never over a file that is there, linked under Notes,
    /// and the waiting copy removed only then.
    func testFilingNeverOverwrites() throws {
        try vault.writeFile(Data("old".utf8), at: "Pictures/a.png")
        let id = UUID()
        let files = [
            try SharedFiles.stage(try source("a.png", "new"), named: "a.png", itemID: id, index: 0, root: staging),
            try SharedFiles.stage(try source("Bill.pdf", "pdf"), named: "Bill.pdf", itemID: id, index: 1, root: staging),
            "\(id.uuidString)/2/gone.png",
        ]
        let note = try vault.capture(CaptureItem(id: id, text: "Receipt", asTask: false, files: files), filesRoot: staging)
        XCTAssertEqual(note.relativePath, "Inbox.md")
        XCTAssertEqual(vault.fileData(at: "Pictures/a.png"), Data("old".utf8))
        XCTAssertEqual(vault.fileData(at: "Pictures/a 2.png"), Data("new".utf8))
        XCTAssertEqual(vault.fileData(at: "Attachments/Bill.pdf"), Data("pdf".utf8))
        XCTAssertEqual(InboxNotes.lines(in: note.text).map(\.text),
                       ["![Receipt](Pictures/a%202.png)", "[Bill.pdf](Attachments/Bill.pdf)"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appendingPathComponent(id.uuidString).path))
        // A note still on its way from iCloud: nothing is copied, the files keep waiting.
        let later = UUID()
        let waiting = try SharedFiles.stage(try source("b.png", "b"), named: "b.png", itemID: later, index: 0, root: staging)
        SharedFiles.sweep(root: staging, keeping: [], now: Date().addingTimeInterval(60))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staging.appendingPathComponent(waiting).path))
        SharedFiles.sweep(root: staging, keeping: [later], now: Date().addingTimeInterval(3 * 86_400))
        XCTAssertTrue(FileManager.default.fileExists(atPath: staging.appendingPathComponent(waiting).path))
        SharedFiles.sweep(root: staging, keeping: [], now: Date().addingTimeInterval(3 * 86_400))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.appendingPathComponent(waiting).path))
    }

    /// Build 318 (review): draining one item at a time. A line a stopped run had taken is
    /// picked up again, a line that cannot be filed goes back, and an item whose waiting
    /// folder is gone was filed already and writes nothing a second time.
    func testDrainLosesNothingAndFilesNothingTwice() throws {
        let outbox = CaptureOutbox(fileURL: staging.appendingPathComponent("capture-outbox.jsonl"))
        // A run that was stopped half-way left its taken lines behind.
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let left = CaptureItem(text: "Left behind", asTask: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var line = try encoder.encode(left)
        line.append(0x0A)
        try line.write(to: staging.appendingPathComponent("capture-outbox.\(UUID().uuidString).jsonl"))
        try outbox.append(CaptureItem(text: "Not yet", asTask: false))
        let id = UUID()
        let staged = try SharedFiles.stage(try source("a.png", "new"), named: "a.png", itemID: id, index: 0, root: outbox.filesURL)
        let shared = CaptureItem(id: id, text: "Receipt", asTask: false, files: [staged])
        try outbox.append(shared)
        let result = outbox.drain { item in
            if item.text == "Not yet" { throw VaultError.notDownloadedYet("Inbox.md") }
            try self.vault.capture(item, filesRoot: outbox.filesURL)
        }
        XCTAssertEqual(result.filed, 2)
        XCTAssertEqual(outbox.peek().map(\.text), ["Not yet"])
        let names = try FileManager.default.contentsOfDirectory(atPath: staging.path)
        XCTAssertEqual(names.filter { CaptureOutbox.isTakenFile($0) }, [])
        // The same share once more (the app was stopped before it struck the line).
        try outbox.append(shared)
        outbox.drain { item in
            if item.text == "Not yet" { throw VaultError.notDownloadedYet("Inbox.md") }
            try self.vault.capture(item, filesRoot: outbox.filesURL)
        }
        let text = try vault.inboxNote().text
        XCTAssertEqual(text.components(separatedBy: "Receipt").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "Left behind").count - 1, 1)
        XCTAssertNil(vault.fileData(at: "Pictures/a 2.png"))
    }
}
