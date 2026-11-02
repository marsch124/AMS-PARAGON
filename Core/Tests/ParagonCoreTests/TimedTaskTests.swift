import XCTest
@testable import ParagonCore

/// A task with a time of day is a fixed point in the day (build 277): the one query for it, how
/// long it lasts, and where **Start the day** puts a block that has such a time.
final class TimedTaskTests: XCTestCase {
    private let day = DateOnly(year: 2026, month: 11, day: 4)
    private let other = DateOnly(year: 2026, month: 11, day: 5)

    private func clock(_ text: String) -> Int {
        let time = TimeOfDay(text)!
        return time.minutesSinceMidnight
    }

    private func note(_ path: String, kind: ParaKind, _ body: String, status: String? = nil) -> Note {
        let name = (path.split(separator: "/").last.map(String.init) ?? path).replacingOccurrences(of: ".md", with: "")
        let statusLine = status.map { "status: \($0)\n" } ?? ""
        let front = "---\ntitle: \(name)\ntype: \(kind.rawValue)\n" + statusLine + "---\n"
        return Note(relativePath: path, kind: kind, text: front + body)
    }

    private func task(_ line: String) throws -> TaskItem {
        try XCTUnwrap(TaskParser.parse(line: line))
    }

    // MARK: How long it lasts

    func testATimedTaskLastsHalfAnHourWhenItHasNoLengthOfItsOwn() throws {
        let call = try task("- [ ] Call the bank >2026-11-04T14:00")
        XCTAssertEqual(TimedTask.minutes(of: call, usesTaskTimes: true), 30)
        XCTAssertEqual(TimedTask.span(of: call, usesTaskTimes: true), clock("14:00")..<clock("14:30"))
    }

    func testItsOwnLengthIsUsedWhenTaskTimesAreOn() throws {
        let call = try task("- [ ] Call the bank ~45m >2026-11-04T14:00")
        XCTAssertEqual(TimedTask.minutes(of: call, usesTaskTimes: true), 45)
        XCTAssertEqual(TimedTask.span(of: call, usesTaskTimes: true), clock("14:00")..<clock("14:45"))
    }

    /// **Use task times** off hides every `~45m`, so it must not change what is drawn either.
    func testWithTaskTimesOffAHiddenLengthIsNotUsed() throws {
        let call = try task("- [ ] Call the bank ~45m >2026-11-04T14:00")
        XCTAssertEqual(TimedTask.minutes(of: call, usesTaskTimes: false), 30)
        XCTAssertEqual(TimedTask.span(of: call, usesTaskTimes: false), clock("14:00")..<clock("14:30"))
    }

    func testATaskWithNoTimeOfDayHasNoSpan() throws {
        let dated = try task("- [ ] Call the bank >2026-11-04")
        let undated = try task("- [ ] Call the bank")
        XCTAssertNil(TimedTask.span(of: dated, usesTaskTimes: true))
        XCTAssertNil(TimedTask.span(of: undated, usesTaskTimes: true))
    }

    /// The span is cut at midnight and is never empty, whatever the time is.
    func testTheSpanIsCutAtMidnight() throws {
        let late = try task("- [ ] Lock up >2026-11-04T23:50")
        XCTAssertEqual(TimedTask.span(of: late, usesTaskTimes: true), (23 * 60 + 50)..<(24 * 60))
        let last = try task("- [ ] Lock up >2026-11-04T23:59 ~2h")
        XCTAssertEqual(TimedTask.span(of: last, usesTaskTimes: true), 1439..<1440)
        let midnight = try task("- [ ] Early >2026-11-04T00:00")
        XCTAssertEqual(TimedTask.span(of: midnight, usesTaskTimes: true), 0..<30)
    }

    // MARK: The one query

    private func index() -> NoteIndex {
        let shed = note("Projects/Shed.md", kind: .project, """
        - [ ] Call the bank >2026-11-04T14:00
        - [ ] Buy screws >2026-11-04
        - [ ] Order wood >2026-11-05T09:00
        - [x] Sign the contract >2026-11-04T10:00
        - [-] Cancelled thing >2026-11-04T11:00
        - [ ] Dentist >2026-11-04T08:30
        - [ ] Someday
        """)
        let inbox = note("Inbox.md", kind: .inbox, "- [ ] Ring the ferry >2026-11-04T12:15\n")
        let old = note("Archive/Old.md", kind: .archive, "- [ ] Old call >2026-11-04T13:00\n")
        return NoteIndex(notes: [shed, inbox, old])
    }

    func testOnlyOpenTasksOnThatDayWithATimeAreListed() {
        let titles = index().timedTasks(on: day).map(\.task.title)
        XCTAssertEqual(titles, ["Dentist", "Ring the ferry", "Call the bank"])
    }

    func testTheListIsInTheOrderOfTheDay() {
        let times = index().timedTasks(on: day).compactMap { $0.task.dueTime?.description }
        XCTAssertEqual(times, ["08:30", "12:15", "14:00"])
    }

    func testAnotherDayHasItsOwnTasks() {
        XCTAssertEqual(index().timedTasks(on: other).map(\.task.title), ["Order wood"])
        XCTAssertTrue(index().timedTasks(on: DateOnly(year: 2026, month: 12, day: 1)).isEmpty)
    }

    func testTheInboxCountsAndTheArchiveDoesNot() {
        let paths = index().timedTasks(on: day).map(\.notePath)
        XCTAssertTrue(paths.contains("Inbox.md"))
        XCTAssertFalse(paths.contains("Archive/Old.md"))
    }

