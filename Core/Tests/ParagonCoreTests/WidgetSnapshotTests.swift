import XCTest
@testable import ParagonCore

/// Build 174: the iPhone widget. The widget itself cannot be tested from here — there is no
/// WidgetKit in this package — but everything it *reads* is decided here, and that is what
/// these tests are about: the app and the widget must never disagree about what is due today.
final class WidgetSnapshotTests: XCTestCase {

    private let today = DateOnly(year: 2026, month: 9, day: 15)

    private func index(_ notes: [Note]) -> NoteIndex { NoteIndex(notes: notes) }

    private func project(_ name: String, body: String, goal: String? = nil, area: String? = nil) -> Note {
        var front = "---\ntitle: \(name)\ntype: project\n"
        if let goal { front += "goal: \(goal)\n" }
        if let area { front += "area: \(area)\n" }
        front += "---\n"
        return Note(relativePath: "Projects/\(name).md", kind: .project, text: front + body)
    }

    func testTodaysActionsAreWhatIsDueThenTheNextActions() {
        let due = project("Race", body: """
        - [ ] Book the hotel >2026-09-15
        - [ ] Something later >2026-12-01
        """)
        let next = project("Bike", body: """
        - [ ] Order the saddle #next
        - [ ] A task nobody asked for
        """)
        let actions = index([due, next]).actionsForPlanning(on: today)
        XCTAssertEqual(actions.map(\.task.title), ["Book the hotel", "Order the saddle"])
    }

    func testAnOverdueTaskIsStillTodaysWork() {
        let late = project("Race", body: "- [ ] Long ride >2026-09-13\n")
        let actions = index([late]).actionsForPlanning(on: today)
        XCTAssertEqual(actions.count, 1)
        let snapshot = index([late]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.items.first?.dueText, "2 days over")
        XCTAssertTrue(snapshot.items.first?.isOverdue ?? false)
        XCTAssertEqual(snapshot.overdue, 1)
    }

    func testEachActionSaysWhatItServes() {
        let goal = Note(relativePath: "Goals/Seventy.md", kind: .goal,
                        text: "---\ntitle: Still racing at seventy\nhorizon: life\n---\n")
        let area = Note(relativePath: "Areas/Health.md", kind: .area, text: "---\ntitle: Health\n---\n")
        let servesGoal = project("Race", body: "- [ ] Book the hotel >2026-09-15\n",
                                 goal: "Still racing at seventy")
        let servesArea = project("Stretching", body: "- [ ] Twenty minutes >2026-09-15\n", area: "Health")
        let loose = project("Tuba", body: "- [ ] Find a teacher >2026-09-15\n")

        let snapshot = index([goal, area, servesGoal, servesArea, loose])
            .widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        let byTitle = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.title, $0) })

        XCTAssertEqual(byTitle["Book the hotel"]?.serves, "Still racing at seventy")
        XCTAssertEqual(byTitle["Book the hotel"]?.servesIsGoal, true)
        XCTAssertEqual(byTitle["Twenty minutes"]?.serves, "Health")
        XCTAssertEqual(byTitle["Twenty minutes"]?.servesIsGoal, false)
        // A project with neither is not a fault and not an invention: it simply says nothing.
        XCTAssertNil(byTitle["Find a teacher"]?.serves)
    }

    func testTheWidgetIsAGlanceAndNotAList() {
        var body = ""
        for i in 1...20 { body += "- [ ] Task \(i) >2026-09-15\n" }
        let snapshot = index([project("Many", body: body)])
            .widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.items.count, WidgetSnapshot.maxItems)
        // The counts are of everything, not of what fits — the widget says "and N more" from
        // them, so they may not be cut with the list.
        XCTAssertEqual(snapshot.dueToday, 20)
    }

    func testNothingToDoIsNotTheSameAsNoFile() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paragon-widget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        // No file: the app has never run on this phone.
        XCTAssertNil(WidgetSnapshot.read(fromContainer: folder))

        // A file with no items: the app has run and there is nothing to do. Good news, and a
        // different sentence on the widget (build 100's rule, on a home screen).
        let empty = index([]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        try empty.write(toContainer: folder)
        let back = WidgetSnapshot.read(fromContainer: folder)
        XCTAssertNotNil(back)
        XCTAssertTrue(back?.isEmpty ?? false)
    }

    func testARoundTripKeepsEverythingTheWidgetDraws() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paragon-widget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let goal = Note(relativePath: "Goals/Seventy.md", kind: .goal,
                        text: "---\ntitle: Still racing at seventy\nhorizon: life\n---\n")
        let note = project("Race", body: "- [ ] Book the hotel >2026-09-15\n",
                           goal: "Still racing at seventy")
        let written = index([goal, note]).widgetSnapshot(on: today, inboxCount: 4, dueForReview: 2)
        try written.write(toContainer: folder)

        let back = try XCTUnwrap(WidgetSnapshot.read(fromContainer: folder))
        XCTAssertEqual(back, written)
        XCTAssertEqual(back.inboxCount, 4)
        XCTAssertEqual(back.dueForReview, 2)
        XCTAssertEqual(back.items.first?.noteKind, "project")
    }

    func testYesterdaysSnapshotKnowsItIsOld() {
        let yesterday = index([]).widgetSnapshot(on: DateOnly(year: 2026, month: 9, day: 14),
                                                 inboxCount: 0, dueForReview: 0)
        XCTAssertTrue(yesterday.isStale(on: today))
        XCTAssertFalse(yesterday.isStale(on: DateOnly(year: 2026, month: 9, day: 14)))
    }

    func testTheTapOpensTheNoteThroughTheSchemeThatAlreadyExists() {
        // `amspara://` is one of the four identifiers the rename deliberately kept. A widget
        // that invented `paragon://` would open nothing at all.
        XCTAssertEqual(WidgetSnapshot.link(toNoteTitled: "Race"), "amspara://Race")
        let spaced = WidgetSnapshot.link(toNoteTitled: "Jönköping 70.3")
        XCTAssertTrue(spaced.hasPrefix("amspara://"))
        XCTAssertFalse(spaced.contains(" "))
        XCTAssertNotNil(URL(string: spaced))
    }

    func testAnArchivedProjectStillDrawsAsAProject() {
        // Archiving moves the file, so `kind` reads `.archive` from the folder. The widget
        // takes its symbol from `declaredKind`, the same as `TaskRow` since build 153.
        let archived = Note(relativePath: "Archive/Old.md", kind: .archive,
                            text: "---\ntitle: Old\ntype: project\n---\n- [ ] Loose end #next\n")
        let snapshot = index([archived]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        for item in snapshot.items {
            XCTAssertEqual(item.noteKind, "project")
        }
    }
}
