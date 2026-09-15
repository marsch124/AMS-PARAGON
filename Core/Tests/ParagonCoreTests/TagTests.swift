import XCTest
@testable import ParagonCore

final class TagTests: XCTestCase {
    var vault: Vault!

    override func setUpWithError() throws {
        vault = try makeTemporaryVault()
    }

    override func tearDown() {
        removeVault(vault)
    }

    private func note(_ text: String) -> Note {
        Note(relativePath: "Projects/P.md", kind: .project, text: text)
    }

    func testRenamingATagTouchesBothPlacesItCanLive() {
        let before = note("""
        ---
        title: P
        type: project
        tags: [travel, Summer]
        ---
        - [ ] Book the ferry #travel #summer
        - [ ] Pack #travelling
        ## Travel notes
        """)
        let after = before.changingTag("travel", to: "trips")
        XCTAssertNotNil(after)
        XCTAssertEqual(after?.tags, ["trips", "Summer"])
        XCTAssertTrue(after!.body.contains("- [ ] Book the ferry #trips #summer"))
        // A longer tag that starts the same way is not a match.
        XCTAssertTrue(after!.body.contains("#travelling"))
        // A markdown heading is not a tag.
        XCTAssertTrue(after!.body.contains("## Travel notes"))
    }

    func testRenamingIsCaseInsensitiveAndNeverDuplicates() {
        let before = note("---\ntitle: P\ntype: project\ntags: [Travel, trips]\n---\n- [ ] Go #TRAVEL\n")
        let after = before.changingTag("travel", to: "trips")
        XCTAssertEqual(after?.tags, ["trips"])
        XCTAssertTrue(after!.body.contains("#trips"))
    }

    func testRemovingATagTidiesTheSpaceItLeaves() {
        let before = note("---\ntitle: P\ntype: project\ntags: [travel, summer]\n---\n  - [ ] Book the ferry #travel #summer\n- [ ] Alone #travel\n")
        let after = before.changingTag("travel", to: nil)
        XCTAssertEqual(after?.tags, ["summer"])
        XCTAssertTrue(after!.body.contains("  - [ ] Book the ferry #summer"), after!.body)
        XCTAssertTrue(after!.body.contains("- [ ] Alone\n"), after!.body)
    }

    func testANoteWithoutTheTagIsLeftAlone() {
        let before = note("---\ntitle: P\ntype: project\ntags: [summer]\n---\n- [ ] Nothing here\n")
        XCTAssertNil(before.changingTag("travel", to: "trips"))
        XCTAssertNil(before.changingTag("travel", to: nil))
    }

    func testRenamingAcrossTheVaultWritesOnlyWhatChanged() throws {
        var carrying = try vault.createNote(kind: .project, title: "Ferry")
        carrying.frontmatter.set("tags", list: ["travel"])
        carrying.body = "- [ ] Book it #travel\n"
        try vault.save(carrying)
        _ = try vault.createNote(kind: .project, title: "Untouched")

        let result = try vault.changeTag("travel", to: "trips")
        XCTAssertEqual(result.saved, ["Projects/Ferry.md"])
        XCTAssertTrue(result.isComplete)

        let reread = NoteIndex(notes: try vault.allNotes())
        XCTAssertEqual(reread.notesTagged("trips").map(\.title), ["Ferry"])
        XCTAssertTrue(reread.notesTagged("travel").isEmpty)
        XCTAssertEqual(reread.tasksTagged("trips").count, 1)
    }

    func testATagMadeButNotUsedIsRemembered() {
        XCTAssertTrue(vault.knownTags().isEmpty)
        vault.rememberTag("#someday")
        vault.rememberTag("someday")
        vault.rememberTag("Waiting")
        XCTAssertEqual(vault.knownTags(), ["someday", "Waiting"])
        vault.forgetTag("SOMEDAY")
        XCTAssertEqual(vault.knownTags(), ["Waiting"])
    }

    func testCountsSplitNotesFromTasks() throws {
        var trip = try vault.createNote(kind: .project, title: "Trip")
        trip.frontmatter.set("tags", list: ["travel"])
        trip.body = "- [ ] Book #travel\n- [x] Packed #travel @done(2026-09-01 08:00)\n"
        try vault.save(trip)

        let uses = NoteIndex(notes: try vault.allNotes()).tagUses()
        let travel = uses.first { $0.tag.lowercased() == "travel" }
        XCTAssertEqual(travel?.noteCount, 1)
        XCTAssertEqual(travel?.openTaskCount, 1)
        XCTAssertEqual(travel?.finishedTaskCount, 1)
        XCTAssertFalse(travel?.isUnused ?? true)
    }

    // MARK: The stored shape of a tag (build 187; it lived in the app untested until now)

    func testCleanTurnsWhatHeTypesIntoATagTheParserCanAlsoMatch() {
        XCTAssertEqual(TagName.clean("travel"), "travel")
        XCTAssertEqual(TagName.clean("#travel"), "travel")
        // Build 146's fault: only the leading # was stripped, so this became one tag called
        // "Claude-#Productivity", which `#tag` on a task line can never spell.
        XCTAssertEqual(TagName.clean("Claude #Productivity"), "Claude-Productivity")
        XCTAssertEqual(TagName.clean("  two   words "), "two-words")
        XCTAssertEqual(TagName.clean("a -- b"), "a-b")
        XCTAssertEqual(TagName.clean("-edge-"), "edge")
        XCTAssertNil(TagName.clean(""))
        XCTAssertNil(TagName.clean("   "))
        XCTAssertNil(TagName.clean("#"))
        XCTAssertNil(TagName.clean("---"))
    }

    func testCleanedDropsWhatIsOnlyADifferentCase() {
        XCTAssertEqual(TagName.cleaned(["Travel", "travel", "#TRAVEL", "waiting"]),
                       ["Travel", "waiting"])
        XCTAssertEqual(TagName.cleaned(["", "  "]), [])
    }

    // MARK: Tags given to a note as it is made

    func testANewNoteCanBeGivenItsTags() throws {
        let note = try vault.createNote(kind: .project, title: "Trip", tags: ["#Travel", "travel", "two words"])
        let saved = try vault.loadNote(relativePath: note.relativePath)
        XCTAssertEqual(saved.tags, ["Travel", "two-words"])
    }

    func testNoTagsLeavesTheTemplatesOwnLineAlone() throws {
        try vault.saveTemplate(named: "Project", text: "---\ntype: project\ntags: kept\n---\n\n# {{title}}\n")
        let note = try vault.createNote(kind: .project, title: "Plain")
        let saved = try vault.loadNote(relativePath: note.relativePath)
        XCTAssertEqual(saved.tags, ["kept"])
    }
}