    // MARK: Hours that are busy

    func testTheBusyHoursAreEachTasksSpan() {
        let ranges = index().timedTaskRanges(on: day, usesTaskTimes: true)
        XCTAssertEqual(ranges, [clock("08:30")..<clock("09:00"), clock("12:15")..<clock("12:45"),
                                clock("14:00")..<clock("14:30")])
    }

    /// A picked task's own hour must not be busy, or it could never be put where it is due.
    func testAPickedTasksOwnHourIsLeftOut() throws {
        let all = index().timedTasks(on: day)
        let call = try XCTUnwrap(all.first { $0.task.title == "Call the bank" })
        let ranges = index().timedTaskRanges(on: day, usesTaskTimes: true, excluding: [call.id])
        XCTAssertEqual(ranges, [clock("08:30")..<clock("09:00"), clock("12:15")..<clock("12:45")])
    }

    // MARK: Where Start the day puts a block

    /// A block with a time of day is placed at that time when the hour is free.
    func testATimedBlockGoesAtItsTime() {
        let starts = DayPlan.starts(for: [PlanWish(length: 60, at: clock("14:00"))],
                                    from: clock("08:00"), until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [clock("14:00")])
    }

    /// The others go around it, in the first free time, as they always did.
    func testOtherBlocksGoAroundATimedOne() {
        let wishes = [PlanWish(length: 120), PlanWish(length: 60, at: clock("09:30"))]
        let starts = DayPlan.starts(for: wishes, from: clock("08:00"), until: 24 * 60, busy: [])
        // The timed block is settled first and 09:30-10:30 is taken, so the two hours that
        // start at 08:00 would run into it: the long block goes after it instead.
        XCTAssertEqual(starts, [clock("10:30"), clock("09:30")])
    }

    func testTheAnswersAreInTheOrderTheWishesWereAskedIn() {
        let wishes = [PlanWish(length: 30, at: clock("15:00")), PlanWish(length: 30),
                      PlanWish(length: 30, at: clock("09:00"))]
        let starts = DayPlan.starts(for: wishes, from: clock("08:00"), until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [clock("15:00"), clock("08:00"), clock("09:00")])
    }

    /// When the hour is taken (a meeting), the block goes into the first free gap, not on top.
    func testATimedBlockWhoseHourIsTakenFindsAGap() {
        let starts = DayPlan.starts(for: [PlanWish(length: 60, at: clock("14:00"))],
                                    from: clock("08:00"), until: 24 * 60,
                                    busy: [clock("13:30")..<clock("14:30")])
        XCTAssertEqual(starts, [clock("08:00")])
    }

    /// When the time has already gone by, the block is not put into the past.
    func testATimedBlockAlreadyInThePastTakesTheFirstGapFromNow() {
        let starts = DayPlan.starts(for: [PlanWish(length: 30, at: clock("09:00"))],
                                    from: clock("11:07"), until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [clock("11:15")])
    }

    func testATimedBlockThatWouldRunPastTheEndOfTheDayFindsNoRoom() {
        let starts = DayPlan.starts(for: [PlanWish(length: 60, at: clock("23:30"))],
                                    from: clock("08:00"), until: 24 * 60, busy: [clock("08:00")..<clock("23:59")])
        XCTAssertEqual(starts, [nil])
    }

    /// Two blocks due at the same time cannot both have it: the second goes into a gap.
    func testTwoBlocksDueTogetherDoNotOverlap() {
        let wishes = [PlanWish(length: 60, at: clock("10:00")), PlanWish(length: 60, at: clock("10:00"))]
        let starts = DayPlan.starts(for: wishes, from: clock("08:00"), until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [clock("10:00"), clock("08:00")])
    }

    /// With no time on any of them it is exactly the placing `freeStarts(lengths:…)` always did.
    func testWithoutTimesItIsTheOldPlacing() {
        let lengths = [45, 15, 30]
        let busy = [clock("08:30")..<clock("09:00")]
        let old = DayPlan.freeStarts(lengths: lengths, from: clock("08:00"), until: 24 * 60, busy: busy)
        let new = DayPlan.starts(for: lengths.map { PlanWish(length: $0) }, from: clock("08:00"),
                                 until: 24 * 60, busy: busy)
        XCTAssertEqual(new, old)
    }

    func testAWishWithNoLengthGetsNoStart() {
        let starts = DayPlan.starts(for: [PlanWish(length: 0, at: clock("10:00")), PlanWish(length: 30)],
                                    from: clock("08:00"), until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [nil, clock("08:00")])
    }

    // MARK: The sum and the placing agree

    /// The same busy list feeds the sum (`DayFit`) and the placing: a call at 14:00 takes half an
    /// hour out of the free time, and a picked task's own hour does not.
    func testTheSumCountsAnUnpickedCallAsBusyAndAPickedOneAsFree() throws {
        let all = index().timedTasks(on: day)
        let call = try XCTUnwrap(all.first { $0.task.title == "Call the bank" })
        let busyWithCall = index().timedTaskRanges(on: day, usesTaskTimes: true)
        let busyWithout = index().timedTaskRanges(on: day, usesTaskTimes: true, excluding: [call.id])
        let withCall = DayFit(picked: 60, from: clock("13:00"), workdayEnds: clock("16:00"), busy: busyWithCall)
        let without = DayFit(picked: 60, from: clock("13:00"), workdayEnds: clock("16:00"), busy: busyWithout)
        XCTAssertEqual(withCall.freeInWorkday, 150)
        XCTAssertEqual(without.freeInWorkday, 180)
    }
}
