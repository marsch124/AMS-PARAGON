import XCTest
@testable import ParagonCore

final class OneThingWhyTests: XCTestCase {
    private func goal(_ title: String, life: Bool, goal: String? = nil, why: String? = nil) -> Note {
        var text = "---\ntitle: \(title)\ntype: goal\nhorizon: \(life ? "life" : "year")\n"
        if let goal { text += "goal: \(goal)\n" }
        text += "---\n# \(title)\n"
        if let why { text += "\n## Why\n\n\(why)\n" }
        return Note(relativePath: "Goals/\(title).md", kind: .goal, text: text)
    }

    func testReasonFoundThroughProjectAndGoalAndNilWhenThereIsNone() {
        let asp = goal("Strong at seventy", life: true, why: "  Still walking the fells at 80.  ")
        let dated = goal("Kungsleden", life: false, goal: "Strong at seventy")
        let trip = Note(relativePath: "Projects/Trip.md", kind: .project, text: "---\ngoal: Kungsleden\n---\n")
        let loose = Note(relativePath: "Projects/Loose.md", kind: .project, text: "---\ntitle: Loose\n---\n")
        let index = NoteIndex(notes: [asp, dated, trip, loose])
        XCTAssertEqual(OneThingWhy.reason(forNotePath: trip.relativePath, in: index), "Still walking the fells at 80.")
        XCTAssertEqual(OneThingWhy.reason(forNotePath: dated.relativePath, in: index), "Still walking the fells at 80.")
        XCTAssertEqual(OneThingWhy.reason(forNotePath: asp.relativePath, in: index), "Still walking the fells at 80.")
        XCTAssertNil(OneThingWhy.reason(forNotePath: loose.relativePath, in: index))
    }

    func testEmptyReasonIsNil() {
        let asp = goal("Strong at seventy", life: true, why: "   ")
        let trip = Note(relativePath: "Projects/Trip.md", kind: .project, text: "---\ngoal: Strong at seventy\n---\n")
        XCTAssertNil(OneThingWhy.reason(forNotePath: trip.relativePath, in: NoteIndex(notes: [asp, trip])))
    }
}
