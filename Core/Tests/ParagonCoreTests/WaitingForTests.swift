import XCTest
@testable import ParagonCore

/// Build 279: **Waiting for**. What counts as a waiting line, how the person and the thing are
/// read, how a line is made waiting and made ordinary again, the words a row says, the list
/// grouped by person, and that a waiting line is never the next thing.
final class WaitingForTests: XCTestCase {
    /// A Monday. 6 November is the Friday after it.
    private let today = DateOnly(year: 2026, month: 11, day: 2)
    private let english = Locale(identifier: "en_US")
    private let gregorian = Calendar(identifier: .gregorian)

    private func task(_ line: String) throws -> TaskItem {
        try XCTUnwrap(TaskParser.parse(line: line, lineIndex: 0), "\(line) is not a task line")
    }

    private func day(_ text: String) throws -> DateOnly {
        try XCTUnwrap(DateOnly(text))
    }

    private func ref(_ line: String, path: String = "Projects/Shed.md", index: Int = 0) throws -> TaskRef {
        var parsed = try task(line)
        parsed.lineIndex = index
        return TaskRef(notePath: path, noteTitle: "Shed", task: parsed)
    }

    private func project(_ title: String, status: String? = nil, body: String) -> Note {
        var lines = ["title: \(title)", "type: project"]
        if let status { lines.append("status: \(status)") }
        return Note(relativePath: "Projects/\(title).md", kind: .project,
                    text: "---\n" + lines.joined(separator: "\n") + "\n---\n" + body)
    }

    // MARK: @since on the task line

    func testSinceIsReadAndWrittenBackInItsPlace() throws {
        let line = "- [ ] Ask Anna ~15m >2026-11-06 @repeat(weekly) @since(2026-11-01) ^t123abc"
        let parsed = try task(line)
        XCTAssertEqual(parsed.since, try day("2026-11-01"))
        XCTAssertEqual(parsed.title, "Ask Anna", "The marker is lifted out of the title, like a date")
        XCTAssertEqual(parsed.serialized, line, "After @repeat, before @done and the id")

        let finished = "- [x] Quote @since(2026-11-01) @done(2026-11-02 10:00)"
        XCTAssertEqual(try task(finished).serialized, finished, "Before @done")
    }

    func testASinceWithoutADateStaysInTheTitle() throws {
        let parsed = try task("- [ ] Quote @since(soon)")
        XCTAssertNil(parsed.since)
        XCTAssertEqual(parsed.title, "Quote @since(soon)")
    }

    func testTheNextCopyOfARepeatingTaskHasNotStartedWaiting() throws {
        let weekly = try task("- [x] Chase Anna >2026-11-02 @repeat(weekly) @since(2026-10-26) @done(2026-11-02 10:00)")
        let next = try XCTUnwrap(weekly.nextOccurrence(completedOn: today, calendar: gregorian))
        XCTAssertNil(next.since)
        XCTAssertFalse(next.serialized.contains("@since"))
    }

    func testTheEditorDimsSinceLikeADate() {
        let text = "- [ ] Waiting for Anna: the quote >2026-11-06 @since(2026-11-01)"
        let range = (text as NSString).range(of: "@since(2026-11-01)")
        let styles = MarkdownHighlight.spans(in: text)
            .filter { NSIntersectionRange($0.range, range).length > 0 }
            .map(\.style)
        XCTAssertTrue(styles.contains(.dueDate))
    }

    // MARK: What a waiting line is

    func testWhatCountsAsWaiting() throws {
        XCTAssertTrue(try task("- [ ] Chase the plumber #waiting").isWaiting, "the tag alone")
        XCTAssertTrue(try task("- [ ] Chase the plumber #Waiting").isWaiting, "capitals do not matter in the tag")
        XCTAssertTrue(try task("- [ ] Waiting for Anna: the quote").isWaiting, "the words alone")
        XCTAssertTrue(try task("- [ ] waiting FOR Anna: the quote").isWaiting, "capitals do not matter in the words")
        XCTAssertTrue(try task("- [>] Waiting for Anna: the quote >2026-11-06").isWaiting, "a scheduled line is still open")

        XCTAssertFalse(try task("- [ ] Send the quote").isWaiting)
        XCTAssertFalse(try task("- [ ] Waiting room for the clinic #waitingroom").isWaiting, "a longer tag is another tag")
        XCTAssertFalse(try task("- [x] Waiting for Anna: the quote #waiting @done(2026-11-02 10:00)").isWaiting,
                       "A ticked line is not waiting any more")
        XCTAssertFalse(try task("- [-] Waiting for Anna: the quote #waiting").isWaiting, "nor is a cancelled one")
    }

