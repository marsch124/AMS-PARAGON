import XCTest
@testable import ParagonCore

/// A file iCloud has not sent to this device yet is a hidden ".Name.md.icloud" stub. These
/// tests are about not mistaking that for "the file is not there".
final class CloudFilesTests: XCTestCase {
    private var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
        vault = nil
    }

    func testReadsTheNameOutOfAPlaceholder() {
        XCTAssertEqual(CloudFiles.realName(ofPlaceholder: ".Project.md.icloud"), "Project.md")
        XCTAssertNil(CloudFiles.realName(ofPlaceholder: "Project.md"))
        XCTAssertNil(CloudFiles.realName(ofPlaceholder: ".icloud"))
    }

    func testAPlaceholderCountsAsTheFileBeingThere() throws {
        let url = vault.rootURL.appendingPathComponent("Projects/Roof.md")
        XCTAssertFalse(CloudFiles.exists(url))

        try "".write(to: CloudFiles.placeholderURL(for: url), atomically: true, encoding: .utf8)

        XCTAssertTrue(CloudFiles.exists(url))
    }

    func testBootstrapLeavesATemplateThatIsStillOnItsWay() throws {
        let snippets = vault.templatesURL.appendingPathComponent("\(Snippets.fileName).md")
        try FileManager.default.removeItem(at: snippets)
        try "".write(to: CloudFiles.placeholderURL(for: snippets), atomically: true, encoding: .utf8)

        try vault.bootstrap()

        XCTAssertFalse(FileManager.default.fileExists(atPath: snippets.path),
                       "A default was written over a template iCloud was still sending")
    }

    func testANoteThatIsStillOnItsWayIsNotOverwrittenByANewOne() throws {
        let path = "Projects/Roof.md"
        try "".write(to: CloudFiles.placeholderURL(for: vault.url(for: path)), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try vault.createNote(kind: .project, title: "Roof")) { error in
            XCTAssertEqual(error as? VaultError, .noteAlreadyExists(path))
        }
    }

    func testLoadingAPlaceholderSaysItIsComing() throws {
        let path = "Projects/Roof.md"
        try "".write(to: CloudFiles.placeholderURL(for: vault.url(for: path)), atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try vault.loadNote(relativePath: path)) { error in
            XCTAssertEqual(error as? VaultError, .notDownloadedYet(path))
        }
    }

    func testTheDownloadPassFindsPlaceholdersAndIgnoresOrdinaryFiles() throws {
        _ = try vault.createNote(kind: .area, title: "Health")
        let waiting = vault.url(for: "Projects/Roof.md")
        try "".write(to: CloudFiles.placeholderURL(for: waiting), atomically: true, encoding: .utf8)

        XCTAssertEqual(vault.downloadCloudFiles(), ["Projects/Roof.md"])
    }
}

extension CloudFilesTests {
    /// The empty-vault incident: iCloud had every note as a hidden ".Note.md.icloud" stub, the
    /// note listing skipped hidden files, and the app saw a vault with nothing in it — not even
    /// something to report as unreadable.
    func testNotesStillInTheCloudAreCountedRatherThanUnseen() throws {
        let real = try vault.createNote(kind: .project, title: "Roof")
        let waiting = vault.url(for: "Projects/Ridge.md")
        try "".write(to: CloudFiles.placeholderURL(for: waiting), atomically: true, encoding: .utf8)

        let notes = try vault.notes(kind: .project)

        XCTAssertEqual(notes.map(\.relativePath), [real.relativePath], "the readable note was lost")
        XCTAssertEqual(vault.notesWaitingForCloud, ["Projects/Ridge.md"],
                       "a note that is only an iCloud stub was passed over in silence")
    }

    func testAVaultThatIsAllStubsIsNotReportedAsEmpty() throws {
        for name in ["Roof", "Garden", "Kitchen"] {
            let url = vault.url(for: "Projects/\(name).md")
            try "".write(to: CloudFiles.placeholderURL(for: url), atomically: true, encoding: .utf8)
        }

        let notes = try vault.allNotes()

        XCTAssertTrue(notes.filter { $0.kind == .project }.isEmpty)
        XCTAssertEqual(vault.notesWaitingForCloud.count, 3)
        XCTAssertTrue(vault.skippedFiles.isEmpty, "waiting for iCloud is not the same as damaged")
    }
}

/// A clock a test can move: `CloudFiles.fetch` asks the time and the test decides it.
private final class FakeClock {
    var now = Date(timeIntervalSince1970: 0)
}

/// Build 261: nothing on the main thread waits for iCloud. The app's own reads wait for nothing,
/// a note not here is named as still coming, every try at waiting costs one, and the waiting
/// that is left is done by a time-boxed pass on another thread.
extension CloudFilesTests {
    private func makeStub(_ path: String) throws {
        let url = vault.url(for: path)
        try? FileManager.default.removeItem(at: url)
        try "".write(to: CloudFiles.placeholderURL(for: url), atomically: true, encoding: .utf8)
    }

