import XCTest
@testable import ParagonCore

/// Build 317: a task ticked on a widget, the Lock Screen's words, and what the focus timer's
/// Live Activity is told. One small test per rule.
final class WidgetTickTests: XCTestCase {

    private let today = DateOnly(year: 2026, month: 11, day: 13)
    private let noon = Date(timeIntervalSince1970: 1_794_000_000)

    private func note(_ body: String) -> Note {
        Note(relativePath: "Projects/Race.md", kind: .project,
             text: "---\ntitle: Race\ntype: project\n---\n" + body)
    }

    private func tick(_ title: String, id: String? = nil, due: DateOnly? = nil,
                      key: String = "Projects/Race.md#4", seconds: TimeInterval = 0, ticked: Bool = true) -> WidgetTick {
        WidgetTick(key: key, notePath: "Projects/Race.md", taskID: id, title: title, due: due,
                   at: noon.addingTimeInterval(seconds), ticked: ticked)
    }

    func testATickLandsOnItsOwnTaskAndOnNoOther() {
        let race = note("""
        - [ ] Book the hotel >2026-11-13
        - [x] Pay the fee
        - [ ] Pack
        - [ ] Pack
        """)
        // Found by its exact words and date.
        guard case .tick(let found) = tick("Book the hotel", due: today).outcome(in: race, notesStillArriving: false) else {
            return XCTFail("the open task was not found")
        }
        XCTAssertEqual(found.title, "Book the hotel")
        // Same words, another date: a repeating task's next copy is never taken for it.
        XCTAssertEqual(tick("Book the hotel", due: nil).outcome(in: race, notesStillArriving: false), .gone)
        // Already done elsewhere, or two that cannot be told apart: nothing is ticked.
        XCTAssertEqual(tick("Pay the fee").outcome(in: race, notesStillArriving: false), .gone)
        XCTAssertEqual(tick("Pack").outcome(in: race, notesStillArriving: false), .gone)
        // The note is not here: wait while iCloud is still bringing notes, else drop it.
        XCTAssertEqual(tick("Pack").outcome(in: nil, notesStillArriving: true), .wait)
        XCTAssertEqual(tick("Pack").outcome(in: nil, notesStillArriving: false), .gone)
    }

