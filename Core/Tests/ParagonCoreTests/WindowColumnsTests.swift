import XCTest
@testable import ParagonCore

final class WindowColumnsTests: XCTestCase {
    /// A list fills the Mac window until a note is open; the sections with a right side of
    /// their own never do; Close Note is offered only where it gives the width back.
    func testTheListTakesTheWindowUntilANoteIsOpen() {
        XCTAssertTrue(WindowColumns.listTakesAll(section: "Weekly review", noteOpen: false))
        XCTAssertFalse(WindowColumns.listTakesAll(section: "Weekly review", noteOpen: true))
        XCTAssertFalse(WindowColumns.listTakesAll(section: "Inbox", noteOpen: false))
        XCTAssertFalse(WindowColumns.listTakesAll(section: "Time Blocks", noteOpen: false))
        XCTAssertTrue(WindowColumns.canCloseNote(section: "Projects", noteOpen: true))
        XCTAssertFalse(WindowColumns.canCloseNote(section: "Projects", noteOpen: false))
        XCTAssertFalse(WindowColumns.canCloseNote(section: "Goals", noteOpen: true))
        XCTAssertEqual(WindowColumns.listWidth(100), 220)
        XCTAssertEqual(WindowColumns.listWidth(900), 480)
    }

    /// Four groups, every row once, the first five numbered; Tools starts folded and a press
    /// on a heading folds or opens just that group.
    func testTheSidebarGroupsFoldAndNumberTheFirstFive() {
        XCTAssertEqual(SidebarGroups.all.map(\.name), ["Do", "Goals and PARA", "Look back", "Tools"])
        let rows = SidebarGroups.all.flatMap(\.rows)
        XCTAssertEqual(rows.count, 19)
        XCTAssertEqual(Set(rows).count, 19)
        XCTAssertFalse(rows.contains("Search"))
        XCTAssertEqual(SidebarGroups.numbered, ["Inbox", "Today", "Time Blocks", "All actions", "Aspirations"])
        XCTAssertEqual(SidebarGroups.folded(in: nil), ["Tools"])
        XCTAssertEqual(SidebarGroups.toggling("Look back", in: nil), "Look back|Tools")
        XCTAssertEqual(SidebarGroups.toggling("Tools", in: "Look back|Tools"), "Look back")
        XCTAssertEqual(SidebarGroups.folded(in: ""), [])
    }
}