    func testThePersonAndTheThing() throws {
        func read(_ line: String) throws -> WaitingFor.Parsed {
            try XCTUnwrap(WaitingFor.parse(try task(line)), "\(line) should be waiting")
        }
        XCTAssertEqual(try read("- [ ] Waiting for Anna: the quote #waiting >2026-11-06"),
                       WaitingFor.Parsed(person: "Anna", what: "the quote"))
        XCTAssertEqual(try read("- [ ] waiting for   Anna  Berg  :   the quote"),
                       WaitingFor.Parsed(person: "Anna Berg", what: "the quote"),
                       "Trimmed, and runs of spaces closed")
        XCTAssertEqual(try read("- [ ] Waiting for the quote"),
                       WaitingFor.Parsed(person: nil, what: "the quote"),
                       "No colon means no person")
        XCTAssertEqual(try read("- [ ] Call Anna about the quote #waiting"),
                       WaitingFor.Parsed(person: nil, what: "Call Anna about the quote"),
                       "Only the tag is there: the whole title less the tag")
        XCTAssertEqual(try read("- [ ] Waiting for : the quote"),
                       WaitingFor.Parsed(person: nil, what: "the quote"),
                       "A colon with no name before it names nobody")
        XCTAssertEqual(try read("- [ ] Waiting for Anna: the 12:30 train"),
                       WaitingFor.Parsed(person: "Anna", what: "the 12:30 train"),
                       "Only the first colon ends the name")
        XCTAssertEqual(try read("- [ ] Waiting for the 12:30 train"),
                       WaitingFor.Parsed(person: nil, what: "the 12:30 train"),
                       "A colon between two digits is a time, not the end of a name")
        XCTAssertNil(WaitingFor.parse(try task("- [ ] Send the quote")))
    }

    // MARK: Never the next thing

    func testAWaitingLineIsNeverTheNextThing() {
        let note = project("Shed", body: """
        - [ ] Waiting for Anna: the quote #next #waiting
        - [ ] Draft the plan
        """)
        XCTAssertEqual(note.nextThing?.title, "Draft the plan",
                       "Not even a waiting line tagged #next can be the next thing")
        XCTAssertEqual(NoteIndex(notes: [note]).nextActions().map(\.task.title), ["Draft the plan"])

        let onlyWaiting = project("Roof", body: """
        - [x] Choose the tiles
        - [ ] Waiting for Anna: the quote #waiting
        - [ ] waiting for Bo: the delivery date
        """)
        XCTAssertNil(onlyWaiting.nextThing)
        XCTAssertTrue(NoteIndex(notes: [onlyWaiting]).nextActions().isEmpty)
        // Nothing he can do himself, but not idle: the Goals screens must not warn in orange
        // about a project the Projects list shows calmly (build 279).
        XCTAssertFalse(ChainProject(note: onlyWaiting).hasNothingToDo)
        XCTAssertEqual(ChainProject(note: onlyWaiting).waitingCount, 2)
        XCTAssertNil(ChainProject(note: onlyWaiting).nextAction)
    }

    /// Marking a waiting line as the next action would take `#next` off the real one and put it
    /// where nothing reads it, so the note must be left exactly as it is.
    func testAWaitingLineCannotBeMadeTheNextAction() throws {
        var note = project("Shed", body: """
        - [ ] Draft the plan #next
        - [ ] Waiting for Anna: the quote #waiting
        - [ ] Buy wood
        """)
        let before = note.lines
        let waiting = try XCTUnwrap(note.tasks.first { $0.isWaiting })
        XCTAssertFalse(note.setNextAction(waiting))
        XCTAssertEqual(note.lines, before, "Nothing may move, least of all the real #next")
        XCTAssertTrue(try XCTUnwrap(note.nextThing).title.hasPrefix("Draft the plan"))

        // An ordinary line still can.
        let wood = try XCTUnwrap(note.tasks.first { $0.title == "Buy wood" })
        XCTAssertTrue(note.setNextAction(wood))
        XCTAssertTrue(try XCTUnwrap(note.nextThing).title.hasPrefix("Buy wood"))
    }

