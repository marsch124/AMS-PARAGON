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
/// `new.<thing>`, `sheet.action` / `sheet.cancel`, `today.capture`, `capture.text`,
/// `capture.save`, `map.<path>`. The vault is `TestVault` in the app, which is where its
/// titles live.
///
/// **One suite, two platforms.** A test bundle compiles once per platform, so `#if os(macOS)`
/// picks the Mac's way in — the sidebar row — where the phone taps a tab. What comes after is
/// the same code; that is the point of the names. Tests the Mac cannot run yet sit under
/// `#if os(iOS)` and come across one or two at a time (build 196 on).
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

    // MARK: The phone only, until build 196 brings them across

    #if os(iOS)
    /// Browse › Projects › the test project, then type into it. From build 114 to 128 the phone
    /// editor needed a press-and-hold before it would take a letter, three builds were spent on
    /// its layout while the fault was a gesture, and CI never knew any of it.
    func testANoteCanBeOpenedAndTypedIn() {
        XCTAssertTrue(app.buttons["tab.browse"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        app.buttons["tab.browse"].tap()

        let projects = element("browse.Projects")
        XCTAssertTrue(projects.waitForExistence(timeout: 20), "Browse has no Projects row.")
        projects.tap()

        let row = element("note.Projects/Plan the Kungsleden trip.md")
        XCTAssertTrue(row.waitForExistence(timeout: 20),
                      "The Projects list does not show the test project.")
        row.tap()

        let editor = app.textViews["note.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The note opened without its editor. Either the row did not open the note, or the editor is not in Edit mode.")
        editor.tap()
        editor.typeText("Typed by the screen test. ")

        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Typed by the screen test"),
                      "The editor did not take the typing. It shows: \(shown.prefix(200))")
    }

    /// A line in the Inbox can be picked by tapping it. Builds 71 to 74 attached a drag and a
    /// tap to the row, each of which took the click, and no line could be selected at all —
    /// the very thing this asks.
    func testALineInTheInboxCanBeSelected() {
        XCTAssertTrue(app.buttons["tab.inbox"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        app.buttons["tab.inbox"].tap()

        let line = element("inbox.Call the bank about the ferry")
        XCTAssertTrue(line.waitForExistence(timeout: 20),
                      "The Inbox does not show the test line. Did the test vault capture it?")
        line.tap()

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
        XCTAssertTrue(app.buttons["tab.browse"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        app.buttons["tab.browse"].tap()

        let projects = element("browse.Projects")
        XCTAssertTrue(projects.waitForExistence(timeout: 20), "Browse has no Projects row.")
        projects.tap()

        let newNote = element("list.newNote")
        XCTAssertTrue(newNote.waitForExistence(timeout: 20), "The Projects list has no New note button.")
        newNote.tap()

        let projectButton = element("new.project")
        XCTAssertTrue(projectButton.waitForExistence(timeout: 20),
                      "The New note screen did not open, or has no Project button.")
        projectButton.tap()

        let name = element("new.name")
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The New note screen has no name field.")
        name.tap()
        name.typeText("Made by the screen test")

        let create = element("sheet.action")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "The New note screen has no Create button.")
        XCTAssertTrue(create.isEnabled, "Create stayed grey after a name was typed.")
        create.tap()

        // A new note is opened straight away, so the editor is the proof that it was made:
        // it shows the file from disk, and the template puts the name in the first line.
        let editor = app.textViews["note.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "Create was pressed and no note opened. The note may not have been made.")
        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Made by the screen test"),
                      "The note that opened does not carry the name that was typed. It shows: \(shown.prefix(200))")
    }

    /// Quick capture, end to end: the button at the top left of Today, a line typed, **Save**,
    /// and the line waiting in the Inbox. That is the whole point of the app's fastest path,
    /// and build 158 rebuilt the screen on a Mac panel width that had pushed Save off the phone.
    func testACaptureLandsInTheInbox() {
        XCTAssertTrue(app.buttons["tab.today"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        app.buttons["tab.today"].tap()

        let open = element("today.capture")
        XCTAssertTrue(open.waitForExistence(timeout: 20), "Today has no Quick capture button.")
        open.tap()

        let field = app.textViews["capture.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "The capture screen did not open, or has no field.")
        field.tap()
        field.typeText("Captured by the screen test")

        let save = element("capture.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10), "The capture screen has no Save button.")
        XCTAssertTrue(save.isEnabled, "Save stayed grey after a line was typed.")
        save.tap()

        // What the app says after Save ("Saved to Inbox") is the proof the capture ran; the
        // screen then closes itself a moment later, and the Inbox tab is behind it until it
        // does. Each is checked on its own, with what was on screen in the message, because a
        // log is the only eye there is on this simulator.
        let saidSaved = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Saved'")).firstMatch
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

        app.buttons["tab.inbox"].tap()
        let line = element("inbox.Captured by the screen test")
        XCTAssertTrue(line.waitForExistence(timeout: 20),
                      "The captured line is not in the Inbox. Either the capture was not written, or the Inbox did not reload.")
    }

    /// A box on the Map takes a tap and opens its note. Build 85 had every box swallow clicks
    /// across the whole canvas and the last one drawn win them all; CI compiled it green. The
    /// aspiration's box is the one tapped because root goals sit at the top of the layout,
    /// where a phone shows them without scrolling.
    func testAMapBoxOpensItsNote() {
        XCTAssertTrue(app.buttons["tab.browse"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        app.buttons["tab.browse"].tap()

        let mapRow = element("browse.Map")
        XCTAssertTrue(mapRow.waitForExistence(timeout: 20), "Browse has no Map row.")
        mapRow.tap()

        let box = element("map.Goals/Be strong and steady at seventy.md")
        XCTAssertTrue(box.waitForExistence(timeout: 30),
                      "The Map drew no box for the test aspiration. On screen: \(visibleTexts())")
        XCTAssertTrue(box.isHittable,
                      "The aspiration's box is on the Map but not on screen at this size, so it cannot be tapped. On screen: \(visibleTexts())")
        box.tap()

        let editor = app.textViews["note.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 20),
                      "The box was tapped and its note did not open. On screen: \(visibleTexts())")
        let shown = editor.value as? String ?? ""
        XCTAssertTrue(shown.contains("Be strong and steady at seventy"),
                      "A note opened, but not the one whose box was tapped. It shows: \(shown.prefix(200))")
    }
    #endif

    // MARK: Where each platform keeps its way in

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

    /// A Mac window has no navigation bar; the window itself still standing is the check.
    private func screenIsDrawn(timeout: TimeInterval) -> Bool {
        app.windows.firstMatch.waitForExistence(timeout: timeout)
    }
    #else
    private static let home = "tab.today"
    private static let homeMarks = ["tab.today", "tab.plan", "tab.actions", "tab.inbox", "tab.browse"]
    private static let sections = homeMarks

    private func screenIsDrawn(timeout: TimeInterval) -> Bool {
        app.navigationBars.firstMatch.waitForExistence(timeout: timeout)
    }
    #endif

    /// The first twenty texts on screen, for a failure message. The nearest thing to a
    /// screenshot that can be read back from the CI log.
    private func visibleTexts() -> String {
        app.staticTexts.allElementsBoundByIndex.prefix(20).map { $0.label }.joined(separator: " | ")
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
}
