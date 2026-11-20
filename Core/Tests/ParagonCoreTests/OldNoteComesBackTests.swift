import XCTest
@testable import ParagonCore

final class OldNoteComesBackTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 11, day: 20)

    private func resource(_ name: String, daysOld: Int?, body: String = "Some words") -> Note {
        var note = Note(relativePath: "Resources/\(name).md", kind: .resource,
                        text: "---\ntitle: \(name)\n---\n# \(name)\n\n\(body)")
        if let daysOld {
            note.modifiedAt = Calendar.current.date(byAdding: .day, value: -daysOld, to: today.date() ?? Date())
        }
        return note
    }

    func testOnlyOldResourcesComeBackAndTheChoiceIsSteadyForTheDay() {
        let notes = [
            resource("Alpha", daysOld: 40),
            resource("Beta", daysOld: 31),
            resource("Fresh", daysOld: 5),
            resource("Unknown", daysOld: nil),
        ]
        let index = NoteIndex(notes: notes)
        let found = OldNoteComesBack.candidates(in: index, today: today).map(\.displayTitle)
        XCTAssertEqual(found, ["Alpha", "Beta"])

        let a = OldNoteComesBack.pick(in: index, today: today)
        XCTAssertEqual(OldNoteComesBack.pick(in: index, today: today)?.relativePath, a?.relativePath)
        // The next day shows the other one.
        let b = OldNoteComesBack.pick(in: index, today: today.adding(days: 1))
        XCTAssertNotEqual(a?.relativePath, b?.relativePath)

        XCTAssertNil(OldNoteComesBack.pick(in: NoteIndex(notes: [notes[2]]), today: today))
    }

    func testTheFirstLineIsPlainWords() {
        let note = resource("Idea", daysOld: 40, body: "- [ ] **Try** the new cable #gear\nSecond line")
        XCTAssertEqual(OldNoteComesBack.firstLine(of: note), "**Try** the new cable #gear")
        let empty = resource("Empty", daysOld: 40, body: "")
        XCTAssertNil(OldNoteComesBack.firstLine(of: empty))
    }
}
