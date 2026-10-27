import XCTest
#if os(macOS)
import AppKit
#endif

/// The screens, actually pressed — on a simulated iPhone and, since build 195, on the Mac.
///
/// **Build 190.** Everything else in this repository is checked by a compiler or by a test over
/// plain values. These are the first checks that open the app and touch it, which is the only
/// way to catch the class of fault that has cost this project the most: a row that cannot be
/// selected, a gesture that eats a tap, a screen that draws nothing.
///
/// **Deliberately few, and deliberately dull.** A screen test that fails for its own reasons is
/// worse than no screen test, because the next red light is then ignored. Each one here asks a
/// question the app must always answer yes to, and says plainly which step failed.
///
/// **Every element is found by an accessibility identifier, never by its words.** The phone's
/// tabs are pages of one pager, so a title such as "Projects" can be on screen twice at once
/// (the Browse row and a group heading on the Actions page), and a word he asks to be renamed
/// must not quietly stop a test from finding the thing. The names the tests use are spelled in
/// the app beside the views: `tab.*` and `browse.<section>` on the phone, `sidebar.<section>`
/// on the Mac, and on both `note.<path>`, `inbox.<line>`, `note.editor`, `list.newNote`,
/// `new.<thing>`, `sheet.action` / `sheet.cancel`, `capture.open`, `capture.text`,
/// `capture.save`, `map.<path>`, `projects.group.<id>`, `project.next.<path>`,
/// `project.tile.<path>`, `note.emoji`, `emoji.choice.<emoji>`, `task.tick.<title>`,
/// `projects.band`, `project.weekly.<path>`, `focus.start`, `focus.bar`, `focus.pause`,
/// `focus.stop`, `new.inArea`, `note.area`, and on the Mac `focus.menuBar` (a status item).
/// The vault is `TestVault` in the app, which is where its titles live.
///
/// **One suite, two platforms.** A test bundle compiles once per platform, so `#if os(macOS)`
/// picks the Mac's way in — the sidebar row — where the phone taps a tab, and `go(to:)` is the
/// one place that choice is made. What comes after is the same code; that is the point of the
/// names. Since build 196 all seven run on both, and four more run on the Mac alone: the
/// three columns staying inside the window, and the menu bar's shortcuts, neither of which
/// the phone has.
final class ScreenTests: XCTestCase {
    private var app: XCUIApplication!

