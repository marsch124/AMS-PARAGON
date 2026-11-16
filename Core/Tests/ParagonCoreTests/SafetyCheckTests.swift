import XCTest
@testable import ParagonCore

/// Build 326: the Safety lines in Settings.
final class SafetyCheckTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }

    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func facts(devices: [VaultDevice] = [], build: Int = 326, inside: Date? = nil, outside: Date? = nil,
                       paths: [String] = [], lastSync: Date? = nil, conflicts: Int = 0) -> SafetyCheck.Facts {
        SafetyCheck.Facts(devices: devices, thisDeviceID: "MAC", thisDeviceName: "MS MBP 2021", thisBuild: build,
                          newestInsideCopy: inside ?? date(16, 8), newestOutsideCopy: outside ?? date(16, 8),
                          notePaths: paths, lastSync: lastSync, syncConflicts: conflicts, now: date(16, 13))
    }

    private func line(_ kind: SafetyCheck.Kind, _ facts: SafetyCheck.Facts) -> SafetyCheck.Line {
        SafetyCheck.lines(facts, calendar: calendar).first { $0.kind == kind }!
    }

    func testAllDevicesOnOneBuildIsSafe() {
        let devices = [VaultDevice(deviceID: "PHONE", name: "iPhone 17 Pro", build: 326, kind: "iPhone", seenAt: date(16, 12)),
                       VaultDevice(deviceID: "PAD", name: "iPad mini", build: 326, kind: "iPad", seenAt: date(15))]
        let all = SafetyCheck.lines(facts(devices: devices), calendar: calendar)
        XCTAssertEqual(SafetyCheck.summary(all), "Everything is safe")
        let devicesLine = all[0]
        XCTAssertEqual(devicesLine.words, "All 3 devices run PARAGON 326.")
        XCTAssertEqual(devicesLine.details, ["MS MBP 2021: PARAGON 326, this device",
                                             "iPad mini: PARAGON 326, seen 2026-11-15",
                                             "iPhone 17 Pro: PARAGON 326, seen 2026-11-16"])
    }

    func testADeviceOnAnOlderBuildNeedsALook() {
        let pad = VaultDevice(deviceID: "PAD", name: "iPad mini", build: 325, kind: "iPad", seenAt: date(15))
        let found = line(.devices, facts(devices: [pad]))
        XCTAssertTrue(found.needsALook)
        XCTAssertEqual(found.words, "iPad mini runs PARAGON 325, the newest here is 326. Update iPad mini in TestFlight.")

        // The other way round: this device is the one behind.
        let phone = VaultDevice(deviceID: "PHONE", name: "iPhone 17 Pro", build: 327, kind: "iPhone", seenAt: date(16))
        let mine = line(.devices, facts(devices: [phone]))
        XCTAssertEqual(mine.words, "This device runs PARAGON 326, iPhone 17 Pro runs 327. Update this device in TestFlight.")
        XCTAssertEqual(SafetyCheck.summary([mine]), "1 thing to look at")
    }

    func testAnOldPhoneInADrawerIsNotCounted() {
        let old = VaultDevice(deviceID: "OLD", name: "iPhone 12", build: 300, kind: "iPhone",
                              seenAt: date(16).addingTimeInterval(-61 * 86_400))
        let found = line(.devices, facts(devices: [old]))
        XCTAssertFalse(found.needsALook)
        XCTAssertEqual(found.words, "Only this device uses these notes (PARAGON 326).")
    }

    func testThisDevicesOwnOldFileIsNotCountedAgainstIt() {
        // The device file still says the build before the update; the running build counts.
        let stale = VaultDevice(deviceID: "MAC", name: "MS MBP 2021", build: 322, kind: "Mac", seenAt: date(16, 9))
        let phone = VaultDevice(deviceID: "PHONE", name: "iPhone 17 Pro", build: 326, kind: "iPhone", seenAt: date(16))
        XCTAssertFalse(line(.devices, facts(devices: [stale, phone])).needsALook)
    }

    func testCopiesOlderThanTwoDaysNeedALook() {
        XCTAssertFalse(line(.insideCopy, facts(inside: date(14, 23))).needsALook, "two days old is still fine")
        let old = line(.insideCopy, facts(inside: date(13, 8)))
        XCTAssertTrue(old.needsALook)
        XCTAssertEqual(old.words, "The newest copy is 3 days old (2026-11-13 08:00).")
        XCTAssertEqual(line(.outsideCopy, facts(outside: date(16, 9))).words, "Newest copy: 2026-11-16 09:00.")
        let none = SafetyCheck.copy(.outsideCopy, made: nil, now: date(16), calendar: calendar)
        XCTAssertTrue(none.needsALook)
        XCTAssertEqual(none.words, "No copy has been made yet.")
    }

    func testConflictCopiesAndDoubledFilesAreFound() {
        let paths = ["Inbox.md", "Inbox (conflict 2026-11-16 0752).md", "Calendar/20260930.md", "Calendar/20260930 2.md",
                     "Work/Test work 2.md", "Projects/Chapter 12.md", "Projects/inbox 2.md"]
        XCTAssertEqual(SafetyCheck.strayCopies(among: paths),
                       ["Calendar/20260930 2.md", "Inbox (conflict 2026-11-16 0752).md"],
                       "a note that only ends in a number, with no twin beside it, is an ordinary note")
        let found = line(.conflictCopies, facts(paths: paths))
        XCTAssertTrue(found.needsALook)
        XCTAssertEqual(found.words, "2 conflict copies in your notes.")
        XCTAssertEqual(found.details, ["20260930 2", "Inbox (conflict 2026-11-16 0752)"])
        XCTAssertEqual(line(.conflictCopies, facts(paths: ["Inbox.md"])).words, "No conflict copies.")
    }

    func testASyncWithConflictsNeedsALook() {
        XCTAssertEqual(line(.sync, facts(lastSync: date(16, 12))).words, "Last sync: 2026-11-16 12:00, no conflicts.")
        let bad = line(.sync, facts(lastSync: date(16, 12), conflicts: 2))
        XCTAssertTrue(bad.needsALook)
        XCTAssertEqual(bad.words, "The last sync had 2 conflicts.")
        XCTAssertFalse(line(.sync, facts()).needsALook, "not synced yet is not a fault")
    }
}
