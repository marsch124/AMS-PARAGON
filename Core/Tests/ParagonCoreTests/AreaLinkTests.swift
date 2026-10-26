import XCTest
@testable import ParagonCore

/// Which area a project is in (build 269). **Only the `area:` line decides**, his answer:
/// a `[[Health]]` in the text links two notes but does not put a project in Health.
/// `NoteIndex.area(named:)` is the one place the line is resolved, and the Map, the
/// Aspirations chain, the planner and the widget all ask it.
final class AreaLinkTests: XCTestCase {
    private func note(_ path: String, kind: ParaKind, _ frontmatter: [(String, String)] = [],
                      type: ParaKind? = nil, title: String? = nil, body: String = "") -> Note {
        var fm = Frontmatter()
        fm.set("title", title ?? String(path.split(separator: "/").last!.dropLast(3)))
        fm.set("type", (type ?? kind).frontmatterType)
        for (key, value) in frontmatter { fm.set(key, value) }
        return Note(relativePath: path, kind: kind, frontmatter: fm, body: body)
    }

    private var health: Note { note("Areas/Health.md", kind: .area) }
    private var yoga: Note { note("Areas/Yoga.md", kind: .area, [("parent", "Health")]) }

    func testTheAreaLineDecides() {
        let project = note("Projects/Stretch daily.md", kind: .project, [("area", "Yoga")],
                           body: "Part of looking after [[Health]].\n")
        let index = NoteIndex(notes: [health, yoga, project])

        XCTAssertEqual(index.area(of: project)?.relativePath, "Areas/Yoga.md")
        XCTAssertEqual(index.projects(in: yoga).map(\.title), ["Stretch daily"])
    }

    func testALinkInTheTextAloneDoesNotPutAProjectInAnArea() {
        let project = note("Projects/Run a 10k.md", kind: .project,
                           body: "See [[Health]].\n- [ ] Buy shoes\n")
        let related = note("Projects/Sleep better.md", kind: .project, [("related", "Health")])
        let index = NoteIndex(notes: [health, project, related])

        XCTAssertNil(index.area(of: project))
        XCTAssertNil(index.area(of: related))
        XCTAssertEqual(index.projects(in: health), [])
        // The text still links the two notes: that is what Linked notes shows.
        XCTAssertEqual(index.backlinks(to: health).map(\.title), ["Run a 10k", "Sleep better"])
    }

    func testAProjectInASubAreaBelongsToTheSubAreaNotItsParent() {
        let project = note("Projects/Morning flow.md", kind: .project, [("area", "Yoga")])
        let index = NoteIndex(notes: [health, yoga, project])

        XCTAssertEqual(index.projects(in: yoga).map(\.title), ["Morning flow"])
        XCTAssertEqual(index.projects(in: health), [])
    }

    func testAnArchivedProjectStillKnowsItsArea() {
        let archived = note("Archive/Projects/Old trail.md", kind: .archive,
                            [("area", "Health"), ("status", "archived")], type: .project)
        let index = NoteIndex(notes: [health, archived])

        XCTAssertEqual(index.area(of: archived)?.relativePath, "Areas/Health.md")
        XCTAssertEqual(index.projects(in: health).map(\.title), ["Old trail"])
    }

    func testOnlyAnAreaIsEverTheAnswer() {
        // A resource and a project named like an area, and listed before it: a plain link
        // lookup would find the resource first.
        let resource = note("Resources/Health.md", kind: .resource)
        let garden = note("Projects/Garden.md", kind: .project)
        let shed = note("Resources/Garden shed.md", kind: .resource, title: "Shed")
        let index = NoteIndex(notes: [resource, garden, shed, health])

        XCTAssertEqual(index.note(matching: "Health")?.relativePath, "Resources/Health.md")
        XCTAssertEqual(index.area(named: "Health")?.relativePath, "Areas/Health.md")
        XCTAssertNil(index.area(named: "Garden"), "a project is never an area")
        XCTAssertNil(index.area(named: "Shed"), "a resource is never an area")
        XCTAssertNil(index.area(named: "   "))
    }

