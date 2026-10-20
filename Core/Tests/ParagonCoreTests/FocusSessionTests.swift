import XCTest
@testable import ParagonCore

/// The focus timer (build 256): what the clock says, and what is written under `## Worked`.
final class FocusSessionTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
    }

    func testTheClockLeavesThePausesOut() {
        var session = FocusSession(notePath: "Projects/Shed.md", taskTitle: "Write the offer #next",
                                   title: "Write the offer", plannedMinutes: 45, startedAt: at(20, 8, 2))
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(session.workedSeconds(at: at(20, 8, 12)), 600)
        session.pause(at: at(20, 8, 12))
        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.workedSeconds(at: at(20, 9, 0)), 600, "Paused time is not worked time")
        session.resume(at: at(20, 9, 0))
        XCTAssertEqual(session.workedSeconds(at: at(20, 9, 5)), 900)
        XCTAssertEqual(session.allRuns(endingAt: at(20, 9, 5)).count, 2)
        session.pause(at: at(20, 9, 5))
        session.pause(at: at(20, 9, 30))
        XCTAssertEqual(session.runs.count, 2, "A second pause changes nothing")
    }

    func testTheNoticeWaitsForThePlannedTimeAndComesOnce() {
        var session = FocusSession(notePath: "Projects/Shed.md", taskTitle: "Call the bank",
                                   title: "Call the bank", plannedMinutes: 15, startedAt: at(20, 9, 0))
        XCTAssertEqual(session.secondsUntilPlanned(at: at(20, 9, 0)), 900)
        XCTAssertEqual(session.secondsUntilPlanned(at: at(20, 9, 10)), 300)
        session.pause(at: at(20, 9, 10))
        XCTAssertNil(session.secondsUntilPlanned(at: at(20, 9, 30)), "No notice while the clock is paused")
        session.resume(at: at(20, 9, 30))
        XCTAssertEqual(session.secondsUntilPlanned(at: at(20, 9, 30)), 300, "The pause is not counted")
        XCTAssertNil(session.secondsUntilPlanned(at: at(20, 9, 35)), "The time is up now")
        session.pause(at: at(20, 9, 40))
        session.resume(at: at(20, 9, 50))
        XCTAssertNil(session.secondsUntilPlanned(at: at(20, 9, 50)), "Going on after the time is up plants nothing again")

        let unplanned = FocusSession(notePath: nil, taskTitle: "Read", title: "Read", plannedMinutes: nil,
                                     startedAt: at(20, 9, 0))
        XCTAssertNil(unplanned.secondsUntilPlanned(at: at(20, 9, 0)), "No time planned, no notice")
    }

    func testTheClockOnTheBar() {
        XCTAssertEqual(FocusSession.clock(0), "0:00")
        XCTAssertEqual(FocusSession.clock(249), "4:09")
        XCTAssertEqual(FocusSession.clock(23 * 60 + 14), "23:14")
        XCTAssertEqual(FocusSession.clock(3725), "1:02:05")
        XCTAssertEqual(FocusSession.clock(-5), "0:00")
    }

    func testASessionSurvivesBeingStoredAndReadBack() throws {
        var session = FocusSession(notePath: nil, taskTitle: "Swim", title: "Swim", plannedMinutes: 40,
                                   startedAt: at(20, 6, 40))
        session.pause(at: at(20, 7, 0))
        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(FocusSession.self, from: data), session)
    }

    func testEachStretchBecomesALineOfWholeMinutes() {
        let runs = [
            FocusSession.Run(start: at(20, 8, 2, 40), end: at(20, 8, 54, 10)),   // 51.5 min → 52
            FocusSession.Run(start: at(20, 9, 5), end: at(20, 9, 5, 20)),         // 20 s → no line
            FocusSession.Run(start: at(20, 9, 5), end: at(20, 9, 15)),
        ]
        let spans = WorkLog.spans(from: runs, title: "Write the offer", calendar: calendar)
        XCTAssertEqual(spans.map(\.span.line), ["- 08:02-08:54 Write the offer", "- 09:05-09:15 Write the offer"])
        XCTAssertEqual(spans.map(\.span.minutes).reduce(0, +), 62, "The lines add up to what the question says")
        XCTAssertEqual(Set(spans.map(\.day)), [DateOnly(year: 2026, month: 10, day: 20)])
    }

    func testAStretchPastMidnightIsWrittenOnBothDays() {
        let runs = [FocusSession.Run(start: at(20, 23, 30), end: at(21, 0, 45))]
        let spans = WorkLog.spans(from: runs, title: "Late reading", calendar: calendar)
        XCTAssertEqual(spans.map(\.day), [DateOnly(year: 2026, month: 10, day: 20), DateOnly(year: 2026, month: 10, day: 21)])
        XCTAssertEqual(spans.map(\.span.line), ["- 23:30-24:00 Late reading", "- 00:00-00:45 Late reading"])
        XCTAssertEqual(WorkLog.span(in: "- 23:30-24:00 Late reading")?.minutes, 30, "24:00 reads back as midnight")
    }

    func testTheSectionIsMadeAboveLookingBackAndOnlyAddedTo() {
        let day = Note(relativePath: "Calendar/2026-10-20.md", kind: .daily,
                       text: "---\ntitle: 2026-10-20\n---\n## Tasks\n\n- [ ] Call the bank\n\n## Looking back\n\nGood morning.\n")
        let first = day.addingWorkedSpans([WorkedSpan(start: 482, end: 534, title: "Write the offer")])
        XCTAssertTrue(first.body.contains("## Worked\n\n- 08:02-08:54 Write the offer\n\n## Looking back"),
                      "Made above Looking back: \(first.body)")
        XCTAssertEqual(first.lookingBack, "Good morning.", "Nothing else in the note moved")

        let second = first.addingWorkedSpans([WorkedSpan(start: 545, end: 555, title: "Call the bank")])
        XCTAssertEqual(second.workedSpans.map(\.title), ["Write the offer", "Call the bank"])
        XCTAssertEqual(second.body.components(separatedBy: "## Worked").count, 2, "One section, not two")

        let plain = Note(relativePath: "Calendar/2026-10-21.md", kind: .daily, text: "---\ntitle: 2026-10-21\n---\n## Tasks\n")
        let made = plain.addingWorkedSpans([WorkedSpan(start: 0, end: 45, title: "Late reading")])
        XCTAssertTrue(made.body.hasSuffix("## Worked\n\n- 00:00-00:45 Late reading\n"), "At the end otherwise: \(made.body)")
        XCTAssertEqual(plain.addingWorkedSpans([]), plain, "Nothing to add changes nothing")
    }

    func testAnEmptySectionGetsOneBlankLineNotTwo() {
        let day = Note(relativePath: "Calendar/2026-10-20.md", kind: .daily,
                       text: "---\ntitle: 2026-10-20\n---\n## Worked\n\n## Looking back\n\nFine.\n")
        let added = day.addingWorkedSpans([WorkedSpan(start: 482, end: 534, title: "Write the offer")])
        XCTAssertTrue(added.body.hasPrefix("## Worked\n\n- 08:02-08:54 Write the offer\n\n## Looking back"),
                      "One blank line on each side: \(added.body)")

        let last = Note(relativePath: "Calendar/2026-10-21.md", kind: .daily,
                        text: "---\ntitle: 2026-10-21\n---\n## Tasks\n\n## Worked\n")
        XCTAssertTrue(last.addingWorkedSpans([WorkedSpan(start: 0, end: 45, title: "Late reading")]).body
                        .hasSuffix("## Worked\n\n- 00:00-00:45 Late reading\n"),
                      "At the end of the note the final newline stays")
    }

    func testDoneFindsTheRightTaskOrNone() {
        let tasks = Note(relativePath: "Projects/Boat.md", kind: .project, text: """
            ---
            title: Boat
            ---
            - [ ] Paint the hull >2026-10-20
            - [ ] Paint the hull >2026-10-27
            - [ ] Call the yard ^t1a2b3c
            - [x] Sand it

            """).tasks
        func session(_ title: String, id: String? = nil, due: DateOnly? = nil) -> FocusSession {
            FocusSession(notePath: "Projects/Boat.md", taskTitle: title, title: title, plannedMinutes: nil,
                         startedAt: at(20, 8, 0), taskID: id, taskDue: due)
        }
        XCTAssertEqual(session("Paint the hull", due: DateOnly(year: 2026, month: 10, day: 27)).task(in: tasks)?.dueDate,
                       DateOnly(year: 2026, month: 10, day: 27), "The date tells two tasks with the same words apart")
        XCTAssertEqual(session("Renamed by hand", id: "t1a2b3c").task(in: tasks)?.title, "Call the yard",
                       "The id finds a task whose words have changed")
        XCTAssertNil(session("Sand it").task(in: tasks), "A task already ticked is not ticked again")
        let ticked = Note(relativePath: "Projects/Boat.md", kind: .project,
                          text: "---\ntitle: Boat\n---\n- [x] Paint the hull ^t9f9f9f\n- [ ] Paint the hull\n").tasks
        XCTAssertNil(session("Paint the hull", id: "t9f9f9f").task(in: ticked),
                     "Its own task was ticked elsewhere, so the other one with the same words is left alone")
        XCTAssertNil(session("Gone").task(in: tasks), "Nothing matches, so nothing is ticked")
    }

    func testAWorkedLineIsReadLiberally() {
        XCTAssertEqual(WorkLog.span(in: "- 8:02 – 8:54 Write the offer"), WorkedSpan(start: 482, end: 534, title: "Write the offer"))
        XCTAssertEqual(WorkLog.span(in: "08:02-08:54 No bullet")?.title, "No bullet")
        XCTAssertNil(WorkLog.span(in: "- 25:00-26:00 Not a time"))
        XCTAssertNil(WorkLog.span(in: "- 23:00-24:30 Past midnight is two lines, never one"))
        XCTAssertNil(WorkLog.span(in: "Just words"))
    }
}
