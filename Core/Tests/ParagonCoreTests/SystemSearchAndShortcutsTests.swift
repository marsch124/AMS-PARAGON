import XCTest
@testable import ParagonCore

/// Build 317: what goes into the system search (features-21) and what the Shortcuts and Siri
/// actions say and do (features-07). One small test per rule.
final class SystemSearchAndShortcutsTests: XCTestCase {
    private func note(_ path: String, kind: ParaKind, _ frontmatter: [(String, String)] = [], body: String = "") -> Note {
        var fm = Frontmatter()
        fm.set("title", String(path.split(separator: "/").last!.dropLast(3)))
        fm.set("type", kind.frontmatterType)
        for (key, value) in frontmatter { fm.set(key, value) }
        return Note(relativePath: path, kind: kind, frontmatter: fm, body: body)
    }

    private let today = DateOnly(year: 2026, month: 11, day: 13)

    // MARK: System search

    func testAResultShowsTitlePartAndTheFirstWords() {
        let ferry = note("Projects/Ferry trip.md", kind: .project, body: """
        # Ferry trip

        - [ ] Call **the bank** about [[Travel money]] ^t1a2b3c
        ![a picture](pictures/boat.png)
        Book the [cabin](https://example.com/cabin).
        """)
        let entry = SystemSearchRule.entry(for: ferry)
        XCTAssertEqual(entry?.title, "Ferry trip")
        XCTAssertEqual(entry?.partWord, "Project")
        XCTAssertEqual(entry?.snippet, "Call the bank about Travel money \u{00B7} Book the cabin.")
        XCTAssertEqual(entry?.resultLine, "Project \u{00B7} Call the bank about Travel money \u{00B7} Book the cabin.")
    }

    func testThePartOfEachKindOfNote() {
        let parts = [
            note("Areas/Health.md", kind: .area),
            note("Resources/Knots.md", kind: .resource),
            note("Goals/Sail to Gotland.md", kind: .goal),
            note("Goals/A calm life.md", kind: .goal, [("horizon", "life")]),
            note("Calendar/20261113.md", kind: .daily),
            note("Archive/Old boat.md", kind: .archive),
            note("Projects/Sold car.md", kind: .project, [("status", "archived")]),
        ].compactMap { SystemSearchRule.entry(for: $0) }
        XCTAssertEqual(parts.map(\.partWord),
                       ["Area", "Resource", "Goal", "Aspiration", "Daily note", "Archive", "Archive"])
        XCTAssertEqual(parts[4].title, "Friday 2026-11-13")
    }

    func testWorkNotesAndConflictCopiesAreNeverInTheIndex() {
        let notes = [
            note("Projects/Ferry trip.md", kind: .project),
            note("Work/Salary talk.md", kind: .resource),
            note("Projects/Ferry trip (conflict 2026-11-12 0930).md", kind: .project),
        ]
        XCTAssertEqual(SystemSearchRule.entries(for: notes).map(\.path), ["Projects/Ferry trip.md"])
    }

    func testALongNoteIsCutOnAWord() {
        let long = note("Resources/Long.md", kind: .resource,
                        body: (1...80).map { "word\($0) and more" }.joined(separator: "\n"))
        let snippet = SystemSearchRule.snippet(of: long)
        XCTAssertLessThanOrEqual(snippet.count, SystemSearchRule.snippetLimit + 1)
        XCTAssertTrue(snippet.hasSuffix("\u{2026}"))
    }

    func testOnlyWhatChangedIsHandedOver() {
        let ferry = note("Projects/Ferry trip.md", kind: .project, body: "Book the cabin.")
        let health = note("Areas/Health.md", kind: .area)
        let first = SystemSearchRule.entries(for: [ferry, health])
        let known = Dictionary(uniqueKeysWithValues: first.map { ($0.path, $0.fingerprint) })

        // Nothing changed: nothing to do.
        XCTAssertTrue(SystemSearchRule.changes(from: known, to: first).index.isEmpty)
        XCTAssertTrue(SystemSearchRule.changes(from: known, to: first).remove.isEmpty)

        // One note's text changed, one was renamed (a new path), so the old path goes.
        var edited = ferry
        edited.body = "Book two cabins."
        let moved = note("Areas/Body.md", kind: .area)
        let change = SystemSearchRule.changes(from: known, to: SystemSearchRule.entries(for: [edited, moved]))
        XCTAssertEqual(change.index.map(\.path), ["Projects/Ferry trip.md", "Areas/Body.md"])
        XCTAssertEqual(change.remove, ["Areas/Health.md"])
    }

