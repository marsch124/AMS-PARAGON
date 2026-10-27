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
        // The parser keeps `#tags` in a title on purpose, so they round-trip to the file.
        XCTAssertEqual(actions.map(\.task.title), ["Book the hotel", "Order the saddle #next"])
    }

    func testTheWidgetDropsHashNextAndKeepsHisOwnTags() {
        // `#next` is the app's own marker, and the widget is showing the task because of it —
        // so on three short lines the word says nothing. His own tags do say something.
        XCTAssertEqual(WidgetSnapshot.widgetTitle("Order the saddle #next"), "Order the saddle")
        XCTAssertEqual(WidgetSnapshot.widgetTitle("#next Order the saddle"), "Order the saddle")
        XCTAssertEqual(WidgetSnapshot.widgetTitle("Book the hotel #travel"), "Book the hotel #travel")
        XCTAssertEqual(WidgetSnapshot.widgetTitle("Plan #nextweek"), "Plan #nextweek")
        XCTAssertEqual(WidgetSnapshot.widgetTitle("Ring #next the shop"), "Ring the shop")

        let note = project("Bike", body: "- [ ] Order the saddle #next\n")
        let snapshot = index([note]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.items.first?.title, "Order the saddle")
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

    // MARK: Build 271: the widgets follow every change

    private func snapshotOf(_ notes: [Note], on day: DateOnly? = nil, inbox: Int = 0,
                          written: TimeInterval) -> WidgetSnapshot {
        index(notes).widgetSnapshot(on: day ?? today, inboxCount: inbox, dueForReview: 0,
                                    written: Date(timeIntervalSince1970: written))
    }

    func testTwoSnapshotsThatDifferOnlyInWhenTheyWereWrittenAreTheSame() {
        let note = project("Race", body: "- [ ] Book the hotel >2026-09-15\n")
        let early = snapshotOf([note], inbox: 1, written: 1_000)
        let later = snapshotOf([note], inbox: 1, written: 9_000)
        // The two really are different values, which is why a plain `==` cannot be the rule.
        XCTAssertNotEqual(early.written, later.written)
        XCTAssertNotEqual(early, later)
        XCTAssertTrue(later.sameContent(as: early))
        XCTAssertTrue(early.sameContent(as: later))
        XCTAssertTrue(early.sameContent(as: early))
    }

    func testANewDayIsAChange() {
        // The midnight rule hangs on this: the same notes on the next day must be written again,
        // or the widgets would keep yesterday's date and say "Nothing since you last opened".
        let note = project("Race", body: "- [ ] Book the hotel >2026-09-15\n")
        let tomorrow = DateOnly(year: 2026, month: 9, day: 16)
        let before = snapshotOf([note], written: 1_000)
        let after = snapshotOf([note], on: tomorrow, written: 1_000)
        XCTAssertEqual(before.written, after.written)
        XCTAssertFalse(after.sameContent(as: before))
        XCTAssertFalse(before.sameContent(as: after))
    }

    func testATickedTaskIsAChange() {
        let untouched = project("Race", body: "- [ ] Book the hotel >2026-09-15\n- [ ] Pack the bike >2026-09-15\n")
        let ticked = project("Race", body: "- [x] Book the hotel @done(2026-09-15 08:00)\n- [ ] Pack the bike >2026-09-15\n")
        let before = snapshotOf([untouched], written: 1_000)
        let after = snapshotOf([ticked], written: 2_000)
        // Said first, so a surprise in the parser fails with its own words and not as a rule.
        XCTAssertEqual(before.items.count, 2)
        XCTAssertEqual(after.items.count, 1)
        XCTAssertFalse(after.sameContent(as: before))
        XCTAssertEqual(after.dueToday, 1)
    }

    func testAChangedCountIsAChange() {
        let note = project("Race", body: "- [ ] Book the hotel >2026-09-15\n")
        let before = snapshotOf([note], inbox: 1, written: 1_000)
        let after = snapshotOf([note], inbox: 2, written: 1_000)
        XCTAssertFalse(after.sameContent(as: before))
    }

    func testNothingWrittenYetIsNeverTheSame() {
        // With no file written there is nothing to compare with, even for an empty snapshot:
        // the first write has to happen so the widget can tell "nothing to do" from "no file".
        let empty = snapshotOf([], written: 1_000)
        XCTAssertFalse(empty.sameContent(as: nil))
        let note = project("Race", body: "- [ ] Book the hotel >2026-09-15\n")
        XCTAssertFalse(snapshotOf([note], written: 1_000).sameContent(as: nil))
    }

    // MARK: Build 273: Today's plan

    private func dailyNote(_ day: DateOnly, plan: String) -> Note {
        Note(relativePath: "Calendar/\(Note.dailyFileName(for: day)).md", kind: .daily,
             text: "---\ntitle: \(day)\ntype: daily\n---\n# \(day)\n\n## Plan\n\n\(plan)\n\n## Tasks\n\n")
    }

    func testAFileWrittenBeforeBuild273StillReadsAndHasNoPlan() throws {
        // What build 271 wrote: no `plan`, no `events`. It must decode, and both must be nil —
        // "an older app wrote this" — and never empty lists, which would say "nothing planned".
        let old = """
        {"day":{"year":2026,"month":10,"day":26},"written":0,"dueToday":1,"overdue":0,\
        "inboxCount":2,"dueForReview":0,"items":[]}
        """
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(old.utf8))
        XCTAssertNil(snapshot.plan)
        XCTAssertNil(snapshot.events)
        XCTAssertEqual(snapshot.dueToday, 1)
        XCTAssertEqual(snapshot.inboxCount, 2)
        XCTAssertNil(snapshot.planSummary)
    }

    func testThePlanIsReadFromTheDaysPlanSection() {
        let note = dailyNote(today, plan: "TB: 09:30-10:15 Swim\n\nTB: 11:00-12:00 Write the report")
        let snapshot = index([note]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.plan, [
            WidgetSnapshot.Span(title: "Swim", start: 570, end: 615),
            WidgetSnapshot.Span(title: "Write the report", start: 660, end: 720),
        ])
    }

    func testADayWithNoDailyNoteHasAnEmptyPlanAndNotANilOne() {
        // Nothing planned is an answer the widget says in words; nil would send him to open
        // the app for a file that is perfectly new.
        let snapshot = index([]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.plan, [])
        // The calendar was not handed in, so it is not shown: nil, never "no events".
        XCTAssertNil(snapshot.events)
    }

    func testAnotherDaysPlanIsNotThisDays() {
        let yesterday = DateOnly(year: 2026, month: 9, day: 14)
        let note = dailyNote(yesterday, plan: "TB: 09:30-10:15 Swim")
        let snapshot = index([note]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)
        XCTAssertEqual(snapshot.plan, [])
    }

    func testEventsAreHandedThroughAndKeepTheDifferenceBetweenNilAndEmpty() {
        let meeting = WidgetSnapshot.Span(title: "Meeting", start: 600, end: 660)
        let shown = index([]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0, events: [meeting])
        let none = index([]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0, events: [])
        XCTAssertEqual(shown.events, [meeting])
        XCTAssertEqual(none.events, [])
        XCTAssertFalse(none.sameContent(as: shown))
        XCTAssertFalse(none.sameContent(as: index([]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0)))
    }

    func testSpansAreCutToTheDay() {
        let early = WidgetSnapshot.Span(title: "From yesterday", start: -300, end: 90)
        XCTAssertEqual(early.start, 0)
        let late = WidgetSnapshot.Span(title: "Into tomorrow", start: 1400, end: 2000)
        XCTAssertEqual(late.end, 1440)
        let backwards = WidgetSnapshot.Span(title: "Odd", start: 600, end: 500)
        XCTAssertEqual(backwards.end, 600)
    }

    func testAPlanChangeIsAChangeAndTheFileRoundTripsWithPlanAndEvents() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paragon-widget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let swim = dailyNote(today, plan: "TB: 09:30-10:15 Swim")
        let moved = dailyNote(today, plan: "TB: 09:45-10:30 Swim")
        let before = index([swim]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0,
                                                  written: Date(timeIntervalSince1970: 1_000))
        let after = index([moved]).widgetSnapshot(on: today, inboxCount: 0, dueForReview: 0,
                                                  written: Date(timeIntervalSince1970: 1_000))
        // Build 271's "write only when something changed" has to see a block being moved.
        XCTAssertFalse(after.sameContent(as: before))

        let withEvents = index([swim]).widgetSnapshot(
            on: today, inboxCount: 0, dueForReview: 0,
            events: [WidgetSnapshot.Span(title: "Meeting", start: 600, end: 660)])
        try withEvents.write(toContainer: folder)
        let back = try XCTUnwrap(WidgetSnapshot.read(fromContainer: folder))
        XCTAssertEqual(back, withEvents)
        XCTAssertEqual(back.plan?.first?.title, "Swim")
        XCTAssertEqual(back.events?.first?.title, "Meeting")
    }

    func testWhatSettingsSaysAboutThePlanInTheFile() {
        let swim = WidgetSnapshot.Span(title: "Swim", start: 570, end: 615)
        let meeting = WidgetSnapshot.Span(title: "Meeting", start: 600, end: 660)
        func file(_ plan: [WidgetSnapshot.Span]?, _ events: [WidgetSnapshot.Span]?) -> WidgetSnapshot {
            WidgetSnapshot(day: today, written: Date(timeIntervalSince1970: 0), dueToday: 0, overdue: 0,
                           inboxCount: 0, dueForReview: 0, items: [], plan: plan, events: events)
        }
        XCTAssertEqual(file([swim, swim, swim], [meeting, meeting]).planSummary, "3 blocks \u{00B7} 2 events")
        XCTAssertEqual(file([swim, swim, swim], nil).planSummary, "3 blocks \u{00B7} Calendar not shown")
        XCTAssertEqual(file([swim], [meeting]).planSummary, "1 block \u{00B7} 1 event")
        // Never "0 blocks" and never "0 events" (build 141).
        XCTAssertEqual(file([], []).planSummary, "No blocks \u{00B7} No events")
        XCTAssertNil(file(nil, nil).planSummary)
    }

    func testOnlyThePlanLinkOpensThePlan() {
        let plan = URL(string: WidgetSnapshot.planLink)!
        XCTAssertTrue(WidgetSnapshot.opensPlan(plan))
        XCTAssertTrue(WidgetSnapshot.opensPlan(URL(string: "AMSPARA:///plan")!))
        // A note called Plan has the title as its host, so it can never be this link.
        XCTAssertFalse(WidgetSnapshot.opensPlan(URL(string: WidgetSnapshot.link(toNoteTitled: "Plan"))!))
        XCTAssertFalse(WidgetSnapshot.opensPlan(URL(string: "amspara://")!))
        XCTAssertFalse(WidgetSnapshot.opensPlan(URL(string: "amspara:///other")!))
        XCTAssertFalse(WidgetSnapshot.opensPlan(URL(string: "amspara://capture?text=hello")!))
        XCTAssertFalse(WidgetSnapshot.opensPlan(URL(string: "https://example.com/plan")!))
        // And the link is not a capture, so `handle(url:)` cannot take it for one.
        XCTAssertNil(CaptureItem(url: plan))
    }
}