    func testAnAreaIsFoundByTitleOrFileNameIgnoringCase() {
        let body = note("Areas/Body and mind.md", kind: .area, title: "Body & mind")
        let index = NoteIndex(notes: [body])

        XCTAssertEqual(index.area(named: "BODY & MIND")?.relativePath, "Areas/Body and mind.md")
        XCTAssertEqual(index.area(named: "body and mind")?.relativePath, "Areas/Body and mind.md")
        XCTAssertEqual(index.area(named: " Body & mind ")?.relativePath, "Areas/Body and mind.md")
        XCTAssertNil(index.area(named: "Body"))
    }

    func testANoteIsNeverItsOwnArea() {
        let selfish = note("Areas/Health.md", kind: .area, [("area", "Health")])
        let index = NoteIndex(notes: [selfish])

        XCTAssertNil(index.area(of: selfish))
    }

    func testProjectsInAnAreaComeInListOrder() {
        let later = note("Projects/A walk.md", kind: .project, [("area", "Health")])
        let first = note("Projects/B run.md", kind: .project, [("area", "health"), ("order", "10")])
        let index = NoteIndex(notes: [later, health, first])

        XCTAssertEqual(index.projects(in: health).map(\.title), ["B run", "A walk"])
    }

    func testTheMapPutsAProjectUnderTheAreaItsLineNames() {
        let byLine = note("Projects/Stretch daily.md", kind: .project, [("area", "Yoga")],
                          body: "Part of [[Health]].\n")
        let byLink = note("Projects/Run a 10k.md", kind: .project, body: "See [[Health]].\n")
        let map = NoteIndex(notes: [health, yoga, byLine, byLink]).linkMap()

        XCTAssertEqual(map.parent(of: "Projects/Stretch daily.md"), "Areas/Yoga.md")
        XCTAssertEqual(map.parent(of: "Projects/Run a 10k.md"), "group:unlinked",
                       "a link in the text alone does not put a project under an area")
    }

    func testTheWidgetAndTheChainNameTheAreaNotANoteWithItsName() {
        // A resource whose file is called Health, listed first: a plain link lookup finds it.
        let resource = note("Resources/Health.md", kind: .resource, title: "Health notes")
        let area = note("Areas/Health.md", kind: .area)
        let project = note("Projects/Stretching.md", kind: .project, [("area", "health")],
                           body: "- [ ] Twenty minutes #next\n")
        let aspiration = note("Goals/Strong at seventy.md", kind: .goal,
                              [("horizon", "life"), ("area", "Health")])
        let index = NoteIndex(notes: [resource, area, project, aspiration])
        guard let task = project.tasks.first else {
            XCTFail("The project's task was not read.")
            return
        }
        let ref = TaskRef(notePath: project.relativePath, noteTitle: project.displayTitle, task: task)

        XCTAssertEqual(index.serves(ref)?.title, "Health")
        XCTAssertEqual(index.serves(ref)?.isGoal, false)
        XCTAssertEqual(index.chain(of: aspiration).area?.relativePath, "Areas/Health.md")
    }

    func testANewProjectCarriesOneAreaLine() throws {
        let vault = try makeTemporaryVault()
        defer { removeVault(vault) }
        _ = try vault.createNote(kind: .area, title: "Health")
        let made = try vault.createNote(kind: .project, title: "Run 10k", extraFrontmatter: [("area", "Health")])

        let index = NoteIndex(notes: try vault.allNotes())
        let project = try XCTUnwrap(index.note(path: made.relativePath))
        XCTAssertEqual(project.area, "Health")
        let lines = project.text.split(separator: "\n").filter { $0.hasPrefix("area:") }
        XCTAssertEqual(lines, ["area: Health"], "the template's empty area: line is replaced, not repeated")
        let area = try XCTUnwrap(index.area(named: "Health"))
        XCTAssertEqual(index.projects(in: area).map(\.title), ["Run 10k"])
    }
}
