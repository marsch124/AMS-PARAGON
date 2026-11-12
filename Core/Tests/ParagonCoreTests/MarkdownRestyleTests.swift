import XCTest
@testable import ParagonCore

/// Premium review, hardening-20: only the lines around the cursor are drawn again while typing.
final class MarkdownRestyleTests: XCTestCase {
    private let text = "---\ntitle: Shed\n---\n# Shed\nSome **bold** words\n```\nlet a = 1\n```\n- [ ] Buy wood\nLast"

    private func offset(of piece: String) -> Int { (text as NSString).range(of: piece).location }

    func testOnlyTheChangedLinesAreDrawnAgain() {
        let ns = text as NSString
        // A letter typed in a plain line: that line, and the spans are the whole note's own.
        let line = ns.lineRange(for: NSRange(location: offset(of: "bold"), length: 0))
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: offset(of: "bold"), length: 1)),
                       .lines(line, inCode: false))
        let whole = MarkdownHighlight.spans(in: text).filter { NSIntersectionRange($0.range, line).length > 0 }
        XCTAssertEqual(MarkdownHighlight.spans(in: ns, lines: line, inCode: false), whole)
        XCTAssertFalse(whole.isEmpty)
        // The task line after the code block is not taken for code.
        let task = ns.lineRange(for: NSRange(location: offset(of: "Buy"), length: 0))
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: offset(of: "Buy"), length: 0)),
                       .lines(task, inCode: false))
        // Inside the code block the line is code.
        let code = ns.lineRange(for: NSRange(location: offset(of: "let a"), length: 0))
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: offset(of: "let a"), length: 1)),
                       .lines(code, inCode: true))
        XCTAssertEqual(MarkdownHighlight.spans(in: ns, lines: code, inCode: true),
                       MarkdownHighlight.spans(in: text).filter { NSIntersectionRange($0.range, code).length > 0 })
        // A change that ends in a line break takes the next line along.
        let breakAt = NSMaxRange(line) - 1
        XCTAssertEqual(MarkdownHighlight.restyle(of: "# One\ntwo\nthree" as NSString, around: NSRange(location: 5, length: 1)),
                       .lines(NSRange(location: 0, length: 10), inCode: false))
        XCTAssertEqual(ns.character(at: breakAt), 10)
    }

    func testLinesThatChangeOthersAskForTheWholeNote() {
        let ns = text as NSString
        // The settings block, a line that opens or closes a code block, a very long paste.
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: offset(of: "title"), length: 1)), .whole)
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: offset(of: "```"), length: 1)), .whole)
        XCTAssertEqual(MarkdownHighlight.restyle(of: ns, around: NSRange(location: 0, length: ns.length + 1)), .whole)
        let long = String(repeating: "word ", count: 5_000) as NSString
        XCTAssertEqual(MarkdownHighlight.restyle(of: long, around: NSRange(location: 10, length: 1)), .whole)
        XCTAssertTrue(MarkdownHighlight.reachesOtherLines("text\n  ~~~swift\n"))
        XCTAssertTrue(MarkdownHighlight.reachesOtherLines("---"))
        XCTAssertFalse(MarkdownHighlight.reachesOtherLines("a --- b and `code`"))
    }
}
