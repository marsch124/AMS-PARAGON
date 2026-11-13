import XCTest
@testable import ParagonCore

/// Review round 8, part C (build 315): widget links to lists, the capture key, sharing a note.
final class Round8CTests: XCTestCase {
    func testEachNumberOnTheWidgetHasItsOwnListLink() {
        for list in WidgetList.allCases {
            let url = URL(string: WidgetSnapshot.link(toList: list))!
            XCTAssertEqual(WidgetSnapshot.list(for: url), list)
            XCTAssertFalse(WidgetSnapshot.opensPlan(url))
            XCTAssertNil(CaptureItem(url: url))
        }
        XCTAssertEqual(WidgetSnapshot.link(toList: .review), "amspara:///list/review")
        // A note called "list" or "Inbox" has its title as the host, so it is never a list link.
        XCTAssertNil(WidgetSnapshot.list(for: URL(string: WidgetSnapshot.link(toNoteTitled: "list"))!))
        XCTAssertNil(WidgetSnapshot.list(for: URL(string: "amspara://list/inbox")!))
        XCTAssertNil(WidgetSnapshot.list(for: URL(string: "amspara:///list/other")!))
        XCTAssertNil(WidgetSnapshot.list(for: URL(string: WidgetSnapshot.planLink)!))
        XCTAssertNil(WidgetSnapshot.list(for: URL(string: "https://example.com/list/inbox")!))
    }

    func testTheSmallWidgetOpensTheFirstListWithSomethingInIt() {
        func snapshot(today: Int, overdue: Int, inbox: Int, review: Int) -> WidgetSnapshot {
            WidgetSnapshot(day: DateOnly(year: 2026, month: 11, day: 13), written: Date(), dueToday: today,
                           overdue: overdue, inboxCount: inbox, dueForReview: review, items: [])
        }
        XCTAssertEqual(snapshot(today: 0, overdue: 0, inbox: 0, review: 0).firstWaitingList, .today)
        XCTAssertEqual(snapshot(today: 0, overdue: 2, inbox: 3, review: 1).firstWaitingList, .overdue)
        XCTAssertEqual(snapshot(today: 0, overdue: 0, inbox: 3, review: 1).firstWaitingList, .inbox)
        XCTAssertEqual(snapshot(today: 0, overdue: 0, inbox: 0, review: 1).firstWaitingList, .review)
    }

    func testTheCaptureKeyIsOffUntilChosen() {
        XCTAssertEqual(CaptureHotKey.stored(nil), .off)
        XCTAssertEqual(CaptureHotKey.stored("something else"), .off)
        XCTAssertEqual(CaptureHotKey.stored("controlOptionSpace"), .controlOptionSpace)
        XCTAssertNil(CaptureHotKey.off.keyCode)
        XCTAssertEqual(CaptureHotKey.controlOptionSpace.keyCode, 49)
        XCTAssertEqual(CaptureHotKey.controlOptionSpace.modifiers, 0x1800)
        // Every choice is a different key, and every one holds Control.
        let on = CaptureHotKey.allCases.filter { $0 != .off }
        XCTAssertEqual(Set(on.map(\.modifiers)).count, on.count)
        XCTAssertTrue(on.allSatisfy { $0.modifiers & 0x1000 != 0 })
    }

    func testASharedNoteHasASafeNameAndNoHiddenLines() {
        XCTAssertEqual(NoteShare.fileName(title: "Trip: Oslo/Bergen", ext: "pdf"), "Trip- Oslo-Bergen.pdf")
        XCTAssertEqual(NoteShare.fileName(title: "  ", ext: "txt"), "Note.txt")
        let text = "---\nkind: project\n---\n# Trip\n- [ ] Book the ferry ^t1a2b3c\n"
        let plain = NoteShare.plainText(of: text)
        XCTAssertEqual(plain, "# Trip\n- [ ] Book the ferry\n")
    }
}
