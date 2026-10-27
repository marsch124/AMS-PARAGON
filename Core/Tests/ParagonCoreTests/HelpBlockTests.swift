import XCTest
@testable import ParagonCore

/// Build 272: Help draws a hard-wrapped bullet as one bullet.
///
/// The documents in `Docs/` are wrapped at about 95 columns, so a long bullet is written over
/// several lines with the later ones indented two spaces. The parser used to end the bullet
/// at the first line break and draw the rest as a paragraph under it.
final class HelpBlockTests: XCTestCase {
    func testOneLineBulletsAreDrawnAsBefore() {
        let blocks = HelpBlock.parse("""
        ## Heading

        - one
        - two **bold**
        - three
        """)
        XCTAssertEqual(blocks, [.heading("Heading"), .bullets(["one", "two **bold**", "three"])])
    }

    func testAWrappedBulletIsOneBullet() {
        let blocks = HelpBlock.parse("""
        - first line of the bullet
          and the second line
          and the third
        - the next bullet
        """)
        XCTAssertEqual(blocks, [.bullets(["first line of the bullet and the second line and the third",
                                          "the next bullet"])])
    }

    func testAWrappedSubBulletIsOneBullet() {
        let blocks = HelpBlock.parse("""
        - parent
          - sub one starts here
            and goes on
          - sub two
        """)
        XCTAssertEqual(blocks, [.bullets(["parent", "sub one starts here and goes on", "sub two"])])
    }

    /// The document says "**Done** saves the line…" at the parent's indent after the
    /// sub-bullets (Close the day in the manual). It is not part of the last sub-bullet.
    func testALineAtTheParentsIndentAfterASubBulletStaysAParagraph() {
        let blocks = HelpBlock.parse("""
        - parent
          - sub one
            wrapped
          Done saves the line
          and so on
        - next
        """)
        XCTAssertEqual(blocks, [.bullets(["parent", "sub one wrapped"]),
                                .paragraph("Done saves the line and so on"),
                                .bullets(["next"])])
    }

    func testAPlainLineRightAfterABulletStillStartsAParagraph() {
        let blocks = HelpBlock.parse("""
        - item
        Not indented, so not part of it.
        """)
        XCTAssertEqual(blocks, [.bullets(["item"]), .paragraph("Not indented, so not part of it.")])
    }

    func testABlankLineEndsABullet() {
        let blocks = HelpBlock.parse("""
        - item

          An indented paragraph.
        """)
        XCTAssertEqual(blocks, [.bullets(["item"]), .paragraph("An indented paragraph.")])
    }

    func testAnIndentedLineAfterAParagraphJoinsTheParagraph() {
        let blocks = HelpBlock.parse("""
        First line.
          Second line.
        """)
        XCTAssertEqual(blocks, [.paragraph("First line. Second line.")])
    }

    func testAnIndentedLineDoesNotJoinAnEarlierBulletAcrossAParagraph() {
        let blocks = HelpBlock.parse("""
        - item
        A paragraph.
          Still the paragraph.
        """)
        XCTAssertEqual(blocks, [.bullets(["item"]), .paragraph("A paragraph. Still the paragraph.")])
    }

    func testAWrappedBulletEndsAtAHeadingAndAtACodeFence() {
        let blocks = HelpBlock.parse("""
        - wrapped
          bullet
        ### Sub

        - another
          one
        ```
          code stays as written
        ```
        """)
        XCTAssertEqual(blocks, [.bullets(["wrapped bullet"]), .subheading("Sub"),
                                .bullets(["another one"]), .code("  code stays as written")])
    }

    func testATabCountsAsFourColumns() {
        let blocks = HelpBlock.parse("- item\n\twrapped with a tab")
        XCTAssertEqual(blocks, [.bullets(["item wrapped with a tab"])])
    }

    func testSearchFindsWordsOnTheWrappedLines() {
        let blocks = HelpBlock.parse("- a long bullet\n  with a word on its second line")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(blocks[0].text.contains("second line"))
        XCTAssertTrue(blocks[0].text.contains("a long bullet with"))
    }

    func testTitlesHeadingsAndParagraphsAreAsBefore() {
        let blocks = HelpBlock.parse("# Title\n\nSome words\nover two lines.\n\n## Part\n\n### Detail\n")
        XCTAssertEqual(blocks, [.title("Title"), .paragraph("Some words over two lines."),
                                .heading("Part"), .subheading("Detail")])
    }
}
