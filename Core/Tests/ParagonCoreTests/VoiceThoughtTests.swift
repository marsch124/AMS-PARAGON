import XCTest
@testable import ParagonCore

final class VoiceThoughtTests: XCTestCase {
    func testWordsForTheLockScreenAndTheNote() {
        XCTAssertEqual(VoiceThought.clock(42.9), "0:42")
        XCTAssertEqual(VoiceThought.clock(725), "12:05")
        XCTAssertEqual(VoiceThought.clock(3723), "1:02:03")
        XCTAssertEqual(VoiceThought.fallbackTitle(from: "  the drawer needs new screws, I should order them tonight"),
                       "The drawer needs new screws, I")
        XCTAssertEqual(VoiceThought.fallbackTitle(from: " … "), "Voice note")
        let tail = VoiceThought.liveTail(String(repeating: "word ", count: 40), limit: 20)
        XCTAssertTrue(tail.hasPrefix("…word"))
        XCTAssertLessThanOrEqual(tail.count, 21)
        XCTAssertEqual(VoiceThought.liveTail("short words"), "short words")

        let thought = VoiceThought(transcript: "x", title: " Drawer: screws [and] Saturday. ",
                                   tasks: ["- [ ] Order drawer screws.", "order drawer screws", "  ", "• Call Anna about Saturday"],
                                   recordedAt: Date(), duration: 42)
        XCTAssertEqual(thought.finalTitle, "Drawer screws and Saturday")
        XCTAssertEqual(thought.finalTasks, ["Order drawer screws", "Call Anna about Saturday"])
        XCTAssertTrue(VoiceThought(transcript: " ... ", recordedAt: Date(), duration: 3).isEmpty)
        XCTAssertEqual(VoiceThought.link(inInboxLine: "[[Drawer screws]] — voice note, 0:42")?.title, "Drawer screws")
        XCTAssertEqual(VoiceThought.link(inInboxLine: "[[Drawer screws]] — voice note, 0:42")?.rest, "voice note, 0:42")
        XCTAssertNil(VoiceThought.link(inInboxLine: "Idea for the boat [[Boat]]"))
    }

    func testAThoughtIsFiledAsANoteAndInboxLines() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("paragon-voice-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try Vault(rootURL: root)

        let thought = VoiceThought(transcript: "The drawer needs new screws. Call Anna about Saturday.",
                                   title: "Drawer screws and Saturday", summary: "The drawer needs screws. Saturday is open.",
                                   tasks: ["Order drawer screws", "Call Anna about Saturday"],
                                   recordedAt: Date(), duration: 42)
        let title = try vault.fileVoiceThought(thought)
        XCTAssertEqual(title, "Drawer screws and Saturday")

        let note = try vault.loadNote(relativePath: "Resources/Drawer screws and Saturday.md")
        XCTAssertEqual(note.kind, .resource)
        XCTAssertTrue(note.text.contains("source: voice"))
        XCTAssertTrue(note.text.contains("## Summary\n\nThe drawer needs screws. Saturday is open."))
        XCTAssertTrue(note.text.contains("## Tasks\n\n- Order drawer screws\n- Call Anna about Saturday"))
        XCTAssertTrue(note.text.contains("## Full text\n\nThe drawer needs new screws. Call Anna about Saturday."))

        let inbox = try vault.inboxNote()
        XCTAssertEqual(inbox.tasks.map(\.title), ["Order drawer screws", "Call Anna about Saturday"])
        XCTAssertTrue(inbox.text.contains("## Notes\n- [[Drawer screws and Saturday]] — voice note, 0:42"))
        XCTAssertEqual(InboxNotes.lines(in: inbox.text).map(\.text), ["[[Drawer screws and Saturday]] — voice note, 0:42"])

        // Without the on-device model: the first words are the title, no tasks, one plain line.
        let plain = try vault.fileVoiceThought(VoiceThought(transcript: "buy more coffee beans soon please today ok",
                                                            recordedAt: Date(), duration: 5))
        XCTAssertEqual(plain, "Buy more coffee beans soon please")
        XCTAssertTrue(try vault.loadNote(relativePath: "Resources/\(plain).md").text.contains("No summary"))

        // The summary came too late: the note waits for it, and gets it next time.
        var late = VoiceThought(transcript: "paint the fence before winter comes back", recordedAt: Date(), duration: 9)
        late.summaryPending = true
        let filed = try vault.fileVoiceThoughtNote(late)
        XCTAssertTrue(try vault.loadNote(relativePath: filed.path).text.contains(VoiceThought.pendingLine))
        XCTAssertTrue(try vault.addLateVoiceSummary(path: filed.path, summary: "The fence needs paint.", tasks: ["Paint the fence"]))
        let done = try vault.loadNote(relativePath: filed.path).text
        XCTAssertTrue(done.contains("## Summary\n\nThe fence needs paint.\n\n## Tasks\n\n- Paint the fence\n\n## Full text"))
        XCTAssertTrue(try vault.inboxNote().tasks.map(\.title).contains("Paint the fence"))
        XCTAssertFalse(try vault.addLateVoiceSummary(path: filed.path, summary: "Again", tasks: []))

        // Nothing heard: nothing written.
        XCTAssertThrowsError(try vault.fileVoiceThought(VoiceThought(transcript: "  ", recordedAt: Date(), duration: 2)))
    }
}
