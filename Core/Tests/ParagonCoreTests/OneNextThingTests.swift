import XCTest
@testable import ParagonCore

final class OneNextThingTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 11, day: 17)
    private func day(_ d: Int) -> DateOnly { DateOnly(year: 2026, month: 11, day: d) }
    private var line = 0

    private func ref(_ title: String, due: DateOnly? = nil, time: TimeOfDay? = nil,
                     status: TaskItem.Status = .open, tags: [String] = [], id: String? = nil) -> TaskRef {
        line += 1
        let task = TaskItem(status: status, title: title, dueDate: due, dueTime: time,
                            tags: tags, id: id, lineIndex: line)
        return TaskRef(notePath: "Inbox.md", noteTitle: "Inbox", task: task)
    }

    func testLongestOverdueBeatsDueToday() {
        let refs = [ref("today", due: today), ref("recent", due: day(16)), ref("oldest", due: day(10))]
        let pick = OneNextThing.pick(from: refs, today: today)
        XCTAssertEqual(pick?.ref.task.title, "oldest")
        XCTAssertEqual(pick?.reason, .overdue(days: 7))
    }

    func testDueTodayGoesByTimeTimedBeforeUntimed() {
        let refs = [ref("none", due: today),
                    ref("late", due: today, time: TimeOfDay(hour: 16, minute: 0)),
                    ref("early", due: today, time: TimeOfDay(hour: 9, minute: 30))]
        XCTAssertEqual(OneNextThing.queue(from: refs, today: today).map(\.ref.task.title),
                       ["early", "late", "none"])
    }

    func testNextActionComesOnlyAfterEverythingDue() {
        let refs = [ref("next", tags: ["next"]), ref("due", due: today)]
        let queue = OneNextThing.queue(from: refs, today: today)
        XCTAssertEqual(queue.map(\.ref.task.title), ["due", "next"])
        XCTAssertEqual(queue.last?.reason, .nextAction)
    }

    func testDoneSomedayWaitingAndFutureAreNeverPicked() {
        let refs = [ref("done", due: day(1), status: .done),
                    ref("cancelled", due: day(1), status: .cancelled),
                    ref("someday", due: day(1), tags: ["someday"]),
                    ref("Waiting for Anna: reply", due: day(1), tags: ["waiting"]),
                    ref("future", due: day(20)),
                    ref("future next", due: day(20), tags: ["next"])]
        XCTAssertNil(OneNextThing.pick(from: refs, today: today))
    }

    func testSetAsideTaskIsSkippedAndTheNextComes() {
        let first = ref("first", due: day(10), id: "t1")
        let second = ref("second", due: day(12))
        let aside: Set<String> = [OneNextThing.key(for: first)]
        XCTAssertEqual(OneNextThing.key(for: first), "t1")
        XCTAssertEqual(OneNextThing.key(for: second), "Inbox.md#second")
        XCTAssertEqual(OneNextThing.pick(from: [first, second], today: today, setAside: aside)?.ref.task.title, "second")
    }

    func testNothingLeftGivesNil() {
        let only = ref("only", due: today)
        XCTAssertNil(OneNextThing.pick(from: [], today: today))
        XCTAssertNil(OneNextThing.pick(from: [only], today: today, setAside: [OneNextThing.key(for: only)]))
    }

    /// Build 332: with Today's own next actions handed in, group 3 is exactly those — a
    /// project's first open line counts without a `#next`, and a line already shown as due
    /// is not named twice.
    func testTodaysNextActionsAreTheThirdGroup() throws {
        let today = DateOnly(year: 2026, month: 11, day: 17)
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        var a = try vault.createNote(kind: .project, title: "A")
        a.body = "- [ ] First open line of A\n- [ ] Second line\n"
        try vault.save(a)
        var b = try vault.createNote(kind: .project, title: "B")
        b.body = "- [ ] Due line of B >2026-11-17\n"
        try vault.save(b)
        let index = NoteIndex(notes: try vault.allNotes())
        let queue = OneNextThing.queue(in: index, today: today)
        XCTAssertEqual(queue.map(\.ref.task.title).map { $0.contains("Due line") ? "due" : $0 },
                       ["due", "First open line of A"])
        XCTAssertEqual(queue.map(\.reason), [.dueToday, .nextAction])
        XCTAssertEqual(OneNextThing.words(for: queue[0], today: today), "Due today")
        XCTAssertEqual(OneNextThing.words(for: queue[1], today: today), "Next action")
    }

    /// Build 332: what Not now set aside is forgotten the next day.
    func testWhatWasSetAsideCountsForOneDay() {
        let today = DateOnly(year: 2026, month: 11, day: 17)
        XCTAssertEqual(OneNextThing.setAside(["t1"], writtenOn: "2026-11-17", today: today), ["t1"])
        XCTAssertTrue(OneNextThing.setAside(["t1"], writtenOn: "2026-11-16", today: today).isEmpty)
        XCTAssertTrue(OneNextThing.setAside(["t1"], writtenOn: nil, today: today).isEmpty)
    }
}
