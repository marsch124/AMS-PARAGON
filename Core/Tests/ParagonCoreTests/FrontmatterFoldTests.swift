import XCTest
@testable import ParagonCore

final class FrontmatterFoldTests: XCTestCase {
    let note = """
    ---
    title: Plan the trip
    type: project
    tags: [AppDev]
    ---
    # Plan the trip

    - [ ] Book the train
    """

    func testHeadIsTheBlockWithBothFencesAndItsLineBreak() {
        XCTAssertEqual(FrontmatterFold.head(of: note), "---\ntitle: Plan the trip\ntype: project\ntags: [AppDev]\n---\n")
        XCTAssertEqual(FrontmatterFold.body(of: note), "# Plan the trip\n\n- [ ] Book the train")
    }

    func testHeadAndBodyAddUpToTheWholeText() {
        let head = FrontmatterFold.head(of: note)
        XCTAssertEqual(FrontmatterFold.joined(head: head, body: FrontmatterFold.body(of: note)), note)
    }

    func testANoteWithoutABlockIsAllBody() {
        let plain = "# Just words\n\n- [ ] One task"
        XCTAssertNil(FrontmatterFold.head(of: plain))
        XCTAssertEqual(FrontmatterFold.body(of: plain), plain)
        XCTAssertEqual(FrontmatterFold.joined(head: nil, body: plain), plain)
    }

    func testAnUnclosedFenceIsNotABlock() {
        let open = "---\ntitle: Half\n# Then prose"
        XCTAssertNil(FrontmatterFold.head(of: open))
        XCTAssertEqual(FrontmatterFold.body(of: open), open)
    }

    func testAClosingFenceOnTheLastLineLeavesAnEmptyBody() {
        let onlyHead = "---\ntitle: Bare\n---"
        XCTAssertEqual(FrontmatterFold.head(of: onlyHead), onlyHead)
        XCTAssertEqual(FrontmatterFold.body(of: onlyHead), "")
        XCTAssertEqual(FrontmatterFold.joined(head: onlyHead, body: ""), onlyHead)
    }

    func testTheBodyEditedWhileFoldedKeepsTheBlock() {
        let head = FrontmatterFold.head(of: note)
        let edited = FrontmatterFold.body(of: note) + "\n- [ ] Pack the tent"
        let whole = FrontmatterFold.joined(head: head, body: edited)
        XCTAssertTrue(whole.hasPrefix("---\ntitle: Plan the trip\n"))
        XCTAssertTrue(whole.hasSuffix("- [ ] Pack the tent"))
        XCTAssertEqual(Frontmatter.parse(whole).frontmatter.string("type"), "project")
    }
}