    func testASubtaskThatIsWaitingIsSkippedToo() {
        let note = project("Boat", body: """
        - [x] Order the paint
            - [ ] Waiting for Sven: the colour card #waiting
            - [ ] Sand the hull
        """)
        XCTAssertEqual(note.nextThing?.title, "Sand the hull")

        let alone = project("Barn", body: """
        - [x] Order the paint
            - [ ] Waiting for Sven: the colour card #waiting
        """)
        XCTAssertNil(alone.nextThing)
    }

    func testAProjectOfWaitingLinesDoesNotReadAsFinished() {
        let roof = project("Roof", body: """
        - [x] Choose the tiles
        - [ ] Waiting for Anna: the quote #waiting
        - [ ] Waiting for Bo: the delivery date
        """)
        let lines = NoteIndex(notes: [roof]).projectGroups([roof], today: today).flatMap(\.lines)
        XCTAssertEqual(lines.first?.need, .waitingOnly(count: 2),
                       "Three tasks, one ticked and two waiting: not 'all finished'")
        XCTAssertEqual(ProjectLine.waitingText(count: 1), "Its one open task is waiting for someone")
        XCTAssertEqual(ProjectLine.waitingText(count: 2), "All 2 open tasks are waiting for others")

        let mixed = project("Shed", body: "- [ ] Waiting for Anna: the quote\n- [ ] Draft the plan\n")
        let mixedLine = NoteIndex(notes: [mixed]).projectGroups([mixed], today: today).flatMap(\.lines).first
        XCTAssertEqual(mixedLine?.nextTitle, "Draft the plan", "Another open task is still the next thing")

        let finished = project("Fence", body: "- [x] Paint it\n")
        let finishedLine = NoteIndex(notes: [finished]).projectGroups([finished], today: today).flatMap(\.lines).first
        XCTAssertEqual(finishedLine?.need, .allFinished(count: 1), "Nothing waiting: the old answer stands")
    }

    // MARK: Making a line waiting, and ordinary again

    func testMakingATaskWaitDatesItAWeekOutAndStartsTheWait() throws {
        let plain = try task("- [ ] Send the quote !! ~30m ^t1a2b3c")
        let made = plain.makingWaiting(for: "Anna", today: today, calendar: gregorian)

        XCTAssertEqual(made.title, "Waiting for Anna: Send the quote #waiting")
        XCTAssertEqual(made.tags, ["waiting"], "The tag is read back by the parser, once")
        XCTAssertEqual(made.since, today)
        XCTAssertEqual(made.dueDate, try day("2026-11-09"), "No date: today and a week")
        XCTAssertEqual(made.priority, 2)
        XCTAssertEqual(made.minutes, 30)
        XCTAssertEqual(made.id, "t1a2b3c")
        XCTAssertTrue(made.isWaiting)
        XCTAssertEqual(made.serialized,
                       "- [ ] Waiting for Anna: Send the quote #waiting !! ~30m >2026-11-09 @since(2026-11-02) ^t1a2b3c")
    }

    func testADateAlreadyThereIsTheFollowUpDate() throws {
        let dated = try task("- [ ] Send the quote >2026-11-20T09:00")
        let made = dated.makingWaiting(for: "Anna", today: today, calendar: gregorian)
        XCTAssertEqual(made.dueDate, try day("2026-11-20"))
        XCTAssertEqual(made.dueTime, TimeOfDay(hour: 9, minute: 0), "The time of day stays with it")
    }

