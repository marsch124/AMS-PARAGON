import XCTest
@testable import ParagonCore

/// Round 350 (voice-words): what he says out loud that means more than words.
final class VoiceWordsTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Friday 20 November 2026.
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour, minute: minute))!
    }

    private func first(_ said: String, now: Date) -> SpokenTask? {
        VoiceThought.spokenTaskItems(in: said, now: now, calendar: cal).first
    }

    func testDaysAndTimesBecomeTaskDates() {
        let now = at(10)
        XCTAssertEqual(first("Task call the bank on Friday.", now: now),
                       SpokenTask(title: "Call the bank", date: DateOnly(year: 2026, month: 11, day: 27)))
        XCTAssertEqual(first("Task call the bank tomorrow.", now: now)?.date, DateOnly(year: 2026, month: 11, day: 21))
        XCTAssertEqual(first("Task email Lisa next Monday.", now: now)?.date, DateOnly(year: 2026, month: 11, day: 23))
        XCTAssertEqual(first("Task pay the rent on the 25th.", now: now)?.date, DateOnly(year: 2026, month: 11, day: 25))
        XCTAssertEqual(first("Task pay the rent on the 12th.", now: now)?.date, DateOnly(year: 2026, month: 12, day: 12))
        XCTAssertEqual(first("Uppgift ring banken på måndag.", now: now),
                       SpokenTask(title: "Ring banken", date: DateOnly(year: 2026, month: 11, day: 23)))
        // A weekday with no word before it is just words.
        XCTAssertEqual(first("Task call Anna about Saturday.", now: now),
                       SpokenTask(title: "Call Anna about Saturday"))
    }

    /// Round 352: the German "am 25." is the 25th — only when German is spoken.
    func testTheGermanDayWithADotIsADateOnlyInGerman() {
        let now = at(10)
        let german = VoiceThought.spokenTaskItems(in: "Aufgabe Miete zahlen am 25.", now: now, calendar: cal, german: true)
        XCTAssertEqual(german.first, SpokenTask(title: "Miete zahlen", date: DateOnly(year: 2026, month: 11, day: 25)))
        // A day already past this month is next month's.
        XCTAssertEqual(VoiceThought.spokenTaskItems(in: "Aufgabe Arzt anrufen am 12.", now: now, calendar: cal, german: true).first?.date,
                       DateOnly(year: 2026, month: 12, day: 12))
        // "am 25.11" is not read as the 25th (the month after it is not understood).
        XCTAssertNil(VoiceThought.spokenTaskItems(in: "Aufgabe Miete zahlen am 25.11 bitte.", now: now, calendar: cal, german: true).first?.date)
        // Not German: "am 25." is words, never a date.
        XCTAssertNil(VoiceThought.spokenTaskItems(in: "Task tell them I am 25.", now: now, calendar: cal).first?.date)
        XCTAssertNil(VoiceThought.spokenTaskItems(in: "Aufgabe Miete zahlen am 25.", now: now, calendar: cal).first?.date)
        // Through the thought: the language decides, and the Inbox line carries the day.
        var thought = VoiceThought(transcript: "Aufgabe Miete zahlen am 25.", recordedAt: now, duration: 0)
        thought.language = "de-DE"
        XCTAssertTrue(thought.speaksGerman)
        let items = thought.finalTaskItems(calendar: cal)
        XCTAssertEqual(items.map { $0.title }, ["Miete zahlen"])
        XCTAssertEqual(items.first?.dueDate, DateOnly(year: 2026, month: 11, day: 25))
        thought.language = "en-US"
        XCTAssertFalse(thought.speaksGerman)
        XCTAssertNil(thought.finalTaskItems(calendar: cal).first?.dueDate)
    }

    /// Diagnostic for the Swedish time (CI said "Klockan 14" was not read).
    func testTheSwedishClockIsFound() {
        let said = "Påminn mig klockan 14 att ringa Anna."
        let found = SpokenWhen.findTime(in: said)
        XCTAssertNotNil(found, "findTime found nothing in: \(said)")
        let got = SpokenWhen.extract(from: said, now: at(10), calendar: cal)
        XCTAssertEqual(got.time, TimeOfDay(hour: 14, minute: 0), "extract gave text '\(got.text)', date \(String(describing: got.date))")
        let prepared = VoiceThought.sentencesOf(VoiceThought.clean(VoiceWords.prepared(said)))
        XCTAssertEqual(prepared, [said], "the sentences were: \(prepared)")
    }

    func testSpokenTimesBecomeReminders() {
        let today = DateOnly(year: 2026, month: 11, day: 20)
        XCTAssertEqual(first("Remind me at 3 to call Anna.", now: at(10)),
                       SpokenTask(title: "Call Anna", date: today, time: TimeOfDay(hour: 15, minute: 0)))
        // Both 3:00 and 15:00 have passed: tomorrow 3:00.
        XCTAssertEqual(first("Remind me at 3 to call Anna.", now: at(16)),
                       SpokenTask(title: "Call Anna", date: DateOnly(year: 2026, month: 11, day: 21), time: TimeOfDay(hour: 3, minute: 0)))
        XCTAssertEqual(first("Erinnere mich um 15 Uhr daran, Anna anzurufen.", now: at(10)),
                       SpokenTask(title: "Anna anzurufen", date: today, time: TimeOfDay(hour: 15, minute: 0)))
        XCTAssertEqual(first("Påminn mig klockan 14 att ringa Anna.", now: at(10)),
                       SpokenTask(title: "Ringa Anna", date: today, time: TimeOfDay(hour: 14, minute: 0)))
        XCTAssertEqual(first("Task call Anna tomorrow at 3 pm.", now: at(10)),
                       SpokenTask(title: "Call Anna", date: DateOnly(year: 2026, month: 11, day: 21), time: TimeOfDay(hour: 15, minute: 0)))
        let thought = VoiceThought(transcript: "Remind me at 3 to call Anna.", recordedAt: at(10), duration: 0)
        let items = thought.finalTaskItems(calendar: cal)
        XCTAssertEqual(items.map { $0.title }, ["Call Anna"])
        XCTAssertTrue(items[0].serialized.contains(">2026-11-20T15:00"), items[0].serialized)
    }

    func testTitleTagsAndIdeasAreTakenOutOfTheWords() {
        let said = "Title Garden plan. Tag garden. The beds need work. Idea build a cold frame. "
            + "Tag Wasser, then water the beds. Stop recording."
        let r = VoiceWords.read(said)
        XCTAssertEqual(r.title, "Garden plan")
        XCTAssertEqual(r.tags, ["garden", "Wasser"])
        XCTAssertEqual(r.ideas, ["Build a cold frame"])
        XCTAssertEqual(r.text, "The beds need work. Idea build a cold frame. Then water the beds.")

        var thought = VoiceThought(transcript: said, title: "Model title", summary: "About beds.", recordedAt: at(10), duration: 30)
        thought.readWords()
        XCTAssertEqual(thought.finalTitle, "Garden plan")
        let note = thought.noteText(today: DateOnly(year: 2026, month: 11, day: 20))
        XCTAssertTrue(note.contains("tags: [voice, garden, Wasser]"), note)
        XCTAssertTrue(note.contains("## Ideas\n\n- Build a cold frame\n\n## Full text"), note)
        // A late summary puts the tasks above the ideas.
        thought.summary = nil
        thought.summaryPending = true
        let pending = thought.noteText(today: DateOnly(year: 2026, month: 11, day: 20))
        let later = VoiceThought.enriched(pending, summary: "About beds.", tasks: ["Sweep the porch"])
        XCTAssertTrue(later?.contains("## Tasks\n\n- Sweep the porch\n\n## Ideas") == true, later ?? "nil")
    }

    func testStopPhraseAndWordsItMishears() {
        XCTAssertEqual(VoiceWords.removingStopPhrase(from: "Buy milk. Stop recording."), "Buy milk.")
        XCTAssertEqual(VoiceWords.removingStopPhrase(from: "Aufnahme beenden"), "")
        XCTAssertNil(VoiceWords.removingStopPhrase(from: "I will stop recording music now"))
        let list = [VoiceReplacement(word: "PARAGON", heardAs: "para gone, paragone"), VoiceReplacement(word: "iCloud")]
        XCTAssertEqual(VoiceWords.applyingReplacements("open para gone and Paragone with icloud", list),
                       "open PARAGON and PARAGON with iCloud")
        XCTAssertEqual(VoiceReplacement.decode(VoiceReplacement.encode(list)), list)
        XCTAssertEqual(VoiceWords.contextualWords(list), ["PARAGON", "iCloud"])
        XCTAssertTrue(VoiceWords.offersEnglishSummary(voiceLanguage: "sv-SE", phoneLanguageCode: "en"))
        XCTAssertTrue(VoiceWords.offersEnglishSummary(voiceLanguage: "", phoneLanguageCode: "sv"))
        XCTAssertFalse(VoiceWords.offersEnglishSummary(voiceLanguage: "de-DE", phoneLanguageCode: "sv"))
    }

    func testNamesBecomeLinksAndLongThoughtsGetHeadings() {
        XCTAssertEqual(VoiceWords.linking("Met Anna about the Garden Plan, and the garden plan again.", titles: ["Garden Plan", "Ann"]),
                       "Met Anna about the [[Garden Plan]], and the garden plan again.")
        XCTAssertEqual(VoiceWords.linking("see garden plan", titles: ["Garden Plan"]), "see [[Garden Plan|garden plan]]")

        let sentence = String(repeating: "word ", count: 50) + "end."
        let text = Array(repeating: sentence, count: 15).joined(separator: " ")
        let chunks = VoiceChapters.chunks(of: text)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks.joined(separator: " "), text)
        let chapters = VoiceChapters.chapters(chunks: chunks, headings: ["Start", nil, "End"])
        XCTAssertEqual(chapters.map { $0.heading }, ["Start", "End"])
        XCTAssertTrue(VoiceChapters.markdown(chapters, linking: []).hasPrefix("### Start\n\n"))
        XCTAssertTrue(VoiceChapters.isLong(duration: 241, transcript: "short"))
        XCTAssertFalse(VoiceChapters.isLong(duration: 100, transcript: "short"))
    }
}
