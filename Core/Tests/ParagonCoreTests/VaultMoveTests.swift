import XCTest
@testable import ParagonCore

/// Build 319: moving the vault into PARAGON's own folder. Every rule, on temporary folders.
final class VaultMoveTests: XCTestCase {
    private let fm = FileManager.default
    private var folders: [URL] = []

    override func tearDown() {
        folders.forEach { try? fm.removeItem(at: $0) }
        folders = []
    }

    private func emptyFolder() throws -> URL {
        let url = fm.temporaryDirectory.appendingPathComponent("paragon-move-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        folders.append(url)
        return url
    }

    private func write(_ text: String, _ path: String, in root: URL) throws {
        let url = root.appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private func text(_ path: String, in root: URL) -> String? {
        try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// A vault with notes, a Swedish name, a picture, and the hidden state: Reminders memory of
    /// two devices, the vault's id, settings, an in-vault backup and a deleted note.
    private func oldVault() throws -> URL {
        let root = try emptyFolder()
        let vault = try Vault(rootURL: root)
        try vault.bootstrap()
        try write("# Alpha\n- [ ] one ^t111111\n", "Projects/Alpha.md", in: root)
        try write("# Beta\n- [ ] two ^t222222\n", "Projects/Beta.md", in: root)
        try write("# Gamma\n", "Areas/Gamma.md", in: root)
        try write("# Delta\n", "Areas/Delta.md", in: root)
        try write("# Hälsa och träning\n", "Areas/Hälsa och träning.md", in: root)
        try Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]).write(to: root.appendingPathComponent("Areas/photo.png"))
        try write("{\"links\":{},\"version\":1}", ".ams-para/sync-state-MAC.json", in: root)
        try write("{\"links\":{},\"version\":1}", ".ams-para/sync-state-PHONE.json", in: root)
        try write("11111111-2222-3333-4444-555555555555", ".ams-para/vault-id.txt", in: root)
        try write("# Alpha, older\n", ".ams-para/Backups/2026-11-12 0900~daily/Projects/Alpha.md", in: root)
        try write("# Gone\n", ".ams-para/Deleted/Gone.md", in: root)
        return root
    }

    private func request(from source: URL, to destination: URL, toOwn: Bool = true, device: String = "MAC") -> MoveRequest {
        MoveRequest(source: source, destination: destination, vaultID: "11111111-2222-3333-4444-555555555555",
                    knownVaultIDs: [], deviceName: "Martin\u{2019}s Mac", deviceID: device, toOwnFolder: toOwn,
                    placeName: toOwn ? VaultMove.ownFolderWords : source.lastPathComponent, build: 319)
    }

    private func isVault(_ standing: FolderStanding) -> MoveStamp? {
        if case .vault(let stamp) = standing { return stamp }
        return nil
    }

    // MARK: Copy, verify, markers

    func testMoveCopiesEveryFileVerifiesAndLeavesTheOldFolderAsItWas() throws {
        let old = try oldVault(), new = try emptyFolder()
        let before = try VaultMove.manifest(of: old)
        XCTAssertEqual(VaultMove.standing(of: old), .plain)

        let outcome = try VaultMove.run(request(from: old, to: new))

        // Every file, the hidden state included, with the same bytes.
        let after = try VaultMove.manifest(of: new)
        XCTAssertEqual(after.files, before.files)
        XCTAssertEqual(outcome.manifest.files, before.files)
        XCTAssertTrue(after.hashes.keys.contains(".ams-para/sync-state-PHONE.json"))
        XCTAssertTrue(after.hashes.keys.contains(".ams-para/Backups/2026-11-12 0900~daily/Projects/Alpha.md"))
        XCTAssertTrue(after.hashes.keys.contains("Areas/Hälsa och träning.md"))
        XCTAssertEqual(outcome.stamp.fileCount, before.fileCount)
        XCTAssertEqual(outcome.stamp.byteCount, before.byteCount)
        XCTAssertEqual(outcome.stamp.manifestDigest, before.digest)
        XCTAssertEqual(outcome.stamp.generation, 1)
        XCTAssertEqual(outcome.setAside, 0)

        // The old folder: not one note changed, and exactly one new file, the visible marker.
        XCTAssertEqual(try VaultMove.manifest(of: old).files, before.files)
        let top = try fm.contentsOfDirectory(atPath: old.path)
        XCTAssertTrue(top.contains(VaultMove.movedFileName))
        XCTAssertFalse(fm.fileExists(atPath: old.appendingPathComponent(".ams-para/move").path))
        let words = try XCTUnwrap(text(VaultMove.movedFileName, in: old))
        XCTAssertTrue(words.hasPrefix("PARAGON moved these notes to PARAGON\u{2019}s own folder (iCloud Drive \u{203A} PARAGON) on "))
        XCTAssertTrue(words.contains("by Martin\u{2019}s Mac."))

        // What each folder now is.
        XCTAssertEqual(isVault(VaultMove.standing(of: new))?.moveID, outcome.stamp.moveID)
        guard case .movedAway(let moved) = VaultMove.standing(of: old) else { return XCTFail("old folder not marked") }
        XCTAssertEqual(moved.moveID, outcome.stamp.moveID)
        XCTAssertTrue(VaultMove.look(at: new).isComplete)
        // The file's date travels with it.
        let was = try fm.attributesOfItem(atPath: old.appendingPathComponent("Projects/Alpha.md").path)[.modificationDate] as? Date
        let now = try fm.attributesOfItem(atPath: new.appendingPathComponent("Projects/Alpha.md").path)[.modificationDate] as? Date
        XCTAssertEqual(was?.timeIntervalSince1970 ?? 0, now?.timeIntervalSince1970 ?? 1, accuracy: 1)
    }

    // MARK: Stopped half-way, and run again

    func testAStoppedMoveIsRecognisableNeverAVaultAndCanBeRunAgain() throws {
        let old = try oldVault(), new = try emptyFolder()
        let before = try VaultMove.manifest(of: old)
        var hooks = MoveHooks()
        var copied = 0
        hooks.progress = { if $0.step == .copying { copied = $0.done } }
        hooks.cancelled = { copied >= 3 }
        XCTAssertThrowsError(try VaultMove.run(request(from: old, to: new), hooks: hooks)) {
            XCTAssertEqual($0 as? MoveError, .cancelled)
        }
        // Half-made: marked, not complete, and the old folder untouched and unmarked.
        guard case .halfMade(let first) = VaultMove.standing(of: new) else { return XCTFail("not half-made") }
        XCTAssertFalse(VaultMove.look(at: new).isComplete)
        XCTAssertNil(VaultMove.look(at: new).stamp)
        XCTAssertEqual(VaultMove.standing(of: old), .plain)
        XCTAssertEqual(try VaultMove.manifest(of: old).files, before.files)
        XCTAssertFalse(fm.fileExists(atPath: old.appendingPathComponent(VaultMove.movedFileName).path))

        // Again: the same move goes on, what was copied is kept, nothing is set aside.
        let outcome = try VaultMove.run(request(from: old, to: new))
        XCTAssertEqual(outcome.stamp.moveID, first.moveID)
        XCTAssertEqual(outcome.stamp.generation, 1)
        XCTAssertEqual(outcome.alreadyThere, 3)
        XCTAssertEqual(outcome.setAside, 0)
        XCTAssertEqual(try VaultMove.manifest(of: new).files, before.files)
        XCTAssertNotNil(isVault(VaultMove.standing(of: new)))
    }

    func testANoteChangedWhileCopyingIsCopiedAgainBeforeTheMoveCounts() throws {
        let old = try oldVault(), new = try emptyFolder()
        var hooks = MoveHooks()
        var changed = false
        hooks.progress = { [self] progress in
            if progress.step == .copying, progress.done == progress.total, !changed {
                changed = true
                try? write("# Alpha\n- [x] one ^t111111\n- [ ] late\n", "Projects/Alpha.md", in: old)
            }
        }
        let outcome = try VaultMove.run(request(from: old, to: new), hooks: hooks)
        XCTAssertTrue(changed)
        XCTAssertEqual(text("Projects/Alpha.md", in: new), "# Alpha\n- [x] one ^t111111\n- [ ] late\n")
        XCTAssertEqual(try VaultMove.manifest(of: new).files, try VaultMove.manifest(of: old).files)
        XCTAssertEqual(outcome.setAside, 0)
    }

    func testFullICloudNoRoomAndAForeignFolderStopTheMoveWithNothingChanged() throws {
        let old = try oldVault()
        // iCloud full: the copy is there but never called complete; the old folder is not marked.
        let full = try emptyFolder()
        var hooks = MoveHooks()
        hooks.uploadState = { _ in .full }
        XCTAssertThrowsError(try VaultMove.run(request(from: old, to: full), hooks: hooks)) {
            XCTAssertEqual($0 as? MoveError, .cloudFull)
        }
        guard case .halfMade = VaultMove.standing(of: full) else { return XCTFail("not half-made") }
        XCTAssertEqual(VaultMove.standing(of: old), .plain)

        // iCloud never takes the files: given up after the patience, nothing changed.
        var slow = MoveHooks()
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        slow.now = { clock }
        slow.pause = { clock.addTimeInterval($0 * 400) }
        slow.uploadState = { _ in .waiting }
        XCTAssertThrowsError(try VaultMove.run(request(from: old, to: full), hooks: slow)) {
            guard case .uploadSlow = $0 as? MoveError else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(VaultMove.standing(of: old), .plain)

        // No room on the device: stopped before anything is written.
        let tight = try emptyFolder()
        var small = MoveHooks()
        small.freeBytes = { _ in 1_000 }
        XCTAssertThrowsError(try VaultMove.run(request(from: old, to: tight), hooks: small)) {
            guard case .notEnoughRoom = $0 as? MoveError else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: tight.path), [])

        // A folder with somebody's files in it is never filled.
        let foreign = try emptyFolder()
        try write("mine", "Holiday.txt", in: foreign)
        XCTAssertThrowsError(try VaultMove.run(request(from: old, to: foreign))) {
            XCTAssertEqual($0 as? MoveError, .destinationHoldsOtherThings(1))
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: foreign.path), ["Holiday.txt"])
    }