    func testAskingWhoAgainChangesTheNameAndKeepsTheWait() throws {
        let waiting = try task("- [ ] Waiting for Anna: the quote #waiting >2026-11-06 @since(2026-10-28)")
        let again = waiting.makingWaiting(for: "Bo", today: today, calendar: gregorian)
        XCTAssertEqual(again.title, "Waiting for Bo: the quote #waiting", "No second prefix, no second tag")
        XCTAssertEqual(again.since, try day("2026-10-28"), "Changing the person does not reset the wait")
        XCTAssertEqual(again.dueDate, try day("2026-11-06"))
        XCTAssertEqual(again.tags, ["waiting"])

        let byHand = try task("- [ ] Waiting for Anna: the quote")
        let tagged = byHand.makingWaiting(for: "Anna", today: today, calendar: gregorian)
        XCTAssertEqual(tagged.title, "Waiting for Anna: the quote #waiting", "A hand-written line gets the tag")
    }

    func testABlankPersonChangesNothing() throws {
        let plain = try task("- [ ] Send the quote")
        for blank in [nil, "", "   ", " : # "] as [String?] {
            XCTAssertEqual(plain.makingWaiting(for: blank, today: today, calendar: gregorian), plain, "\(String(describing: blank))")
        }
    }

    func testANameCannotBreakTheLine() throws {
        let plain = try task("- [ ] Send the quote")
        let made = plain.makingWaiting(for: "  Anna:  Bo #x >2026-01-01 ", today: today, calendar: gregorian)
        XCTAssertEqual(made.title, "Waiting for Anna Bo x 2026-01-01: Send the quote #waiting")
        XCTAssertEqual(WaitingFor.parse(made)?.person, "Anna Bo x 2026-01-01")
        XCTAssertEqual(made.tags, ["waiting"], "A # in a name did not become a tag")
    }

    func testOtherTagsAndNextStayOnTheLine() throws {
        let tagged = try task("- [ ] Order the saddle #next #horse")
        let made = tagged.makingWaiting(for: "Sven", today: today, calendar: gregorian)
        XCTAssertEqual(made.title, "Waiting for Sven: Order the saddle #next #horse #waiting")
        XCTAssertEqual(made.tags, ["next", "horse", "waiting"])
    }

    func testASubtaskStaysASubtask() throws {
        var child = try task("    - [ ] Check the colour card")
        child.parentLineIndex = 3
        let made = child.makingWaiting(for: "Sven", today: today, calendar: gregorian)
        XCTAssertEqual(made.parentLineIndex, 3)
        XCTAssertEqual(made.indent, "    ")
    }

    func testNotWaitingTakesAwayTheWordsTheTagAndTheStart() throws {
        let waiting = try task("- [ ] Waiting for Anna: the quote #waiting #horse >2026-11-06 !! ~15m @since(2026-11-01) ^t1a2b3c")
        let plain = waiting.notWaiting()
        XCTAssertEqual(plain.title, "the quote #horse")
        XCTAssertNil(plain.since)
        XCTAssertEqual(plain.dueDate, try day("2026-11-06"), "The date stays: it is still a date")
        XCTAssertEqual(plain.priority, 2)
        XCTAssertEqual(plain.minutes, 15)
        XCTAssertEqual(plain.id, "t1a2b3c")
        XCTAssertEqual(plain.tags, ["horse"])
        XCTAssertFalse(plain.isWaiting)

        let tagOnly = try task("- [ ] Call the bank #waiting #finance @since(2026-11-01)")
        XCTAssertEqual(tagOnly.notWaiting().title, "Call the bank #finance")
        XCTAssertFalse(tagOnly.notWaiting().isWaiting)
    }

    func testNotWaitingNeverLeavesATaskWithNoWords() throws {
        let bare = try task("- [ ] Waiting for Anna: #waiting")
        XCTAssertTrue(bare.isWaiting)
        XCTAssertEqual(bare.notWaiting().title, "Anna", "The name is the words that are left")
        XCTAssertFalse(bare.notWaiting().isWaiting, "It must stop being a waiting line")

        let noTag = try task("- [ ] Waiting for Anna:")
        XCTAssertEqual(noTag.notWaiting().title, "Anna")
        XCTAssertFalse(noTag.notWaiting().isWaiting)

        let sinceOnly = try task("- [ ] Waiting for Anna: #waiting @since(2026-11-01)")
        XCTAssertFalse(sinceOnly.notWaiting().isWaiting)
        XCTAssertNil(sinceOnly.notWaiting().since)

        // No words and no name at all: nothing to keep, and the title is never empty.
        let nameless = try task("- [ ] Waiting for : #waiting")
        XCTAssertFalse(nameless.notWaiting().title.isEmpty)
    }

