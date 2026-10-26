import XCTest
@testable import ParagonCore

/// Build 267: the Done screen tells each day's story, for twelve calendar weeks, in one pass.
final class DoneDiaryTests: XCTestCase {
    /// Wednesday 21 October 2026, in week 43 (Monday 19 to Sunday 25 October). Eleven weeks
    /// before that week is week 32, which starts on Monday 3 August.
    private let today = DateOnly(year: 2026, month: 10, day: 21)

    private func date(_ month: Int, _ day: Int, _ year: Int = 2026) -> DateOnly {
        DateOnly(year: year, month: month, day: day)
    }

    private func daily(_ month: Int, _ day: Int, _ body: String) -> Note {
        let name = String(format: "2026%02d%02d", month, day)
        return Note(relativePath: "Calendar/\(name).md", kind: .daily,
                    text: "---\ntitle: \(name)\n---\n\(body)")
    }

    private func project(_ title: String, _ frontmatter: String = "", body: String) -> Note {
        Note(relativePath: "Projects/\(title).md", kind: .project,
             text: "---\ntitle: \(title)\ntype: project\n\(frontmatter)---\n# \(title)\n\n\(body)")
    }

    /// A day record holding `count` finished tasks, for the wording tests.
    private func record(_ count: Int, worked: Int? = nil, evening: String = "") -> DayRecord {
        let lines = (0..<count).map { "- [x] Task \($0) @done(2026-10-21)" }.joined(separator: "\n")
        let note = project("Shed", body: lines + "\n")
        let refs = note.tasks.map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
        return DayRecord(day: today, finished: refs, workedMinutes: worked, lookingBack: evening)
    }

    // MARK: The window

    func testTheDiaryCoversTwelveCalendarWeeks() {
        XCTAssertEqual(DoneDiary.weeks, 12)
        XCTAssertEqual(DoneDiary.firstDay(today: today), date(8, 3))
        // Any day of the same week gives the same first Monday.
        XCTAssertEqual(DoneDiary.firstDay(today: date(10, 19)), date(8, 3))
        XCTAssertEqual(DoneDiary.firstDay(today: date(10, 25)), date(8, 3))
        XCTAssertEqual(DoneDiary.firstDay(today: date(10, 26)), date(8, 10))
    }

    func testTheFirstMondayIsInAndTheSundayBeforeIsOut() {
        let shed = project("Shed", body: """
        - [x] First day of the window @done(2026-08-03 09:00)
        - [x] The Sunday before @done(2026-08-02 18:00)
        """)
        let diary = NoteIndex(notes: [shed]).doneDiary(today: today)
        XCTAssertEqual(diary.days.map(\.day), [date(8, 3)])
        XCTAssertEqual(diary.finishedTotal, 1)
        // Out of the window, but still the first task ever finished.
        XCTAssertEqual(diary.firstFinished, date(8, 2))
    }

    // MARK: One rule for a finished task

    /// The diary's days and `tasksCompleted(on:)` are one rule, so the list and the number
    /// beside **Done** in the sidebar can never disagree.
    func testEveryDayAgreesWithTasksCompleted() {
        let shed = project("Shed", body: """
        - [x] Pour the base @done(2026-10-21 09:10)
        - [x] Raise the walls @done(2026-10-15 16:00)
          - [x] Nail the corners @done(2026-10-15 15:00)
        - [x] Order the wood @done(2026-09-01)
        - [x] Ticked with no stamp
        - [-] Cancelled @done(2026-10-20 10:00)
        - [ ] Still open
        """)
        let garden = project("Garden", body: "- [x] Rake @done(2026-10-15)\n- [x] Plant @done(2026-08-03)\n")
        let monday = daily(10, 19, "## Tasks\n\n- [x] Call the bank @done(2026-10-19 11:00)\n")
        let index = NoteIndex(notes: [shed, garden, monday])
        let diary = index.doneDiary(today: today)
        var day = DoneDiary.firstDay(today: today)
        while day <= today {
            XCTAssertEqual(diary.day(day)?.finished.map(\.id) ?? [],
                           index.tasksCompleted(on: day).map(\.id), "\(day)")
            day = day.adding(days: 1)
        }
        XCTAssertEqual(diary.days.map(\.day), [date(10, 21), date(10, 19), date(10, 15), date(9, 1), date(8, 3)])
        XCTAssertEqual(diary.day(date(10, 15))?.finished.count, 3)
        XCTAssertEqual(diary.finishedTotal, 7)
        XCTAssertEqual(diary.finishedThisWeek, 2)
    }

