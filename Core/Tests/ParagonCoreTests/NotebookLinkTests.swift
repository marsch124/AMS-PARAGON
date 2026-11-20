import XCTest
@testable import ParagonCore

/// **Notebook** on a Resource (build 343): `notebook:` in the settings block, only ever a Google
/// notebook address, written and removed without touching anything else.
final class NotebookLinkTests: XCTestCase {
    private func resource(_ lines: String = "") -> Note {
        Note(relativePath: "Resources/Sailing.md", kind: .resource,
             text: "---\ntitle: Sailing\ntype: resource\n\(lines)---\n# Sailing\n\nSome words.\n")
    }

    private func reread(_ note: Note) -> Note {
        Note(relativePath: note.relativePath, kind: note.kind, text: note.text)
    }

    func testOnlyNotebookAddressesAreAccepted() {
        XCTAssertEqual(NotebookLink.cleaned("  https://notebooklm.google.com/notebook/abc \n")?.absoluteString,
                       "https://notebooklm.google.com/notebook/abc")
        XCTAssertEqual(NotebookLink.cleaned("notebooklm.google.com/notebook/abc")?.absoluteString,
                       "https://notebooklm.google.com/notebook/abc")
        XCTAssertNotNil(NotebookLink.cleaned("https://gemini.google.com/notebook/xyz"))
        XCTAssertNil(NotebookLink.cleaned("http://notebooklm.google.com/notebook/abc"))
        XCTAssertNil(NotebookLink.cleaned("https://evil.com/notebooklm.google.com"))
        XCTAssertNil(NotebookLink.cleaned("https://notebooklm.google.com.evil.com/x"))
        XCTAssertNil(NotebookLink.cleaned("my notebook"))
        XCTAssertNil(NotebookLink.cleaned(""))
    }

    func testSetReadAndRemoveTouchNothingElse() throws {
        let url = try XCTUnwrap(NotebookLink.cleaned("https://notebooklm.google.com/notebook/abc"))
        let linked = reread(NotebookLink.setting(url, on: resource()))
        XCTAssertEqual(NotebookLink.link(of: linked), url)
        XCTAssertTrue(linked.text.contains("notebook: https://notebooklm.google.com/notebook/abc"))
        XCTAssertTrue(linked.text.hasSuffix("# Sailing\n\nSome words.\n"))
        XCTAssertEqual(NotebookLink.setting(url, on: linked), linked, "the same link again changes nothing")
        let removed = reread(NotebookLink.setting(nil, on: linked))
        XCTAssertNil(NotebookLink.link(of: removed))
        XCTAssertFalse(removed.text.contains("notebook:"))
    }

    func testWhichNotesOfferTheMenu() {
        XCTAssertTrue(NotebookLink.isOffered(for: resource()))
        let project = Note(relativePath: "Projects/Boat.md", kind: .project,
                           text: "---\ntitle: Boat\ntype: project\n---\n# Boat\n")
        XCTAssertFalse(NotebookLink.isOffered(for: project))
        let archived = Note(relativePath: "Archive/Sailing.md", kind: .archive,
                            text: "---\ntitle: Sailing\nnotebook: https://notebooklm.google.com/notebook/abc\n---\n")
        XCTAssertTrue(NotebookLink.isOffered(for: archived))
        let junk = resource("notebook: https://example.com/x\n")
        XCTAssertNil(NotebookLink.link(of: junk), "a line that is no notebook address opens nothing")
    }
}