    func testMakingAndUndoingKeepsTheWords() throws {
        let plain = try task("- [ ] Send the quote")
        let back = plain.makingWaiting(for: "Anna", today: today, calendar: gregorian).notWaiting()
        XCTAssertEqual(back.title, plain.title)
        XCTAssertNil(back.since)
    }

    func testTheFollowUpMovesAWeekFromTheLaterOfItsDateAndToday() throws {
        XCTAssertEqual(WaitingFor.followUpNextWeek(from: nil, today: today, calendar: gregorian), try day("2026-11-09"))
        XCTAssertEqual(WaitingFor.followUpNextWeek(from: today, today: today, calendar: gregorian), try day("2026-11-09"))
        XCTAssertEqual(WaitingFor.followUpNextWeek(from: try day("2026-11-06"), today: today, calendar: gregorian),
                       try day("2026-11-13"), "A date still ahead moves a week on")
        XCTAssertEqual(WaitingFor.followUpNextWeek(from: try day("2026-10-20"), today: today, calendar: gregorian),
                       try day("2026-11-09"), "An overdue one starts again from today")
    }

    func testTheLineUnderTheWhoField() throws {
        let plain = try task("- [ ] Send the quote")
        XCTAssertEqual(WaitingFor.writesText(for: plain, person: "Anna"),
                       "Writes \u{201C}Waiting for Anna: Send the quote\u{201D} with a follow-up date in a week.")
        let dated = try task("- [ ] Send the quote >2026-11-20")
        XCTAssertEqual(WaitingFor.writesText(for: dated, person: " Anna "),
                       "Writes \u{201C}Waiting for Anna: Send the quote\u{201D} and keeps its date as the follow-up date.")
        XCTAssertNil(WaitingFor.writesText(for: plain, person: "  "), "Nothing to say until a name is typed")
        let again = try task("- [ ] Waiting for Anna: the quote #waiting")
        XCTAssertEqual(WaitingFor.writesText(for: again, person: "Bo"),
                       "Writes \u{201C}Waiting for Bo: the quote\u{201D} with a follow-up date in a week.")
    }

    // MARK: Writing into the note

    func testRewritingReplacesTheLineEvenThoughTheTitleChanged() throws {
        var note = project("Shed", body: "- [ ] Send the quote\n- [ ] Draft the plan\n")
        let original = try XCTUnwrap(note.tasks.first)
        let made = original.makingWaiting(for: "Anna", today: today, calendar: gregorian)
        XCTAssertTrue(note.rewrite(task: original, with: made))
        XCTAssertEqual(note.tasks.map(\.title), ["Waiting for Anna: Send the quote #waiting", "Draft the plan"])
        XCTAssertEqual(note.tasks.first?.since, today)
    }

    func testTheLiveLineIsFoundWhenTheLinesHaveMoved() throws {
        let before = project("Shed", body: "- [ ] Send the quote ^t1a2b3c\n")
        let copy = try XCTUnwrap(before.tasks.first)

        let after = project("Shed", body: "- [ ] A new line first\n- [ ] Send the quote >2026-12-01 ^t1a2b3c\n")
        let live = try XCTUnwrap(after.liveTask(for: copy))
        XCTAssertEqual(live.lineIndex, 1)
        XCTAssertEqual(live.dueDate, try day("2026-12-01"), "The change is made to the line as it is now")

        let gone = project("Shed", body: "- [ ] Something else\n")
        XCTAssertNil(gone.liveTask(for: copy))
        var unchanged = gone
        XCTAssertFalse(unchanged.rewrite(task: copy, with: copy.notWaiting()))
        XCTAssertEqual(unchanged, gone)
    }

    // MARK: The words on a row

