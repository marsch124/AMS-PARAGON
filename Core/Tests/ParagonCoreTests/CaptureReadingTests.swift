import XCTest
@testable import ParagonCore

/// What the capture screen shows back has to be what the note will hold. These pin that the
/// read-back comes from the task parser and not from a second, looser one of its own.
final class CaptureReadingTests: XCTestCase {
    private let today = DateOnly(year: 2026, month: 9, day: 13)

    func testReadsTheDatePriorityAndTagsOutOfOneLine() {
        let reading = CaptureReading(line: "Ring Anna about the Granden trip >2026-09-15 !! #travel")
        XCTAssertEqual(reading.dueDate, DateOnly(year: 2026, month: 9, day: 15))
        XCTAssertEqual(reading.priority, 2)
        XCTAssertEqual(reading.priorityMarks, "!!")
        XCTAssertEqual(reading.tags, ["travel"])
        XCTAssertFalse(reading.isPlain)
    }

    func testAPlainLineHasNothingToShowBack() {
        let reading = CaptureReading(line: "Buy milk")
        XCTAssertTrue(reading.isPlain)
        XCTAssertNil(reading.priorityMarks)
        XCTAssertNil(reading.dueDate)
        XCTAssertEqual(reading.title, "Buy milk")
    }

    func testAnEmptyLineIsPlainAndDoesNotCrash() {
        let reading = CaptureReading(line: "   ")
        XCTAssertTrue(reading.isPlain)
        XCTAssertEqual(reading.title, "")
    }

    func testATimeOnTheDateIsRead() {
        let reading = CaptureReading(line: "Call the dentist >2026-09-15T14:30")
        XCTAssertEqual(reading.dueDate, DateOnly(year: 2026, month: 9, day: 15))
        XCTAssertNotNil(reading.dueTime)
    }

    func testNearnessNamesTodayTomorrowAndYesterday() {
        XCTAssertEqual(CaptureReading(line: "x >2026-09-13").nearness(to: today), .today)
        XCTAssertEqual(CaptureReading(line: "x >2026-09-14").nearness(to: today), .tomorrow)
        XCTAssertEqual(CaptureReading(line: "x >2026-09-12").nearness(to: today), .yesterday)
        XCTAssertEqual(CaptureReading(line: "x >2026-12-24").nearness(to: today), .other)
        XCTAssertNil(CaptureReading(line: "x").nearness(to: today))
    }

    func testTheReadingMatchesWhatTheCaptureWillWrite() {
        // The chips must agree with the vault, so the reading is taken from `lineText` — the
        // very string the capture puts in the note.
        let item = CaptureItem(text: "Book the ferry >2026-09-20 !!! #travel", target: .inbox)
        let reading = item.reading
        XCTAssertEqual(reading.dueDate, DateOnly(year: 2026, month: 9, day: 20))
        XCTAssertEqual(reading.priorityMarks, "!!!")
        XCTAssertEqual(reading.tags, ["travel"])
    }

    // MARK: Writing the tags back into the line (build 188)

    func testSettingTagsReplacesEveryTagAndKeepsTheRest() {
        let line = CaptureReading.line("Book the ferry >2026-09-15 !! #summer", settingTags: ["travel", "waiting"])
        XCTAssertEqual(line, "Book the ferry >2026-09-15 !! #travel #waiting")
        XCTAssertEqual(CaptureReading(line: line).tags, ["travel", "waiting"])
        XCTAssertEqual(CaptureReading(line: line).priority, 2)
        XCTAssertEqual(CaptureReading(line: line).dueDate, DateOnly("2026-09-15"))
    }

    func testSettingNoTagsTakesThemAllOutAndTidiesTheGap() {
        XCTAssertEqual(CaptureReading.line("Book  #travel the ferry #summer", settingTags: []),
                       "Book the ferry")
    }

    func testTagsAreTidiedAndNotDuplicatedByCase() {
        XCTAssertEqual(CaptureReading.line("Call the bank", settingTags: ["#Travel", "travel", "two words"]),
                       "Call the bank #Travel #two-words")
    }

    func testAHashGluedToAWordIsNotATagAndIsLeftAlone() {
        XCTAssertEqual(CaptureReading.line("Order part no#4 today", settingTags: ["parts"]),
                       "Order part no#4 today #parts")
    }
}
