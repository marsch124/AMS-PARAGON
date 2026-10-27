import XCTest
@testable import ParagonCore

/// The top of an area note (build 270). Monday 19 October 2026 is "today", so this week runs
/// from the 19th to the 25th and the week before it from the 12th to the 18th — the same days
/// `WeeklyFinishedTests` uses.
///
/// His answers, pinned here: only the `area:` line puts a project in an area, and a sub-area's
/// projects are listed on the sub-area, never on its parent, which gets one row per sub-area.
final class AreaOverviewTests: XCTestCase {
    let today = DateOnly(year: 2026, month: 10, day: 19)

    private func note(_ path: String, kind: ParaKind, _ frontmatter: [(String, String)] = [],
                      type: ParaKind? = nil, body: String = "") -> Note {
        var fm = Frontmatter()
        fm.set("title", String(path.split(separator: "/").last!.dropLast(3)))
        fm.set("type", (type ?? kind).frontmatterType)
        for (key, value) in frontmatter { fm.set(key, value) }
        return Note(relativePath: path, kind: kind, frontmatter: fm, body: body)
    }

    private var health: Note { note("Areas/Health.md", kind: .area) }
    private var home: Note { note("Areas/Home.md", kind: .area) }

    private func project(_ title: String, in area: String, _ more: [(String, String)] = [],
                         body: String = "") -> Note {
        note("Projects/\(title).md", kind: .project, [("area", area)] + more, body: body)
    }

    func testItsProjectsAreListedInHandOrder() {
        let cook = project("Cook more", in: "Health", [("order", "30")])
        let run = project("Run a 10k", in: "Health", [("order", "10")])
        let sleep = project("Sleep better", in: "Health")
        let elsewhere = project("Paint the fence", in: "Home")
        let index = NoteIndex(notes: [health, home, sleep, cook, elsewhere, run])

        let overview = index.areaOverview(of: health, today: today)
        XCTAssertEqual(overview.projects.map(\.note.title), ["Run a 10k", "Cook more", "Sleep better"],
                       "Arranged ones first in their order, then the rest by title; another area's project is not here")
        XCTAssertEqual(overview.overCount, 0)
        XCTAssertNil(overview.overText, "Nothing is over, so nothing is said about it")
    }

    func testOnHoldIsListedAndWhatIsOverIsOnlyCounted() {
        let walk = project("Walk daily", in: "Health")
        let swim = project("Swim", in: "Health", [("status", "on-hold")])
        let diet = project("Old diet", in: "Health", [("status", "done")])
        let marathon = project("Marathon", in: "Health", [("status", "missed")])
        let gym = project("Gym card", in: "Health", [("status", "dropped")])
        let trail = note("Archive/Projects/Old trail.md", kind: .archive,
                         [("area", "Health"), ("status", "archived")], type: .project)
        let index = NoteIndex(notes: [health, walk, swim, diet, marathon, gym, trail])

        let overview = index.areaOverview(of: health, today: today)
        XCTAssertEqual(overview.projects.map(\.note.title), ["Swim", "Walk daily"])
        XCTAssertEqual(overview.projects.first?.status, .onHold, "On hold is still work, so it is listed")
        XCTAssertEqual(overview.overCount, 4, "Done, missed, dropped and archived are counted, never listed")
        XCTAssertEqual(overview.overText,
                       "Not shown here: 4 projects that are done, missed, dropped or archived.")
    }

    func testASubAreasProjectsAreCountedOnItsRowNotListedOnTheParent() {
        let yoga = note("Areas/Yoga.md", kind: .area, [("parent", "Health")], body: "- [ ] Find a mat\n")
        let flow = project("Morning flow", in: "Yoga",
                           body: "- [ ] Learn the sun salute\n- [ ] Book a class\n- [x] Buy a mat\n")
        let over = project("Old class", in: "Yoga", [("status", "done")], body: "- [ ] Never done\n")
        let walk = project("Walk daily", in: "Health")
        let index = NoteIndex(notes: [health, yoga, flow, over, walk])

        let overview = index.areaOverview(of: health, today: today)
        XCTAssertEqual(overview.projects.map(\.note.title), ["Walk daily"],
                       "Morning flow is in Yoga, so it is listed on Yoga's page and not here")
        XCTAssertEqual(overview.subAreas.map(\.note.title), ["Yoga"])
        XCTAssertEqual(overview.subAreas.first?.projectCount, 1, "The finished project is not counted")
        XCTAssertEqual(overview.subAreas.first?.openTaskCount, 3,
                       "Yoga's own open task and its live project's two")
        XCTAssertEqual(overview.subAreas.first?.factsText, "1 project \u{00B7} 3 open")

        let own = index.areaOverview(of: yoga, today: today)
        XCTAssertEqual(own.projects.map(\.note.title), ["Morning flow"])
        XCTAssertEqual(own.overCount, 1)
        XCTAssertEqual(own.subAreas, [], "Areas nest one level only")
    }

