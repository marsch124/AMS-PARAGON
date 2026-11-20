import XCTest
@testable import ParagonCore

/// Round 350 (voice-controls): marking a moment, reading and changing a voice note's text, the
/// voice notes list, and taking a filed thought back.
final class VoiceControlsTests: XCTestCase {
    func testAMarkedSentenceIsBoldAndListed() {
        let said = "I need new screws. Call Anna about Saturday. Then the lake."
        // The mark came while "Call Anna about" was being said.
        let marked = VoiceMarks.marked(said, offsets: [30])
        XCTAssertEqual(marked.text, "I need new screws. **Call Anna about Saturday.** Then the lake.")
        XCTAssertEqual(marked.sentences, ["Call Anna about Saturday."])
        // In the gap after a full stop: the sentence before. Beyond the end: the last one.
        XCTAssertEqual(VoiceMarks.markedSentences(in: said, offsets: [18]), [0])
        XCTAssertEqual(VoiceMarks.markedSentences(in: said, offsets: [999, 5]), [0, 2])
        XCTAssertEqual(VoiceMarks.marked(said, offsets: []).text, said)

        let thought = VoiceThought(transcript: said, title: "Screws", summary: "S.", recordedAt: Date(), duration: 5)
        var withMark = thought
        withMark.marks = [30]
        let text = withMark.noteText(today: DateOnly(year: 2026, month: 11, day: 20))
        XCTAssertTrue(text.contains("**Call Anna about Saturday.**"))
        XCTAssertTrue(text.contains("## Marked\n\n- Call Anna about Saturday."))
        XCTAssertEqual(VoiceNoteText.fullText(of: text), said)
        XCTAssertFalse(thought.noteText(today: DateOnly(year: 2026, month: 11, day: 20)).contains("## Marked"))
    }

    func testAVoiceNoteTextCanBeReadAndChanged() {
        let thought = VoiceThought(transcript: "The drawer needs screws. Task: call Anna.", title: "Drawer", summary: "Screws are needed.",
                                   tasks: ["Order screws"], recordedAt: Date(), duration: 42)
        let text = thought.noteText(today: DateOnly(year: 2026, month: 11, day: 20))
        XCTAssertEqual(VoiceNoteText.summary(of: text), "Screws are needed.")
        XCTAssertEqual(VoiceNoteText.tasksListed(in: text), ["Call Anna", "Order screws"])

        let again = VoiceNoteText.settingSummary("The drawer is broken.", in: text)
        XCTAssertEqual(VoiceNoteText.summary(of: again ?? ""), "The drawer is broken.")
        let added = VoiceNoteText.addingTasks(["Order screws", "Buy glue"], to: again ?? text)
        XCTAssertEqual(added.added, ["Buy glue"])
        XCTAssertEqual(VoiceNoteText.tasksListed(in: added.text), ["Call Anna", "Order screws", "Buy glue"])

        let fewer = VoiceNoteText.removingTasks(["Order screws"], from: added.text)
        XCTAssertEqual(VoiceNoteText.tasksListed(in: fewer), ["Call Anna", "Buy glue"])
        let none = VoiceNoteText.removingTasks(["Call Anna", "Buy glue"], from: fewer)
        XCTAssertFalse(none.contains("## Tasks"))
        XCTAssertTrue(none.contains("## Full text"))

        XCTAssertEqual(VoiceNoteText.spoken(from: text), "Drawer. Screws are needed. 2 tasks.")
        XCTAssertEqual(VoiceNoteText.spoken(from: text, language: "de-DE"), "Drawer. Screws are needed. 2 Aufgaben.")
    }

    func testAFiledThoughtCanBeListedEditedAndThrownAway() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("paragon-voicecontrols-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try Vault(rootURL: root)

        let thought = VoiceThought(transcript: "The drawer needs new screws. Call Anna about Saturday.",
                                   title: "Drawer screws", summary: "The drawer needs screws.",
                                   tasks: ["Order drawer screws", "Call Anna about Saturday"],
                                   recordedAt: Date(), duration: 42)
        let filed = try vault.fileVoiceThoughtNote(thought, today: DateOnly(year: 2026, month: 11, day: 20))
        let record = VoiceFiled(path: filed.path, title: filed.title, toToday: false, day: "2026-11-20",
                                tasks: thought.finalTasks, duration: 42, locale: "en-US", madeAt: Date(), checked: false)

        let rows = VoiceNoteList.rows(from: try vault.allNotes())
        XCTAssertEqual(rows.map(\.title), ["Drawer screws"])
        XCTAssertEqual(rows.first?.length, "0:42")
        XCTAssertEqual(rows.first?.firstWords, "The drawer needs screws.")
        XCTAssertEqual(VoiceNoteList.matching(rows, "SCREWS drawer").count, 1)
        XCTAssertEqual(VoiceNoteList.matching(rows, "lake").count, 0)

        // Check card: one task is not wanted.
        XCTAssertEqual(try vault.dropVoiceTasks(record, titles: ["Order drawer screws"]), 1)
        XCTAssertEqual(try vault.inboxNote().openTasks.map(\.title), ["Call Anna about Saturday"])
        let note = try vault.loadNote(relativePath: filed.path)
        XCTAssertEqual(VoiceNoteText.tasksListed(in: note.text), ["Call Anna about Saturday"])

        // Write it up again: only missing tasks are added, nothing is taken out.
        let added = try vault.rewriteVoiceNote(path: filed.path, summary: "A new summary.", tasks: ["Call Anna about Saturday", "Buy glue"])
        XCTAssertEqual(added, ["Buy glue"])
        XCTAssertEqual(VoiceNoteText.summary(of: try vault.loadNote(relativePath: filed.path).text), "A new summary.")

        // Throw away: the note goes to Deleted, the open tasks and the line leave the Inbox.
        let gone = try vault.discardVoiceThought(record)
        XCTAssertTrue(gone.noteRemoved)
        XCTAssertFalse(CloudFiles.exists(vault.url(for: filed.path)))
        let inbox = try vault.inboxNote()
        XCTAssertFalse(inbox.text.contains("[[Drawer screws]]"))
        XCTAssertEqual(inbox.openTasks.map(\.title), ["Buy glue"])

        let list = VoiceHistory.adding(record, to: [])
        XCTAssertEqual(VoiceHistory.nextToCheck(in: list)?.path, filed.path)
        XCTAssertTrue(VoiceHistory.removing(path: filed.path, from: list).isEmpty)
    }
}
