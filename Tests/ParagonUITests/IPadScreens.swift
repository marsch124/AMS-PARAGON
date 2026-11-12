import XCTest
#if os(iOS)
import UIKit

/// The iPad, looked at — on a simulated iPad mini (2 November 2026).
///
/// He asked what it would take to use PARAGON on his iPad mini. The iPhone app has always been
/// an iPad app as well (`TARGETED_DEVICE_FAMILY: "1,2"`), and on a full iPad screen it draws the
/// Mac's three columns, not the phone's tabs (`ContentView.isCompact`). Nothing had ever opened
/// it on an iPad. These two tests do, upright and on its side, press every row of the sidebar,
/// open a note, and leave a picture of each screen behind so he can see it before he installs it.
///
/// **A class of its own, and a CI job of its own** ("Screen tests (iPad mini)"). `ScreenTests`
/// picks its way in by platform — tabs on iOS, the sidebar on the Mac — and an iPad is iOS with
/// a sidebar, so none of its iOS ways in exist here. A suite that fails for its own reasons is
/// worse than none (build 190), so this one starts small. On an iPhone both tests are skipped;
/// the Mac never compiles them.
///
/// **The iPad may keep the sidebar folded away**, and the system decides that by orientation,
/// not the app. `reveal(_:_:)` brings a row out the way a person would — the bar's **Show
/// Sidebar** button, else a swipe in from the left edge — and scrolls the sidebar for a row
/// below the fold, the way `bringIntoView` does on the Mac.
///
/// **The pictures** are kept twice: as test attachments in the result bundle, and as PNG files
/// in `build/ipad-screens/` beside the repository, which the CI job uploads as the
/// `ipad-mini-screens` artifact. A simulator's processes can write to the runner's own disk;
/// if that ever stops working, the job takes the pictures out of the result bundle instead.
final class IPadScreens: XCTestCase {
    private var app: XCUIApplication!

    /// Long, as in `ScreenTests`: a cold simulator on a CI runner is slow.
    private let appears: TimeInterval = 60

    /// The sidebar rows pressed one after another — the Mac suite's list, spelled as
    /// `SidebarSection.title` spells them. The Tools group is left out: it folds.
    /// **Search is last** (CI 358/360): its field takes the keyboard, the keyboard covers the
    /// lower half of the sidebar, and the next row's press typed an "a" into the search.
    private static let sections = ["Inbox", "Today", "Calendar", "Time Blocks", "Weekly review",
                                   "Map", "All actions", "Aspirations", "Goals", "Projects",
                                   "Areas", "Resources", "Search"]

    /// The middle column's title where it is not the row's name: Time Blocks draws
    /// `PlannerView`, titled "Plan" since round 3 (the row's identifier kept its old name).
    private static let titles = ["Time Blocks": "Plan"]

