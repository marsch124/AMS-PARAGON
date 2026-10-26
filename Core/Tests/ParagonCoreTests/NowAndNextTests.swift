import XCTest
@testable import ParagonCore

/// Build 266: the **Now** and **Then** lines at the top of **Today** — the block of the day's
/// plan you are in, and the one after it.
final class NowAndNextTests: XCTestCase {
    private func block(_ start: String, _ end: String, _ title: String, index: Int) -> PlanBlock {
        PlanBlock(start: minutes(start), end: minutes(end), title: title, index: index)
    }

    private func minutes(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    private var day: [PlanBlock] {
        [block("09:30", "11:00", "Write the offer", index: 0),
         block("11:00", "11:30", "Call Anna", index: 1)]
    }

    /// No plan: nothing is now, nothing comes next, and nothing is drawn.
    func testAnEmptyPlanIsEmpty() {
        let reading = NowAndNext(blocks: [], minute: minutes("10:00"))
        XCTAssertNil(reading.now)
        XCTAssertNil(reading.next)
        XCTAssertTrue(reading.isEmpty)
    }

    /// Before the first block only the second line has something to say.
    func testBeforeTheFirstBlockOnlyThenIsShown() {
        let reading = NowAndNext(blocks: day, minute: minutes("08:00"))
        XCTAssertNil(reading.now)
        XCTAssertEqual(reading.next?.title, "Write the offer")
        XCTAssertFalse(reading.isEmpty)
    }

    /// Inside a block: that block is now, and the one after it is then.
    func testInsideABlockBothLinesAreShown() {
        let reading = NowAndNext(blocks: day, minute: minutes("10:00"))
        XCTAssertEqual(reading.now?.title, "Write the offer")
        XCTAssertEqual(reading.next?.title, "Call Anna")
    }

    /// The start minute is part of the block; the end minute is not.
    func testTheEndMinuteIsNoLongerNow() {
        let alone = [block("09:30", "11:00", "Write the offer", index: 0)]
        XCTAssertEqual(NowAndNext(blocks: alone, minute: minutes("09:30")).now?.title, "Write the offer")
        XCTAssertEqual(NowAndNext(blocks: alone, minute: minutes("10:59")).now?.title, "Write the offer")
        XCTAssertTrue(NowAndNext(blocks: alone, minute: minutes("11:00")).isEmpty)

        // With a block starting the minute the first one ends, the new one takes over at once.
        let reading = NowAndNext(blocks: day, minute: minutes("11:00"))
        XCTAssertEqual(reading.now?.title, "Call Anna")
        XCTAssertNil(reading.next)
    }

    /// A short block inside a long one is now while it runs; the long one is now again after.
    func testAShortBlockInsideALongOneWinsWhileItRuns() {
        let blocks = [block("08:00", "17:00", "Office day", index: 0),
                      block("09:30", "11:00", "Write the offer", index: 1)]

        let before = NowAndNext(blocks: blocks, minute: minutes("09:00"))
        XCTAssertEqual(before.now?.title, "Office day")
        XCTAssertEqual(before.next?.title, "Write the offer")

        let inside = NowAndNext(blocks: blocks, minute: minutes("10:00"))
        XCTAssertEqual(inside.now?.title, "Write the offer")
        XCTAssertNil(inside.next, "The long block started before now, so it is never Then.")

        let after = NowAndNext(blocks: blocks, minute: minutes("11:00"))
        XCTAssertEqual(after.now?.title, "Office day")
        XCTAssertNil(after.next)
    }

    /// Two blocks with the same start: the one first in the plan, whatever order they come in.
    func testTwoBlocksWithTheSameStartTakeTheFirstInThePlan() {
        let blocks = [block("09:00", "09:30", "Second", index: 1),
                      block("09:00", "10:00", "First", index: 0)]
        XCTAssertEqual(NowAndNext(blocks: blocks, minute: minutes("08:00")).next?.title, "First")
        XCTAssertEqual(NowAndNext(blocks: blocks, minute: minutes("09:10")).now?.title, "First")
        // Once the short one has ended only the long one is left.
        XCTAssertEqual(NowAndNext(blocks: blocks, minute: minutes("09:45")).now?.title, "First")
    }

    /// Then is the earliest block still to come, never a later one listed first.
    func testThenIsTheEarliestStillToCome() {
        let blocks = [block("15:00", "16:00", "Late", index: 2),
                      block("13:00", "14:00", "Early", index: 1),
                      block("09:00", "10:00", "Done already", index: 0)]
        let reading = NowAndNext(blocks: blocks, minute: minutes("11:00"))
        XCTAssertNil(reading.now)
        XCTAssertEqual(reading.next?.title, "Early")
    }

    /// After the last block there is nothing to say, so nothing is drawn.
    func testAfterTheLastBlockItIsEmpty() {
        let reading = NowAndNext(blocks: day, minute: minutes("12:00"))
        XCTAssertTrue(reading.isEmpty)
    }

    /// 25 October 2026 is the day the clocks go back in Sweden: at 10:00 eleven hours have
    /// passed since midnight. The minute is read from the clock, so it is 600 — seconds since
    /// midnight divided by 60 would say 660 and pick the wrong block (build 238).
    func testTheMinuteIsReadFromTheClockOnTheDayTheClocksChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Stockholm"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25,
                                                                     hour: 10, minute: 0)))
        XCTAssertEqual(NowAndNext.minute(of: date, calendar: calendar), 600)
        let sinceMidnight = date.timeIntervalSince(calendar.startOfDay(for: date)) / 60
        XCTAssertEqual(sinceMidnight, 660, "The day did not have its extra hour, so this test proves nothing.")
    }

    /// The running clock is matched to a block the way Planned and worked matches them.
    func testSameNameIgnoresCaseAndSpacesButNotATag() {
        XCTAssertTrue(NowAndNext.sameName("Write the offer", "write  the   OFFER"))
        XCTAssertTrue(NowAndNext.sameName(" Write the offer ", "Write the offer"))
        XCTAssertFalse(NowAndNext.sameName("Write the offer #work", "Write the offer"))
        XCTAssertFalse(NowAndNext.sameName("Write the offer", "Call Anna"))
        XCTAssertFalse(NowAndNext.sameName(nil, "Write the offer"))
        XCTAssertFalse(NowAndNext.sameName("", ""))
    }

    // MARK: A block's clock finds its task (build 267)

    private let today = DateOnly(year: 2026, month: 10, day: 26)

    private func note(_ path: String, kind: ParaKind, _ body: String, status: String? = nil) -> Note {
        let name = (path.split(separator: "/").last.map(String.init) ?? path).replacingOccurrences(of: ".md", with: "")
        let statusLine = status.map { "status: \($0)\n" } ?? ""
        let front = "---\ntitle: \(name)\ntype: \(kind.rawValue)\n" + statusLine + "---\n"
        return Note(relativePath: path, kind: kind, text: front + body)
    }

    private func found(_ title: String, among notes: [Note], on day: DateOnly? = nil) -> TaskRef? {
        let block = PlanBlock(start: minutes("09:30"), end: minutes("10:15"), title: title)
        return NoteIndex(notes: notes).openTask(forBlock: block, on: day ?? today)
    }

    /// The task the block was made from is found, in its own note, with its own words.
    func testABlockFindsTheOneOpenTaskWithItsName() {
        let shed = note("Projects/Shed.md", kind: .project, """
        - [ ] Order the wood
        - [ ] Write the offer ~45m
        """)
        let ref = found("Write the offer", among: [shed])
        XCTAssertEqual(ref?.notePath, "Projects/Shed.md")
        XCTAssertEqual(ref?.task.title, "Write the offer")
    }

    /// A block never carries `#next` (`planTitle` takes it off), but the task still does.
    func testATaskMarkedNextStillMatchesItsBlock() {
        let shed = note("Projects/Shed.md", kind: .project, "- [ ] Write the offer #next\n")
        XCTAssertEqual(found("Write the offer", among: [shed])?.task.title, "Write the offer #next")
    }

    func testCaseAndSpacesAreIgnored() {
        let shed = note("Projects/Shed.md", kind: .project, "- [ ] Write the offer\n")
        XCTAssertNotNil(found("write  the   OFFER", among: [shed]))
        XCTAssertNotNil(found(" Write the offer ", among: [shed]))
    }

    /// Two open tasks with one name cannot be told apart, so neither is lent to the block.
    func testTwoOpenTasksWithTheNameFindNothing() {
        let shed = note("Projects/Shed.md", kind: .project, "- [ ] Call Anna\n")
        let office = note("Areas/Office.md", kind: .area, "- [ ] Call Anna\n")
        XCTAssertNil(found("Call Anna", among: [shed, office]))
        // Two in one note are just as unclear.
        let twice = note("Projects/Shed.md", kind: .project, "- [ ] Call Anna\n- [ ] Call Anna\n")
        XCTAssertNil(found("Call Anna", among: [twice]))
    }

    /// A ticked task is done: nothing to tick. A ticked copy beside an open one leaves the open one.
    func testATickedTaskIsNeverFound() {
        let done = note("Projects/Shed.md", kind: .project, "- [x] Call Anna @done(2026-10-25)\n- [-] Call Bo\n")
        XCTAssertNil(found("Call Anna", among: [done]))
        XCTAssertNil(found("Call Bo", among: [done]), "A cancelled task is not open either.")
        let both = note("Projects/Shed.md", kind: .project, "- [x] Call Anna @done(2026-10-25)\n- [ ] Call Anna\n")
        XCTAssertEqual(found("Call Anna", among: [both])?.task.isDone, false)
    }

    /// Ticking a repeating task writes its next copy, dated later. That copy is not today's work.
    func testTheOnlyOpenCopyDatedAfterTheDayFindsNothing() {
        let home = note("Areas/Home.md", kind: .area, """
        - [x] Water the plants >2026-10-26 @repeat(weekly) @done(2026-10-26 08:00)
        - [ ] Water the plants >2026-11-02 @repeat(weekly)
        """)
        XCTAssertNil(found("Water the plants", among: [home]))
        // On the copy's own day, or later, it is the one.
        XCTAssertNotNil(found("Water the plants", among: [home], on: DateOnly(year: 2026, month: 11, day: 2)))
        // A task that is overdue, or due today, is still the block's task.
        let late = note("Areas/Home.md", kind: .area, "- [ ] Pay the car tax >2026-10-20\n- [ ] Book the dentist >2026-10-26\n")
        XCTAssertNotNil(found("Pay the car tax", among: [late]))
        XCTAssertNotNil(found("Book the dentist", among: [late]))
    }

    /// A task with no date of its own, in a later day's daily note, belongs to that day.
    func testATaskInALaterDailyNoteIsThatDaysTask() {
        let tomorrow = note("Calendar/20261027.md", kind: .daily, "- [ ] Call Anna\n")
        XCTAssertNil(found("Call Anna", among: [tomorrow]))
        let thisMorning = note("Calendar/20261026.md", kind: .daily, "- [ ] Call Anna\n")
        XCTAssertEqual(found("Call Anna", among: [thisMorning])?.notePath, "Calendar/20261026.md")
    }

    /// An archived project's tasks are out of play, in the Archive folder or marked archived.
    func testATaskInAnArchivedProjectIsNeverFound() {
        let moved = note("Archive/Old shed.md", kind: .archive, "- [ ] Paint the door\n")
        let marked = note("Projects/Old fence.md", kind: .project, "- [ ] Paint the gate\n", status: "archived")
        XCTAssertNil(found("Paint the door", among: [moved]))
        XCTAssertNil(found("Paint the gate", among: [marked]))
    }

    /// A tag is part of the name, as in Planned and worked: a block typed by hand without it is
    /// another name. With the tag it is the same name.
    func testABlockTypedWithoutTheTasksTagFindsNothing() {
        let shed = note("Projects/Shed.md", kind: .project, "- [ ] Write the offer #work\n")
        XCTAssertNil(found("Write the offer", among: [shed]))
        XCTAssertNotNil(found("Write the offer #work", among: [shed]))
    }

    /// A block with no words names nothing.
    func testABlockWithNoNameFindsNothing() {
        let shed = note("Projects/Shed.md", kind: .project, "- [ ] Write the offer\n")
        XCTAssertNil(found("  ", among: [shed]))
    }
}
