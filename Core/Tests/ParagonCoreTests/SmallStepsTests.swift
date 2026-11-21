import XCTest
@testable import ParagonCore

final class SmallStepsTests: XCTestCase {
    func testTheShareOfTickedDirectSubtasksIgnoresCancelledAndDeeperOnes() {
        let text = """
        - [ ] Plan the trip
          - [x] Book the train
          - [ ] Book the hotel
            - [x] Compare prices
          - [-] Rent a car
          - [x] Buy a map
        - [ ] Other task
        """
        let tasks = TaskParser.parse(text: text)
        let parent = tasks[0]
        let steps = SmallSteps.of(parent, in: tasks)
        XCTAssertEqual(steps.done, 2)
        XCTAssertEqual(steps.total, 3)
        XCTAssertEqual(steps.text, "2/3")
        XCTAssertEqual(steps.fraction ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertFalse(steps.isComplete)
        XCTAssertNil(SmallSteps.of(tasks.last!, in: tasks).fraction)
        XCTAssertNil(SmallSteps.of(tasks.last!, in: tasks).text)
    }

    // MARK: Round 352: ticking the last small step ticks the task

    private func day() -> (Date, Calendar) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return (cal.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 9))!, cal)
    }

    func testTickingTheLastStepTicksTheTaskAndOnlyThen() {
        let (date, cal) = day()
        var note = Note(relativePath: "Projects/Trip.md", kind: .project, body: """
        - [ ] Plan the trip
          - [x] Book the train
          - [ ] Book the hotel
          - [-] Rent a car
        - [ ] Other task
        """)
        // A ticked step that is not the last: nothing more is ticked.
        var first = note
        let notLast = first.tasks[1]
        let none = first.tickParentsWhenStepsDone(afterTicking: notLast, at: date, calendar: cal)
        XCTAssertTrue(none.isEmpty)
        // The last open step: the task above it is ticked too, with its done stamp.
        let hotel = note.tasks[2]
        note.complete(task: hotel, at: date, calendar: cal)
        let parents = note.tickParentsWhenStepsDone(afterTicking: hotel, at: date, calendar: cal)
        XCTAssertEqual(parents.map { $0.title }, ["Plan the trip"])
        XCTAssertTrue(note.lines[0].hasPrefix("- [x] Plan the trip @done(2026-11-21"), note.lines[0])
        XCTAssertEqual(note.lines[4], "- [ ] Other task")
        // Unticking a step never opens the task again.
        var reopened = note.tasks[2]
        reopened.markOpen()
        note.replace(task: reopened)
        XCTAssertEqual(note.tasks[0].status, .done)
    }

    func testAnAlreadyTickedTaskAndATaskWithNoStepsAreLeftAlone() {
        let (date, cal) = day()
        var note = Note(relativePath: "a.md", kind: .project, body: "- [x] Done already\n  - [ ] Last step\n- [ ] Alone")
        let step = note.tasks[1]
        note.complete(task: step, at: date, calendar: cal)
        let underDone = note.tickParentsWhenStepsDone(afterTicking: step, at: date, calendar: cal)
        XCTAssertTrue(underDone.isEmpty)
        let alone = note.tasks[2]
        note.complete(task: alone, at: date, calendar: cal)
        let noParent = note.tickParentsWhenStepsDone(afterTicking: alone, at: date, calendar: cal)
        XCTAssertTrue(noParent.isEmpty)
    }

    func testItGoesUpALevelAndARepeatingParentGetsItsNextTime() {
        let (date, cal) = day()
        var note = Note(relativePath: "a.md", kind: .project, body: """
        - [ ] Move house
          - [x] Find a van
          - [ ] Pack the kitchen
            - [ ] Wrap the plates
        - [ ] Clean the car >2026-11-21 @repeat(weekly)
          - [ ] Vacuum
        """)
        let plates = note.tasks[3]
        note.complete(task: plates, at: date, calendar: cal)
        let up = note.tickParentsWhenStepsDone(afterTicking: plates, at: date, calendar: cal)
        XCTAssertEqual(up.map { $0.title }, ["Pack the kitchen", "Move house"])
        XCTAssertEqual(note.tasks.filter { $0.status == .done }.count, 4)
        let vacuum = note.tasks.first { $0.title == "Vacuum" }!
        note.complete(task: vacuum, at: date, calendar: cal)
        let car = note.tickParentsWhenStepsDone(afterTicking: vacuum, at: date, calendar: cal)
        XCTAssertEqual(car.map { $0.title }, ["Clean the car"])
        // The same path as any tick: the next time of the repeat is there, open.
        XCTAssertTrue(note.tasks.contains { $0.title == "Clean the car" && $0.status == .open && ($0.dueDate ?? DateOnly(year: 2026, month: 11, day: 21)) > DateOnly(year: 2026, month: 11, day: 21) },
                      note.body)
    }

    func testABoxInTheTextTicksTheTaskAboveTooAndSaysSo() {
        let (date, cal) = day()
        let text = "# Trip\n- [ ] Plan the trip\n  - [x] Book the train\n  - [ ] Book the hotel\nNotes\n"
        let offset = (text as NSString).range(of: "- [ ] Book the hotel").location + 3
        let tick = TaskBox.tick(text, at: offset, date: date, calendar: cal)!
        XCTAssertEqual(tick.parentsDone, ["Plan the trip"])
        XCTAssertTrue(tick.text.contains("- [x] Plan the trip @done(2026-11-21"), tick.text)
        XCTAssertTrue(tick.text.contains("  - [x] Book the hotel @done(2026-11-21"), tick.text)
        XCTAssertTrue(tick.text.hasSuffix("\nNotes\n"), tick.text)
        XCTAssertEqual(TaskBox.toggled(text, at: offset, date: date, calendar: cal), tick.text)
        // Opening the step again in the text leaves the task above ticked.
        let hotelAgain = (tick.text as NSString).range(of: "  - [x] Book the hotel").location + 5
        let again = TaskBox.tick(tick.text, at: hotelAgain, date: date, calendar: cal)!
        XCTAssertTrue(again.parentsDone.isEmpty)
        XCTAssertTrue(again.text.contains("- [x] Plan the trip"), again.text)
        XCTAssertTrue(again.text.contains("  - [ ] Book the hotel"), again.text)
    }

    func testTheMessageNamesTheTasks() {
        XCTAssertNil(SmallSteps.parentsDoneMessage([]))
        XCTAssertEqual(SmallSteps.parentsDoneMessage(["Pack"]), "All steps done, so “Pack” is done too.")
        XCTAssertEqual(SmallSteps.parentsDoneMessage(["A", "B", "C"]), "All steps done, so “A”, “B” and “C” are done too.")
    }
}