    func testAStampInTheFutureAndACancelledTaskAreLeftOut() {
        let shed = project("Shed", body: """
        - [x] Tomorrow, typed by hand @done(2026-10-22)
        - [-] Cancelled @done(2026-10-20 10:00)
        """)
        let diary = NoteIndex(notes: [shed]).doneDiary(today: today)
        XCTAssertTrue(diary.days.isEmpty)
        XCTAssertEqual(diary.finishedThisWeek, 0)
        XCTAssertEqual(diary.finishedTotal, 0)
        XCTAssertNil(diary.firstFinished, "A stamp after today is no one's first finish.")
    }

    // MARK: Quiet days

    /// His answer 7a: a day with no tick, but a line from **Close the day** or time on the focus
    /// timer, is listed. A day whose note holds only a plan, or nothing, is not.
    func testAQuietDayIsListedAndAnEmptyOneIsNot() {
        let wrote = daily(10, 20, "## Tasks\n\n## Looking back\n\nA quiet day by the sea.\n")
        let worked = daily(10, 18, "## Worked\n\n- 08:00-08:45 Read\n")
        let planned = daily(10, 17, "## Plan\n\nTB: 09:00-10:00 Swim\n")
        let empty = daily(10, 16, "## Tasks\n")
        let diary = NoteIndex(notes: [wrote, worked, planned, empty]).doneDiary(today: today)
        XCTAssertEqual(diary.days.map(\.day), [date(10, 20), date(10, 18)])
        XCTAssertEqual(diary.day(date(10, 20))?.factsText, "Nothing ticked off")
        XCTAssertEqual(diary.day(date(10, 20))?.eveningLine, "A quiet day by the sea.")
        XCTAssertEqual(diary.day(date(10, 18))?.factsText, "Nothing ticked off \u{00B7} 45 min worked")
        XCTAssertNil(diary.day(date(10, 18))?.eveningLine)
    }

    func testWorkedIsAddedUpAndNilWhenTheTimerWasNotUsed() {
        let monday = daily(10, 19, """
        ## Tasks

        - [x] Write the offer @done(2026-10-19 09:00)

        ## Worked

        - 08:00-08:45 Write the offer

        - 09:00-10:00 Call the bank
        """)
        let tuesday = daily(10, 20, "## Tasks\n\n- [x] Rest @done(2026-10-20)\n")
        let diary = NoteIndex(notes: [monday, tuesday]).doneDiary(today: today)
        XCTAssertEqual(diary.day(date(10, 19))?.workedMinutes, 105)
        XCTAssertEqual(diary.day(date(10, 19))?.factsText, "1 done \u{00B7} 1 h 45 min worked")
        XCTAssertNil(diary.day(date(10, 20))?.workedMinutes)
        XCTAssertEqual(diary.day(date(10, 20))?.factsText, "1 done")
    }

    // MARK: Words

    func testTheFactsLineNeverSaysZero() {
        XCTAssertEqual(DiaryDay(record: record(6, worked: 160), served: []).factsText,
                       "6 done \u{00B7} 2 h 40 min worked")
        XCTAssertEqual(DiaryDay(record: record(1), served: []).factsText, "1 done")
        XCTAssertEqual(DiaryDay(record: record(0, worked: 45), served: []).factsText,
                       "Nothing ticked off \u{00B7} 45 min worked")
        XCTAssertEqual(DiaryDay(record: record(0, evening: "Fine."), served: []).factsText,
                       "Nothing ticked off")
        XCTAssertFalse(DiaryDay(record: record(0), served: []).hasSomething)
        XCTAssertNil(DiaryDay(record: record(0, evening: "  \n "), served: []).eveningLine)
    }

    func testTheSpokenSentenceCarriesTheWholeCard() {
        let day = DiaryDay(record: record(2, worked: 30, evening: "Good start."),
                           served: [ServedCount(title: "Be strong", kind: .goal, count: 2)])
        let spoken = day.spoken(dayName: "Today")
        XCTAssertTrue(spoken.hasPrefix("Today. 2 done, 30 min worked."), spoken)
        XCTAssertTrue(spoken.contains("What it served: Be strong 2."), spoken)
        XCTAssertTrue(spoken.contains("Good start."), spoken)
    }

