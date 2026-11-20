import XCTest
@testable import ParagonCore

/// Round 350: a place on a task (`@place`), a person on a task or note (`@person`, `people:`).
final class PlacePeopleTests: XCTestCase {
    func testAPlaceRoundTripsAndStaysOutOfTheTitle() throws {
        let line = "- [ ] Buy milk >2026-11-20 @place(Home|59.32940,18.06860|arrive) ^t0a1b2c"
        let task = try XCTUnwrap(TaskParser.parse(line: line))
        XCTAssertEqual(task.title, "Buy milk")
        let place = try XCTUnwrap(task.place)
        XCTAssertEqual(place.name, "Home")
        XCTAssertTrue(place.arriving)
        XCTAssertEqual(place.latitude, 59.3294, accuracy: 0.00001)
        XCTAssertEqual(task.serialized, line)
        XCTAssertEqual(TaskParser.parse(line: "- [ ] Return the drill @place(Shop|59.1,18.1|leave)")?.place?.arriving, false)
    }

    func testAPlaceNameCannotBreakTheLine() {
        let place = ReminderPlace(name: "Cafe (Main) | North", latitude: 1, longitude: 2)
        XCTAssertEqual(place.name, "Cafe Main North")
        let task = TaskItem(title: "Meet", place: place)
        XCTAssertEqual(TaskParser.parse(line: task.serialized)?.place, place)
    }

    func testAPlaceThisBuildCannotReadIsKeptAsWritten() throws {
        let line = "- [ ] Water the plants @place(somewhere new)"
        let task = try XCTUnwrap(TaskParser.parse(line: line))
        XCTAssertNil(task.place)
        XCTAssertEqual(task.title, "Water the plants")
        XCTAssertEqual(task.serialized, line)
    }

    func testAPersonRoundTripsAndStaysOutOfTheTitle() throws {
        let line = "- [ ] Send the quote @person(Anna Svensson)"
        let task = try XCTUnwrap(TaskParser.parse(line: line))
        XCTAssertEqual(task.title, "Send the quote")
        XCTAssertEqual(task.person, "Anna Svensson")
        XCTAssertEqual(task.serialized, line)
        XCTAssertEqual(PersonName.clean("  Anna (work) "), "Anna work")
        XCTAssertNil(PersonName.clean(" () "))
    }

    func testAPlaceChangesTheSyncFingerprintOnlyWhenThereIsOne() {
        let plain = TaskItem(title: "Buy milk")
        let placed = TaskItem(title: "Buy milk", place: ReminderPlace(name: "Home", latitude: 59.3, longitude: 18.0))
        XCTAssertFalse(SyncEngine.fingerprint(plain).contains("@"))
        XCTAssertNotEqual(SyncEngine.fingerprint(plain), SyncEngine.fingerprint(placed))
        let record = ReminderRecord(listName: "Home", title: "Buy milk", place: placed.place)
        XCTAssertEqual(SyncEngine.fingerprint(placed), SyncEngine.fingerprint(record))
    }

    func testPeopleAreListedWithTheirTasksAndNotes() throws {
        let one = Note(relativePath: "Projects/Quote.md", kind: .project, text: """
        ---
        people: [Anna Svensson]
        ---
        # Quote
        - [ ] Send the quote @person(Anna Svensson) >2026-11-25
        - [x] Call back @person(anna svensson)
        - [ ] Book the room @person(Bo Berg)
        """)
        let index = NoteIndex(notes: [one])
        let people = index.people()
        XCTAssertEqual(people.map(\.name), ["Anna Svensson", "Bo Berg"])
        let anna = try XCTUnwrap(people.first)
        XCTAssertEqual(anna.open.count, 1)
        XCTAssertEqual(anna.finishedCount, 1)
        XCTAssertEqual(anna.notes.count, 1)
        XCTAssertEqual(anna.summary, "1 open \u{00b7} 1 done \u{00b7} 1 note")
    }

    func testSettingPeopleOnANoteKeepsEachNameOnce() {
        let note = Note(relativePath: "Projects/Quote.md", kind: .project, text: "# Quote\n")
        let updated = note.settingPeople(["Anna Svensson", "anna svensson", "Bo Berg"])
        XCTAssertEqual(updated.people, ["Anna Svensson", "Bo Berg"])
    }
}