    // MARK: The second device: files arrive in any order

    func testASecondDeviceOpensTheNewFolderOnlyWhenItIsCompleteThere() throws {
        let old = try oldVault(), new = try emptyFolder()
        try VaultMove.run(request(from: old, to: new))
        let list = try VaultMove.manifest(of: new)
        func bring(_ path: String, to device: URL) throws {
            let target = device.appendingPathComponent(path)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: new.appendingPathComponent(path), to: target)
        }

        // Order 1: iCloud brings the markers first, the notes later.
        let first = try emptyFolder()
        try bring(".ams-para/move/complete.json", to: first)
        XCTAssertFalse(VaultMove.look(at: first).isComplete, "complete marker without its list")
        try bring(".ams-para/move/manifest.json", to: first)
        try bring(".ams-para/move/arriving.json", to: first)
        var look = VaultMove.look(at: first)
        XCTAssertNotNil(look.stamp)
        XCTAssertFalse(look.isComplete)
        XCTAssertEqual(look.here, 0)
        for file in list.files.dropLast(1) { try bring(file.path, to: first) }
        look = VaultMove.look(at: first)
        XCTAssertFalse(look.isComplete)
        XCTAssertEqual(look.missing, [list.files.last!.path])
        // A file iCloud knows of but has not sent: its placeholder is there.
        let last = list.files.last!.path
        let stub = CloudFiles.placeholderURL(for: first.appendingPathComponent(last))
        try fm.createDirectory(at: stub.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: stub)
        look = VaultMove.look(at: first)
        XCTAssertEqual(look.arriving, [last])
        XCTAssertFalse(look.isComplete)
        try fm.removeItem(at: stub)
        try bring(last, to: first)
        XCTAssertTrue(VaultMove.look(at: first).isComplete)