    /// Long, because a cold simulator on a CI runner is slow and a timeout that is too short
    /// is exactly the flake that makes a suite untrustworthy.
    private let appears: TimeInterval = 60

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-paragon-test-vault"]
        app.launch()
    }

    // MARK: Both platforms

    /// The welcome screen has neither a tab bar nor a sidebar, so this also proves the vault
    /// opened. Without it every other test below would be testing the first-run screen and
    /// passing for the wrong reason — build 179's lesson, where "I cannot open your folder"
    /// and "you have never set this up" were the same picture.
    func testTheAppOpensItsVaultAndDrawsItsHome() {
        XCTAssertTrue(element(Self.home).waitForExistence(timeout: appears),
                      "\(Self.home) never appeared. The app is probably on the welcome screen, which means the vault did not open. On screen: \(visibleTexts())")
        for name in Self.homeMarks {
            XCTAssertTrue(element(name).exists, "\(name) is missing from the app's home.")
        }
    }

    /// Every way in draws a screen and the app is still running at the end. Builds 71 to 74
    /// left a whole screen unusable and CI was green throughout.
    func testEverySectionOpensItsScreen() {
        XCTAssertTrue(element(Self.home).waitForExistence(timeout: appears),
                      "\(Self.home) never appeared.")
        for name in Self.sections {
            let way = element(name)
            XCTAssertTrue(way.waitForExistence(timeout: 20), "\(name) is not on screen.")
            way.press()
            XCTAssertTrue(screenIsDrawn(timeout: 20),
                          "\(name) opened without drawing a screen. On screen: \(visibleTexts())")
            XCTAssertEqual(app.state, .runningForeground, "The app stopped running on \(name).")
        }
        XCTAssertTrue(element(Self.home).exists, "\(Self.home) is gone after visiting every section.")
    }

    /// Browse › Projects › the test project, then type into it. From build 114 to 128 the phone
    /// editor needed a press-and-hold before it would take a letter, three builds were spent on
    /// its layout while the fault was a gesture, and CI never knew any of it.
    func testANoteCanBeOpenedAndTypedIn() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor. Either the row did not open the note, or the editor is not in Edit mode.")
        editor.press()
        editor.typeText("Typed by the screen test. ")

        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Typed by the screen test"),
                      "The editor did not take the typing. It shows: \(shown.prefix(200))")
    }

    /// The settings block at the top of a note can be folded away and comes back (build 246).
    /// Build 248: the **time?** button on a task row writes `~45m` into the note. Both the
    /// button and the choice are pressed at the middle of their frames (`press(_:at:)`).
    func testATaskCanBeGivenATime() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor.")

        // The row first: it is found the way every row is (build 211), and its frame says
        // whether the task box is on screen at all. Build 249's first run found the button but
        // the phone could not work out where it was, so both frames go into every message.
        let row2 = element("task.Book the night train")
        XCTAssertTrue(row2.waitForExistence(timeout: 10),
                      "The note's task box has no row for the test task. On screen: \(visibleTexts())")
        // **Among buttons, never "any element"** (build 249's second run): the name also lands
        // on an element with no frame at all — a wrapper SwiftUI makes around the button for its
        // popover — and `firstMatch` over every kind of element picked that one.
        let named = app.descendants(matching: .any).matching(identifier: "task.time.Book the night train")
        let time = app.buttons.matching(identifier: "task.time.Book the night train").firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 10),
                      "The task row has no time button (\(named.count) elements carry its name). On screen: \(visibleTexts())")
        let whereItIs = "row \(row2.frame), button \(time.frame), window \(app.windows.firstMatch.frame), \(named.count) named"
        // **Both platforms press the button** since build 250. Before it the Mac's note column
        // was wider than its window at 900 points and the button sat past the window's edge
        // (x 980 in a window ending at 962); the header row now wraps, so the row fits. If the
        // button is off the window again, that is the fault this check is here to catch.
        #if os(macOS)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(time.frame),
                      "The time button is outside the window, so the note column is too wide again: \(whereItIs)")
        #endif
        let timeFrame = time.frame
        guard Self.isOnScreen(timeFrame) else {
            XCTFail("The time button has no place on screen: \(whereItIs)")
            return
        }
        press(time, at: timeFrame)

        let choice = app.buttons.matching(identifier: "time.choice.45").firstMatch
        let opened = choice.waitForExistence(timeout: 10)
        #if os(macOS)
        let why = opened ? "" : " The app's log: \(diagnosticsTail())"
        #else
        let why = ""
        #endif
        XCTAssertTrue(opened,
                      "Pressing the time button did not show the choices (\(whereItIs)). On screen: \(visibleTexts())\(why)")
        guard opened else { return }
        // Measured once and used once (build 249's third run): reading `frame` twice asks the
        // app twice, and a popover can answer differently the second time.
        let choiceFrame = choice.frame
        if Self.isOnScreen(choiceFrame) {
            press(choice, at: choiceFrame)
        } else {
            choice.press()
        }

        XCTAssertTrue(editorHolds(editor, "Book the night train ~45m", within: 10),
                      "The note does not carry the time: \(String(((editor.value as? String) ?? "").suffix(200)))")
    }

    /// The editor's text is the proof: `type:` is in it, then not, then in it again.
    func testTheSettingsBlockCanBeFoldedAway() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor.")
        XCTAssertTrue(editorHolds(editor, "type:", within: 10),
                      "The editor does not show the settings block to begin with: \(String(((editor.value as? String) ?? "").prefix(200)))")

        let fold = element("note.frontmatter")
        XCTAssertTrue(fold.waitForExistence(timeout: 10),
                      "There is no fold button above the text.")
        // A click on the button itself when the Mac will take one, the centre point only
        // otherwise: the app's log showed the centre point landing in the note list.
        if fold.isHittable { fold.press() } else { fold.pressCentre() }
        // The editor has to still be there: a wait on "the text no longer contains" is also
        // true of an editor that has gone, and on the Mac the second run ended with
        // "No note open" on screen, which only this check can tell apart from a fold.
        let stillOpen = editor.waitForExistence(timeout: 5)
        #if os(macOS)
        // The app's own log names the view each click landed on and the moment the note was
        // deselected, which is the one thing that tells a stray click from a fault in the fold.
        let why = stillOpen ? "" : " The app's log: \(diagnosticsTail())"
        #else
        let why = ""
        #endif
        XCTAssertTrue(stillOpen,
                      "The note closed when the fold was pressed. On screen: \(visibleTexts())\(why)")
        XCTAssertTrue(editorLacks(editor, "type:", within: 10),
                      "The settings block is still shown after the fold was pressed: \(String(((editor.value as? String) ?? "").prefix(200)))")

        // Asked for again before the second press: on the Mac the first run found the row,
        // folded with it, and then could not resolve it for the coordinate click a moment
        // later. Waiting says whether the row is really gone or was only being redrawn.
        XCTAssertTrue(fold.waitForExistence(timeout: 10),
                      "The fold button is gone after folding. On screen: \(visibleTexts())")
        if fold.isHittable { fold.press() } else { fold.pressCentre() }
        XCTAssertTrue(editorHolds(editor, "type:", within: 10),
                      "The settings block did not come back after the second press.")
    }

    /// A line in the Inbox can be picked by tapping it. Builds 71 to 74 attached a drag and a
    /// tap to the row, each of which took the click, and no line could be selected at all —
    /// the very thing this asks.
    func testALineInTheInboxCanBeSelected() {
        go(to: .inbox)

        let line = element("inbox.Call the bank about the ferry")
        XCTAssertTrue(line.waitForExistence(timeout: 20),
                      "The Inbox does not show the test line. Did the test vault capture it?")
        line.press()

        // Selection is published a turn later (the model's afterUpdate), so wait for it rather
        // than read it at once.
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: line)
        wait(for: [selected], timeout: 10)
        XCTAssertTrue(line.isSelected, "The line was tapped and did not become the selected one.")
    }

    /// The New note screen, end to end: open it from the Projects list, press **Project**, give
    /// it a name, press **Create**, and the new note opens in the editor with that name in it.
    /// The screen was rebuilt in builds 185 to 191 and had never been pressed by anything but
    /// his thumb.
    func testTheNewNoteScreenMakesAProject() {
        go(to: .projects)

        let newNote = element("list.newNote")
        XCTAssertTrue(newNote.waitForExistence(timeout: 20), "The Projects list has no New note button.")
        newNote.press()

        let projectButton = element("new.project")
        XCTAssertTrue(projectButton.waitForExistence(timeout: 20),
                      "The New note screen did not open, or has no Project button.")
        projectButton.press()

        let name = element("new.name")
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The New note screen has no name field.")
        name.press()
        name.typeText("Made by the screen test")

        let create = element("sheet.action")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "The New note screen has no Create button.")
        XCTAssertTrue(create.isEnabled, "Create stayed grey after a name was typed.")
        create.press()

        // A new note is opened straight away, so the editor is the proof that it was made:
        // it shows the file from disk, and the template puts the name in the first line.
        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "Create was pressed and no note opened. The note may not have been made.")
        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Made by the screen test"),
                      "The note that opened does not carry the name that was typed. It shows: \(shown.prefix(200))")
    }

    /// Quick capture, end to end: the Quick capture button (top left of Today on the phone, the
    /// window's toolbar on the Mac), a line typed, **Save**, and the line waiting in the Inbox.
    /// That is the whole point of the app's fastest path, and build 158 rebuilt the screen on
    /// a Mac panel width that had pushed Save off the phone.
    func testACaptureLandsInTheInbox() {
        go(to: .today)

        let open = element("capture.open")
        XCTAssertTrue(open.waitForExistence(timeout: 20), "There is no Quick capture button.")
        open.press()

        // A text view on the phone, a text field on the Mac; the name is what both carry.
        let field = element("capture.text")
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The capture screen did not open, or has no field.")
        field.press()
        field.typeText("Captured by the screen test")

        let save = element("capture.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10), "The capture screen has no Save button.")
        XCTAssertTrue(save.isEnabled, "Save stayed grey after a line was typed.")
        save.press()

        // What the app says after Save ("Saved to Inbox") is the proof the capture ran; the
        // screen then closes itself a moment later, and the Inbox tab is behind it until it
        // does. Each is checked on its own, with what was on screen in the message, because a
        // log is the only eye there is on this simulator.
        // `label` on the phone, `value` on the Mac: an AppKit static text keeps its words in
        // its value and its label is empty, which is why the first Mac run of this test could
        // never see the word (build 196).
        let saidSaved = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Saved' OR value BEGINSWITH 'Saved'")).firstMatch
        let confirmed = saidSaved.waitForExistence(timeout: 10)
        // Thirty seconds, not fifteen: the screen closes itself 1.8 s after Save, but the
        // first run of this test on a cold CI simulator took longer than fifteen and failed
        // for its own reasons — the flake this suite must never have (build 190).
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: save)
        let closing = XCTWaiter().wait(for: [closed], timeout: 30)
        XCTAssertTrue(confirmed,
                      "Save was pressed and the screen never said Saved. On screen: \(visibleTexts())")
        XCTAssertEqual(closing, .completed,
                       "The capture screen said Saved but did not close itself. On screen: \(visibleTexts())")

        go(to: .inbox)
        let line = element("inbox.Captured by the screen test")
        XCTAssertTrue(line.waitForExistence(timeout: 20),
                      "The captured line is not in the Inbox. Either the capture was not written, or the Inbox did not reload.")
    }

    /// A box on the Map takes a tap and opens its note. Build 85 had every box swallow clicks
    /// across the whole canvas and the last one drawn win them all; CI compiled it green. The
    /// aspiration's box is the one tapped because root goals sit at the top of the layout,
    /// where a phone shows them without scrolling.
    func testAMapBoxOpensItsNote() {
        go(to: .map)

        let box = element("map.Goals/Be strong and steady at seventy.md")
        XCTAssertTrue(box.waitForExistence(timeout: 30),
                      "The Map drew no box for the test aspiration. On screen: \(visibleTexts())")
        // "On screen" is the box's frame inside the window's, not `isHittable`: the Mac says
        // "not hittable" of a SwiftUI group whose hit test lands on the text inside it, and
        // said so of this box while it was plainly drawn (build 196).
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.intersects(box.frame) && !box.frame.isEmpty,
                      "The aspiration's box is on the Map but not on screen at this size, so it cannot be pressed. Box \(box.frame), window \(window). On screen: \(visibleTexts())")
        box.pressCentre()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The box was tapped and its note did not open. On screen: \(visibleTexts())")
        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Be strong and steady at seventy"),
                      "A note opened, but not the one whose box was tapped. It shows: \(shown.prefix(200))")
    }

    /// **The All actions filter really narrows the list** (build 211). The boxes are the one
    /// control in this app that decides what you do *not* see, so a tick that quietly did
    /// nothing — or hid everything — would be invisible until he noticed an action missing.
    ///
    /// The test vault has no dated task at all, so **Overdue** must empty the list completely
    /// and the screen must say *which* kind of empty it is: `actions.noMatch`, never
    /// `actions.nothingOpen` (build 100's rule, and build 190's — a check that cannot tell the
    /// two apart would pass on an empty vault).
    func testTheAllActionsFilterNarrowsTheList() {
        go(to: .allActions)

        let action = element("task.Book the night train")
        XCTAssertTrue(action.waitForExistence(timeout: 20),
                      "All actions does not list the test project's action. On screen: \(visibleTexts())")

        openTheBoxes()

        let overdue = element("actions.box.overdue")
        XCTAssertTrue(overdue.waitForExistence(timeout: 20),
                      "The Overdue box is not on screen. On screen: \(visibleTexts())")
        overdue.pressCentre()

        XCTAssertTrue(element("actions.noMatch").waitForExistence(timeout: 20),
                      "Overdue was ticked and the screen did not say that nothing matches. On screen: \(visibleTexts())")
        XCTAssertFalse(element("task.Book the night train").exists,
                       "Overdue was ticked and the undated action is still listed.")

        let clear = element("actions.clear")
        XCTAssertTrue(clear.waitForExistence(timeout: 20),
                      "Clear is not offered while a box is ticked. On screen: \(visibleTexts())")
        clear.pressCentre()

        XCTAssertTrue(element("task.Book the night train").waitForExistence(timeout: 20),
                      "Clear was pressed and the action did not come back. On screen: \(visibleTexts())")
    }

    /// The boxes start folded on the phone and open on the Mac, so this asks the screen rather
    /// than assuming. Pressing the fold button blind would close them on the Mac.
    private func openTheBoxes() {
        if element("actions.box.overdue").waitForExistence(timeout: 5) { return }
        let fold = element("actions.fold")
        XCTAssertTrue(fold.waitForExistence(timeout: 20),
                      "The boxes are folded and there is no button to open them. On screen: \(visibleTexts())")
        fold.pressCentre()
    }

    /// The evening step opens, draws itself, and closes again. Dull on purpose (build 190):
    /// what it really proves is that `CloseDayView` builds at all, on both platforms, which is
    /// the one thing CI could not see about a brand new screen.
    ///
    /// `pressCentre` rather than `press`: the Mac refuses `click()` on an element it calls not
    /// hittable, and it says that of a plain-styled button whose hit test lands on the label
    /// inside it (build 196). A coordinate press asks no such question.
    func testCloseTheDayOpensAndCloses() {
        go(to: .today)

        let open = element("today.closeDay")
        XCTAssertTrue(open.waitForExistence(timeout: 20),
                      "Today has no Close the day button. On screen: \(visibleTexts())")
        open.pressCentre()

        let screen = element("closeDay.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 20),
                      "Close the day did not open. On screen: \(visibleTexts())")

        // Both footer buttons, so "the sheet opened empty" and "the sheet opened" fail with
        // different words.
        XCTAssertTrue(element("sheet.action").waitForExistence(timeout: 10),
                      "Close the day opened without its Done button. On screen: \(visibleTexts())")
        let cancel = element("sheet.cancel")
        XCTAssertTrue(cancel.exists, "Close the day opened without its Cancel button.")
        // Build 259: Planned and worked is drawn. Nothing is planned in the test vault, so this
        // is its empty state, which still has to be there and say why.
        XCTAssertTrue(element("closeDay.plannedWorked").waitForExistence(timeout: 10),
                      "Close the day has no Planned and worked section. On screen: \(visibleTexts())")

        cancel.pressCentre()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 20),
                      "Cancel was pressed and Close the day stayed on screen.")
    }

    /// **Start the day** (build 233) opens and closes. The test vault has no dated task and no
    /// next action — a fixture other tests rely on (build 221) — so the screen shows its
    /// "Nothing is waiting" words and the test does not pick anything. What it really proves is
    /// that a brand new view builds and opens on both platforms (build 190).
    func testStartTheDayOpensAndCloses() {
        go(to: .today)

        let open = element("today.startDay")
        XCTAssertTrue(open.waitForExistence(timeout: 20),
                      "Today has no Start the day button. On screen: \(visibleTexts())")
        open.pressCentre()

        let screen = element("startDay.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 20),
                      "Start the day did not open. On screen: \(visibleTexts())")

        // Build 235: a line typed into the field and added with + lands in the list, dated
        // today, and arrives already picked. The proof is the button's word (**Picked**) or its
        // `isSelected` trait — never its colour (build 191). Either is accepted because a Mac
        // button carries its words as its label and may not report the trait the phone does.
        let field = element("startDay.newAction")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Start the day has no field for a new action. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Water the plants")
        let add = element("startDay.add")
        XCTAssertTrue(add.isEnabled, "The + stayed grey after a line was typed.")
        add.pressCentre()
        let pick = element("startDay.pick.Water the plants")
        XCTAssertTrue(pick.waitForExistence(timeout: 20),
                      "The added action did not appear in the list. On screen: \(visibleTexts())")
        let chosen = expectation(
            for: NSPredicate(format: "label == 'Picked' OR value == 'Picked' OR isSelected == true"),
            evaluatedWith: pick)
        wait(for: [chosen], timeout: 10)
        XCTAssertTrue(element("sheet.action").waitForExistence(timeout: 10),
                      "Start the day opened without its Done button. On screen: \(visibleTexts())")
        let cancel = element("sheet.cancel")
        XCTAssertTrue(cancel.exists, "Start the day opened without its Cancel button.")

        cancel.pressCentre()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 20),
                      "Cancel was pressed and Start the day stayed on screen.")
    }

    /// **Start the day** shows what is already known this morning (build 265): the line written
    /// last evening in **Close the day** — the test vault's daily note for yesterday carries one —
    /// and a heading for today's calendar events. The line's label is set as one sentence, so it
    /// reads the same on both platforms (build 253); the heading is looked for among buttons
    /// (build 249). **The fold is not pressed**: whether the runner has events or Calendar access
    /// is not up to the test, and a test may not fail for its own reasons (build 190).
    func testStartTheDayShowsLastEveningAndTheDay() {
        go(to: .today)

        let open = element("today.startDay")
        XCTAssertTrue(open.waitForExistence(timeout: 20),
                      "Today has no Start the day button. On screen: \(visibleTexts())")
        open.pressCentre()

        let screen = element("startDay.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 20),
                      "Start the day did not open. On screen: \(visibleTexts())")

        let evening = element("startDay.lastEvening")
        XCTAssertTrue(evening.waitForExistence(timeout: 20),
                      "Start the day does not show what was written last evening. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { self.words(of: evening).contains("A quiet day by the sea") },
                      "The line from last evening is not the one in the test vault. It says: \(words(of: evening))")

        let calendar = app.buttons.matching(identifier: "startDay.calendar").firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 10),
                      "Start the day has no heading for today's calendar events. On screen: \(visibleTexts())")

        let cancel = element("sheet.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 10),
                      "Start the day opened without its Cancel button. On screen: \(visibleTexts())")
        cancel.pressCentre()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 20),
                      "Cancel was pressed and Start the day stayed on screen.")
    }

    /// **Now and Then** on Today (build 266). An action added in **Start the day** arrives
    /// picked, and **Plan 1 action** puts it into today's plan as a one-hour block from the next
    /// quarter hour. Today must then name it: as **Then** until that quarter hour has come, as
    /// **Now** after it — on a slow runner it can be either, and both are right.
    ///
    /// The test vault has no plan on purpose (build 221's rule: its emptiness is a fixture), so
    /// this test makes its own block in its own fresh vault. The clock button is not pressed: a
    /// block cannot be made to be now without waiting for it, and the bar the button starts is
    /// `testAFocusTimerStartsPausesAndStops`'s. Skipped after 22:30 on the runner's clock: a
    /// one-hour block from the next quarter hour still fits until about 23:00, and the half hour
    /// before that is room for the test's own run. CI's "Check the tests really ran" counts a
    /// skipped case as finished (the review of 266: before that, a skip turned the job red).
    func testAPlannedActionShowsOnToday() throws {
        let clock = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (clock.hour ?? 0) * 60 + (clock.minute ?? 0)
        try XCTSkipIf(minute >= 22 * 60 + 30,
                      "After 22:30 a one-hour block from the next quarter hour may run out of room before midnight while the test is still running.")

        go(to: .today)

        let open = element("today.startDay")
        XCTAssertTrue(open.waitForExistence(timeout: 20),
                      "Today has no Start the day button. On screen: \(visibleTexts())")
        open.pressCentre()

        let screen = element("startDay.screen")
        XCTAssertTrue(screen.waitForExistence(timeout: 20),
                      "Start the day did not open. On screen: \(visibleTexts())")

        let field = element("startDay.newAction")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Start the day has no field for a new action. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Water the plants")
        let add = element("startDay.add")
        XCTAssertTrue(add.isEnabled, "The + stayed grey after a line was typed.")
        add.pressCentre()
        let pick = element("startDay.pick.Water the plants")
        XCTAssertTrue(pick.waitForExistence(timeout: 20),
                      "The added action did not appear in the list. On screen: \(visibleTexts())")
        let chosen = expectation(
            for: NSPredicate(format: "label == 'Picked' OR value == 'Picked' OR isSelected == true"),
            evaluatedWith: pick)
        wait(for: [chosen], timeout: 10)

        let plan = element("sheet.action")
        XCTAssertTrue(plan.waitForExistence(timeout: 10),
                      "Start the day opened without its button at the bottom. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { self.words(of: plan).contains("Plan 1") },
                      "The button at the bottom does not offer to plan the picked action. It says: \(words(of: plan))")
        plan.pressCentre()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 20),
                      "Plan 1 action was pressed and Start the day stayed on screen.")

        // **One query for both lines, matched by their words** (the review of 266). The block
        // starts at the next quarter hour, so at that minute **Then** turns into **Now** and
        // `today.next` goes away. A line looked up by one name, checked and then read, could
        // vanish between the two and fail the test for its own reasons (build 190). This query is
        // run again on every read, so it answers with whichever line is showing at that moment.
        // Both lines' words are one element with one sentence as its label, so both platforms
        // read them the same (build 253).
        let wanted = "Water the plants"
        let planLines = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'today.now' OR identifier == 'today.next'"))
        let line = planLines.matching(NSPredicate(format: "label CONTAINS %@", wanted)).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 30),
                      "Today does not name the planned action on its Now or Then line (\(planLines.count) such lines are shown). On screen: \(visibleTexts())")

        #if os(macOS)
        // Build 250: on the Mac a row that will not shrink makes its column lay out wider than
        // the column, centred, and cut off at both sides. **Today is the middle column**, so its
        // neighbours are inside the window and a check against the window could never fail
        // (build 178's rule; found by the review of 266). The cut is the same on both sides, so
        // the left side is enough: the line must start to the right of the sidebar. Not against
        // a button in Today's own column: a cut moves that button by the same amount as the line.
        let sidebarRow = element("sidebar.Today")
        XCTAssertTrue(sidebarRow.exists, "The sidebar has no Today row. On screen: \(visibleTexts())")
        let lineFrame = line.frame
        let sidebarFrame = sidebarRow.frame
        // A frame with no size would make the check below pass whatever happens (build 178).
        XCTAssertFalse(sidebarFrame.isEmpty || lineFrame.isEmpty,
                       "The sidebar's Today row or the line has no size: line \(lineFrame), sidebar row \(sidebarFrame).")
        XCTAssertGreaterThanOrEqual(lineFrame.minX, sidebarFrame.maxX - 1,
                                    "The line starts under the sidebar, so Today's column is cut off at both sides again (build 250): line \(lineFrame), sidebar row \(sidebarFrame).")
        #endif
    }

    /// **Week** on the Plan screen opens Calendar → Week, and that screen draws the two strips
    /// build 225 added: the tray of unplaced work and the seven-day row you drop it on.
    ///
    /// Dull on purpose (build 190). What it proves is that a screen reached through a button
    /// that changes two pieces of model state at once really arrives, on both platforms — and
    /// that `WeekTray` draws, which it only does when something is waiting. The test vault's
    /// `Book the night train` has no date, so there is always one tile.
    func testTheWeekButtonOpensTheWeekWithItsTray() {
        go(to: .plan)

        let week = element("plan.week")
        XCTAssertTrue(week.waitForExistence(timeout: 20),
                      "The Plan screen has no Week button. On screen: \(visibleTexts())")
        week.pressCentre()

        XCTAssertTrue(element("week.strip").waitForExistence(timeout: 20),
                      "Week opened without its seven-day strip. On screen: \(visibleTexts())")
        XCTAssertTrue(element("week.tray").waitForExistence(timeout: 10),
                      "The week has an undated task but drew no tray. On screen: \(visibleTexts())")
    }

    /// Build 251: a goal for the week is written on the week screen and shown on Today.
    /// Pressed at the button's own place (`press(_:at:)`, build 249), and the button is looked
    /// for among buttons, never any element.
    func testAGoalForTheWeekCanBeWritten() {
        go(to: .plan)
        let week = element("plan.week")
        XCTAssertTrue(week.waitForExistence(timeout: 20),
                      "The Plan screen has no Week button. On screen: \(visibleTexts())")
        week.pressCentre()

        let goal = app.buttons.matching(identifier: "week.goal").firstMatch
        XCTAssertTrue(goal.waitForExistence(timeout: 20),
                      "The week screen has no goal box. On screen: \(visibleTexts())")
        let goalFrame = goal.frame
        guard Self.isOnScreen(goalFrame) else {
            XCTFail("The goal box has no place on screen: \(goalFrame)")
            return
        }
        press(goal, at: goalFrame)

        let field = element("week.goal.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Pressing the goal box did not open a field. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Rest and the garden\n")

        // The field closing is the sign Return was taken. **No search over every element for
        // the words**: on the Mac that query timed out after two minutes (build 251's first
        // run). Today's line below is the proof the goal was saved.
        let closed = NSPredicate(format: "exists == NO")
        let gone = expectation(for: closed, evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "The field stayed open after Return. On screen: \(visibleTexts())")

        go(to: .today)
        XCTAssertTrue(element("today.weekGoal").waitForExistence(timeout: 20),
                      "Today does not show the goal for this week. On screen: \(visibleTexts())")
    }

    /// The Projects list in groups (build 253). The test project serves a goal with a date,
    /// which serves the test aspiration, so it must sit under that aspiration's heading; its box
    /// must say what it needs next; and pressing the heading folds the group away and back.
    /// The heading is found **among buttons**, never "any element" (build 249's second run).
    func testProjectsSitUnderTheAspirationTheyServe() {
        go(to: .projects)

        let heading = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "projects.group.aspiration:"))
            .firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 20),
                      "The Projects list has no aspiration heading. On screen: \(visibleTexts())")
        XCTAssertTrue(heading.label.contains("Be strong and steady at seventy"),
                      "The heading is not the test aspiration. It says: \(heading.label)")

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The Projects list does not show the test project. On screen: \(visibleTexts())")
        // "Next:" and not the task's words: the first open task is the project template's own,
        // and a test must not depend on how a template is worded (build 211).
        let next = element("project.next.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(next.waitForExistence(timeout: 10),
                      "The project's box does not say what it needs. On screen: \(visibleTexts())")
        XCTAssertTrue(next.label.hasPrefix("Next: "),
                      "The box has open tasks and does not name the next one. It says: \(next.label)")

        if heading.isHittable { heading.press() } else { heading.pressCentre() }
        let folded = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: row)
        XCTAssertEqual(XCTWaiter().wait(for: [folded], timeout: 10), .completed,
                       "The heading was pressed and the group did not fold. On screen: \(visibleTexts())")

        if heading.isHittable { heading.press() } else { heading.pressCentre() }
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The heading was pressed again and the project did not come back. On screen: \(visibleTexts())")
    }

    /// A finished project says when it ended (build 262). The test vault's **Fix the bike** is
    /// done, made 41 days ago, ended today, with two ticked tasks, so its line under the header
    /// must say "after 41 days" and "2 tasks finished". Those are the app's own English words;
    /// the day itself is the runner's language and is not checked. The ended groups start
    /// folded, so the **Done** heading is opened first unless the row is already there. The
    /// line is found among buttons (build 249) and read from its label, which is set
    /// explicitly so both platforms read the same sentence (build 253).
    ///
    /// Build 269: the **Done** heading also says how many projects ended this year. Fix the
    /// bike ended today, so "1 this year" is true on any day, 1 January included. Its box
    /// carries the day it ended as a pill, read by its name only, since the day's words are the
    /// runner's language.
    func testAFinishedProjectSaysWhenItEnded() {
        go(to: .projects)

        let done = app.buttons.matching(identifier: "projects.group.ended:done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 20),
                      "The Projects list has no Done heading. On screen: \(visibleTexts())")
        XCTAssertTrue(words(of: done).contains("1 this year"),
                      "The Done heading does not say how many projects ended this year. It says: \(words(of: done))")

        let row = element("note.Projects/Fix the bike.md")
        if !row.waitForExistence(timeout: 5) {
            if done.isHittable { done.press() } else { done.pressCentre() }
        }
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The Done group does not show the finished test project. On screen: \(visibleTexts())")
        let day = element("project.endedDay.Projects/Fix the bike.md")
        XCTAssertTrue(day.waitForExistence(timeout: 10),
                      "The finished project's box does not show the day it ended. On screen: \(visibleTexts())")
        XCTAssertTrue(words(of: day).hasPrefix("Ended on"),
                      "The day on the box does not say what it is. It says: \(words(of: day))")
        row.press()

        let line = app.buttons.matching(identifier: "project.ended").firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 20),
                      "The finished project has no line saying when it ended. On screen: \(visibleTexts())")
        XCTAssertTrue(line.label.contains("after 41 days"),
                      "The line does not say how long the project took. It says: \(line.label)")
        XCTAssertTrue(line.label.contains("2 tasks finished"),
                      "The line does not count the finished tasks. It says: \(line.label)")
    }

    /// Step 7 of the Weekly review (build 263): it is drawn at the foot of the review, says
    /// which week it shows, and its arrows move one week back and forward again. The week it
    /// opens on depends on the day the test runs (on Monday and Tuesday it is the week before),
    /// so the test only asks that ‹ changes the week and › brings the same one back. The step
    /// sits below six others, so the list is scrolled until it shows (`reveal`). The arrows are
    /// found among buttons (build 249). The review starts folded (build 266), so the step is
    /// opened first.
    func testTheWeekCanBeLookedBackAt() {
        go(to: .review)
        openReviewPart("7")
        let title = reveal("review.lookBack")
        XCTAssertTrue(title.exists, "The Weekly review has no step 7. On screen: \(visibleTexts())")
        let first = words(of: title)
        XCTAssertTrue(first.contains("Week"), "Step 7 does not say which week it shows. It says: \(first)")
        XCTAssertTrue(element("review.lookBack.goal").exists,
                      "Step 7 has no box for the week's goal. On screen: \(visibleTexts())")
        XCTAssertTrue(element("review.lookBack.days").exists,
                      "Step 7 has no row of days. On screen: \(visibleTexts())")

        let earlier = app.buttons.matching(identifier: "review.lookBack.earlier").firstMatch
        XCTAssertTrue(earlier.waitForExistence(timeout: 10),
                      "Step 7 has no arrow to an earlier week. On screen: \(visibleTexts())")
        if earlier.isHittable { earlier.press() } else { earlier.pressCentre() }
        XCTAssertTrue(becomes(within: 10) { self.words(of: title) != first },
                      "The arrow was pressed and the week stayed \(first).")

        let later = app.buttons.matching(identifier: "review.lookBack.later").firstMatch
        XCTAssertTrue(later.waitForExistence(timeout: 10),
                      "Step 7 has no arrow to a later week. On screen: \(visibleTexts())")
        XCTAssertTrue(later.isEnabled, "One week back, the arrow to a later week is greyed out.")
        if later.isHittable { later.press() } else { later.pressCentre() }
        XCTAssertTrue(becomes(within: 10) { self.words(of: title) == first },
                      "The arrow back did not return to \(first). It says: \(words(of: title))")
    }

    /// Step 8 of the Weekly review (build 264): the goal for the week about to start is written
    /// in the same box as Calendar › Week. Pressed at its frame and found among buttons
    /// (build 249); the field closing is the sign Return was taken, and the box's own label —
    /// set explicitly, one sentence on both platforms — is the proof the words were kept. The
    /// review starts folded (build 266), so the step is opened first.
    func testTheComingWeeksGoalCanBeWrittenInTheReview() {
        go(to: .review)
        openReviewPart("8")
        let box = reveal(app.buttons.matching(identifier: "review.nextGoal").firstMatch)
        XCTAssertTrue(box.exists, "The Weekly review has no step 8. On screen: \(visibleTexts())")
        let frame = box.frame
        guard Self.isOnScreen(frame) else {
            XCTFail("The goal box in step 8 has no place on screen: \(frame)")
            return
        }
        press(box, at: frame)

        let field = element("review.nextGoal.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Pressing the goal box in step 8 did not open a field. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Rest and the garden\n")

        let gone = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "The field in step 8 stayed open after Return. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { box.label.contains("Rest and the garden") },
                      "The goal was written and the box does not show it. It says: \(box.label)")
    }

    /// Scrolls the screen until the element is there and on screen, and returns it. On the
    /// phone a list draws only the rows in view; on the Mac the list is scrolled where it is,
    /// down first and then, in case the first half went the wrong way, up.
    private func reveal(_ identifier: String, tries: Int = 10) -> XCUIElement {
        reveal(element(identifier), tries: tries)
    }

    /// The same, for an element found some other way — among buttons, for one with a frame
    /// of its own (build 249).
    private func reveal(_ target: XCUIElement, tries: Int = 10) -> XCUIElement {
        for attempt in 0..<tries {
            #if os(macOS)
            let window = app.windows.firstMatch
            if target.exists && window.frame.contains(target.frame) { return target }
            let list = element("review.list")
            let spot = list.exists
                ? list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                : window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.6))
            spot.scroll(byDeltaX: 0, deltaY: attempt < tries / 2 ? -300 : 300)
            #else
            // **Clear of the tab bar, not only on screen** (build 266's first CI run): with the
            // review folded, step 8's box came to rest low on the screen, under the see-through
            // tab bar. `isHittable` said yes, the press landed on the **Actions** tab, and the
            // test failed for its own reasons (build 190). The middle of the element has to be
            // above the bar before it counts as revealed.
            let bar = app.tabBars.firstMatch
            let barTop = bar.exists ? bar.frame.minY : CGFloat.greatestFiniteMagnitude
            if target.exists && target.isHittable && target.frame.midY < barTop - 12 {
                return target
            }
            app.swipeUp()
            #endif
        }
        return target
    }

    /// The words an element shows: the phone keeps them in `label`, the Mac a text's in `value`.
    private func words(of element: XCUIElement) -> String {
        let label = element.label
        if !label.isEmpty { return label }
        // A bordered button on the Mac may be an AppKit button, which keeps its words in its
        // title and leaves the label empty (raised in the review of build 266).
        if !element.title.isEmpty { return element.title }
        return (element.value as? String) ?? ""
    }

    /// Asks again every quarter of a second until the answer is yes or the time is up.
    private func becomes(within timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    /// The focus timer (build 256): **Focus on this** under a task's time button starts the
    /// clock and the bar appears; **Pause** turns into **Go on** and back; **Stop** takes the
    /// bar away. A clock stopped inside half a minute writes nothing and asks nothing, so the
    /// test needs no long wait; on a slow runner the question may come, and is answered. What a
    /// longer clock writes under `## Worked` is pinned in Core (`FocusSessionTests`). Everything
    /// pressed is found among buttons (build 249).
    func testAFocusTimerStartsPausesAndStops() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        row.press()
        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "The note opened without its editor.")

        let time = app.buttons.matching(identifier: "task.time.Book the night train").firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 10),
                      "The task row has no time button. On screen: \(visibleTexts())")
        let timeFrame = time.frame
        guard Self.isOnScreen(timeFrame) else {
            XCTFail("The time button has no place on screen: \(timeFrame)")
            return
        }
        press(time, at: timeFrame)

        let start = app.buttons.matching(identifier: "focus.start").firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10),
                      "The time button's list has no Focus on this. On screen: \(visibleTexts())")
        let startFrame = start.frame
        if Self.isOnScreen(startFrame) { press(start, at: startFrame) } else { start.press() }

        XCTAssertTrue(element("focus.bar").waitForExistence(timeout: 10),
                      "Focus on this was pressed and no timer bar appeared. On screen: \(visibleTexts())")
        #if os(macOS)
        // The clock in the menu bar (build 257): there while the clock runs, gone after Stop.
        let menuBarClock = app.statusItems.matching(identifier: "focus.menuBar").firstMatch
        XCTAssertTrue(menuBarClock.waitForExistence(timeout: 10),
                      "The clock is running and the menu bar does not show it. Status items: \(statusItemNames())")
        #endif

        let pause = app.buttons.matching(identifier: "focus.pause").firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10), "The timer bar has no Pause button.")
        if pause.isHittable { pause.press() } else { pause.pressCentre() }
        let paused = expectation(for: NSPredicate(format: "label == %@", "Go on"), evaluatedWith: pause)
        XCTAssertEqual(XCTWaiter().wait(for: [paused], timeout: 10), .completed,
                       "Pause was pressed and the button did not turn into Go on. It says: \(pause.label)")
        if pause.isHittable { pause.press() } else { pause.pressCentre() }
        let going = expectation(for: NSPredicate(format: "label == %@", "Pause"), evaluatedWith: pause)
        XCTAssertEqual(XCTWaiter().wait(for: [going], timeout: 10), .completed,
                       "Go on was pressed and the button did not turn back into Pause. It says: \(pause.label)")

        let stop = app.buttons.matching(identifier: "focus.stop").firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "The timer bar has no Stop button.")
        if stop.isHittable { stop.press() } else { stop.pressCentre() }
        // On a slow runner one stretch can reach half a minute, and then Stop rightly asks its
        // one question (review of build 256). Answer it rather than fail for the test's own
        // reasons (build 190): the bar has to go either way.
        let notDone = app.buttons.matching(identifier: "focus.notDone").firstMatch
        if notDone.waitForExistence(timeout: 5) {
            if notDone.isHittable { notDone.press() } else { notDone.pressCentre() }
        }
        let gone = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: element("focus.bar"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "Stop was pressed and the timer bar is still there. On screen: \(visibleTexts())")
        #if os(macOS)
        // Hidden with `isVisible`, never removed, so it keeps the place it was dragged to: gone
        // from the tree, or still in it but no longer on screen, both count.
        let deadline = Date().addingTimeInterval(10)
        while menuBarClock.exists && menuBarClock.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertFalse(menuBarClock.exists && menuBarClock.isHittable,
                       "The clock was stopped and the menu bar still shows it. Status items: \(statusItemNames())")
        #endif
    }

    #if os(macOS)
    /// What the menu bar holds for this app, for a failure message: name and words of each item.
    private func statusItemNames() -> String {
        let items = app.statusItems.allElementsBoundByIndex.map { "[\($0.identifier)] \($0.label) \($0.title)" }
        return items.isEmpty ? "none" : items.joined(separator: ", ")
    }
    #endif

    /// A project's own emoji (build 254): **Emoji…** at the top of the project, one choice in
    /// its list, and `emoji: 🎒` in the settings block. Pressed the way the time button is
    /// (build 249): found among buttons, pressed at the middle of its frame. On the Mac the
    /// Projects list is then asked whether its tile shows the emoji; the phone would have to
    /// find its way back out of the note first, and that is not what this test is about.
    func testAProjectCanBeGivenAnEmoji() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor.")

        let chip = app.buttons.matching(identifier: "note.emoji").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10),
                      "The project has no Emoji… button at the top. On screen: \(visibleTexts())")
        let chipFrame = chip.frame
        guard Self.isOnScreen(chipFrame) else {
            XCTFail("The Emoji… button has no place on screen: \(chipFrame)")
            return
        }
        press(chip, at: chipFrame)

        let backpack = app.buttons.matching(identifier: "emoji.choice.\u{1F392}").firstMatch
        let opened = backpack.waitForExistence(timeout: 10)
        XCTAssertTrue(opened,
                      "Pressing Emoji… did not show the choices. On screen: \(visibleTexts())")
        guard opened else { return }
        let choiceFrame = backpack.frame
        if Self.isOnScreen(choiceFrame) {
            press(backpack, at: choiceFrame)
        } else {
            backpack.press()
        }

        XCTAssertTrue(editorHolds(editor, "emoji: \u{1F392}", within: 10),
                      "The note's settings block does not carry the emoji: \(String(((editor.value as? String) ?? "").prefix(200)))")

        #if os(macOS)
        go(to: .projects)
        let tile = element("project.tile.Projects/Plan the Kungsleden trip.md")
        let shown = expectation(for: NSPredicate(format: "label == %@", "\u{1F392}"), evaluatedWith: tile)
        XCTAssertEqual(XCTWaiter().wait(for: [shown], timeout: 10), .completed,
                       "The project's tile in the list does not show the emoji. It says: \(tile.label)")
        #endif
    }

    // MARK: The Mac only — three columns and a menu bar, which the phone does not have

    #if os(macOS)
    /// Build 255: a task ticked in a project shows in the Projects list. The test vault has no
    /// finished task at all, so before the tick the list has no band and the box no bars; after
    /// it, both. Mac only because the way back from a note to the list is one sidebar click
    /// here, and finding the phone's back arrow is not what this test is about.
    func testATickedTaskShowsInTheWeeklyBars() {
        go(to: .projects)
        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        XCTAssertFalse(element("projects.band").exists,
                       "The band is drawn before any task was finished, so it is saying something the file cannot.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "The project did not open.")
        let tick = app.buttons.matching(identifier: "task.tick.Book the night train").firstMatch
        XCTAssertTrue(tick.waitForExistence(timeout: 10),
                      "The note's task box has no tick for the test task. On screen: \(visibleTexts())")
        let tickFrame = tick.frame
        guard Self.isOnScreen(tickFrame) else {
            XCTFail("The tick has no place on screen: \(tickFrame)")
            return
        }
        press(tick, at: tickFrame)
        XCTAssertTrue(editorHolds(editor, "[x] Book the night train", within: 10),
                      "The tick did not finish the task. It ends: \(editorEnd(editor))")

        go(to: .projects)
        XCTAssertTrue(element("projects.band").waitForExistence(timeout: 10),
                      "A task was finished and the list has no band at the top. On screen: \(visibleTexts())")
        XCTAssertTrue(element("project.weekly.Projects/Plan the Kungsleden trip.md").waitForExistence(timeout: 10),
                      "A task was finished and the project's box has no weekly bars. On screen: \(visibleTexts())")
    }

    /// The window is not scrambled after a note is opened. Builds 30 and 34: the split view
    /// grew past the window whenever a column was re-measured, and every column looked
    /// scrolled under the toolbar. Two checks. The sidebar row and the list row are wholly
    /// inside the window, and the editor's top left corner is (an NSTextView reports its
    /// whole document as its frame, so its bottom edge says nothing — the first run of this
    /// test failed on exactly that). Then `expectNoOverflow(after:)` asks the app itself.
    func testTheWindowIsNotScrambledWhenANoteOpens() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "The note opened without its editor.")

        let window = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        for (name, part) in [("sidebar.Projects", element("sidebar.Projects")), ("the note's row", row)] {
            XCTAssertFalse(part.frame.isEmpty, "\(name) has no size after the note opened.")
            XCTAssertTrue(window.contains(part.frame),
                          "\(name) is not wholly inside the window after the note opened: \(part.frame) against \(window). This is the window scramble of builds 30 and 34.")
        }
        XCTAssertTrue(window.contains(CGPoint(x: editor.frame.minX, y: editor.frame.minY)),
                      "The editor's top left corner is outside the window: \(editor.frame) against \(window). This is the window scramble of builds 30 and 34.")

        expectNoOverflow(after: "the note opened")
    }

    /// **Linked notes opens, and the window does not scramble.** This is the oldest fault in
    /// the app (builds 30 and 34) and until build 205 nothing could test it: the box was a
    /// `DisclosureGroup`, where only the small triangle opens it, and four runs in build 198
    /// proved a test cannot reliably hit that triangle — clicking the words did nothing, and
    /// clicking to the left of them took the note away instead. Build 205 made the whole
    /// heading one button, so this is now the one line it always should have been.
    ///
    /// The test project links to the test resource, so the box is drawn; its contents carry
    /// `note.links.open` and exist only while it is open, which is the proof the press landed.
    func testLinkedNotesOpensAndTheWindowHolds() {
        go(to: .projects)

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        row.press()

        XCTAssertTrue(element("note.editor").waitForExistence(timeout: 20), "The note opened without its editor.")

        let heading = element("note.links")
        XCTAssertTrue(heading.waitForExistence(timeout: 20),
                      "The note has no Linked notes heading, although the test project links to Packing list. On screen: \(visibleTexts())")
        heading.pressCentre()

        XCTAssertTrue(element("note.links.open").waitForExistence(timeout: 20),
                      "Linked notes was pressed and its contents never appeared. On screen: \(visibleTexts())")

        expectNoOverflow(after: "Linked notes was opened")
    }

    /// Asks the app itself whether its window has overflowed: **Help › Copy Diagnostics**, then
    /// the clipboard. An `OVERFLOW` line is the app's own name for builds 30 and 34's fault,
    /// which is a better judge than any frame this test could measure.
    ///
    /// The menu item is found **by its title** — the one exception to the identifier rule,
    /// since an `NSMenuItem` made from a `.commands` Button carries none. Not ⌃⌘D: with the
    /// keyboard focus in the editor that key is macOS's own Look Up, and the first run of this
    /// check pressed it and nothing reached the app at all.
    private func expectNoOverflow(after what: String) {
        NSPasteboard.general.clearContents()
        app.menuBars.menuBarItems["Help"].click()
        let copyItem = app.menuBars.menuItems["Copy Diagnostics"]
        XCTAssertTrue(copyItem.waitForExistence(timeout: 10), "The Help menu has no Copy Diagnostics item.")
        copyItem.click()
        // The app says "Diagnostics copied" for 2.5 s. Checked first, so that "the menu did
        // nothing" and "the clipboard could not be read" fail with different words.
        let banner = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Diagnostics copied' OR value CONTAINS 'Diagnostics copied'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10),
                      "Copy Diagnostics was chosen and the app never said Diagnostics copied. On screen: \(visibleTexts())")
        let copied = expectation(for: NSPredicate(block: { _, _ in
            (NSPasteboard.general.string(forType: .string) ?? "").contains("PARAGON build")
        }), evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [copied], timeout: 10), .completed,
                       "The app said Diagnostics copied, but the test could not read them from the clipboard.")
        let report = NSPasteboard.general.string(forType: .string) ?? ""
        let overflow = report.split(separator: "\n").filter { $0.contains("OVERFLOW") }
        XCTAssertTrue(overflow.isEmpty,
                      "The app's own diagnostics report an overflow after \(what): \(overflow.joined(separator: " | "))")
    }

    /// The last lines of **Help › Copy Diagnostics**, for a failure message. Same menu dance
    /// as `expectNoOverflow`; no assertions of its own, so it never changes which check fails.
    private func diagnosticsTail() -> String {
        NSPasteboard.general.clearContents()
        app.menuBars.menuBarItems["Help"].click()
        let copyItem = app.menuBars.menuItems["Copy Diagnostics"]
        guard copyItem.waitForExistence(timeout: 10) else { return "(no Copy Diagnostics item)" }
        copyItem.click()
        let copied = expectation(for: NSPredicate(block: { _, _ in
            (NSPasteboard.general.string(forType: .string) ?? "").contains("PARAGON build")
        }), evaluatedWith: nil)
        guard XCTWaiter().wait(for: [copied], timeout: 10) == .completed else { return "(clipboard empty)" }
        let report = NSPasteboard.general.string(forType: .string) ?? ""
        return report.split(separator: "\n").suffix(40).joined(separator: " | ")
    }

    /// ⌘N opens the New note screen. In build 120 the window's own New Window item kept ⌘N,
    /// so the key opened an empty second window and never the screen — and CI compiled the
    /// menu green. The New note screen appearing is the proof the key reached the app.
    func testCommandNOpensTheNewNoteScreen() {
        go(to: .projects)
        app.typeKey("n", modifierFlags: .command)

        let projectButton = element("new.project")
        XCTAssertTrue(projectButton.waitForExistence(timeout: 20),
                      "⌘N was pressed and the New note screen did not open. On screen: \(visibleTexts())")
        element("sheet.cancel").press()
    }

    /// ⇧⌘N opens Quick capture, wherever the focus is.
    func testShiftCommandNOpensQuickCapture() {
        go(to: .today)
        app.typeKey("n", modifierFlags: [.command, .shift])

        let field = element("capture.text")
        XCTAssertTrue(field.waitForExistence(timeout: 20),
                      "⇧⌘N was pressed and the capture screen did not open. On screen: \(visibleTexts())")
        app.typeKey(.escape, modifierFlags: [])
    }

    /// ⌃⌘← goes back to the note that was open before. Build 118 chose the arrows because the
    /// browsers' ⌘[ does not exist on a Swedish keyboard; nothing had ever pressed either.
    func testControlCommandLeftGoesBackToThePreviousNote() {
        go(to: .projects)
        let project = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(project.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        project.press()
        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "The project did not open.")
        XCTAssertTrue(shows(editor, "Plan the Kungsleden trip", within: 10), "The editor does not show the project.")

        go(to: .resources)
        let resource = element("note.Resources/Packing list.md")
        XCTAssertTrue(resource.waitForExistence(timeout: 20), "The Resources list does not show the test resource.")
        resource.press()
        XCTAssertTrue(shows(editor, "Packing list", within: 20), "The resource did not open. It shows: \(editorText(editor))")

        app.typeKey(.leftArrow, modifierFlags: [.command, .control])
        XCTAssertTrue(shows(editor, "Plan the Kungsleden trip", within: 20),
                      "⌃⌘← was pressed and the editor did not go back to the project. It shows: \(editorText(editor))")
    }

    /// ⌘Z after leaving a note (build 252). Up to build 251 the typing went into the window's
    /// undo history, which outlives the editor — every note opens a fresh one — so ⌘Z in the
    /// next note asked a text view that was already gone, and PARAGON crashed (16 October).
    /// Each editor now keeps its own history. Two proofs: ⌘Z still undoes typing in the note
    /// you are in, and after leaving it the app is still running and the next note was not
    /// touched by the key.
    func testUndoWorksInANoteAndStaysWithIt() {
        go(to: .projects)
        let project = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(project.waitForExistence(timeout: 20), "The Projects list does not show the test project.")
        project.press()
        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20), "The project did not open.")
        editor.press()
        // Into the body on a line of its own, never the settings block: the autosave rewrites a
        // settings line as `key: value`, which counts as a change from outside and restarts
        // the note's undo by design — and the press may well land at the end of one.
        app.typeKey(.downArrow, modifierFlags: .command)
        editor.typeText("\nUndo me. ")
        XCTAssertTrue(shows(editor, "Undo me.", within: 10),
                      "The editor did not take the typing. It ends: \(editorEnd(editor))")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(editorLacks(editor, "Undo me.", within: 10),
                      "⌘Z in the note did not undo the typing. It ends: \(editorEnd(editor))")

        editor.typeText("Leave me. ")
        XCTAssertTrue(shows(editor, "Leave me.", within: 10),
                      "The editor did not take the second typing. It ends: \(editorEnd(editor))")

        go(to: .resources)
        let resource = element("note.Resources/Packing list.md")
        XCTAssertTrue(resource.waitForExistence(timeout: 20), "The Resources list does not show the test resource.")
        resource.press()
        // "Packing list" is in the project too (its `[[Packing list]]` link), so the switch is
        // proved by what only the project holds.
        XCTAssertTrue(editorLacks(editor, "Book the night train", within: 20),
                      "The resource did not open; the editor still shows the project. It shows: \(editorText(editor))")

        // Into the resource's own text, so ⌘Z is asked of the new editor and not of the note
        // list. Build 251 crashed either way: both fell through to the window's history.
        editor.press()
        let before = editor.value as? String ?? ""
        app.typeKey("z", modifierFlags: .command)
        app.typeKey("z", modifierFlags: .command)

        XCTAssertTrue(editor.waitForExistence(timeout: 10),
                      "⌘Z was pressed after leaving a note and the editor is gone. App state: \(app.state.rawValue).")
        XCTAssertEqual(app.state, .runningForeground, "PARAGON stopped after ⌘Z was pressed in the next note.")
        XCTAssertTrue(editorLacks(editor, "Book the night train", within: 10),
                      "After ⌘Z the editor no longer shows the resource. It shows: \(editorText(editor))")
        XCTAssertEqual(editor.value as? String ?? "", before,
                       "⌘Z in the next note changed that note's text. It ends: \(editorEnd(editor))")
    }

    /// Waits until the editor's text contains the words.
    private func shows(_ editor: XCUIElement, _ words: String, within timeout: TimeInterval) -> Bool {
        let holds = expectation(for: NSPredicate(format: "value CONTAINS %@", words), evaluatedWith: editor)
        return XCTWaiter().wait(for: [holds], timeout: timeout) == .completed
    }

    private func editorText(_ editor: XCUIElement) -> String {
        String(((editor.value as? String) ?? "").prefix(200))
    }

    /// The last 200 characters: where a test's own typing lands, after the settings block.
    private func editorEnd(_ editor: XCUIElement) -> String {
        String(((editor.value as? String) ?? "").suffix(200))
    }
    #endif

    #if os(iOS)
    /// **Pressing a tab puts it in front** (build 232). Until build 231 this test swiped: the
    /// tabs were a page view with a bar of our own, and that shape crashed inside iOS's
    /// navigation bar (two crash reports, builds 227 and 228). The system's tab bar has no
    /// swipe, so the test now asks what that bar does — a press, and the tab selected.
    func testATabPressedComesToTheFront() {
        go(to: .today)
        XCTAssertTrue(tabIsOn("tab.today", within: 20),
                      "Today is not the tab in front to begin with. On screen: \(visibleTexts())")

        element("tab.plan").press()
        XCTAssertTrue(tabIsOn("tab.plan", within: 20),
                      "Plan was pressed and did not come to the front. On screen: \(visibleTexts())")

        element("tab.today").press()
        XCTAssertTrue(tabIsOn("tab.today", within: 20),
                      "Today was pressed and did not come back. On screen: \(visibleTexts())")
    }

    private func tabIsOn(_ identifier: String, within timeout: TimeInterval) -> Bool {
        let chosen = expectation(for: NSPredicate(format: "selected == true"),
                                 evaluatedWith: element(identifier))
        return XCTWaiter().wait(for: [chosen], timeout: timeout) == .completed
    }

    #endif

    // MARK: Where each platform keeps its way in

    /// The screens a test walks to. Spelled once here, so a test says where it is going and
    /// `go(to:)` alone knows how to get there on each platform.
    private enum Place { case today, inbox, projects, resources, map, allActions, plan, review, done, goals, areas }

    /// Waits for the home to be drawn first, so every test starts from the same proof that
    /// the vault opened; a test that walked on from the welcome screen would fail on the wrong
    /// step with the wrong words.
    private func go(to place: Place) {
        XCTAssertTrue(element(Self.home).waitForExistence(timeout: appears),
                      "\(Self.home) never appeared. The app is probably on the welcome screen. On screen: \(visibleTexts())")
        for name in Self.way(to: place) {
            let step = element(name)
            XCTAssertTrue(step.waitForExistence(timeout: 20), "\(name) is not on screen. On screen: \(visibleTexts())")
            step.press()
        }
    }

    #if os(macOS)
    /// The one thing that is always on screen once a vault is open.
    private static let home = "sidebar.Inbox"
    /// What the home has to show. Four rows from different groups of the sidebar.
    private static let homeMarks = ["sidebar.Inbox", "sidebar.Goals", "sidebar.Projects", "sidebar.Map"]
    /// The rows pressed one after another. The Tools group is left out: it folds.
    private static let sections = ["sidebar.Inbox", "sidebar.Today", "sidebar.Calendar",
                                   "sidebar.Time Blocks", "sidebar.Weekly review", "sidebar.Map",
                                   "sidebar.All actions", "sidebar.Aspirations", "sidebar.Goals",
                                   "sidebar.Projects",
                                   "sidebar.Areas", "sidebar.Resources", "sidebar.Search"]

    /// One click on the sidebar row.
    private static func way(to place: Place) -> [String] {
        switch place {
        case .today: return ["sidebar.Today"]
        case .inbox: return ["sidebar.Inbox"]
        case .projects: return ["sidebar.Projects"]
        case .resources: return ["sidebar.Resources"]
        case .map: return ["sidebar.Map"]
        case .allActions: return ["sidebar.All actions"]
        case .plan: return ["sidebar.Time Blocks"]
        case .review: return ["sidebar.Weekly review"]
        case .done: return ["sidebar.Done"]
        case .goals: return ["sidebar.Goals"]
        case .areas: return ["sidebar.Areas"]
        }
    }

    /// A Mac window has no navigation bar; the window itself still standing is the check.
    private func screenIsDrawn(timeout: TimeInterval) -> Bool {
        app.windows.firstMatch.waitForExistence(timeout: timeout)
    }
    #else
    private static let home = "tab.today"
    private static let homeMarks = ["tab.today", "tab.plan", "tab.actions", "tab.inbox", "tab.browse"]
    private static let sections = homeMarks

    /// A tab, or the Browse tab and then a row in it.
    private static func way(to place: Place) -> [String] {
        switch place {
        case .today: return ["tab.today"]
        case .inbox: return ["tab.inbox"]
        case .projects: return ["tab.browse", "browse.Projects"]
        case .resources: return ["tab.browse", "browse.Resources"]
        case .map: return ["tab.browse", "browse.Map"]
        case .allActions: return ["tab.actions"]
        case .plan: return ["tab.plan"]
        case .review: return ["tab.browse", "browse.Weekly review"]
        case .done: return ["tab.browse", "browse.Done"]
        case .goals: return ["tab.browse", "browse.Goals"]
        case .areas: return ["tab.browse", "browse.Areas"]
        }
    }

    private func screenIsDrawn(timeout: TimeInterval) -> Bool {
        app.navigationBars.firstMatch.waitForExistence(timeout: timeout)
    }
    #endif

    /// The first twenty texts on screen, for a failure message. The nearest thing to a
    /// screenshot that can be read back from the CI log.
    /// A press at the element's middle, worked out from its frame in the app's own
    /// coordinates. Neither platform is then asked whether the element is "hittable" — the
    /// question the phone could not answer for the time button (build 249's first run).
    private static func isOnScreen(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isEmpty && !frame.isInfinite
            && frame.midX.isFinite && frame.midY.isFinite
    }

    /// **The Mac measures from the element, the phone from the app** (build 249's third run).
    /// On the Mac the application element has no position of its own, so an offset from its
    /// corner came out as infinity and XCTest threw; the element's own middle is a real point.
    /// On the phone the app's corner is the screen's, and that is what avoids asking the phone
    /// whether the button is "hittable" — the question it could not answer in the first run.
    private func press(_ target: XCUIElement, at frame: CGRect) {
        #if os(macOS)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        #else
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        #endif
    }

    private func visibleTexts() -> String {
        // The phone keeps a text's words in `label`, the Mac in `value` (see the capture test).
        app.staticTexts.allElementsBoundByIndex.prefix(20).map { text -> String in
            let label = text.label
            if !label.isEmpty { return label }
            return (text.value as? String) ?? ""
        }.joined(separator: " | ")
    }

    /// Any element carrying that identifier, whatever kind of element SwiftUI made it.
    ///
    /// **The one exception is a phone tab** (build 232): the system's tab bar carries no
    /// identifier of ours, so `tab.<name>` is looked up by the tab's title inside the tab bar
    /// only — never anywhere else on screen, where "Plan" or "Inbox" can also be a heading.
    /// Waits until the editor's text contains the words, on either platform.
    private func editorHolds(_ editor: XCUIElement, _ words: String, within timeout: TimeInterval) -> Bool {
        let holds = expectation(for: NSPredicate(format: "value CONTAINS %@", words), evaluatedWith: editor)
        return XCTWaiter().wait(for: [holds], timeout: timeout) == .completed
    }

    /// Waits until the editor's text no longer contains the words.
    private func editorLacks(_ editor: XCUIElement, _ words: String, within timeout: TimeInterval) -> Bool {
        let lacks = expectation(for: NSPredicate(format: "exists == YES AND NOT (value CONTAINS %@)", words), evaluatedWith: editor)
        return XCTWaiter().wait(for: [lacks], timeout: timeout) == .completed
    }

    private func element(_ identifier: String) -> XCUIElement {
        #if os(iOS)
        if let title = Self.tabTitles[identifier] {
            return app.tabBars.buttons[title]
        }
        #endif
        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    #if os(iOS)
    /// The five tabs' titles, spelled as `PhoneRootView.Tab.title` spells them.
    private static let tabTitles = ["tab.today": "Today", "tab.plan": "Plan",
                                    "tab.actions": "Actions", "tab.inbox": "Inbox",
                                    "tab.browse": "Browse"]
    #endif

    /// The Weekly review folds step by step (build 266). His words: *"it's so many lines …
    /// that is a bit scary."* Every part starts folded, so step 7's week bar is not there at
    /// first; its heading names the week it shows rather than "the week"; pressing the heading
    /// opens the step and pressing it again folds it; and **Open all** in the summary opens
    /// every part. The test vault wipes the app's settings first, so "folded at first" is the
    /// default and not something an earlier test left behind. Everything pressed is found among
    /// buttons (build 249).
    func testTheReviewFoldsStepByStep() {
        go(to: .review)

        let heading = reveal(app.buttons.matching(identifier: "review.part.7").firstMatch)
        XCTAssertTrue(heading.exists, "The Weekly review has no heading for step 7. On screen: \(visibleTexts())")
        XCTAssertTrue(heading.label.contains("Look back at "),
                      "Step 7's heading does not say what the step does. It says: \(heading.label)")
        XCTAssertFalse(heading.label.contains("at the week"),
                       "Step 7's heading does not name the week it shows. It says: \(heading.label)")
        XCTAssertFalse(element("review.lookBack").exists,
                       "Step 7 is open the first time the review is shown. Every part should start folded.")

        if heading.isHittable { heading.press() } else { heading.pressCentre() }
        XCTAssertTrue(reveal("review.lookBack").exists,
                      "Step 7's heading was pressed and the step did not open. On screen: \(visibleTexts())")

        let again = revealAbove(app.buttons.matching(identifier: "review.part.7").firstMatch)
        XCTAssertTrue(again.exists, "Step 7's heading went away when the step opened. On screen: \(visibleTexts())")
        if again.isHittable { again.press() } else { again.pressCentre() }
        let folded = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: element("review.lookBack"))
        XCTAssertEqual(XCTWaiter().wait(for: [folded], timeout: 10), .completed,
                       "Step 7's heading was pressed again and the step did not fold. On screen: \(visibleTexts())")

        let all = revealAbove(app.buttons.matching(identifier: "review.openAll").firstMatch)
        XCTAssertTrue(all.exists, "The review's summary has no Open all button. On screen: \(visibleTexts())")
        XCTAssertTrue(all.label.contains("Open all"),
                      "With the steps folded, the button does not offer to open them. It says: \(all.label)")
        if all.isHittable { all.press() } else { all.pressCentre() }
        XCTAssertTrue(becomes(within: 10) { all.label.contains("Close all") },
                      "Open all was pressed and the button does not offer to close them again. It says: \(all.label)")
        XCTAssertTrue(reveal("review.lookBack").exists,
                      "Open all was pressed and step 7 stayed folded. On screen: \(visibleTexts())")
    }

    /// Opens one part of the Weekly review, which starts folded (build 266). The heading is
    /// found among buttons (build 249) and scrolled to first, in case it is below the fold.
    private func openReviewPart(_ part: String) {
        let heading = reveal(app.buttons.matching(identifier: "review.part.\(part)").firstMatch)
        XCTAssertTrue(heading.exists,
                      "The Weekly review has no heading review.part.\(part). On screen: \(visibleTexts())")
        if heading.isHittable { heading.press() } else { heading.pressCentre() }
    }

    /// `reveal` the other way round on the phone: swipes down, which moves the list back
    /// towards its top, until the element is on screen. The Mac's `reveal` already scrolls both
    /// ways.
    private func revealAbove(_ target: XCUIElement, tries: Int = 6) -> XCUIElement {
        #if os(macOS)
        return reveal(target)
        #else
        for _ in 0..<tries {
            if target.exists && target.isHittable { return target }
            app.swipeDown()
        }
        return target
        #endif
    }

    /// **Done tells the day's story** (build 267): a task ticked off shows under today's card,
    /// and the card says "1 done"; since build 268 today's square above the list says so too,
    /// and pressing it keeps the app running. The test vault has no `@done` stamp anywhere
    /// (build 221's fixture), so the tick is made here, in **All actions**, pressed at its frame
    /// (build 255). Done is visited once, after the tick: on the phone a second visit would
    /// find Done already pushed and `browse.Done` gone. Yesterday may be listed too — the
    /// vault's daily note holds a line from **Close the day** (build 265) — so only today's
    /// card is read.
    /// Its sentence is set explicitly, so both platforms read the same words (build 253).
    func testATickedTaskShowsInDone() {
        go(to: .allActions)
        let tick = app.buttons.matching(identifier: "task.tick.Book the night train").firstMatch
        XCTAssertTrue(tick.waitForExistence(timeout: 20),
                      "All actions has no tick for the test task. On screen: \(visibleTexts())")
        let frame = tick.frame
        guard Self.isOnScreen(frame) else {
            XCTFail("The tick has no place on screen: \(frame)")
            return
        }
        press(tick, at: frame)
        // Proof the press ticked (build 268), so a failure further down is about Done. The row
        // leaves the list once the task is finished; on the Mac a press in the list can also
        // open the note beside it, whose own task box draws the same task again — ticked, so
        // its value says "done".
        let finished: () -> Bool = {
            let again = self.app.buttons.matching(identifier: "task.tick.Book the night train").firstMatch
            return !again.exists || (again.value as? String) == "done"
        }
        var ticked = becomes(within: 15, finished)
        #if os(macOS)
        // Build 268's first run: the press at the tick's middle in **All actions** did nothing on
        // the Mac, though the same press works on the tick in a note (the weekly bars test). Two
        // causes look alike from here: a wrong frame for a button inside a `List` row (build
        // 247), or a row whose drag takes the click (builds 71–74). XCUITest's own click on the
        // element aims at its hit point rather than its frame, so if that one ticks, the test's
        // point was wrong; if it does not, the app's click log names the view the press reached.
        if !ticked {
            let log = diagnosticsTail()
            let again = app.buttons.matching(identifier: "task.tick.Book the night train").firstMatch
            let pointFrame = again.frame
            if again.exists && again.isHittable { again.click() }
            ticked = becomes(within: 15, finished)
            XCTAssertTrue(ticked, "Neither a press at the tick's middle \(pointFrame) nor a click on the tick itself finished the task in All actions. The app's log: \(log)")
        }
        #endif
        XCTAssertTrue(ticked, "The press on the tick in All actions did not finish the task. On screen: \(visibleTexts())")

        go(to: .done)
        let card = element("done.day.\(Self.todayStamp())")
        XCTAssertTrue(card.waitForExistence(timeout: 20),
                      "Done has no card for today after the task was ticked. Done shows: \(doneScreenSays())")
        XCTAssertTrue(becomes(within: 10) { self.words(of: card).contains("1 done") },
                      "Today's card does not say one task was done. It says: \(words(of: card))")

        // Build 268: the squares above the list. With one finish in the vault, today's square is
        // the only one that can be pressed, and the list is already at its card, so there is
        // nowhere far to go: this proves the press is safe. Which squares can be pressed, and
        // how dark each one is, is pinned in Core (`DoneDiaryTests`). Found among buttons
        // (build 249) and pressed at its centre, as a plain-styled button (build 196).
        XCTAssertTrue(element("done.squares").waitForExistence(timeout: 10),
                      "Done shows no squares after a task was ticked off today. On screen: \(visibleTexts())")
        let square = app.buttons.matching(identifier: "done.square.\(Self.todayStamp())").firstMatch
        XCTAssertTrue(square.waitForExistence(timeout: 10),
                      "Today's square is not a button that can be pressed. On screen: \(visibleTexts())")
        XCTAssertTrue(words(of: square).contains("1 done"),
                      "Today's square does not say one task was done. It says: \(words(of: square))")
        square.pressCentre()
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "Today's card is gone after its square was pressed. On screen: \(visibleTexts())")
        XCTAssertEqual(app.state, .runningForeground, "PARAGON stopped after a square was pressed.")
    }

    /// What the Done screen holds, for a failure message: the sidebar fills the first twenty
    /// texts on the Mac, so `visibleTexts()` never reaches the list (build 268).
    private func doneScreenSays() -> String {
        let ours = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'done.'"))
            .allElementsBoundByIndex.prefix(12)
            .map { "\($0.identifier) = \(words(of: $0))" }
        let empty = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Nothing in the last' OR value BEGINSWITH 'Nothing in the last'")).count
        return (ours.isEmpty ? "no element named done.*" : ours.joined(separator: " | "))
            + (empty > 0 ? " | the empty message" : "")
    }

    /// Today as the app writes a day, `YYYY-MM-DD`, in the runner's own calendar and time zone —
    /// the ones the app reads `DateOnly.today()` from.
    private static func todayStamp() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// A goal's measure and target date are changed from the goal itself (build 268). Before it,
    /// `measure:` had no writer in the app at all and `target:` was written only when a goal was
    /// made. On the Mac the two buttons are on the goal's page in the Goals screen; on the phone
    /// they are in the header of the note that opens. Same names, same test code.
    ///
    /// The test writes a measure and sees the button say it. For the date it only opens the box
    /// and checks it starts on the goal's own day, then presses **Cancel**: clearing a field that
    /// already holds text is fragile in XCUITest, and the date box is already proven by the
    /// deadline and the task date. Every button is found among buttons (build 249).
    func testAGoalsMeasureAndDateCanBeChanged() {
        go(to: .goals)

        let row = element("goal.Goals/Walk the Kungsleden in one go.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Goals list does not show the test goal. On screen: \(visibleTexts())")
        row.press()

        let measure = app.buttons.matching(identifier: "goal.measure").firstMatch
        XCTAssertTrue(measure.waitForExistence(timeout: 20),
                      "The goal has no Set a measure… button. On screen: \(visibleTexts())")
        XCTAssertTrue(measure.label.contains("Set a measure"),
                      "The test goal has no measure yet, but the button says: \(measure.label)")
        let measureFrame = measure.frame
        guard Self.isOnScreen(measureFrame) else {
            XCTFail("The Set a measure… button has no place on screen: \(measureFrame)")
            return
        }
        press(measure, at: measureFrame)

        let field = element("measure.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Pressing Set a measure… did not open a field. On screen: \(visibleTexts())")
        field.press()
        field.typeText("All 440 km in 30 days")

        let setButton = app.buttons.matching(identifier: "measure.set").firstMatch
        XCTAssertTrue(setButton.waitForExistence(timeout: 10),
                      "The measure box has no Set button. On screen: \(visibleTexts())")
        if setButton.isHittable { setButton.press() } else { setButton.pressCentre() }

        // The box closing first, so the next press does not land on a popover on its way out.
        let closed = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed,
                       "The measure box stayed open after Set. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { measure.label.contains("440 km") },
                      "The measure was set and the button does not show it. It says: \(measure.label)")

        let target = app.buttons.matching(identifier: "goal.target").firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 10),
                      "The goal has no target date button. On screen: \(visibleTexts())")
        let targetFrame = target.frame
        guard Self.isOnScreen(targetFrame) else {
            XCTFail("The target date button has no place on screen: \(targetFrame)")
            return
        }
        press(target, at: targetFrame)

        let date = element("date.field")
        XCTAssertTrue(date.waitForExistence(timeout: 10),
                      "Pressing the target date did not open the date box. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { (date.value as? String) == "2027-08-15" },
                      "The date box did not start on the goal's own day. It holds: \(String(describing: date.value))")

        let cancel = app.buttons.matching(identifier: "date.cancel").firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10),
                      "The date box has no Cancel button. On screen: \(visibleTexts())")
        if cancel.isHittable { cancel.press() } else { cancel.pressCentre() }
        let gone = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: date)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "The date box stayed open after Cancel. On screen: \(visibleTexts())")
    }

    /// Build 269: a project has an **In area…** button at the top, and the New note screen has
    /// one for a new project. **Dull on purpose**: pressing the items of a SwiftUI `Menu` is new
    /// ground for this suite, so the test only asks that both buttons are there and say what
    /// they do. The New note screen comes first, so the phone never has to find its way back
    /// out of a pushed note. The test project has no `area:` line, so its button reads
    /// "In area…". Both buttons may carry their name on a frameless wrapper as well as on the
    /// control itself (build 249), and a `Menu` is a button on the phone and a menu button on
    /// the Mac, so every element with the name is asked for its words (`wordsOfEvery`).
    func testAProjectHasAnInAreaButton() {
        go(to: .projects)

        let newNote = element("list.newNote")
        XCTAssertTrue(newNote.waitForExistence(timeout: 20), "The Projects list has no New note button.")
        newNote.press()

        let projectButton = element("new.project")
        XCTAssertTrue(projectButton.waitForExistence(timeout: 20),
                      "The New note screen did not open, or has no Project button.")
        projectButton.press()

        XCTAssertTrue(element("new.inArea").waitForExistence(timeout: 10),
                      "A new project has no In area… button. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { self.wordsOfEvery("new.inArea").contains("In area") },
                      "The New note screen's In area… button does not say what it does. It says: \(wordsOfEvery("new.inArea"))")

        let cancel = element("sheet.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "The New note screen has no Cancel button.")
        cancel.press()
        let closed = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: element("new.project"))
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed,
                       "Cancel was pressed and the New note screen stayed open.")

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.press()

        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor.")

        XCTAssertTrue(element("note.area").waitForExistence(timeout: 10),
                      "The project has no In area… button at the top. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { self.wordsOfEvery("note.area").contains("In area") },
                      "The project's In area… button does not say what it does. It says: \(wordsOfEvery("note.area"))")
    }

    /// The words of every element carrying this name, joined: one of them is the control
    /// itself, whatever kind of element SwiftUI made it.
    private func wordsOfEvery(_ identifier: String) -> String {
        app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
            .map { words(of: $0) }
            .joined(separator: " | ")
    }

    /// **Add a project…** on a goal makes a project that already serves it, and you stay on the
    /// goal (build 269). On the Mac the button is in the rail of the goal's page in the Goals
    /// screen; on the phone it is at the foot of the goal's own note, under the projects that
    /// serve it. Same names, same test code.
    ///
    /// The proof the page stayed is **Add a project…** still being there after the add: had
    /// the app opened the new project, the goal's page and its button would be gone. The test
    /// never counts the new project's tasks — the project template ships its own (build 162).
    /// Every button is found among buttons (build 249).
    func testAProjectCanBeAddedFromItsGoal() {
        go(to: .goals)

        let row = element("goal.Goals/Walk the Kungsleden in one go.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Goals list does not show the test goal. On screen: \(visibleTexts())")
        row.press()

        let add = app.buttons.matching(identifier: "goal.addProject").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 20),
                      "The goal has no Add a project… button. On screen: \(visibleTexts())")
        let addFrame = add.frame
        guard Self.isOnScreen(addFrame) else {
            XCTFail("The Add a project… button has no place on screen: \(addFrame)")
            return
        }
        press(add, at: addFrame)

        let field = element("addNote.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Pressing Add a project… did not open a field. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Buy the maps")

        // The box's own button when it can be pressed; Return in the field otherwise, which
        // does the same thing. On the phone the keyboard is up at this moment.
        let confirm = app.buttons.matching(identifier: "addNote.add").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10),
                      "The box has no Add project button. On screen: \(visibleTexts())")
        if confirm.isHittable { confirm.press() } else { field.typeText("\n") }

        let closed = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed,
                       "The box stayed open after Add project. On screen: \(visibleTexts())")

        let made = element("serves.Projects/Buy the maps.md")
        XCTAssertTrue(made.waitForExistence(timeout: 20),
                      "The new project is not listed under its goal. On screen: \(visibleTexts())")
        XCTAssertTrue(app.buttons.matching(identifier: "goal.addProject").firstMatch.waitForExistence(timeout: 10),
                      "Add a project… is gone, so the page left the goal. On screen: \(visibleTexts())")
    }

    /// **Looked at, from the note** (build 270). A goal says when it was last looked at, and
    /// one press in the box that button opens says you looked at it today. Before this build
    /// `reviewed:` could only be written from the Weekly review's right-click menu. On the Mac
    /// the button is on the goal's page in the Goals screen; on the phone it is in the header
    /// of the note that opens. Same names, same test code, as the measure test above.
    ///
    /// The test vault's goal has no `reviewed:` line, so the button starts on "Never looked at"
    /// and has to end on words with "today" in them. Everything pressed is found among buttons
    /// (build 249); the button is pressed at its frame, as the measure is.
    func testAGoalCanBeMarkedAsLookedAt() {
        go(to: .goals)

        let row = element("goal.Goals/Walk the Kungsleden in one go.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Goals list does not show the test goal. On screen: \(visibleTexts())")
        row.press()

        let chip = app.buttons.matching(identifier: "note.lookedAt").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 20),
                      "The goal has no Looked at button. On screen: \(visibleTexts())")
        XCTAssertTrue(chip.label.contains("Never looked at"),
                      "The test goal has never been looked at, but the button says: \(chip.label)")
        let frame = chip.frame
        guard Self.isOnScreen(frame) else {
            XCTFail("The Looked at button has no place on screen: \(frame)")
            return
        }
        press(chip, at: frame)

        let today = app.buttons.matching(identifier: "lookedAt.today").firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 10),
                      "Pressing the Looked at button did not open its box. On screen: \(visibleTexts())")
        if today.isHittable { today.press() } else { today.pressCentre() }

        // The box closing first, so the label is read from the page and not from a box on its
        // way out.
        let closed = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: today)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed,
                       "The box stayed open after I looked at it today. On screen: \(visibleTexts())")
        XCTAssertTrue(becomes(within: 10) { chip.label.contains("today") },
                      "I looked at it today was pressed and the button does not say so. It says: \(chip.label)")
    }

    /// **An area lists its projects, and Add a project… makes one in it** (build 270). The
    /// test vault's Health has no project in it — the test project serves a goal and names no
    /// area, and only the `area:` line puts a project in an area — so the panel starts with its
    /// empty line. **Add a project…** is build 269's button with an `area:` link, so the steps
    /// after the press are those of `testAProjectCanBeAddedFromItsGoal`. The proof the page
    /// stayed on the area is the new project listed there, with **Add a project…** still on
    /// screen.
    ///
    /// On the Mac more checks, because the panel sits above the editor in a column that does
    /// not scroll (builds 30 and 34): the new row lies inside the window and wholly above the
    /// note's text — a scroll view shorter than its rows would fail there — and the app's own
    /// diagnostics report no overflow. Every button is found among buttons (build 249).
    func testAnAreaListsItsProjectsAndAddsOne() {
        go(to: .areas)

        let row = element("note.Areas/Health.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Areas list does not show the test area. On screen: \(visibleTexts())")
        row.press()

        XCTAssertTrue(element("area.panel").waitForExistence(timeout: 20),
                      "The area opened without its projects panel. On screen: \(visibleTexts())")
        XCTAssertTrue(element("area.noProjects").waitForExistence(timeout: 10),
                      "The test area has no project, and the panel does not say so. On screen: \(visibleTexts())")

        let add = app.buttons.matching(identifier: "area.addProject").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 20),
                      "The area has no Add a project… button. On screen: \(visibleTexts())")
        let addFrame = add.frame
        guard Self.isOnScreen(addFrame) else {
            XCTFail("The Add a project… button has no place on screen: \(addFrame)")
            return
        }
        press(add, at: addFrame)

        let field = element("addNote.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10),
                      "Pressing Add a project… did not open a field. On screen: \(visibleTexts())")
        field.press()
        field.typeText("Stretch every morning")

        // The box's own button when it can be pressed; Return in the field otherwise, which
        // does the same thing. On the phone the keyboard is up at this moment.
        let confirm = app.buttons.matching(identifier: "addNote.add").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10),
                      "The box has no Add project button. On screen: \(visibleTexts())")
        if confirm.isHittable { confirm.press() } else { field.typeText("\n") }

        let closed = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed,
                       "The box stayed open after Add project. On screen: \(visibleTexts())")

        let made = element("area.project.Projects/Stretch every morning.md")
        XCTAssertTrue(made.waitForExistence(timeout: 20),
                      "The new project is not listed on its area. On screen: \(visibleTexts())")
        let gone = expectation(for: NSPredicate(format: "exists == NO"), evaluatedWith: element("area.noProjects"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "The area has a project now, and the panel still says it has none.")
        XCTAssertTrue(app.buttons.matching(identifier: "area.addProject").firstMatch.waitForExistence(timeout: 10),
                      "Add a project… is gone, so the page left the area. On screen: \(visibleTexts())")

        #if os(macOS)
        let window = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        XCTAssertFalse(made.frame.isEmpty,
                       "The new project's row has no size on the area's page: \(made.frame)")
        XCTAssertTrue(window.contains(made.frame),
                      "The new project's row is not wholly inside the window: \(made.frame) against \(window).")
        // The panel's scroll view is as tall as its rows, up to a limit. Had it come out
        // shorter than one row, the row would run on into the text below it — a frame inside
        // the window would not show that.
        let editor = element("note.editor")
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "The area's note has no editor below its panel.")
        XCTAssertLessThanOrEqual(made.frame.maxY, editor.frame.minY + 1,
                                 "The new project's row runs into the note's text: \(made.frame) against the editor at \(editor.frame). The panel is shorter than its rows.")
        expectNoOverflow(after: "a project was added on an area's page")
        #endif
    }
}

extension XCUIElement {
    /// A tap on the phone, a click on the Mac — one word in a test that runs on both.
    func press() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }

    /// A press on the element's centre point, for a box on a canvas. The Mac refuses `click()`
    /// on an element it calls not hittable, and it says that of a SwiftUI group whose hit test
    /// lands on the text inside it; a coordinate click asks no such question.
    func pressCentre() {
        #if os(macOS)
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        #else
        tap()
        #endif
    }
}