    func testHowLongALineHasWaited() throws {
        let line = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote @since(2026-10-28)")))
        XCTAssertEqual(line.waitedDays(today: today, calendar: gregorian), 5)
        XCTAssertEqual(line.waitedText(today: today, calendar: gregorian), "waited 5 days")

        let one = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote @since(2026-11-01)")))
        XCTAssertEqual(one.waitedText(today: today, calendar: gregorian), "waited 1 day")

        let same = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote @since(2026-11-02)")))
        XCTAssertEqual(same.waitedText(today: today, calendar: gregorian), "asked today")
        XCTAssertEqual(same.waitedDays(today: today, calendar: gregorian), 0)
    }

    func testALineWithNoStartNeverSaysWaited() throws {
        let none = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote #waiting")))
        XCTAssertNil(none.waitedDays(today: today, calendar: gregorian))
        XCTAssertNil(none.waitedText(today: today, calendar: gregorian), "Never a guess, never a zero")

        let future = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote @since(2026-12-24)")))
        XCTAssertNil(future.waitedDays(today: today, calendar: gregorian), "Never negative")
        XCTAssertNil(future.waitedText(today: today, calendar: gregorian))
    }

    func testTheFollowUpInWords() throws {
        func words(_ date: String?) throws -> String {
            let dated = date.map { " >\($0)" } ?? ""
            let line = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote\(dated)")))
            return line.followUpText(today: today, calendar: gregorian, locale: english)
        }
        XCTAssertEqual(try words(nil), "No follow-up date")
        XCTAssertEqual(try words("2026-11-02"), "Follow up today")
        XCTAssertEqual(try words("2026-11-06"), "Follow up Fri 6 Nov")
        XCTAssertEqual(try words("2027-02-06"), "Follow up Sat 6 Feb 2027", "The year when it is not this year's")
        XCTAssertEqual(try words("2026-11-01"), "Follow up was yesterday")
        XCTAssertEqual(try words("2026-10-30"), "Follow up was 3 days ago")
    }

    func testTheStateOfTheFollowUp() throws {
        func state(_ date: String?) throws -> WaitingLine.FollowUpState {
            let dated = date.map { " >\($0)" } ?? ""
            let line = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote\(dated)")))
            return line.followUpState(today: today)
        }
        XCTAssertEqual(try state(nil), .noDate)
        XCTAssertEqual(try state("2026-11-01"), .overdue)
        XCTAssertEqual(try state("2026-11-02"), .today)
        XCTAssertEqual(try state("2026-11-03"), .later)
    }

    func testTheCaptionUnderARow() throws {
        let both = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote >2026-11-06 @since(2026-10-28)")))
        XCTAssertEqual(both.captionText(today: today, calendar: gregorian, locale: english),
                       "Follow up Fri 6 Nov \u{00B7} waited 5 days")
        let noStart = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Waiting for Anna: the quote >2026-11-06")))
        XCTAssertEqual(noStart.captionText(today: today, calendar: gregorian, locale: english), "Follow up Fri 6 Nov")
        let nothing = try XCTUnwrap(WaitingLine(ref: try ref("- [ ] Chase the plumber #waiting")))
        XCTAssertEqual(nothing.captionText(today: today, calendar: gregorian, locale: english), "No follow-up date")
    }

    // MARK: The list

    private func list(_ lines: [String]) throws -> WaitingList {
        var refs: [TaskRef] = []
        for (index, line) in lines.enumerated() {
            refs.append(try ref(line, index: index))
        }
        return WaitingList(refs: refs, today: today, calendar: gregorian)
    }

    func testPeopleAreGroupedAndNamedByTheirMostUsedSpelling() throws {
        let waiting = try list([
            "- [ ] Waiting for anna: the quote >2026-11-06 #waiting @since(2026-11-01)",
            "- [ ] Waiting for Anna: the drawings #waiting",
            "- [ ] Waiting for Anna  : the plans >2026-11-04 #waiting @since(2026-10-30)",
            "- [ ] Waiting for Bo: payment >2026-11-04 #waiting @since(2026-10-20)",
            "- [ ] Chase the plumber #waiting",
            "- [x] Waiting for Zed: a ticked thing #waiting @done(2026-11-01 10:00)",
            "- [ ] Plain task",
        ])
        XCTAssertEqual(waiting.groups.map(\.title), ["Anna", "Bo", "Someone"], "Named first, alphabetical, Someone last")
        XCTAssertEqual(waiting.groups.map(\.name), ["Anna", "Bo", nil])
        XCTAssertEqual(waiting.groups[0].lines.map(\.what), ["the plans", "the quote", "the drawings"],
                       "By follow-up date, none last")
        XCTAssertEqual(waiting.groups[2].note, "No name given")
        XCTAssertNil(waiting.groups[0].note)
        XCTAssertEqual(waiting.count, 5)
        XCTAssertEqual(waiting.peopleCount, 2)
        XCTAssertEqual(waiting.summary, "5 things \u{00B7} 2 people")
        XCTAssertEqual(waiting.pointerText, "5 waiting for other people")
        XCTAssertEqual(WaitingFor.people(in: waiting), ["Anna", "Bo"], "Most used first")
    }