    func testTheLastPressOnALineCountsAndNothingIsLostBetweenTwoWriters() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let queue = WidgetTickQueue(container: folder)
        XCTAssertEqual(queue.pending(), [])
        try queue.append(tick("Book the hotel", seconds: 0))
        try queue.append(tick("Pack", key: "Projects/Race.md#6", seconds: 1))
        try queue.append(tick("Pack", key: "Projects/Race.md#6", seconds: 2, ticked: false))   // taken back
        XCTAssertEqual(queue.pending().map(\.title), ["Book the hotel"])
        // The app takes them; a press made after that is in a fresh file.
        XCTAssertEqual(queue.drain().map(\.title), ["Book the hotel"])
        try queue.append(tick("Pay", key: "Projects/Race.md#7", seconds: 3))
        XCTAssertEqual(queue.pending().map(\.title), ["Pay"])
        XCTAssertEqual(queue.drain().count, 1)
        XCTAssertEqual(queue.drain(), [])
    }

    func testAWaitingTickIsDrawnTickedAndLeavesTheLockScreensCount() {
        let race = note("""
        - [ ] Book the hotel >2026-11-13
        - [ ] Long ride >2026-11-11
        - [ ] Order the saddle #next
        """)
        let snapshot = NoteIndex(notes: [race]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0, written: noon)
        XCTAssertEqual(snapshot.dueToday, 1)
        XCTAssertEqual(snapshot.overdue, 1)
        // The line carries what a tick needs, with the words exactly as the note has them.
        let next = snapshot.items[2]
        XCTAssertEqual(next.title, "Order the saddle")
        XCTAssertEqual(next.tick(at: noon)?.title, "Order the saddle #next")
        let ticks = [snapshot.items[0].tick(at: noon), snapshot.items[1].tick(at: noon)].compactMap { $0 }
        XCTAssertEqual(snapshot.tickedIDs(ticks), [snapshot.items[0].id, snapshot.items[1].id])
        let settled = snapshot.settled(ticks)
        XCTAssertEqual(settled.dueToday, 0)
        XCTAssertEqual(settled.overdue, 0)
        XCTAssertEqual(settled.items.map(\.title), ["Order the saddle"])
        // A file from before build 317 has no note path: no tick can be made from it.
        let old = WidgetSnapshot.Item(id: "1", title: "Old", noteTitle: "N", noteKind: "project", dueText: nil,
                                      isOverdue: false, serves: nil, servesIsGoal: false, url: "amspara://")
        XCTAssertNil(old.tick(at: noon))
    }

    func testWhatTheLockScreenSays() {
        func snapshot(due: Int, over: Int, titles: [String] = []) -> WidgetSnapshot {
            WidgetSnapshot(day: today, written: noon, dueToday: due, overdue: over, inboxCount: 0, dueForReview: 0,
                           items: titles.enumerated().map { index, title in
                               WidgetSnapshot.Item(id: "\(index)", title: title, noteTitle: "N", noteKind: "project",
                                                   dueText: nil, isOverdue: false, serves: nil, servesIsGoal: false,
                                                   url: "amspara://")
                           })
        }
        XCTAssertEqual(LockGlance.inline(snapshot(due: 3, over: 0), on: today), "3 due today")
        XCTAssertEqual(LockGlance.inline(snapshot(due: 3, over: 1), on: today), "3 due today, 1 overdue")
        XCTAssertEqual(LockGlance.inline(snapshot(due: 0, over: 2), on: today), "2 overdue")
        XCTAssertEqual(LockGlance.inline(snapshot(due: 0, over: 0), on: today), "Nothing due today")
        XCTAssertEqual(LockGlance.count(snapshot(due: 3, over: 1), on: today), 4)
        XCTAssertEqual(LockGlance.lines(snapshot(due: 3, over: 0, titles: ["A", "B", "C"]), on: today), ["A", "B"])
        XCTAssertEqual(LockGlance.emptyText(snapshot(due: 0, over: 0), on: today), "Nothing due, nothing waiting")
        // No file, or yesterday's file: never an old number beside today's clock.
        let tomorrow = DateOnly(year: 2026, month: 11, day: 14)
        XCTAssertEqual(LockGlance.inline(nil, on: today), "Open PARAGON")
        XCTAssertEqual(LockGlance.inline(snapshot(due: 3, over: 0), on: tomorrow), "Open PARAGON")
        XCTAssertNil(LockGlance.count(snapshot(due: 3, over: 0), on: tomorrow))
        XCTAssertEqual(LockGlance.lines(snapshot(due: 3, over: 0, titles: ["A"]), on: tomorrow), [])
        XCTAssertEqual(LockGlance.emptyText(nil, on: today), "Open PARAGON")
    }

    func testWhatTheLiveActivityIsTold() {
        var session = FocusSession(notePath: nil, taskTitle: "Write", title: "Write", plannedMinutes: 45, startedAt: noon)
        // Running: the clock counts from the start, whatever moment is asked.
        let first = FocusGlance(session: session, at: noon.addingTimeInterval(600))
        XCTAssertFalse(first.isPaused)
        XCTAssertEqual(first.countsFrom, noon)
        XCTAssertEqual(first.plannedEnd, noon.addingTimeInterval(45 * 60))
        XCTAssertEqual(first.note, "of 45 min")
        XCTAssertEqual(FocusGlance(session: session, at: noon.addingTimeInterval(700)).countsFrom, first.countsFrom)
        // Paused after ten minutes: a fixed clock and a bar that stands still.
        session.pause(at: noon.addingTimeInterval(600))
        let paused = FocusGlance(session: session, at: noon.addingTimeInterval(900))
        XCTAssertTrue(paused.isPaused)
        XCTAssertEqual(paused.clock, "10:00")
        XCTAssertEqual(paused.note, "of 45 min \u{00B7} paused")
        XCTAssertEqual(paused.fraction ?? 0, 600.0 / 2700.0, accuracy: 0.0001)
        XCTAssertEqual(paused, FocusGlance(session: session, at: noon.addingTimeInterval(5000)))
        XCTAssertEqual(FocusGlance(session: session, at: noon, awaitingAnswer: true).note, "stopped")
        // Going on five minutes later: the pause is left out of the count.
        session.resume(at: noon.addingTimeInterval(900))
        let again = FocusGlance(session: session, at: noon.addingTimeInterval(960))
        XCTAssertEqual(again.countsFrom, noon.addingTimeInterval(300))
        XCTAssertEqual(again.workedSeconds, 660)
        XCTAssertEqual(session.startedAt, noon)
        // Nothing planned: no bar and no "of".
        let free = FocusGlance(session: FocusSession(notePath: nil, taskTitle: "T", title: "T", plannedMinutes: nil, startedAt: noon), at: noon)
        XCTAssertNil(free.note)
        XCTAssertNil(free.plannedEnd)
        XCTAssertNil(free.fraction)
    }
}