    // MARK: What is due today?

    func testWhatIsDueTodayIsSpokenShort() {
        let project = note("Projects/Ferry trip.md", kind: .project, body: """
        - [ ] Call the bank #money >2026-11-13T14:00
        - [ ] Pack the bags >2026-11-13
        - [ ] Renew the passport >2026-11-10
        - [ ] Some day
        - [x] Done already >2026-11-13
        """)
        let old = note("Archive/Old.md", kind: .archive, body: "- [ ] Not this >2026-11-13\n")
        let answer = DueTodayAnswer(index: NoteIndex(notes: [project, old]), today: today)
        XCTAssertEqual(answer.due.map(\.title), ["Call the bank", "Pack the bags"])
        XCTAssertEqual(answer.overdueCount, 1)
        XCTAssertEqual(answer.spoken,
                       "2 things are due today: Call the bank at 14:00 and Pack the bags. One more is overdue.")
        XCTAssertEqual(answer.footnote, "1 overdue")
    }

    func testNothingDueAndALongDay() {
        XCTAssertEqual(DueTodayAnswer(day: today, due: [], overdueCount: 0).spoken, "Nothing is due today.")
        XCTAssertEqual(DueTodayAnswer(day: today, due: [], overdueCount: 2).spoken,
                       "Nothing is due today. 2 things are overdue.")
        let lines = (1...7).map { DueTodayAnswer.Line(id: "\($0)", title: "Task \($0)", time: nil, noteTitle: "N", priority: 0) }
        let long = DueTodayAnswer(day: today, due: lines, overdueCount: 0)
        XCTAssertEqual(long.spoken, "7 things are due today: Task 1, Task 2, Task 3, and 4 more.")
        XCTAssertEqual(long.shown.count, 5)
        XCTAssertEqual(long.footnote, "and 2 more")
    }

    // MARK: Start focus

    func testStartFocusPicksTheRunningBlockThenTheFirstDueTaskThenTheNextBlock() {
        let running = PlanBlock(start: 9 * 60, end: 10 * 60, title: "Write the plan")
        let later = PlanBlock(start: 15 * 60, end: 16 * 60, title: "Walk", index: 1)
        let task = TaskRef(notePath: "Projects/Ferry trip.md", noteTitle: "Ferry trip",
                           task: TaskItem(title: "Call the bank"))
        let during = NowAndNext(blocks: [running, later], minute: 9 * 60 + 30)
        let between = NowAndNext(blocks: [running, later], minute: 12 * 60)
        let evening = NowAndNext(blocks: [running, later], minute: 20 * 60)

        XCTAssertEqual(FocusPick.pick(plan: during, dueToday: [task]), .block(running))
        XCTAssertEqual(FocusPick.pick(plan: between, dueToday: [task]), .task(task))
        XCTAssertEqual(FocusPick.pick(plan: between, dueToday: []), .block(later))
        XCTAssertEqual(FocusPick.pick(plan: evening, dueToday: []), .nothing)
    }

    // MARK: Add to Inbox

    func testAddToInboxMakesOneInboxTaskAndADateTypedWins() {
        XCTAssertNil(ShortcutCapture.item(text: "  \n "))
        let plain = ShortcutCapture.item(text: "Buy\nmilk ")
        XCTAssertEqual(plain?.text, "Buy milk")
        XCTAssertEqual(plain?.target, .inbox)
        XCTAssertEqual(plain?.asTask, true)
        XCTAssertEqual(ShortcutCapture.answer(for: plain!, filed: true), "Added to your Inbox.")

        let dated = ShortcutCapture.item(text: "Buy milk", day: today)
        XCTAssertEqual(dated?.text, "Buy milk >2026-11-13")
        XCTAssertEqual(ShortcutCapture.answer(for: dated!, filed: true), "Added to your Inbox, for 2026-11-13.")

        let typed = ShortcutCapture.item(text: "Buy milk >2026-12-01", day: today)
        XCTAssertEqual(typed?.text, "Buy milk >2026-12-01")
        XCTAssertEqual(ShortcutCapture.answer(for: typed!, filed: false),
                       "Saved, for 2026-12-01. It goes into your Inbox the next time PARAGON opens your notes.")
    }
}
