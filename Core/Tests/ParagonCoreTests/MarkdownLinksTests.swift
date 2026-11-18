import XCTest
@testable import ParagonCore

/// Build 339: Markdown links that can be opened while a note is being edited.
final class MarkdownLinksTests: XCTestCase {
    private let note = """
    # Summer cabin

    ![Picture](../Pictures/Seedboard%20Summer%20cabin.png)

    [Open the board in Seedboard](seedboard://board/8A60561B-9CC1-4BB3-8B23-A9BC69BA139C)

    - [ ] Read [the permit rules](https://example.com/permit) first
    - See [the plan](Attachments/plan.pdf) and [[Budget]]
    """

    func testABoardLinkAndAWebLinkAreFoundAPictureAndAFileAreNot() {
        let found = MarkdownLinks.matches(in: note).map(\.url.absoluteString)
        XCTAssertEqual(found, ["seedboard://board/8A60561B-9CC1-4BB3-8B23-A9BC69BA139C", "https://example.com/permit"])
    }

    func testAClickAnywhereInALinkGivesItsAddress() {
        let ns = note as NSString
        let words = ns.range(of: "Open the board").location
        let address = ns.range(of: "seedboard://").location + 4
        XCTAssertEqual(MarkdownLinks.link(at: words, in: note)?.scheme, "seedboard")
        XCTAssertEqual(MarkdownLinks.link(at: address, in: note)?.scheme, "seedboard")
        XCTAssertEqual(MarkdownLinks.link(at: ns.range(of: "the permit rules").location, in: note)?.host, "example.com")
        XCTAssertNil(MarkdownLinks.link(at: ns.range(of: "# Summer").location, in: note))
        XCTAssertNil(MarkdownLinks.link(at: ns.range(of: "Picture").location, in: note), "a picture is not a link")
        XCTAssertNil(MarkdownLinks.link(at: ns.range(of: "the plan").location, in: note), "a file on the device is not opened")
    }

    func testATapOpensOnlyALinkToAnotherAppAndOnlyOnItsWords() {
        let ns = note as NSString
        let words = ns.range(of: "Open the board").location
        XCTAssertEqual(MarkdownLinks.appLink(at: words, in: note)?.url.host, "board")
        // On the address, not the words: the caret goes there as before.
        XCTAssertNil(MarkdownLinks.appLink(at: ns.range(of: "seedboard://").location + 4, in: note))
        // A link to the web keeps taking the caret on a tap.
        XCTAssertNil(MarkdownLinks.appLink(at: ns.range(of: "the permit rules").location, in: note))
    }

    func testWhatMayBeOpened() {
        XCTAssertTrue(MarkdownLinks.mayOpen(URL(string: "seedboard://board/1")!))
        XCTAssertTrue(MarkdownLinks.mayOpen(URL(string: "mailto:someone@example.com")!))
        XCTAssertFalse(MarkdownLinks.mayOpen(URL(string: "file:///etc/hosts")!))
        XCTAssertFalse(MarkdownLinks.mayOpen(URL(string: "javascript:alert(1)")!))
        XCTAssertTrue(MarkdownLinks.opensAnotherApp(URL(string: "seedboard://board/1")!))
        XCTAssertFalse(MarkdownLinks.opensAnotherApp(URL(string: "https://example.com")!))
        XCTAssertFalse(MarkdownLinks.opensAnotherApp(URL(string: "amspara://capture?text=x")!), "PARAGON's own links are not another app")
    }
}
