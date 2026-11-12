import XCTest
@testable import ParagonCore

final class SidebarCountsTests: XCTestCase {
    static func bigVault(_ count: Int = 5000) -> [Note] {
        (0..<count).map { n in
            var lines = ["# Note \(n)", ""]
            for t in 0..<10 {
                let done = t % 3 == 0
                lines.append("- [\(done ? "x" : " ")] Task \(t) of \(n) #tag\(t) >2026-11-\(String(format: "%02d", 1 + (n + t) % 28))" + (done ? " @done(2026-11-12 10:00)" : ""))
            }
            for l in 0..<28 { lines.append("Some ordinary line of prose number \(l) in note \(n).") }
            return Note(relativePath: "Projects/Note \(n).md", kind: .project, text: lines.joined(separator: "\n"))
        }
    }

    private let today = DateOnly(year: 2026, month: 11, day: 12)

    /// A note's tasks are read once and follow every change of its words (hardening 07).
    func testTasksFollowEveryChangeOfTheBody() {
        var note = Note(relativePath: "Projects/Trip.md", kind: .project, text: "- [ ] Pack\n- [ ] Book")
        XCTAssertEqual(note.tasks.map(\.title), ["Pack", "Book"])
        let before = note                       // a copy shares the reading…
        note.body += "\n- [ ] Buy maps"          // …until one of them changes
        XCTAssertEqual(note.tasks.map(\.title), ["Pack", "Book", "Buy maps"])
        XCTAssertEqual(before.tasks.map(\.title), ["Pack", "Book"])
        note.text = "---\ntitle: Trip\n---\n- [x] Pack"
        XCTAssertEqual(note.openTasks.count, 0)
        note.lines = ["- [ ] One"]
        XCTAssertEqual(note.tasks.map(\.title), ["One"])
        note.complete(task: note.tasks[0])
        XCTAssertEqual(note.openTasks.count, 0)
        // What was read is not part of what the note is.
        var asked = before, notAsked = before
        asked.body = before.body; notAsked.body = before.body
        _ = asked.tasks
        XCTAssertEqual(asked, notAsked)
    }

    /// Each sidebar number is the count of the list its screen draws, and the ones that
    /// compare against today move with the day.
    func testCountsMatchTheListsAndFollowTheDay() {
        let notes = [
            Note(relativePath: "Projects/Trip.md", kind: .project,
                 text: "---\ntags: [travel]\n---\n- [ ] Pack #bags >2026-11-12\n- [ ] Book >2026-11-13\n- [x] Maps @done(2026-11-12 09:00)\n- [x] Boots @done(2026-11-13 09:00)"),
            Note(relativePath: "Projects/Quiet.md", kind: .project, text: "Nothing to do here."),
            Note(relativePath: "Projects/Over.md", kind: .project, text: "---\nstatus: done\n---\n- [ ] Left open >2026-11-01"),
            Note(relativePath: "Archive/Old.md", kind: .archive, text: "- [ ] Forgotten #old >2026-01-01"),
            Note(relativePath: "Areas/Home.md", kind: .area, text: "- [ ] Mow >2026-11-10"),
            Note(relativePath: "Goals/Live well.md", kind: .goal, text: "---\nhorizon: life\n---\n"),
            Note(relativePath: "Goals/Run.md", kind: .goal, text: "---\nhorizon: year\ntarget: 2027-06-01\n---\n"),
        ]
        let index = NoteIndex(notes: notes)
        let config = VaultConfig()
        for day in [today, today.adding(days: 1)] {
            let counts = index.sidebarCounts(today: day, config: config)
            XCTAssertEqual(counts.day, day)
            XCTAssertEqual(counts.dueByToday, index.openTasks(dueOnOrBefore: day).count)
            XCTAssertEqual(counts.openTasks, index.openTasks(includeArchived: false).count)
            XCTAssertEqual(counts.doneToday, index.tasksCompleted(on: day).count)
            XCTAssertEqual(counts.tags, index.allTags.count)
            XCTAssertEqual(counts.projectsNeedingAttention, index.review(today: day, config: config).projectsNeedingAttention.count)
            XCTAssertEqual(counts.aspirations, index.aspirations().count)
            XCTAssertEqual(counts.datedGoals, index.datedGoals().count)
            XCTAssertEqual(counts.liveProjects, notes.filter { $0.kind == .project && !$0.isEnded && !$0.isArchived }.count)
            for kind in ParaKind.allCases {
                XCTAssertEqual(counts.notesByKind[kind] ?? 0, index.notes(kind: kind).count)
            }
        }
        let first = index.sidebarCounts(today: today, config: config)
        let next = index.sidebarCounts(today: today.adding(days: 1), config: config)
        XCTAssertEqual(first.doneToday, 1)
        XCTAssertEqual(first.dueByToday + 1, next.dueByToday)   // "Book" comes due
        XCTAssertGreaterThan(first.projectsNeedingAttention, 0)
    }

    /// 5,000 notes of 40 lines and 10 tasks: once the notes have been read, every number the
    /// sidebar shows comes in well under a tenth of a second. Before, each one took most of a
    /// second, per row, per redraw. The limit is loose on purpose (a slow, busy test Mac).
    func testABigVaultCountsQuickly() {
        let index = NoteIndex(notes: Self.bigVault())
        let first = Date()
        let counts = index.sidebarCounts(today: today, config: VaultConfig())
        let reading = Date().timeIntervalSince(first)
        let second = Date()
        XCTAssertEqual(index.sidebarCounts(today: today, config: VaultConfig()), counts)
        let again = Date().timeIntervalSince(second)
        print("TIMING sidebarCounts first \(String(format: "%.3f", reading)) s, again \(String(format: "%.3f", again)) s")
        XCTAssertEqual(counts.openTasks, 30000)
        XCTAssertLessThan(again, 1.0)
    }
}
