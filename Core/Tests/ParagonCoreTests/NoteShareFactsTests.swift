import XCTest
@testable import ParagonCore

final class NoteShareFactsTests: XCTestCase {
    func testAProjectPdfHasOneLineOfFactsAndOtherNotesNone() {
        let project = Note(relativePath: "Projects/Shed.md", kind: .project, text: """
        ---
        title: Shed
        type: project
        goal: Build a home
        area: Home
        due: 2026-12-01
        ---
        # Shed

        - [x] Pour the base
        - [ ] Raise the walls
        - [-] Cancelled
        """)
        XCTAssertEqual(NoteShare.factsLine(of: project),
                       "Active \u{00B7} Serves Build a home \u{00B7} In area Home \u{00B7} Deadline 2026-12-01 \u{00B7} 1 of 2 tasks done")
        let resource = Note(relativePath: "Resources/Idea.md", kind: .resource, text: "---\ntitle: Idea\n---\nText")
        XCTAssertNil(NoteShare.factsLine(of: resource))
    }
}