    /// The test vault's project, as `TestVault` names it.
    private static let project = "note.Projects/Plan the Kungsleden trip.md"

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "These tests look at the iPad's screens, and this is not an iPad.")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-paragon-test-vault", "-paragon-settings-block-open"]
        // A question from iOS, such as Calendar access, would sit on top of every screen after it.
        _ = addUIInterruptionMonitor(withDescription: "A question from iOS") { alert in
            for title in ["Don’t Allow", "Don't Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if app != nil { XCUIDevice.shared.orientation = .portrait }
    }

    func testEveryScreenUpright() {
        walk(.portrait, "portrait")
    }

    func testEveryScreenOnItsSide() {
        walk(.landscapeLeft, "landscape")
    }

    // MARK: The walk

    /// Opens the app held this way, presses every sidebar row and then the test project, and
    /// takes a picture after each. Each picture is named with the orientation and a number,
    /// so the folder lists them in the order they were taken.
    private func walk(_ orientation: UIDeviceOrientation, _ held: String) {
        XCUIDevice.shared.orientation = orientation
        app.launch()
        waitForTheFirstScreen()
        snap("\(held) 00 Opened")

        var number = 0
        func next(_ what: String) -> String {
            number += 1
            return "\(held) \(String(format: "%02d", number)) \(what)"
        }
        for section in Self.sections {
            let name = next(section)
            hideTheKeyboard()
            press(reveal("sidebar.\(section)", name))
            // The middle column is titled with the row's name (`NoteListView.navigationTitle`),
            // so this also proves the press landed on the right row (CI 362).
            let title = Self.titles[section] ?? section
            check(showsTitle(title, within: 20),
                  "\(section) was pressed, but the middle column is not titled \(title). On screen: \(visibleTexts())",
                  name)
            settle()
            snap(name)
            check(app.state == .runningForeground, "The app stopped running on \(section).", name)

            // The test project, opened from the Projects list while it is on screen, so the
            // picture shows where a note goes on the iPad: the third column.
            if section == "Projects" {
                let name = next("A project open")
                press(reveal(Self.project, name))
                check(element("note.editor").waitForExistence(timeout: 20),
                      "The test project opened without its editor.", name)
                settle()
                snap(name)
            }
        }
    }

    /// Waits for anything of the open vault — a sidebar row or a navigation bar — so the first
    /// picture is not of a blank screen. Whether the vault really opened is `reveal`'s question.
    private func waitForTheFirstScreen() {
        let anyRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'sidebar.'")).firstMatch
        let deadline = Date().addingTimeInterval(appears)
        while Date() < deadline {
            if anyRow.exists || app.navigationBars.firstMatch.exists { break }
            Thread.sleep(forTimeInterval: 1)
        }
        settle()
    }

    /// A moment for a column to finish sliding in, so a picture is not taken mid-way — and
    /// a question from iOS answered first, so it is not in the picture. The interruption
    /// monitor only acts at the test's next press (CI 360's landscape Today showed the
    /// Calendar question), so the alert is looked for here as well.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.5)
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.exists else { return }
        for title in ["Don’t Allow", "Don't Allow", "OK"] where alert.buttons[title].exists {
            alert.buttons[title].tap()
            Thread.sleep(forTimeInterval: 1.5)
            return
        }
    }

    // MARK: Finding things

    /// The element, on screen. Tries up to ten times. When the sidebar is out, a sidebar row is
    /// scrolled to: towards it when it exists, otherwise down five times and then up. **A row
    /// below the fold does not exist at all** until it is scrolled to (CI 358/360: Aspirations,
    /// on its side), because the list only makes the rows it draws. When the sidebar is not
    /// out, it is brought out with **Show Sidebar**, or with a swipe in from the left edge when
    /// the bar has no such button.
    private func reveal(_ identifier: String, _ step: String) -> XCUIElement {
        _ = element(identifier).waitForExistence(timeout: 5)
        // Looked up again on every try: which of its elements has a frame can change once the
        // sidebar is out.
        var target = element(identifier)
        for attempt in 0..<10 {
            if isOnScreen(target) {
                if holdsStill(target) { return target }
                continue
            }
            if identifier.hasPrefix("sidebar."), aSidebarRowIsOnScreen() {
                let frame = target.exists ? target.frame : .zero
                if !frame.isEmpty, frame.midY.isFinite {
                    scrollTheSidebar(down: frame.midY > app.frame.midY)
                } else {
                    scrollTheSidebar(down: attempt < 5)
                }
            } else if let button = showSidebarButton() {
                button.tap()
            } else {
                swipeInFromTheLeft()
            }
            _ = target.waitForExistence(timeout: 3)
            target = element(identifier)
        }
        check(isOnScreen(target),
              "\(identifier) could not be brought on screen. If no sidebar row is on screen at all, the vault probably did not open. \(whereItIs(target)) On screen: \(visibleTexts())",
              step)
        return target
    }

    /// The same frame twice, half a second apart. **A list still sliding after a scroll moves
    /// the row between reading its frame and pressing it** (CI 362: on its side, the press
    /// meant for Projects opened Goals, the row above it).
    private func holdsStill(_ element: XCUIElement) -> Bool {
        let before = element.frame
        Thread.sleep(forTimeInterval: 0.5)
        return element.exists && element.frame == before
    }

    /// Waits until a navigation bar carries that title.
    private func showsTitle(_ title: String, within timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if app.navigationBars[title].exists || app.navigationBars.staticTexts[title].exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return false
    }

    /// The first element with that name that has a frame. A name can also land on a wrapper
    /// SwiftUI makes, with no frame at all (build 249), and `firstMatch` may pick that one.
    private func element(_ identifier: String) -> XCUIElement {
        let named = app.descendants(matching: .any).matching(identifier: identifier)
        let framed = named.allElementsBoundByIndex.first { !$0.frame.isEmpty }
        return framed ?? named.firstMatch
    }

    /// There, with its middle on the screen. **The first run asked two more things and both
    /// are gone:** whether the element was "hittable", and whether its middle was inside
    /// `app.windows.firstMatch` — and the sidebar was plainly drawn, upright and on its side,
    /// while no row counted as on screen. The screen is now the app's own frame, which on
    /// iOS is the screen's (`press(_:at:)` in `ScreenTests`), and `press(_:)` taps by
    /// coordinate, so nothing asks about "hittable" at all.
    /// **Not under the keyboard either** (CI 358/360): a press there types a letter.
    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard !frame.isEmpty, frame.midX.isFinite, frame.midY.isFinite else { return false }
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        let screen = app.frame
        guard screen.isEmpty || screen.contains(middle) else { return false }
        return middle.y < visibleBottom()
    }

    /// Puts the keyboard away if a screen brought it up (the note editor may), with the iPad
    /// keyboard's own key or a **Done** above it. Nothing happens when neither is there; the
    /// keyboard check in `isOnScreen` is the safety net.
    private func hideTheKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        for button in [keyboard.buttons["Hide keyboard"], app.toolbars.buttons["Done"]] where button.exists {
            button.tap()
            Thread.sleep(forTimeInterval: 1)
            return
        }
    }

    /// Where the screen stops being the app's: the top of the keyboard while it is up.
    private func visibleBottom() -> CGFloat {
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, !keyboard.frame.isEmpty { return keyboard.frame.minY }
        return app.frame.isEmpty ? .greatestFiniteMagnitude : app.frame.maxY
    }

    /// A tap at the element's middle, measured from the app's corner — the phone's way in
    /// `ScreenTests.press(_:at:)`, which never asks whether the element is "hittable".
    private func press(_ element: XCUIElement) {
        let frame = element.frame
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
    }

    /// What the test knew about an element when it gave up, for the failure message: the
    /// first run said only "could not be brought on screen", which could not tell a missing
    /// row from a hidden one.
    private func whereItIs(_ element: XCUIElement) -> String {
        guard element.exists else { return "It does not exist." }
        let named = app.descendants(matching: .any).matching(identifier: element.identifier).count
        return "It exists (\(named) elements carry its name), hittable \(element.isHittable), frame \(element.frame), app \(app.frame), first window \(app.windows.firstMatch.frame), Show Sidebar button \(showSidebarButton() != nil)."
    }

    private func aSidebarRowIsOnScreen() -> Bool {
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'sidebar.'"))
        return rows.allElementsBoundByIndex.contains { isOnScreen($0) }
    }

    /// The system's own button in the bar. Only its "show" spelling: the same button says
    /// **Hide Sidebar** while the sidebar is out, and pressing that would undo the step.
    private func showSidebarButton() -> XCUIElement? {
        let button = app.buttons.matching(NSPredicate(format: "label == 'Show Sidebar'")).firstMatch
        return button.exists && button.isHittable ? button : nil
    }

    private func swipeInFromTheLeft() {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: 2, dy: 0))
        edge.press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
    }

    /// One drag in the left strip of the window, where the sidebar is. `down` shows the rows
    /// further down the list. The drag stays above the keyboard, if it is up: a drag that
    /// starts on the keys would type.
    private func scrollTheSidebar(down: Bool) {
        let screen = app.frame
        let height = screen.isEmpty ? 1000 : screen.height
        let x = screen.isEmpty ? 80 : screen.width * 0.12
        let highY = height * 0.3
        let lowY = max(highY + 120, min(height * 0.75, visibleBottom() - screen.minY - 40))
        let corner = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let low = corner.withOffset(CGVector(dx: x, dy: lowY))
        let high = corner.withOffset(CGVector(dx: x, dy: highY))
        if down {
            low.press(forDuration: 0.05, thenDragTo: high)
        } else {
            high.press(forDuration: 0.05, thenDragTo: low)
        }
    }

    // MARK: Pictures and failures

    /// A failure with a picture of the moment, named after the step it stopped on.
    private func check(_ condition: Bool, _ message: String, _ step: String) {
        if condition { return }
        snap("\(step) - FAILED")
        XCTFail("\(step): \(message)")
    }

    /// The first twenty texts on screen, for a failure message (as in `ScreenTests`).
    private func visibleTexts() -> String {
        app.staticTexts.allElementsBoundByIndex.prefix(20).map { text -> String in
            let label = text.label
            if !label.isEmpty { return label }
            return (text.value as? String) ?? ""
        }.joined(separator: " | ")
    }

    /// The whole screen, kept as an attachment and written as a PNG. The image is drawn once
    /// more before it is written, so a picture taken on its side is saved the right way up.
    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let image = shot.image
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let png = UIGraphicsImageRenderer(size: image.size, format: format).pngData { _ in
            image.draw(at: .zero)
        }
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try? png.write(to: Self.folder.appendingPathComponent("\(name).png"))
    }

    /// `build/ipad-screens/` in the repository this file was built from.
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // ParagonUITests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // the repository
        .appendingPathComponent("build/ipad-screens", isDirectory: true)
}
#endif