    func testPresenceFollowsTheDownloadStatus() {
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: nil, status: nil), .here)
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: false, status: .notDownloaded), .here)
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: true, status: nil), .here)
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: true, status: .current), .here)
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: true, status: .downloaded), .stale)
        XCTAssertEqual(CloudFiles.presence(isUbiquitous: true, status: .notDownloaded), .away)
    }

    /// Until 261 the Inbox was read before everything else, with no limit, and a failure there
    /// threw out of `allNotes()`: the whole vault was empty and nothing said why.
    func testAnInboxStillInTheCloudDoesNotEmptyTheVault() throws {
        let roof = try vault.createNote(kind: .project, title: "Roof")
        try makeStub(vault.config.inboxFile)

        let notes = try vault.allNotes()

        XCTAssertEqual(notes.map(\.relativePath), [roof.relativePath])
        XCTAssertEqual(vault.notesWaitingForCloud, [vault.config.inboxFile])
        XCTAssertTrue(vault.skippedFiles.isEmpty)
    }

    func testAnUnreadableInboxIsSkippedNotFatal() throws {
        let roof = try vault.createNote(kind: .project, title: "Roof")
        let inbox = vault.url(for: vault.config.inboxFile)
        try FileManager.default.removeItem(at: inbox)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let notes = try vault.allNotes()

        XCTAssertEqual(notes.map(\.relativePath), [roof.relativePath])
        XCTAssertEqual(vault.skippedFiles, [vault.config.inboxFile])
        XCTAssertTrue(vault.notesWaitingForCloud.isEmpty)
    }

    /// Until 261 only a read that succeeded used up the budget, so a stub iCloud could not
    /// deliver cost a full wait and left the budget as it was.
    func testEveryTryAtWaitingCostsOneEvenWhenNothingComes() throws {
        try makeStub(vault.config.inboxFile)
        for name in ["Roof", "Garden", "Kitchen", "Shed"] {
            try makeStub("Projects/\(name).md")
        }

        let notes = try vault.allNotes(cloudFetches: 2)

        XCTAssertTrue(notes.isEmpty)
        XCTAssertEqual(vault.cloudFetchesLeftAfterLastLoad, 0)
        XCTAssertEqual(vault.notesWaitingForCloud.count, 5)
        XCTAssertEqual(vault.notesWaitingForCloud.first, vault.config.inboxFile)
        XCTAssertTrue(vault.skippedFiles.isEmpty)
    }

    /// A stub left beside its real file is not a note on its way: the real one is listed, and
    /// nothing is named as waiting (a restore can copy such a stub in).
    func testAStubBesideItsRealFileIsNotWaitingForEver() throws {
        let roof = try vault.createNote(kind: .project, title: "Roof")
        try "".write(to: CloudFiles.placeholderURL(for: vault.url(for: roof.relativePath)),
                     atomically: true, encoding: .utf8)

        let notes = try vault.allNotes()

        XCTAssertEqual(notes.filter { $0.kind == .project }.map(\.relativePath), [roof.relativePath])
        XCTAssertTrue(vault.notesWaitingForCloud.isEmpty)
    }

    func testAPassStopsWhenItsTimeIsSpent() {
        let clock = FakeClock()
        var allowances: [TimeInterval] = []
        let urls = (1...5).map { URL(fileURLWithPath: "/tmp/note\($0).md") }

        let arrived = CloudFiles.fetch(urls, within: 50, now: { clock.now }, waitFor: { _, wait in
            allowances.append(wait)
            clock.now = clock.now.addingTimeInterval(wait)
            return false
        })

        XCTAssertTrue(arrived.isEmpty)
        XCTAssertEqual(allowances, [20, 20, 10])
    }

    func testAFileThatNeverComesCostsOnlyItsShare() {
        let clock = FakeClock()
        let stuck = URL(fileURLWithPath: "/tmp/stuck.md")
        let roof = URL(fileURLWithPath: "/tmp/roof.md")
        let shed = URL(fileURLWithPath: "/tmp/shed.md")

        let arrived = CloudFiles.fetch([stuck, roof, shed], within: 60, now: { clock.now }, waitFor: { url, wait in
            if url == stuck {
                clock.now = clock.now.addingTimeInterval(wait)
                return false
            }
            clock.now = clock.now.addingTimeInterval(1)
            return true
        })

        XCTAssertEqual(arrived, [roof, shed])
    }

    func testAPassWithNothingToFetchTriesNothing() {
        var tries = 0
        let arrived = CloudFiles.fetch([], within: 60, waitFor: { _, _ in
            tries += 1
            return true
        })
        XCTAssertTrue(arrived.isEmpty)
        XCTAssertEqual(tries, 0)
    }

    func testAReadThatMayNotWaitThrowsAtOnce() {
        let missing = vault.url(for: "Projects/Nowhere.md")
        XCTAssertThrowsError(try CloudFiles.read(missing, waitingUpTo: 0))
    }

    /// Until 261 a capture checked `fileExists`, so an Inbox that was only a stub got a fresh
    /// Inbox written beside it, and iCloud then had two.
    func testACaptureNeverWritesOverAnInboxStillInTheCloud() throws {
        try makeStub(vault.config.inboxFile)
        let inbox = vault.url(for: vault.config.inboxFile)

        XCTAssertThrowsError(try vault.capture(CaptureItem(text: "Call the bank"))) { error in
            XCTAssertEqual(error as? VaultError, .notDownloadedYet(self.vault.config.inboxFile))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: inbox.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: CloudFiles.placeholderURL(for: inbox).path))
    }

    /// A capture aimed at a note still in iCloud goes into that note or nowhere: it is kept for
    /// a later try, never filed in the Inbox instead.
    func testACaptureAimedAtANoteStillInTheCloudIsNotMisfiled() throws {
        try makeStub("Projects/Roof.md")
        let before = try vault.loadNote(relativePath: vault.config.inboxFile).text

        XCTAssertThrowsError(try vault.capture(CaptureItem(text: "Order tiles", target: .note(path: "Projects/Roof.md")))) { error in
            XCTAssertEqual(error as? VaultError, .notDownloadedYet("Projects/Roof.md"))
        }
        XCTAssertEqual(try vault.loadNote(relativePath: vault.config.inboxFile).text, before)
    }
}
