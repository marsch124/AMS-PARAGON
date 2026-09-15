import XCTest

/// The screens, actually pressed.
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
/// the app beside the views: `tab.*`, `browse.<section>`, `note.<path>`, `inbox.<line>`,
/// `note.editor`. The vault is `TestVault` in the app, which is where its titles live.
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

    /// The welcome screen has no tab bar, so this also proves the vault opened. Without it
    /// every other test below would be testing the first-run screen and passing for the wrong
    /// reason — which is build 179's lesson, where "I cannot open your folder" and "you have
    /// never set this up" were the same picture.
    func testTheAppOpensItsVaultAndDrawsTheTabBar() {
        XCTAssertTrue(app.buttons["tab.today"].waitForExistence(timeout: appears),
                      "The tab bar never appeared. The app is probably on the welcome screen, which means the vault did not open.")
        for tab in Self.tabs {
            XCTAssertTrue(app.buttons[tab].exists, "\(tab) is missing from the tab bar.")
        }
    }

    /// Every tab draws something and the app is still running at the end. Builds 71 to 74 left
    /// a whole screen unusable and CI was green throughout.
    func testEveryTabOpensItsScreen() {
        XCTAssertTrue(app.buttons["tab.today"].waitForExistence(timeout: appears),
                      "The tab bar never appeared.")
        for tab in Self.tabs {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 20), "\(tab) is not on screen.")
            button.tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 20),
                          "\(tab) opened without a navigation bar, so it drew nothing.")
            XCTAssertEqual(app.state, .runningForeground, "The app stopped running on \(tab).")
        }
        XCTAssertTrue(app.buttons["tab.browse"].exists,
                      "The tab bar is gone after visiting every tab.")
    }

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

    /// Any element carrying that identifier, whatever kind of element SwiftUI made it.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private static let tabs = ["tab.today", "tab.plan", "tab.actions", "tab.inbox", "tab.browse"]
}