    func testTheBarsCountTheAreaAndEveryProjectInIt() {
        let area = note("Areas/Health.md", kind: .area,
                        body: "- [x] Book a check-up @done(2026-10-19 08:00)\n")
        let walk = project("Walk daily", in: "Health",
                           body: "- [x] Buy shoes @done(2026-10-15 09:00)\n- [ ] Walk 5 km\n")
        let diet = project("Old diet", in: "Health", [("status", "done")],
                           body: "- [x] Throw out the sweets @done(2026-10-13 10:00)\n")
        let yoga = note("Areas/Yoga.md", kind: .area, [("parent", "Health")])
        let flow = project("Morning flow", in: "Yoga", body: "- [x] Buy a mat @done(2026-10-19 07:00)\n")
        let loose = note("Projects/Loose.md", kind: .project,
                         body: "Looks after [[Health]].\n- [x] Not in the area @done(2026-10-19 07:00)\n")
        let index = NoteIndex(notes: [area, walk, diet, yoga, flow, loose])

        let weekly = index.areaOverview(of: area, today: today).weekly
        XCTAssertEqual(weekly.counts, [0, 0, 0, 0, 0, 0, 2, 1],
                       "The area's own task this week; a live and a finished project's tasks last week")
        XCTAssertEqual(weekly.total, 3,
                       "Yoga's work is on Yoga's page, and a project that only links to Health is not in it")
        XCTAssertEqual(weekly.lastFinished, today)
    }

    func testNoDatedFinishMeansNoBars() {
        let walk = project("Walk daily", in: "Health", body: "- [x] Ticked with no stamp\n- [ ] Open\n")
        let index = NoteIndex(notes: [health, walk])
        XCTAssertTrue(index.areaOverview(of: health, today: today).weekly.isEmpty,
                      "Empty bars would say nothing was done; the truth is the file cannot say")

        let bare = NoteIndex(notes: [health])
        let nothing = bare.areaOverview(of: health, today: today)
        XCTAssertTrue(nothing.weekly.isEmpty)
        XCTAssertEqual(nothing.projects, [])
        XCTAssertEqual(nothing.subAreas, [])
    }

    func testAnOldFinishGivesAGreyLineAndNoBars() {
        // Stamped 100 days before "today" (19 October): older than the eight weeks the bars cover.
        let old = project("Old diet", in: "Health", [("status", "done")],
                          body: "- [x] Throw out the sweets @done(2026-07-11 09:00)\n")
        let index = NoteIndex(notes: [health, old])

        let weekly = index.areaOverview(of: health, today: today).weekly
        XCTAssertFalse(weekly.isEmpty, "The file does say when the last task was finished")
        XCTAssertEqual(weekly.total, 0, "But none of it is inside the eight weeks")
        XCTAssertEqual(weekly.caption(today: today), "last task finished about 3 months ago",
                       "The area page says this instead of \"0 tasks finished in 8 weeks\" (build 141)")
    }

    func testEachBoxSaysWhatTheProjectsListSays() {
        let walk = project("Walk daily", in: "Health",
                           body: "- [x] Buy shoes\n- [ ] Plan the route #next\n- [ ] Walk 5 km\n")
        let swim = project("Swim", in: "Health", body: "- [x] Find a pool\n- [x] Buy goggles\n")
        let sleep = project("Sleep better", in: "Health")
        let index = NoteIndex(notes: [health, walk, swim, sleep])

        let lines = index.areaOverview(of: health, today: today).projects
        let byTitle = Dictionary(uniqueKeysWithValues: lines.map { ($0.note.title, $0) })
        XCTAssertEqual(byTitle["Walk daily"]?.nextTitle, "Plan the route",
                       "The task marked #next, without the tag")
        XCTAssertEqual(byTitle["Swim"]?.need, .allFinished(count: 2))
        XCTAssertEqual(byTitle["Sleep better"]?.need, .noTasks)

        let listed = index.projectGroups([walk, swim, sleep], today: today).flatMap(\.lines)
        for line in listed {
            XCTAssertEqual(byTitle[line.note.title], line,
                           "\(line.note.title): the area page and the Projects list say the same")
        }
    }

    func testTheWords() {
        XCTAssertEqual(AreaOverview.projectsText(0), "No projects")
        XCTAssertEqual(AreaOverview.projectsText(1), "1 project")
        XCTAssertEqual(AreaOverview.projectsText(3), "3 projects")

        let yoga = note("Areas/Yoga.md", kind: .area)
        XCTAssertEqual(SubAreaLine(note: yoga, projectCount: 0, openTaskCount: 0).factsText, "No projects")
        XCTAssertEqual(SubAreaLine(note: yoga, projectCount: 0, openTaskCount: 2).factsText,
                       "No projects \u{00B7} 2 open")
        XCTAssertEqual(SubAreaLine(note: yoga, projectCount: 2, openTaskCount: 0).factsText, "2 projects",
                       "Never \"0 open\"")

        let empty = AreaOverview(area: health, projects: [], overCount: 0, subAreas: [],
                                 weekly: WeeklyFinished(counts: Array(repeating: 0, count: 8), lastFinished: nil))
        XCTAssertEqual(empty.emptyText, "No projects in this area yet.")
        var allOver = empty
        allOver.overCount = 1
        XCTAssertEqual(allOver.emptyText, "No projects in this area right now.")
        XCTAssertEqual(allOver.overText, "Not shown here: 1 project that is done, missed, dropped or archived.")
    }
}
