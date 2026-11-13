import XCTest
@testable import ParagonCore

/// Build 316, the fixes after the code review: living beside a device that is still on build
/// 315, and the small rules of plain-word dates, repeats and the recorded capture key.
final class Round9FixTests: XCTestCase {
    /// Friday 13 November 2026.
    private let today = DateOnly(year: 2026, month: 11, day: 13)
    private let cal = WeekRef.calendar

    private func line(_ text: String) -> String {
        PlainDate.line(text, understoodOn: today, calendar: cal)
    }

    // MARK: 1 — a repeat build 315 cannot read is written with its id

    func testANewKindOfRepeatGetsItsIDAtOnce() {
        var note = Note(relativePath: "Inbox.md", kind: .inbox, text: "## Tasks\n\n- [ ] Gym\n- [ ] Rent\n- [ ] Read ^t000001\n")
        // Choosing the repeat (what `AppModel.setRepeat` does).
        var gym = note.tasks[0]
        gym.repeatRule = RepeatRule("mon,wed,fri")
        XCTAssertTrue(note.replace(task: gym))
        let written = note.tasks[0]
        XCTAssertEqual(written.repeatRule?.description, "mon,wed,fri")
        XCTAssertNotNil(written.id, "nothing is left for build 315 to rewrite")
        XCTAssertNotEqual(written.id, "t000001")
        // A repeat 315 can read stays as it was: its id comes from the sync.
        var rent = note.tasks[1]
        rent.repeatRule = RepeatRule("monthly")
        note.replace(task: rent)
        XCTAssertNil(note.tasks[1].id)
        // A new task typed with one, and the next copy after a tick.
        let added = note.append(task: TaskParser.normalized(TaskItem(title: "Report @repeat(monthend)")))
        XCTAssertNotNil(added.id)
        let next = note.complete(task: note.tasks[0], at: today.date(calendar: cal)!, calendar: cal)
        XCTAssertNotNil(next?.id)
        XCTAssertNotEqual(next?.id, written.id)
        let ticked = TaskBox.toggled("- [ ] Water @repeat(10d after done)", at: 3, date: today.date(calendar: cal)!, calendar: cal)!
        XCTAssertNotNil(TaskParser.parse(text: ticked).last?.id)
    }

    // MARK: 2 — a deadline in a reminder's title (a device on build 315 puts it there)

    func testADeadlineInAReminderTitleIsKeptAndNeverComesBackIntoTheTaskTitle() async throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        let store = InMemoryRemindersStore()
        let engine = SyncEngine(vault: vault, store: store, deviceID: "d316")
        func write(_ body: String) throws {
            var inbox = try vault.loadNote(relativePath: "Inbox.md")
            inbox.body = body
            try vault.save(inbox)
        }
        func task() throws -> TaskItem { try vault.loadNote(relativePath: "Inbox.md").tasks[0] }
        func reminder() async throws -> ReminderRecord { try await store.reminders(inList: "Inbox")[0] }

        try write("## Tasks\n\n- [ ] Renew passport @deadline(2026-11-20)\n")
        try await engine.run()
        // Alone, 316 sends no deadline to Reminders.
        var r = try await reminder()
        XCTAssertEqual(r.title, "Renew passport")

        // A device on 315 writes the mark into the title. 316 sees no change and no loop.
        r.title = "Renew passport @deadline(2026-11-20)"
        try await store.update(r)
        let quiet = try await engine.run()
        XCTAssertEqual(quiet.changeCount, 0)
        XCTAssertEqual(try task().title, "Renew passport")

        // Note to reminder: a new title and a new deadline keep the mark, with the new day.
        let id = try XCTUnwrap(try task().id)
        try write("## Tasks\n\n- [ ] Renew my passport @deadline(2026-11-25) ^\(id)\n")
        try await engine.run()
        r = try await reminder()
        XCTAssertEqual(r.title, "Renew my passport @deadline(2026-11-25)")

        // Reminder to note: ticked in Reminders. The title stays clean, the deadline stays, once.
        r.isCompleted = true
        try await store.update(r)
        try await engine.run()
        let done = try task()
        XCTAssertTrue(done.isDone)
        XCTAssertEqual(done.title, "Renew my passport")
        XCTAssertEqual(done.deadline, DateOnly(year: 2026, month: 11, day: 25))
        XCTAssertEqual(done.serialized.components(separatedBy: "@deadline(").count, 2)
        let after = try await engine.run()
        XCTAssertEqual(after.changeCount, 0)

