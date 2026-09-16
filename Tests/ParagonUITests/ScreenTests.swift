import XCTest

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
/// `capture.save`, `map.<path>`. The vault is `TestVault` in the app, which is where its
/// titles live.
///
/// **One suite, two platforms.** A test bundle compiles once per platform, so `#if os(macOS)`
/// picks the Mac's way in — the sidebar row — where the phone taps a tab, and `go(to:)` is the
/// one place that choice is made. What comes after is the same code; that is the point of the
/// names. Since build 196 all seven run on both.
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

    // MARK: Where each platform keeps its way in

    /// The screens a test walks to. Spelled once here, so a test says where it is going and
    /// `go(to:)` alone knows how to get there on each platform.
    private enum Place { case today, inbox, projects, map }

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
                                   "sidebar.All actions", "sidebar.Goals", "sidebar.Projects",
                                   "sidebar.Areas", "sidebar.Resources", "sidebar.Search"]

    /// One click on the sidebar row.
    private static func way(to place: Place) -> [String] {
        switch place {
        case .today: return ["sidebar.Today"]
        case .inbox: return ["sidebar.Inbox"]
        case .projects: return ["sidebar.Projects"]
        case .map: return ["sidebar.Map"]
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
        case .map: return ["tab.browse", "browse.Map"]
        }
    }

    private func screenIsDrawn(timeout: TimeInterval) -> Bool {
        app.navigationBars.firstMatch.waitForExistence(timeout: timeout)
    }
    #endif

    /// The first twenty texts on screen, for a failure message. The nearest thing to a
    /// screenshot that can be read back from the CI log.
    private func visibleTexts() -> String {
        // The phone keeps a text's words in `label`, the Mac in `value` (see the capture test).
        app.staticTexts.allElementsBoundByIndex.prefix(20).map { text -> String in
            let label = text.label
            if !label.isEmpty { return label }
            return (text.value as? String) ?? ""
        }.joined(separator: " | ")
    }

    /// Any element carrying that identifier, whatever kind of element SwiftUI made it.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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
