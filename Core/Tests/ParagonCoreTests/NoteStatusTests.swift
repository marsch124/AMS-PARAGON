import XCTest
@testable import ParagonCore

/// Build 165. The vocabulary he chose — **Done**, **Missed**, **Dropped** — and the promise
/// that goes with it: a note written before this build still reads exactly as it did.
final class NoteStatusTests: XCTestCase {

    func testEveryOlderSpellingStillReads() {
        // These are what vaults already hold. None of them may change meaning, ever.
        XCTAssertEqual(NoteStatus(reading: "done"), .done)
        XCTAssertEqual(NoteStatus(reading: "completed"), .done)
        XCTAssertEqual(NoteStatus(reading: "achieved"), .done)
        XCTAssertEqual(NoteStatus(reading: "on-hold"), .onHold)
        XCTAssertEqual(NoteStatus(reading: "onhold"), .onHold)
        XCTAssertEqual(NoteStatus(reading: "on hold"), .onHold)
        XCTAssertEqual(NoteStatus(reading: "paused"), .onHold)
        XCTAssertEqual(NoteStatus(reading: "someday"), .onHold)
        XCTAssertEqual(NoteStatus(reading: "archived"), .archived)
        // Nothing written is active, and so is a word nobody recognises.
        XCTAssertEqual(NoteStatus(reading: nil), .active)
        XCTAssertEqual(NoteStatus(reading: ""), .active)
        XCTAssertEqual(NoteStatus(reading: "wibble"), .active)
        // Case and stray spaces are his typing, not a different state.
        XCTAssertEqual(NoteStatus(reading: " Done "), .done)
        XCTAssertEqual(NoteStatus(reading: "DROPPED"), .dropped)
    }

    func testEndedIsNotTheSameAsDelivered() {
        XCTAssertTrue(NoteStatus.done.isEnded)
        XCTAssertTrue(NoteStatus.missed.isEnded)
        XCTAssertTrue(NoteStatus.dropped.isEnded)
        XCTAssertFalse(NoteStatus.active.isEnded)
        XCTAssertFalse(NoteStatus.onHold.isEnded)

        // The whole point of the build: three ways to end, one way to deliver.
        XCTAssertTrue(NoteStatus.done.isDelivered)
        XCTAssertFalse(NoteStatus.missed.isDelivered)
        XCTAssertFalse(NoteStatus.dropped.isDelivered)
    }

    func testTheMenuOffersTheThreeEndingsInOrder() {
        XCTAssertEqual(NoteStatus.endings, [.done, .missed, .dropped])
        XCTAssertEqual(NoteStatus.endings.map(\.label), ["Done", "Missed", "Dropped"])
        // Every case says what it means, or a new word is a guess.
        for status in NoteStatus.allCases {
            XCTAssertFalse(status.label.isEmpty)
            XCTAssertFalse(status.meaning.isEmpty)
        }
        // `on-hold` is what the file says; "On hold" is what a person reads.
        XCTAssertEqual(NoteStatus.onHold.rawValue, "on-hold")
        XCTAssertEqual(NoteStatus.onHold.label, "On hold")
    }

    func testANoteReadsItsOwnStatus() {
        let dropped = Note(relativePath: "Projects/Tuba.md", kind: .project,
                           text: "---\ntitle: Learn the tuba\nstatus: dropped\n---\n")
        XCTAssertEqual(dropped.noteStatus, .dropped)
        XCTAssertTrue(dropped.isEnded)
        XCTAssertFalse(dropped.isAchieved)
        // And it is not a finished project, so a goal never counts it as delivered.
        XCTAssertFalse(dropped.isFinishedProject)

        let done = Note(relativePath: "Projects/Electrics.md", kind: .project,
                        text: "---\ntitle: Electrics\nstatus: achieved\n---\n")
        XCTAssertTrue(done.isAchieved)
        XCTAssertTrue(done.isFinishedProject)

        let plain = Note(relativePath: "Projects/Kitchen.md", kind: .project, text: "# Kitchen\n")
        XCTAssertEqual(plain.noteStatus, .active)
        XCTAssertFalse(plain.isEnded)
    }
}