    func testOnTheSameDayTheLongestWaitComesFirstThenTheTitle() throws {
        let waiting = try list([
            "- [ ] Waiting for Anna: b thing >2026-11-04 #waiting @since(2026-11-01)",
            "- [ ] Waiting for Anna: a thing >2026-11-04 #waiting @since(2026-11-01)",
            "- [ ] Waiting for Anna: c thing >2026-11-04 #waiting @since(2026-10-20)",
            "- [ ] Waiting for Anna: d thing >2026-11-04 #waiting",
        ])
        XCTAssertEqual(waiting.groups[0].lines.map(\.what), ["c thing", "a thing", "b thing", "d thing"])
    }

    func testTheSpellingSeenFirstWinsATie() throws {
        let waiting = try list([
            "- [ ] Waiting for bo: a",
            "- [ ] Waiting for BO: b",
        ])
        XCTAssertEqual(waiting.groups.count, 1, "Case and spaces do not make a second person")
        XCTAssertEqual(waiting.groups.first?.name, "bo")
    }

    func testTheSummaryInWords() throws {
        XCTAssertEqual(try list(["- [ ] Waiting for Anna: a"]).summary, "1 thing \u{00B7} 1 person")
        XCTAssertEqual(try list(["- [ ] Waiting for Anna: a"]).pointerText, "1 waiting for another person")
        XCTAssertEqual(try list(["- [ ] Chase a #waiting", "- [ ] Chase b #waiting", "- [ ] Chase c #waiting"]).summary,
                       "3 things \u{00B7} nobody named")
        let empty = try list(["- [ ] Plain task"])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.summary, "Nothing is waiting")
        XCTAssertNil(empty.pointerText, "Nothing to point at")
        XCTAssertEqual(empty.count, 0)
        XCTAssertEqual(empty.peopleCount, 0)
    }

    func testTheIndexListsOnlyLiveOpenLines() {
        let live = project("Shed", body: "- [ ] Waiting for Anna: the quote #waiting\n")
        let finished = project("Fence", status: "done", body: "- [ ] Waiting for Bo: a gate #waiting\n")
        let parked = project("Barn", status: "archived", body: "- [ ] Waiting for Cy: a key #waiting\n")
        let index = NoteIndex(notes: [live, finished, parked])

        let waiting = index.waitingFor(today: today, calendar: gregorian)
        XCTAssertEqual(waiting.groups.map(\.title), ["Anna"],
                       "What a finished or archived project was waiting for is not something to chase")
        XCTAssertEqual(waiting.count, 1)

        // The same answer from the list the All actions screen already holds.
        let among = index.waitingFor(among: index.openTasks(), today: today, calendar: gregorian)
        XCTAssertEqual(among, waiting)
    }

    // MARK: The shipped snippet

    func testTheShippedSnippetStartsTheWait() throws {
        let snippet = try XCTUnwrap(Snippets.parse(Templates.snippets).first { $0.name == "Waiting for" })
        let lines = Snippets.filled(snippet, answers: ["who": "Anna", "what": "the quote"], today: today)
        XCTAssertEqual(lines, ["- [ ] Waiting for Anna: the quote >2026-11-09 #waiting @since(2026-11-02)"])
        let parsed = try task(lines[0])
        XCTAssertTrue(parsed.isWaiting)
        XCTAssertEqual(parsed.since, today)
        XCTAssertEqual(WaitingFor.parse(parsed), WaitingFor.Parsed(person: "Anna", what: "the quote"))
    }
}
