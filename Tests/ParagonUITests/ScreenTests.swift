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

    private static let tabs = ["tab.today", "tab.plan", "tab.actions", "tab.inbox", "tab.browse"]
}
