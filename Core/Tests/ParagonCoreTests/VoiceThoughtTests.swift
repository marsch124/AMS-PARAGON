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

    // Build 349: saying "task" makes the sentence a task.
    func testSayingTaskMakesTheSentenceATask() {
        let said = "I was thinking about the weekend. Task: call Anna about Saturday. The boat is fine. "
            + "Task. Order new drawer screws! New task buy milk and bread? Aufgabe, Reifen wechseln. "
            + "This task is hard. Uppgift ring mamma. Task."
        XCTAssertEqual(VoiceThought.spokenTasks(in: said),
                       ["Call Anna about Saturday", "Order new drawer screws", "Buy milk and bread", "Reifen wechseln", "Ring mamma"])
        XCTAssertEqual(VoiceThought.spokenTasks(in: "Taskbar is broken. Tasks are many."), [])
        let long = "Task " + Array(repeating: "word", count: 40).joined(separator: " ")
        XCTAssertEqual(VoiceThought.spokenTasks(in: long).first?.split(separator: " ").count, VoiceThought.longestSpokenTask)

        // Spoken ones first; the model's that say the same (or less) are left out.
        let thought = VoiceThought(transcript: "Task: call Anna. Then the garden.",
                                   tasks: ["Call Anna about Saturday", "Weed the garden", "Shop"], recordedAt: Date(), duration: 9)
        XCTAssertEqual(thought.finalTasks, ["Call Anna", "Weed the garden", "Shop"])
        XCTAssertEqual(VoiceThought.lateTasks(transcript: "Task: call Anna.", modelTasks: ["Call Anna about Saturday", "Shopping list"]),
                       ["Shopping list"])
        // A late summary adds the model's tasks under the spoken ones.
        let note = thought.noteText(today: .today()).replacingOccurrences(of: "No summary: Apple Intelligence was not available on this phone.",
                                                                          with: VoiceThought.pendingLine)
        let later = VoiceThought.enriched(note, summary: "About Anna.", tasks: ["Sweep the porch"])!
        XCTAssertTrue(later.contains("## Tasks\n\n- Call Anna\n- Weed the garden\n- Shop\n- Sweep the porch\n\n## Full text"), later)
    }

    // Build 349: Today on the Lock Screen files into today's note, not the Inbox.
    func testAThoughtCanGoIntoTodaysNote() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("paragon-voice-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = try Vault(rootURL: root)
        let day = DateOnly.today()
        let inboxBefore = try vault.inboxNote().text
        let thought = VoiceThought(transcript: "Task: call Anna. The garden needs work.", title: "Anna and the garden",
                                   tasks: ["Weed the garden"], recordedAt: Date(), duration: 12)
        let filed = try vault.fileVoiceThoughtNote(thought, today: day, into: .today)
        let daily = try vault.dailyNote(for: day).text
        XCTAssertTrue(daily.contains("- [ ] Call Anna"), daily)
        XCTAssertTrue(daily.contains("- [ ] Weed the garden"), daily)
        XCTAssertTrue(daily.contains("[[Anna and the garden]] — voice note, 0:12"), daily)
        XCTAssertEqual(try vault.inboxNote().text, inboxBefore)
        XCTAssertTrue(filed.path.hasSuffix("Anna and the garden.md"))

        // Its late tasks go to that day's note too.
        var note = try vault.loadNote(relativePath: filed.path)
        note.text = note.text.replacingOccurrences(of: "No summary: Apple Intelligence was not available on this phone.", with: VoiceThought.pendingLine)
        try vault.save(note)
        XCTAssertTrue(try vault.addLateVoiceSummary(path: filed.path, summary: "Anna.", tasks: ["Sweep the porch"], intoDay: day))
        XCTAssertTrue(try vault.dailyNote(for: day).text.contains("- [ ] Sweep the porch"))
        XCTAssertEqual(try vault.inboxNote().text, inboxBefore)
    }
}
