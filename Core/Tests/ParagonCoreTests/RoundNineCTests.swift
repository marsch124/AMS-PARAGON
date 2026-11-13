import XCTest
@testable import ParagonCore

/// Round 9, builder C (build 316): one identity per vault, one sub-folder per vault for the
/// outside copies, and the "No weekly review yet" line.
final class RoundNineCTests: XCTestCase {
    private func makePlace() throws -> URL {
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("ams-para-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        return place
    }

    // MARK: 10 — two identities become the older one

    func testTheOlderIdentityWinsAndTiesGoToTheOneThatSortsFirst() {
        let a = "AAAAAAAA-0000-4000-8000-000000000001", b = "BBBBBBBB-0000-4000-8000-000000000002"
        let early = Date(timeIntervalSince1970: 1_800_000_000), late = early.addingTimeInterval(60)
        XCTAssertEqual(VaultIDs.winner(of: [.init(id: a, created: late), .init(id: b, created: early)]), b)
        XCTAssertEqual(VaultIDs.winner(of: [.init(id: b, created: early), .init(id: a, created: early)]), a, "a tie: sorts first")
        // Noted twice (once by each device): the oldest day counts.
        XCTAssertEqual(VaultIDs.winner(of: [.init(id: a, created: late), .init(id: b, created: late.addingTimeInterval(5)),
                                            .init(id: b, created: early)]), b)
        XCTAssertNil(VaultIDs.winner(of: []))
        // The file name carries the record, also after iCloud renamed it.
        let record = VaultIDRecord(id: a, created: early)
        XCTAssertEqual(VaultIDs.record(fromFileName: VaultIDs.fileName(for: record)), record)
        XCTAssertEqual(VaultIDs.record(fromFileName: VaultIDs.fileName(for: record).replacingOccurrences(of: ".txt", with: " 2.txt")), record)
        XCTAssertNil(VaultIDs.record(fromFileName: "notes.txt"))
    }

    func testBothDevicesAdoptTheOlderIdentityAndCopiesMarkedWithTheOtherStillCount() throws {
        let vault = try makeTemporaryVault()
        let place = try makePlace()
        defer { removeVault(vault); try? FileManager.default.removeItem(at: place) }
        try vault.createNote(kind: .project, title: "Boat")
        let start = Date()
        // This device made its identity and a first copy…
        let first = try XCTUnwrap(try vault.makeOutsideCopy(in: place, now: start.addingTimeInterval(-3600)))
        let mine = try XCTUnwrap(vault.identity()?.id)
        XCTAssertEqual(vault.identityRecords().map(\.id), [mine])
        // …and then iCloud brought the other device's, made a day earlier.
        let theirs = UUID().uuidString
        let older = VaultIDRecord(id: theirs, created: start.addingTimeInterval(-86_400))
        try VaultIDs.fileText.write(to: vault.identityRecordsURL.appendingPathComponent(VaultIDs.fileName(for: older)),
                                    atomically: true, encoding: .utf8)
        XCTAssertEqual(vault.identity()?.id, theirs, "the older one, before anything is written")
        XCTAssertEqual(try String(contentsOf: vault.identityURL, encoding: .utf8), mine, "a look writes nothing")

        try vault.createNote(kind: .project, title: "Later")
        let second = try XCTUnwrap(try vault.makeOutsideCopy(in: place, now: start))
        XCTAssertEqual(try String(contentsOf: vault.identityURL, encoding: .utf8), theirs, "the file now holds the older one")
        XCTAssertEqual(vault.knownIdentities().all, [mine, theirs])
        XCTAssertNotEqual(first.subfolder, second.subfolder)
        // The copy marked with the identity that lost is still offered, and still there.
        let offered = vault.outsideCopiesForRestore(in: place)
        XCTAssertEqual(offered.map(\.id), [second.id, first.id])
        XCTAssertTrue(offered.allSatisfy(\.isMarked))
    }

    func testAnIdentityFromBuild315IsKeptAndNoted() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let old = UUID().uuidString
        try old.write(to: vault.identityURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(vault.identity(creating: true)?.id, old)
        XCTAssertEqual(vault.identityRecords(), [VaultIDRecord(id: old, created: VaultIDs.unrecordedCreated)])
        XCTAssertEqual(try String(contentsOf: vault.identityURL, encoding: .utf8), old, "still one line: build 315 can read it")
    }

    // MARK: 9 — one sub-folder per vault

    func testTwoVaultsInOneFolderNeverThinOutEachOthersCopiesAndOldCopiesStayFindable() throws {
        let mine = try makeTemporaryVault()
        let other = try makeTemporaryVault()
        let place = try makePlace()
        defer { removeVault(mine); removeVault(other); try? FileManager.default.removeItem(at: place) }
        let fm = FileManager.default
        let home = Vault.outsideBackupsURL(in: place)
        try mine.createNote(kind: .project, title: "Mine")
        try other.createNote(kind: .project, title: "Theirs")
        let start = Date()
        let longAgo = start.addingTimeInterval(-200 * 86_400)

        // The other vault's copy from long ago, and mine from long ago.
        let theirs = try XCTUnwrap(try other.makeOutsideCopy(in: place, now: longAgo))
        let myOld = try XCTUnwrap(try mine.makeOutsideCopy(in: place, now: longAgo))
        XCTAssertNotNil(myOld.subfolder)
        XCTAssertNotEqual(theirs.subfolder, myOld.subfolder, "each vault has its own sub-folder")
        XCTAssertTrue(try XCTUnwrap(myOld.subfolder).hasSuffix(try XCTUnwrap(mine.identity()?.id)))
        // Copies in the old place, as builds up to 315 left them: one with my mark (as 315
        // made it), one with no mark (before 315), and one with the other vault's mark.
        func oldPlaceCopy(_ name: String, markedBy vault: Vault?) throws {
            let folder = home.appendingPathComponent(name, isDirectory: true)
            try fm.createDirectory(at: folder.appendingPathComponent("Projects"), withIntermediateDirectories: true)
            try "x".write(to: folder.appendingPathComponent("signature.txt"), atomically: true, encoding: .utf8)
            try "# Old\n".write(to: folder.appendingPathComponent("Projects/Old.md"), atomically: true, encoding: .utf8)
            if let identity = vault?.identity() {
                try JSONEncoder().encode(identity).write(to: folder.appendingPathComponent(Vault.ownerFileName))
            }
        }
        try oldPlaceCopy("2026-01-05 0900~daily", markedBy: mine)
        try oldPlaceCopy("2026-01-06 0900~daily", markedBy: nil)
        try oldPlaceCopy("2026-01-07 0900~daily", markedBy: other)

        // A new copy of mine thins out by the tiers.
        try mine.createNote(kind: .project, title: "Mine too")
        let myNew = try XCTUnwrap(try mine.makeOutsideCopy(in: place, now: start))

        XCTAssertFalse(fm.fileExists(atPath: mine.outsideCopyURL(myOld, in: place).path), "my own 200-day-old copy is cleared out")
        XCTAssertTrue(fm.fileExists(atPath: other.outsideCopyURL(theirs, in: place).path), "the other vault's old copy is not touched")
        XCTAssertTrue(fm.fileExists(atPath: home.appendingPathComponent("2026-01-06 0900~daily").path), "a copy with no mark is never cleared out")
        XCTAssertTrue(fm.fileExists(atPath: home.appendingPathComponent("2026-01-07 0900~daily").path), "the other vault's copy in the old place stays")
        XCTAssertFalse(fm.fileExists(atPath: home.appendingPathComponent("2026-01-05 0900~daily").path), "my marked copy in the old place follows the tiers")

        // Restore reads both places: my new copy, and the unmarked one from the old place.
        let offered = mine.outsideCopiesForRestore(in: place)
        XCTAssertEqual(offered.map(\.id), [myNew.id, "2026-01-06 0900~daily"])
        XCTAssertEqual(offered.map(\.isMarked), [true, false])
        // A copy in the old place can still be put back.
        let result = try mine.restoreOutsideCopy(offered[1].backup, in: place, now: start.addingTimeInterval(120))
        XCTAssertEqual(result.notes, 1)
        XCTAssertNoThrow(try mine.loadNote(relativePath: "Projects/Old.md"))
    }

    // MARK: 16 — a capture key he recorded himself

    func testARecordedKeyNeedsAModifierAndWarnsAboutKeysMacOSOwns() {
        let plain = RecordedKey(keyCode: 40, modifiers: 0, keyName: "K")
        let shifted = RecordedKey(keyCode: 40, modifiers: RecordedKey.shift, keyName: "K")
        let own = RecordedKey(keyCode: 40, modifiers: RecordedKey.option | RecordedKey.command, keyName: "K")
        XCTAssertFalse(plain.isAllowed)
        XCTAssertFalse(shifted.isAllowed, "Shift and a letter is typing")
        XCTAssertTrue(own.isAllowed)
        XCTAssertEqual(own.label, "\u{2325}\u{2318}K")
        XCTAssertNil(own.warningLine)
        let spotlight = RecordedKey(keyCode: 49, modifiers: RecordedKey.command, keyName: "Space")
        XCTAssertTrue(spotlight.isAllowed, "a warning, not a refusal")
        XCTAssertEqual(spotlight.knownUse, "Spotlight on most Macs")
        XCTAssertNotNil(RecordedKey(keyCode: 12, modifiers: RecordedKey.command, keyName: "Q").warningLine)
        // Stored and read back, also when the key is the colon itself.
        XCTAssertEqual(RecordedKey(stored: own.stored), own)
        let colon = RecordedKey(keyCode: 41, modifiers: RecordedKey.control, keyName: ":")
        XCTAssertEqual(RecordedKey(stored: colon.stored), colon)
        XCTAssertNil(RecordedKey(stored: "nonsense"))
        XCTAssertEqual(CaptureHotKey.stored("custom"), .custom)
        XCTAssertNil(CaptureHotKey.custom.keyCode)
        XCTAssertFalse(CaptureHotKey.fixedChoices.contains(.custom))
    }

    // MARK: 8 — the line that stays in Settings

    func testTheRestoreLineNamesNotesAndTheCopysDay() {
        let stamp = "2026-11-13 08:57"
        XCTAssertEqual(RestoreResult(written: 15, failed: [], notes: 15).line(stamp: stamp), "Restored 15 notes from 2026-11-13 08:57")
        XCTAssertEqual(RestoreResult(written: 5, failed: [], notes: 1).line(stamp: stamp), "Restored 1 note and 4 other files from 2026-11-13 08:57")
        XCTAssertEqual(RestoreResult(written: 2, failed: ["a.md"], notes: 2).line(stamp: stamp),
                       "Restored 2 of 3 files from 2026-11-13 08:57. 1 could not be written.")
        XCTAssertTrue(RestoreResult(written: 0, failed: []).line(stamp: stamp).hasPrefix("Nothing was put back"))
    }

    // MARK: 12 — "No weekly review yet"

    func testNoWeeklyReviewYetShowsAWeekAfterFirstUseAndNeverAfterAReview() {
        let today = DateOnly(year: 2026, month: 11, day: 13)
        let first = DateOnly(year: 2026, month: 11, day: 6)
        XCTAssertTrue(WeeklyReviewDone.isNoneYetDue(last: nil, firstUse: first, today: today), "a whole week")
        XCTAssertFalse(WeeklyReviewDone.isNoneYetDue(last: nil, firstUse: DateOnly(year: 2026, month: 11, day: 7), today: today), "six days")
        XCTAssertFalse(WeeklyReviewDone.isNoneYetDue(last: nil, firstUse: nil, today: today), "nothing to count from")
        XCTAssertFalse(WeeklyReviewDone.isNoneYetDue(last: DateOnly(year: 2026, month: 1, day: 1), firstUse: first, today: today),
                       "a review was done: the other line takes over")
        XCTAssertEqual(WeeklyReviewDone.noneYetLine, "No weekly review yet")
    }
}