        // Order 2: the notes first, the markers last. Without a complete marker it is no vault.
        let second = try emptyFolder()
        for file in list.files { try bring(file.path, to: second) }
        XCTAssertEqual(VaultMove.standing(of: second), .plain)
        XCTAssertFalse(VaultMove.look(at: second).isComplete)
        try bring(".ams-para/move/arriving.json", to: second)
        guard case .halfMade = VaultMove.standing(of: second) else { return XCTFail("not half-made") }
        XCTAssertFalse(VaultMove.look(at: second).isComplete)
        try bring(".ams-para/move/manifest.json", to: second)
        XCTAssertFalse(VaultMove.look(at: second).isComplete)
        try bring(".ams-para/move/complete.json", to: second)
        XCTAssertTrue(VaultMove.look(at: second).isComplete)

        // A marker that is still in iCloud: nothing is decided.
        let third = try emptyFolder()
        try write("", ".ams-para/move/.complete.json.icloud", in: third)
        XCTAssertEqual(VaultMove.standing(of: third), .unclear)
        // In-vault backups and deleted notes are not waited for.
        XCTAssertEqual(VaultMove.look(at: new).expected,
                       list.files.filter { !$0.path.hasPrefix(".ams-para/Backups/") && !$0.path.hasPrefix(".ams-para/Deleted/") }.count)
    }

    // MARK: Changes made in the old folder after the move

    func testChangesInTheOldFolderAfterTheMoveAreFoundAndBroughtOverWithoutLosingEitherSide() throws {
        let old = try oldVault(), new = try emptyFolder()
        try VaultMove.run(request(from: old, to: new))
        let baseline = try XCTUnwrap(VaultMove.baseline(for: "PHONE", in: new))
        XCTAssertTrue(try VaultMove.changes(in: old, since: baseline).changes.isEmpty)

        // A device on an older PARAGON goes on working in the old folder.
        try write("# Alpha\n- [x] one ^t111111\n", "Projects/Alpha.md", in: old)          // changed there only
        try write("# New on the old phone\n", "Projects/Epsilon.md", in: old)              // new there
        try write("# Beta, old folder\n", "Projects/Beta.md", in: old)                     // changed in both
        try write("# Beta, new folder\n", "Projects/Beta.md", in: new)
        try fm.removeItem(at: old.appendingPathComponent("Areas/Gamma.md"))                // deleted there
        try write("{\"links\":{\"a\":1},\"version\":1}", ".ams-para/sync-state-PHONE.json", in: old)
        try write("# a daily backup\n", ".ams-para/Backups/2026-11-14 0900~daily/Inbox.md", in: old)
        try write("# Delta, new folder only\n", "Areas/Delta.md", in: new)                 // changed here only

        let found = try VaultMove.changes(in: old, since: baseline).changes
        XCTAssertEqual(found.notes, ["Projects/Alpha.md", "Projects/Beta.md", "Projects/Epsilon.md"])
        XCTAssertEqual(found.deleted, ["Areas/Gamma.md"])
        XCTAssertFalse(found.added.contains { $0.contains("Backups") })

        let oldBefore = try VaultMove.manifest(of: old)
        let when = Date(timeIntervalSince1970: 1_794_580_000)
        let result = try VaultMove.bringOver(from: old, to: new, deviceID: "PHONE", now: when)
        XCTAssertEqual(result.copied, ["Projects/Epsilon.md"])
        XCTAssertEqual(result.replaced.sorted(), [".ams-para/sync-state-PHONE.json", "Projects/Alpha.md"])
        XCTAssertEqual(result.deletedInOld, ["Areas/Gamma.md"])
        XCTAssertEqual(result.failed, [])
        XCTAssertEqual(result.keptBoth.count, 1)
        // Both versions of Beta are there; the copy carries the app's conflict name.
        XCTAssertEqual(text("Projects/Beta.md", in: new), "# Beta, new folder\n")
        XCTAssertEqual(text(result.keptBoth[0], in: new), "# Beta, old folder\n")
        XCTAssertTrue(Note(relativePath: result.keptBoth[0], kind: .project, text: "").isConflictCopy)
        XCTAssertEqual(text("Projects/Alpha.md", in: new), "# Alpha\n- [x] one ^t111111\n")
        XCTAssertEqual(text("Areas/Gamma.md", in: new), "# Gamma\n", "nothing is deleted in the new folder")
        XCTAssertEqual(text("Areas/Delta.md", in: new), "# Delta, new folder only\n")
        XCTAssertEqual(try VaultMove.manifest(of: old).files, oldBefore.files, "the old folder is only read")

        // A second time: nothing more to bring, and no second conflict copy.
        let again = try VaultMove.bringOver(from: old, to: new, deviceID: "PHONE", now: when)
        XCTAssertFalse(again.changedSomething)
        XCTAssertEqual(again.keptBoth, [])
        // Another device has not looked yet: it finds the same changes, and they are there already.
        let other = try VaultMove.bringOver(from: old, to: new, deviceID: "IPAD", now: when)
        XCTAssertEqual(other.copied, [])
        XCTAssertEqual(other.replaced, [])
        XCTAssertEqual(other.keptBoth, [], "the same conflict copy is not made twice")
    }

    // MARK: Going back

    func testGoingBackIsTheSameMoveTheOtherWayAndSetsAsideInsteadOfDeleting() throws {
        let old = try oldVault(), new = try emptyFolder()
        try VaultMove.run(request(from: old, to: new))
        // He works in the new folder for a while.
        try write("# Alpha, a week later\n", "Projects/Alpha.md", in: new)
        try write("# Zeta\n", "Projects/Zeta.md", in: new)
        try fm.removeItem(at: new.appendingPathComponent("Areas/Delta.md"))

        let back = try VaultMove.run(request(from: new, to: old, toOwn: false))
        XCTAssertEqual(back.stamp.generation, 2)
        XCTAssertEqual(back.setAside, 2)
        XCTAssertEqual(try VaultMove.manifest(of: old).files, try VaultMove.manifest(of: new).files)
        XCTAssertEqual(isVault(VaultMove.standing(of: old))?.generation, 2)
        guard case .movedAway(let moved) = VaultMove.standing(of: new) else { return XCTFail("new folder not marked") }
        XCTAssertEqual(moved.generation, 2)
        XCTAssertFalse(moved.toOwnFolder)
        XCTAssertFalse(fm.fileExists(atPath: old.appendingPathComponent(VaultMove.movedFileName).path))
        // What the old folder held and the vault no longer does is kept, not deleted.
        let aside = old.appendingPathComponent(".ams-para/Set aside by a move")
        let kept = try fm.subpathsOfDirectory(atPath: aside.path)
        XCTAssertTrue(kept.contains { $0.hasSuffix("Projects/Alpha.md") })
        XCTAssertTrue(kept.contains { $0.hasSuffix("Areas/Delta.md") })

        // And forward again: move 3, into the folder that was left.
        let forward = try VaultMove.run(request(from: old, to: new))
        XCTAssertEqual(forward.stamp.generation, 3)
        XCTAssertEqual(isVault(VaultMove.standing(of: new))?.generation, 3)
        guard case .movedAway = VaultMove.standing(of: old) else { return XCTFail("old folder not marked again") }
    }

    // MARK: Devices, and the backup

    func testDevicesThatHaveNotOpenedThisBuildHoldTheOfferBack() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let now = Date(timeIntervalSince1970: 1_794_580_000)
        XCTAssertTrue(vault.noteDevice(VaultDevice(deviceID: "MAC", name: "Martin\u{2019}s Mac", build: 319, kind: "Mac", seenAt: now)))
        XCTAssertFalse(vault.noteDevice(VaultDevice(deviceID: "MAC", name: "Martin\u{2019}s Mac", build: 319, kind: "Mac", seenAt: now.addingTimeInterval(60))),
                       "not written again within a day")
        let recent = now.addingTimeInterval(-3 * 86_400), longAgo = now.addingTimeInterval(-200 * 86_400)
        var lines = VaultDevices.lines(devices: vault.devices(),
                                       syncStates: [("MAC", now), ("PHONE", recent), ("OLDPHONE", longAgo)],
                                       thisDeviceID: "MAC", now: now)
        XCTAssertEqual(lines.map(\.id), ["PHONE", "MAC"])
        XCTAssertFalse(VaultDevices.allReady(lines))
        XCTAssertTrue(lines[0].words.contains("has not opened PARAGON 319"))
        // The phone opens build 319 once.
        vault.noteDevice(VaultDevice(deviceID: "PHONE", name: "Martin\u{2019}s iPhone", build: 319, kind: "iPhone", seenAt: now))
        lines = VaultDevices.lines(devices: vault.devices(), syncStates: [("MAC", now), ("PHONE", recent)], thisDeviceID: "MAC", now: now)
        XCTAssertTrue(VaultDevices.allReady(lines))
        XCTAssertEqual(lines.count, 2)
    }

    func testTheBackupMadeBeforeAMoveIsCheckedAgainstTheVault() throws {
        let root = try oldVault(), place = try emptyFolder()
        let vault = try Vault(rootURL: root)
        XCTAssertFalse(vault.checkNewestOutsideCopy(in: place).isGood, "no copy yet")
        XCTAssertNotNil(try vault.makeOutsideCopy(in: place, reason: "before move"))
        let good = vault.checkNewestOutsideCopy(in: place)
        XCTAssertTrue(good.isGood, good.problem ?? "")
        XCTAssertEqual(good.notes, good.expectedNotes)
        XCTAssertGreaterThan(good.notes, 5)
        // A note changed after the copy: the copy no longer stands for the vault.
        try write("# Alpha, changed\n", "Projects/Alpha.md", in: root)
        let stale = vault.checkNewestOutsideCopy(in: place)
        XCTAssertFalse(stale.isGood)
        XCTAssertEqual(stale.different, ["Projects/Alpha.md"])
    }
}
