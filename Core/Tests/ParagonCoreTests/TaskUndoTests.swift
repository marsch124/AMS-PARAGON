import XCTest
@testable import ParagonCore

/// **Undo for the one-press changes** (build 277). The rule is the same for both: Undo writes
/// only what it can prove is still as the press left it, and it never writes over a change made
/// afterwards. Each of these asks one way that rule could be broken.
final class TaskUndoTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 11, day: 2)

    private func note(_ body: String, path: String = "Projects/Garden.md", kind: ParaKind = .project) -> Note {
        Note(relativePath: path, kind: kind, body: body)
    }

    /// Does to a note what the **Move to today** button does, and keeps the records it would.
    private func moveAll(_ note: Note, to date: DateOnly) -> (note: Note, moves: [MovedTask]) {
        var moved = note
        var moves: [MovedTask] = []
        for task in note.openTasks {
            var changed = task
            changed.dueDate = date
            XCTAssertTrue(moved.replace(task: changed))
            let ref = TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: task)
            moves.append(MovedTask(ref: ref, to: date))
        }
        return (moved, moves)
    }

    private let threeDates = """
    # Garden

    ## Tasks
    - [ ] Pay the old invoice >2020-01-01 ^t000001
    - [ ] Send the letter >2024-05-17
    - [ ] Call the plumber >2026-10-30 ^t000003
    """

    // MARK: Dates

    func testEveryOldDateComesBack() {
        let before = note(threeDates)
        let (after, moves) = moveAll(before, to: today)
        XCTAssertNotEqual(after.body, before.body)
        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 3)
        XCTAssertTrue(undone.skipped.isEmpty)
        XCTAssertEqual(undone.note.body, before.body, "Each task has its own old date, not the new one.")
    }

    /// A task changed by someone else after the press is left as it is, and the others are put
    /// back. This is "5 of 6 tasks put back".
    func testATaskMovedAgainMeanwhileIsLeftAlone() {
        let before = note(threeDates)
        let moved = moveAll(before, to: today)
        var after = moved.note
        let moves = moved.moves
        var other = after.tasks[1]
        other.dueDate = DateOnly(year: 2026, month: 12, day: 24)
        XCTAssertTrue(after.replace(task: other))

        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 2)
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Send the letter", reason: .changed)])
        XCTAssertEqual(undone.note.tasks[0].dueDate, DateOnly(year: 2020, month: 1, day: 1))
        XCTAssertEqual(undone.note.tasks[1].dueDate, DateOnly(year: 2026, month: 12, day: 24),
                       "A date somebody else chose is not written over.")
        XCTAssertEqual(undone.note.tasks[2].dueDate, DateOnly(year: 2026, month: 10, day: 30))
    }

    func testATaskTickedMeanwhileIsLeftAlone() {
        let before = note(threeDates)
        let moved = moveAll(before, to: today)
        var after = moved.note
        let moves = moved.moves
        var ticked = after.tasks[0]
        ticked.markDone()
        XCTAssertTrue(after.replace(task: ticked))

        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 2)
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Pay the old invoice", reason: .done)])
        XCTAssertTrue(undone.note.tasks[0].isDone)
        XCTAssertEqual(undone.note.tasks[0].dueDate, today, "A finished task keeps the date it was finished with.")
    }

    func testATaskThatIsGoneIsReported() {
        let before = note(threeDates)
        let moved = moveAll(before, to: today)
        var after = moved.note
        after.removeTask(at: after.tasks[1].lineIndex)

        let undone = after.undoingDateMoves(moved.moves)
        XCTAssertEqual(undone.restored.count, 2)
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Send the letter", reason: .gone)])
    }

    /// The id finds a task whose title was changed meanwhile; a task with no id is found by its
    /// exact title, and a changed title makes it a task that is gone.
    func testAnIdFindsAnEditedTitleAndATitleDoesNot() {
        let before = note(threeDates)
        let moved = moveAll(before, to: today)
        var after = moved.note
        after.body = after.body
            .replacingOccurrences(of: "Pay the old invoice", with: "Pay the very old invoice")
            .replacingOccurrences(of: "Send the letter", with: "Send a longer letter")

        let undone = after.undoingDateMoves(moved.moves)
        XCTAssertEqual(undone.note.tasks[0].dueDate, DateOnly(year: 2020, month: 1, day: 1),
                       "It has an id, so a new title does not hide it.")
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Send the letter", reason: .gone)])
    }

    func testLinesThatMovedAreStillFound() {
        let before = note(threeDates)
        let (after, moves) = moveAll(before, to: today)
        var lines = after.lines
        lines.insert("A line somebody typed above.", at: 1)
        lines.insert("- [ ] A new task >2026-11-05", at: 3)
        var edited = after
        edited.lines = lines

        let undone = edited.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 3)
        XCTAssertTrue(undone.skipped.isEmpty)
        XCTAssertTrue(undone.note.body.contains("A line somebody typed above."))
        XCTAssertTrue(undone.note.body.contains("- [ ] A new task >2026-11-05"))
        XCTAssertTrue(undone.note.body.contains("Send the letter >2024-05-17"))
    }

    /// Another device changed other lines in the note in the meantime. That costs nothing.
    func testOtherLinesChangedElsewhereDoNotMatter() {
        let before = note(threeDates)
        let (after, moves) = moveAll(before, to: today)
        var edited = after
        edited.body = edited.body.replacingOccurrences(of: "# Garden", with: "# Garden and orchard")
        let undone = edited.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 3)
        XCTAssertTrue(undone.note.body.hasPrefix("# Garden and orchard"))
    }

    func testARepeatingTaskKeepsItsRepeat() {
        let before = note("## Tasks\n- [ ] Water the plants >2026-10-01 @repeat(weekly)\n")
        let (after, moves) = moveAll(before, to: today)
        XCTAssertTrue(after.body.contains("@repeat(weekly)"))
        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.note.body, before.body)
    }

    /// The press changed the date and not the time, so Undo changes the date and not the time.
    func testTheDueTimeIsNotTouched() {
        let before = note("## Tasks\n- [ ] Ring the bank >2026-10-01T09:30\n")
        let (after, moves) = moveAll(before, to: today)
        XCTAssertTrue(after.body.contains(">2026-11-02T09:30"))
        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.note.body, before.body)
    }

    func testAnUndoneMoveCannotBeUndoneTwice() {
        let before = note(threeDates)
        let (after, moves) = moveAll(before, to: today)
        let once = after.undoingDateMoves(moves)
        let twice = once.note.undoingDateMoves(moves)
        XCTAssertTrue(twice.restored.isEmpty)
        XCTAssertEqual(twice.note.body, once.note.body, "The second press writes nothing.")
    }

    func testOnlyTheNotesOwnTasksAreTouched() {
        let moved = moveAll(note(threeDates), to: today)
        let elsewhere = note(threeDates, path: "Projects/Other.md")
        let undone = elsewhere.undoingDateMoves(moved.moves)
        XCTAssertTrue(undone.restored.isEmpty)
        XCTAssertEqual(undone.note, elsewhere)
    }

    func testATaskThatAlreadyHadTheDateHasNothingToPutBack() {
        let before = note("## Tasks\n- [ ] Pay >2026-11-02\n")
        let (after, moves) = moveAll(before, to: today)
        XCTAssertFalse(moves[0].changedTheDate)
        let undone = after.undoingDateMoves(moves)
        XCTAssertTrue(undone.restored.isEmpty)
        XCTAssertTrue(undone.skipped.isEmpty)
        XCTAssertEqual(undone.note, after)
    }

    func testATaskWithNoOldDateGoesBackToNone() {
        let before = note("## Tasks\n- [ ] Think about it\n")
        let (after, moves) = moveAll(before, to: today)
        XCTAssertTrue(after.body.contains(">2026-11-02"))
        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.note.body, before.body)
    }

    // MARK: Two tasks with one name

    private let twins = """
    ## Tasks
    - [ ] Pay the invoice >2020-01-01
    - [ ] Pay the invoice >2021-02-02
    """

    /// While the lines have not moved, each twin gets its own date.
    func testTwoTasksWithOneNameKeepTheirOwnDates() {
        let before = note(twins)
        let (after, moves) = moveAll(before, to: today)
        let undone = after.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 2)
        XCTAssertEqual(undone.note.body, before.body)
    }

    /// A line added above moves both by one place. Giving the first the second's date would be
    /// the one mistake an Undo may not make, so nothing is written.
    func testTwoTasksWithOneNameAreLeftAloneWhenTheLinesMoved() {
        let before = note(twins)
        let (after, moves) = moveAll(before, to: today)
        var lines = after.lines
        lines.insert("- [ ] Something new", at: 1)
        var edited = after
        edited.lines = lines

        let undone = edited.undoingDateMoves(moves)
        XCTAssertTrue(undone.restored.isEmpty)
        XCTAssertEqual(undone.skipped.map(\.reason), [.unclear, .unclear])
        XCTAssertEqual(undone.note, edited)
    }

    /// With the same old date it does not matter which is which, so lines that moved are fine.
    func testTwoTasksWithOneNameAndOneOldDateAreFoundWhereverTheyAre() {
        let before = note("## Tasks\n- [ ] Pay the invoice >2020-01-01\n- [ ] Pay the invoice >2020-01-01\n")
        let (after, moves) = moveAll(before, to: today)
        var lines = after.lines
        lines.insert("- [ ] Something new", at: 1)
        var edited = after
        edited.lines = lines
        let undone = edited.undoingDateMoves(moves)
        XCTAssertEqual(undone.restored.count, 2)
        XCTAssertTrue(undone.skipped.isEmpty)
    }

    /// A twin that already had the new date before the press is not a moved task, and it looks
    /// just like one. With two lines added above, the moved twin is no longer on the line it was
    /// pressed on, so nothing can say which is which: both are left alone.
    func testAnUnmovedTwinOnTheNewDateIsNotGivenTheOldDate() {
        let before = note("## Tasks\n- [ ] Call mum >2026-11-02\n- [ ] Call mum >2020-01-01\n")
        let (after, moves) = moveAll(before, to: today)
        XCTAssertEqual(moves.filter { $0.changedTheDate }.count, 1)
        var lines = after.lines
        lines.insert("Something typed above.", at: 1)
        lines.insert("Something more typed above.", at: 1)
        var edited = after
        edited.lines = lines

        let undone = edited.undoingDateMoves(moves)
        XCTAssertTrue(undone.restored.isEmpty)
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Call mum", reason: .unclear)])
        XCTAssertEqual(undone.note, edited)
    }

    /// The same with one line added: now the unmoved twin sits on the line the moved one was
    /// pressed on, and a match by line number alone would have given it the old date.
    func testAnUnmovedTwinOnThePressedLineIsNotGivenTheOldDate() {
        let before = note("## Tasks\n- [ ] Call mum >2026-11-02\n- [ ] Call mum >2020-01-01\n")
        let (after, moves) = moveAll(before, to: today)
        var lines = after.lines
        lines.insert("Something typed above.", at: 1)
        var edited = after
        edited.lines = lines

        let undone = edited.undoingDateMoves(moves)
        XCTAssertTrue(undone.restored.isEmpty)
        XCTAssertEqual(undone.skipped, [SkippedTask(title: "Call mum", reason: .unclear)])
        XCTAssertEqual(undone.note, edited)
    }

    // MARK: A deleted line

    private let inbox = """
    # Inbox

    ## Tasks
    - [ ] Call the bank about the ferry
    - [ ] Buy a new hose ^t0a1b2c
        - [ ] Measure the old one
        - [ ] Check the thread
    - [ ] Order the saddle
    """

    private func removal(_ note: Note, _ title: String) -> TaskRemoval {
        guard let task = note.tasks.first(where: { $0.title == title }),
              let removal = note.removingTaskBlock(for: task) else {
            XCTFail("Could not take \(title) out of the note.")
            return TaskRemoval(note: note, record: RemovedTask(notePath: "", id: nil, title: "", lines: [], index: 0, before: nil, after: nil))
        }
        return removal
    }

    func testTheRecordHoldsTheLinesAndTheirPlace() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Buy a new hose")
        XCTAssertEqual(taken.record.lines.count, 3, "The task and both its subtasks.")
        XCTAssertEqual(taken.record.lines[0], "- [ ] Buy a new hose ^t0a1b2c")
        XCTAssertTrue(taken.record.lines[1].hasPrefix("    - [ ]"), "Their indentation is kept as it was.")
        XCTAssertEqual(taken.record.id, "t0a1b2c")
        XCTAssertEqual(taken.record.index, 4)
        XCTAssertEqual(taken.record.before, "- [ ] Call the bank about the ferry")
        XCTAssertEqual(taken.record.after, "- [ ] Order the saddle")
        XCTAssertFalse(taken.note.body.contains("Buy a new hose"))
        XCTAssertTrue(original.body.contains("Buy a new hose"), "The note that was handed in is not changed.")
    }

    func testAnUntouchedNoteTakesTheTaskBackWhereItWas() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Buy a new hose")
        var restored = taken.note
        XCTAssertEqual(restored.putBack(taken.record), .sameSpot)
        XCTAssertEqual(restored.body, original.body, "Subtasks, indentation, order and the id are all back.")
    }

    func testAFirstLineGoesBackToTheTop() {
        let original = note("- [ ] Top line\n- [ ] Second\n", path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Top line")
        XCTAssertNil(taken.record.before)
        var restored = taken.note
        XCTAssertEqual(restored.putBack(taken.record), .sameSpot)
        XCTAssertEqual(restored.body, original.body)
    }

    func testADeletedLineWithNoIdComesBackWithNoId() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Order the saddle")
        XCTAssertNil(taken.record.id)
        var restored = taken.note
        XCTAssertEqual(restored.putBack(taken.record), .sameSpot)
        XCTAssertEqual(restored.body, original.body)
    }

    /// A second Undo adds nothing: the task is there.
    func testPuttingBackTwiceAddsItOnce() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Buy a new hose")
        var restored = taken.note
        XCTAssertEqual(restored.putBack(taken.record), .sameSpot)
        let once = restored
        XCTAssertEqual(restored.putBack(taken.record), .alreadyThere)
        XCTAssertEqual(restored, once)
    }

    func testATaskWithTheSameIdIsAlreadyThere() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Buy a new hose")
        // Somebody wrote the task again, with its id, further down.
        var other = taken.note
        other.append(task: TaskItem(title: "Buy a hose", id: "t0a1b2c"))
        let before = other
        XCTAssertEqual(other.putBack(taken.record), .alreadyThere)
        XCTAssertEqual(other, before)
    }

    func testATaskWithNoIdIsAlreadyThereOnlyWithTheSameLine() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Order the saddle")
        // The same words, typed again: the line is there, so nothing is added.
        var same = taken.note
        same.append(task: TaskItem(title: "Order the saddle"))
        let sameBefore = same
        XCTAssertEqual(same.putBack(taken.record), .alreadyThere)
        XCTAssertEqual(same, sameBefore)
        // The same words with a date added: a different line, so the deleted one comes back.
        var different = taken.note
        different.append(task: TaskItem(title: "Order the saddle", dueDate: DateOnly(year: 2026, month: 12, day: 1)))
        XCTAssertNotEqual(different.putBack(taken.record), .alreadyThere)
        XCTAssertEqual(different.tasks.filter { $0.title == "Order the saddle" }.count, 2)
    }

    /// The Inbox often gains a capture within seconds. The deleted line goes before it, where
    /// it was in the order, and the new capture is not written over.
    func testANewCaptureAtTheEndDoesNotGetInTheWay() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Order the saddle")
        var meanwhile = taken.note
        meanwhile.append(task: TaskItem(title: "Phone the dentist"))

        XCTAssertEqual(meanwhile.putBack(taken.record), .afterPrevious)
        let titles = meanwhile.tasks.filter { !$0.isSubtask }.map(\.title)
        XCTAssertEqual(titles, ["Call the bank about the ferry", "Buy a new hose", "Order the saddle", "Phone the dentist"])
        XCTAssertEqual(meanwhile.tasks.filter { $0.isSubtask }.count, 2, "The hose's subtasks stay under the hose.")
    }

    /// A task is never put between a parent and a child it has gained.
    func testATaskIsNotPutBetweenAParentAndItsNewChild() {
        let original = note("## Tasks\n- [ ] Parent\n- [ ] Deleted one\n- [ ] Last\n", path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Deleted one")
        var meanwhile = taken.note
        var lines = meanwhile.lines
        let parentAt = lines.firstIndex(of: "- [ ] Parent") ?? 0
        lines.insert("    - [ ] A child added meanwhile", at: parentAt + 1)
        meanwhile.lines = lines

        XCTAssertEqual(meanwhile.putBack(taken.record), .afterPrevious)
        let tasks = meanwhile.tasks
        let child = tasks.first { $0.title == "A child added meanwhile" }
        XCTAssertEqual(child?.parentLineIndex, tasks.first { $0.title == "Parent" }?.lineIndex,
                       "The child still belongs to the parent.")
        let restored = tasks.first { $0.title == "Deleted one" }
        XCTAssertFalse(restored?.isSubtask ?? true, "And the restored task is not its child.")
        XCTAssertTrue((restored?.lineIndex ?? 0) > (child?.lineIndex ?? 99))
    }

    /// The line before it was edited, the line after it is still there.
    func testWithOnlyTheNextLineLeftItGoesBeforeIt() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Buy a new hose")
        var meanwhile = taken.note
        meanwhile.body = meanwhile.body.replacingOccurrences(of: "Call the bank about the ferry", with: "Call the bank")
        XCTAssertEqual(meanwhile.putBack(taken.record), .beforeNext)
        let titles = meanwhile.tasks.filter { !$0.isSubtask }.map(\.title)
        XCTAssertEqual(titles, ["Call the bank", "Buy a new hose", "Order the saddle"])
    }

    /// Both neighbours gone: the end of the Tasks section, and a subtask whose parent is gone
    /// comes back at the top level, never as the child of whatever happens to be above it.
    func testWithNothingLeftToHoldOnToItGoesToTheEnd() {
        let original = note(inbox, path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Measure the old one")
        XCTAssertTrue(taken.record.lines[0].hasPrefix("    "))
        var meanwhile = taken.note
        meanwhile.body = "# Inbox\n\n## Tasks\n- [ ] Something else entirely\n"

        XCTAssertEqual(meanwhile.putBack(taken.record), .endOfTasks)
        let restored = meanwhile.tasks.first { $0.title == "Measure the old one" }
        XCTAssertNotNil(restored)
        XCTAssertFalse(restored?.isSubtask ?? true, "Top level: its parent is not there.")
        XCTAssertEqual(meanwhile.tasks.last?.title, "Measure the old one")
    }

    func testABlankNeighbourIsNotAnAnchor() {
        let original = note("## Tasks\n- [ ] One\n\n- [ ] Two\n", path: "Inbox.md", kind: .inbox)
        let taken = removal(original, "Two")
        XCTAssertEqual(taken.record.before, "")
        XCTAssertEqual(taken.record.after, "")
        // Both neighbours were blank lines. A blank line is the same line in many places, so
        // neither says where the task was, and when the exact place has changed only the end
        // of the Tasks section is left.
        var meanwhile = taken.note
        meanwhile.body = "## Tasks\n- [ ] One\n"
        XCTAssertEqual(meanwhile.putBack(taken.record), .endOfTasks)
        XCTAssertEqual(meanwhile.tasks.map(\.title), ["One", "Two"])
    }

    // MARK: Through a real vault

    /// The Inbox as the app writes it, with a capture arriving between the delete and the Undo.
    func testWithARealInboxACaptureInBetweenKeepsBothLines() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        _ = try vault.capture(CaptureItem(text: "Call the bank about the ferry"))
        _ = try vault.capture(CaptureItem(text: "Order the saddle"))
        let inboxNote = try vault.inboxNote()
        let saddle = try XCTUnwrap(inboxNote.tasks.first { $0.title == "Order the saddle" })
        let taken = try XCTUnwrap(inboxNote.removingTaskBlock(for: saddle))
        _ = try vault.save(taken.note)

        _ = try vault.capture(CaptureItem(text: "Phone the dentist"))
        var fresh = try vault.inboxNote()
        let outcome = fresh.putBack(taken.record)
        XCTAssertEqual(outcome, .afterPrevious)
        _ = try vault.save(fresh)

        let finalTitles = try vault.inboxNote().tasks.map(\.title)
        XCTAssertEqual(finalTitles, ["Call the bank about the ferry", "Order the saddle", "Phone the dentist"])
    }

    // MARK: Words

    func testTheWordsForPuttingDatesBack() {
        XCTAssertEqual(UndoWording.datesPutBack(total: 1, restored: 1, skipped: []), "1 task put back.")
        XCTAssertEqual(UndoWording.datesPutBack(total: 6, restored: 6, skipped: []), "6 tasks put back.")
        XCTAssertEqual(
            UndoWording.datesPutBack(total: 6, restored: 5,
                                     skipped: [SkippedTask(title: "Send the invoice", reason: .changed)]),
            "5 of 6 tasks put back. \u{201C}Send the invoice\u{201D} was changed after the move, so it was left as it is.")
        XCTAssertEqual(
            UndoWording.datesPutBack(total: 1, restored: 0,
                                     skipped: [SkippedTask(title: "Pay", reason: .done)]),
            "Nothing was put back. \u{201C}Pay\u{201D} was ticked off after the move, so it was left as it is.")
    }

    func testSeveralLeftAloneForOneReasonAreNamedTogether() {
        let skipped = ["A", "B", "C", "D", "E"].map { SkippedTask(title: $0, reason: .done) }
        let said = UndoWording.datesPutBack(total: 7, restored: 2, skipped: skipped)
        XCTAssertTrue(said.hasPrefix("2 of 7 tasks put back. 5 were ticked off after the move, so they were left as they are: "))
        XCTAssertTrue(said.contains("\u{201C}A\u{201D}, \u{201C}B\u{201D}, \u{201C}C\u{201D} and 2 more."), said)
    }

    func testSeveralLeftAloneForDifferentReasonsSayWhatTheyHaveInCommon() {
        let skipped = [SkippedTask(title: "A", reason: .done), SkippedTask(title: "B", reason: .gone)]
        let said = UndoWording.datesPutBack(total: 4, restored: 2, skipped: skipped)
        XCTAssertTrue(said.contains("2 tasks were left as they are, because they were ticked off or changed after the move, are not there any more, have the same name as another task, or could not be written: "), said)
    }

    func testTheWordsForPuttingALineBack() {
        let title = "Order the saddle"
        XCTAssertEqual(UndoWording.deletionUndone(title: title, .sameSpot), "\u{201C}Order the saddle\u{201D} put back.")
        XCTAssertTrue(UndoWording.deletionUndone(title: title, .afterPrevious).contains("near where it was"))
        XCTAssertTrue(UndoWording.deletionUndone(title: title, .beforeNext).contains("near where it was"))
        XCTAssertTrue(UndoWording.deletionUndone(title: title, .endOfTasks).contains("end of the tasks"))
        XCTAssertTrue(UndoWording.deletionUndone(title: title, .alreadyThere).contains("already there"))
        XCTAssertTrue(UndoWording.noteMissing(title: title).contains("not there"))
        XCTAssertTrue(UndoWording.notWritten(title: title).contains("could not be written"))
    }

    func testTheOfferStaysForEightSeconds() {
        XCTAssertEqual(UndoWording.offerSeconds, 8)
        XCTAssertEqual(UndoWording.secondsOnScreen(offersUndo: true), 8)
    }

    /// Only a message with an Undo stays longer than it always did. Every other message, long or
    /// short, stays the two and a half seconds it had before this build.
    func testAMessageWithoutAnUndoStaysTwoAndAHalfSeconds() {
        XCTAssertEqual(UndoWording.secondsOnScreen(offersUndo: false), 2.5)
        XCTAssertEqual(UndoWording.secondsOnScreen(offersUndo: true), 8)
    }
}