        // A task without a deadline never takes a mark off a title, and never adds one.
        var plain = ReminderRecord(listName: "Inbox", title: "Call @deadline(2026-12-01)")
        engine.apply(task: TaskItem(title: "Call Anna"), to: &plain, listName: "Inbox")
        XCTAssertEqual(plain.title, "Call Anna @deadline(2026-12-01)")
        var bare = ReminderRecord(listName: "Inbox", title: "Call")
        engine.apply(task: TaskItem(title: "Call Anna", deadline: today), to: &bare, listName: "Inbox")
        XCTAssertEqual(bare.title, "Call Anna")
    }

    // MARK: 3 — the task line's own marks are not a do-day

    func testADateInsideAMarkIsNotReadAsTheDoDay() {
        XCTAssertEqual(line("Renew passport @deadline(2026-12-01)"), "Renew passport @deadline(2026-12-01)")
        XCTAssertEqual(line("Wait for Anna @since(2026-11-01)"), "Wait for Anna @since(2026-11-01)")
        XCTAssertEqual(line("Old @done(2026-11-01 10:00)"), "Old @done(2026-11-01 10:00)")
        XCTAssertEqual(TaskParser.parse(line: "- [ ] " + line("Renew passport @deadline(2026-12-01)"))?.deadline,
                       DateOnly(year: 2026, month: 12, day: 1))
        // The words beside the mark are still read.
        XCTAssertEqual(line("Renew passport tomorrow @deadline(2026-12-01)"), "Renew passport >2026-11-14 @deadline(2026-12-01)")
    }

    // MARK: 5, 6 — money is not a time, and "at 2" is the afternoon

    func testMoneyIsNotATimeOfDay() {
        XCTAssertEqual(line("Pay Anna tomorrow 12.50 kr"), "Pay Anna >2026-11-14 12.50 kr")
        XCTAssertEqual(line("Pay rent tomorrow 45.00"), "Pay rent >2026-11-14 45.00")
        XCTAssertEqual(line("Call tomorrow 25:00"), "Call >2026-11-14 25:00")
        // With nothing after it, the dot is still a time.
        XCTAssertEqual(line("Call Anna tomorrow 14.00"), "Call Anna >2026-11-14T14:00")
        XCTAssertEqual(line("Call Anna tomorrow 2.30 pm"), "Call Anna >2026-11-14T14:30")
        XCTAssertEqual(line("Call Anna tomorrow 14:00 sharp"), "Call Anna >2026-11-14T14:00 sharp")
    }

    func testABareAtNumberIsTheAfternoon() {
        XCTAssertEqual(line("Call Anna tomorrow at 2"), "Call Anna >2026-11-14T14:00")
        XCTAssertEqual(line("Call Anna tomorrow at 6"), "Call Anna >2026-11-14T18:00")
        XCTAssertEqual(line("Call Anna tomorrow at 7"), "Call Anna >2026-11-14T07:00")
        XCTAssertEqual(line("Call Anna tomorrow at 12"), "Call Anna >2026-11-14T12:00")
        XCTAssertEqual(line("Call Anna tomorrow at 14"), "Call Anna >2026-11-14T14:00")
        XCTAssertEqual(line("Call Anna tomorrow at 2am"), "Call Anna >2026-11-14T02:00")
        XCTAssertEqual(line("Call Anna tomorrow at 2:00"), "Call Anna >2026-11-14T02:00")
    }

    // MARK: 7 — a repeat is never dropped

    func testAfterDoneOnWeekdaysIsLeftOutAndAnUnknownRepeatIsKept() {
        XCTAssertEqual(RepeatRule("weekdays after done"), .workingDays)
        XCTAssertEqual(RepeatRule("monthend after done"), .lastDayOfMonth)
        XCTAssertEqual(RepeatRule("mon,thu after done")?.description, "mon,thu")
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Report @repeat(monthend after done)")?.serialized, "- [ ] Report @repeat(monthend)")

        // A rule a newer build wrote: not understood, and written back as it was.
        let newer = "- [ ] Tax >2026-11-13 @repeat(first monday of the month) ^t0a1b2c"
        var task = TaskParser.parse(line: newer)!
        XCTAssertNil(task.repeatRule)
        XCTAssertEqual(task.title, "Tax")
        XCTAssertEqual(task.serialized, newer)
        task.dueDate = today.adding(days: 1, calendar: cal)
        XCTAssertEqual(TaskParser.normalized(task).serialized, "- [ ] Tax >2026-11-14 @repeat(first monday of the month) ^t0a1b2c")
        // Choosing a repeat, or "Does not repeat", replaces it.
        task.repeatRule = nil
        XCTAssertFalse(task.serialized.contains("@repeat"))
    }

    // MARK: 4 — the recorded capture key

    func testARecordedKeyNeedsCommandOrControlAndIsNoEveryAppKey() {
        func key(_ held: UInt32, _ name: String) -> RecordedKey { RecordedKey(keyCode: 0, modifiers: held, keyName: name) }
        // ⌥ and a key types a sign on a Swedish keyboard: ⌥2 is "@".
        XCTAssertFalse(key(RecordedKey.option, "2").isAllowed)
        XCTAssertFalse(key(RecordedKey.option | RecordedKey.shift, "8").isAllowed)
        XCTAssertEqual(key(RecordedKey.option, "2").refusalLine, RecordedKey.refusedLine)
        XCTAssertTrue(key(RecordedKey.option | RecordedKey.command, "K").isAllowed)
        XCTAssertTrue(key(RecordedKey.control, "K").isAllowed)
        // Keys every app uses are refused, not warned about.
        for name in ["C", "V", "X", "Z", "A", "S", "Q", "W", "Tab", "Space"] {
            let refused = key(RecordedKey.command, name)
            XCTAssertFalse(refused.isAllowed, name)
            XCTAssertTrue(refused.refusalLine?.hasPrefix("\u{2318}\(name) is used in almost every app") ?? false, name)
        }
        // The same letter with one more key held is his to take.
        XCTAssertTrue(key(RecordedKey.control | RecordedKey.command, "C").isAllowed)
    }
}