    func testTheCountLineSaysWhatTheFileKnows() {
        let none = NoteIndex(notes: [project("Shed", body: "- [x] Ticked with no stamp\n")]).doneDiary(today: today)
        XCTAssertNil(none.firstFinished)
        XCTAssertNil(none.weekText, "With no stamp anywhere, a count would be a zero that only says the file cannot tell.")
        XCTAssertNil(none.totalText)
        XCTAssertNil(none.countText)

        let old = NoteIndex(notes: [project("Shed", body: "- [x] Long ago @done(2025-03-01)\n")]).doneDiary(today: today)
        XCTAssertEqual(old.firstFinished, date(3, 1, 2025))
        XCTAssertEqual(old.weekText, "Nothing done this week yet")
        XCTAssertEqual(old.totalText, "none in 12 weeks")

        let busy = NoteIndex(notes: [project("Shed", body: """
        - [x] A @done(2026-10-19)
        - [x] B @done(2026-10-21)
        - [x] C @done(2026-10-18)
        """)]).doneDiary(today: today)
        XCTAssertEqual(busy.weekText, "2 done this week")
        XCTAssertEqual(busy.totalText, "3 in 12 weeks")
        XCTAssertEqual(busy.countText, "2 done this week \u{00B7} 3 in 12 weeks")
    }

    // MARK: What it served

    func testTheLabelsSayWhatTheDayWentTowards() {
        let shed = project("Shed", "goal: Be strong and steady\n", body: """
        - [x] A @done(2026-10-21)
        - [x] B @done(2026-10-21)
        - [x] C @done(2026-10-21)
        """)
        let loose = project("Bathroom", body: "- [x] Tiles @done(2026-10-21)\n")
        let todayNote = daily(10, 21, "## Tasks\n\n- [x] Water the plants @done(2026-10-21)\n")
        let diary = NoteIndex(notes: [shed, loose, todayNote]).doneDiary(today: today)
        let labels = diary.day(today)?.served ?? []
        XCTAssertEqual(labels.map(\.title), ["Be strong and steady", "Bathroom", DoneDiary.ownNoteLabel])
        XCTAssertEqual(labels.map(\.count), [3, 1, 1])
        XCTAssertEqual(labels.first?.kind, .goal)
    }

    /// The day's own daily note is called "Daily note": the day's name is the line above it, and
    /// a label repeating the date would carry nothing (build 169). Only that note — a weekly note
    /// and another day's note keep their own names (review of 268).
    func testTheDaysOwnNoteIsCalledDailyNote() {
        let own = "Wednesday 21 October 2026"
        let counts = [ServedCount(title: "Monday 19 October 2026", kind: .note(.daily), count: 1),
                      ServedCount(title: "Garden", kind: .area, count: 1),
                      ServedCount(title: own, kind: .note(.daily), count: 2)]
        let labels = DoneDiary.labels(counts, ownNoteTitle: own)
        XCTAssertEqual(labels.map(\.title), [DoneDiary.ownNoteLabel, "Garden", "Monday 19 October 2026"])
        XCTAssertEqual(labels.map(\.count), [2, 1, 1])

        let one = DoneDiary.labels([ServedCount(title: own, kind: .note(.daily), count: 1)], ownNoteTitle: own)
        XCTAssertEqual(one.map(\.title), [DoneDiary.ownNoteLabel])

        // A weekly note is a daily note by its folder, and keeps its own name.
        let week = [ServedCount(title: "Week 43, 19 Oct – 25 Oct 2026", kind: .note(.daily), count: 3)]
        XCTAssertEqual(DoneDiary.labels(week, ownNoteTitle: own), week)

        let noDaily = [ServedCount(title: "Garden", kind: .area, count: 1)]
        XCTAssertEqual(DoneDiary.labels(noDaily, ownNoteTitle: own), noDaily)
    }

    // MARK: The shared pass

    /// The Weekly review's step 7 reads the same records through `dayRecords(from:through:)`,
    /// which now goes through the pass the diary uses. It must not have moved.
    func testTheWeekStillReadsTheSameRecords() {
        let shed = project("Shed", body: "- [x] A @done(2026-10-12 09:10)\n- [x] B @done(2026-10-14)\n")
        let index = NoteIndex(notes: [shed])
        let week = WeekRef(year: 2026, week: 42)
        let records = index.dayRecords(from: week.monday, through: week.sunday)
        XCTAssertEqual(records.map(\.day), week.days)
        XCTAssertEqual(records.map(\.finished.count), [1, 0, 1, 0, 0, 0, 0])
        XCTAssertTrue(index.dayRecords(from: week.sunday, through: week.monday).isEmpty)
    }
}
