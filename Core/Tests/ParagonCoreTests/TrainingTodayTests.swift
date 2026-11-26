import XCTest
@testable import ParagonCore

/// Build 369: the "Training:" line on Today. One small test per rule.
final class TrainingTodayTests: XCTestCase {
    private let today = "2026-12-01"
    private let now = ISO8601DateFormatter().date(from: "2026-12-01T09:00:00Z")!

    private let run = #"{"key":"r","sport":"run","sportWord":"Run","title":"Easy run","minutes":45,"length":"45 min","state":"todo","canDone":true,"open":"amsworkoutsync://session/r","done":"amsworkoutsync://done/r","extra":1}"#
    private let swimDone = #"{"key":"s","sport":"swim","sportWord":"Swim","title":"Drills","minutes":40,"length":"40 min","state":"done","open":"amsworkoutsync://session/s"}"#
    private let rest = #"{"key":"x","sport":"rest","sportWord":"Rest","title":"Rest","state":"rest"}"#

    private func note(_ sessions: [String], v: Int = 1, day: String? = nil, written: String = "2026-12-01T06:50:12Z") -> Data {
        Data(#"{"v":\#(v),"day":"\#(day ?? today)","written":"\#(written)","sessions":[\#(sessions.joined(separator: ","))],"tomorrow":"Bike"}"#.utf8)
    }
    private func line(_ data: Data?) -> TrainingToday.Line? { TrainingToday.line(from: data, today: today, now: now) }

    func testOneToDoSessionOpensItsOwnPage() {
        let l = line(note([run]))
        XCTAssertEqual(l?.words, "Run 45 min")
        XCTAssertEqual(l?.link, "amsworkoutsync://session/r")
        XCTAssertEqual(TrainingToday.spoken(l!), "Training: Run 45 min")
    }

    func testTwoSessionsMixedListsBothAndOpensToday() {
        let l = line(note([swimDone, run]))
        XCTAssertEqual(l?.words, "Swim done, Run 45 min")
        // Exactly one is to do, so its own link is used.
        XCTAssertEqual(l?.link, "amsworkoutsync://session/r")
        let two = line(note([run, run.replacingOccurrences(of: "\"r\"", with: "\"r2\"")]))
        XCTAssertEqual(two?.link, "amsworkoutsync://today")
    }

    func testAllDoneAndRestDay() {
        XCTAssertEqual(line(note([swimDone]))?.words, "done")
        XCTAssertEqual(line(note([rest]))?.words, "rest day")
        XCTAssertEqual(line(note([rest]))?.link, "amsworkoutsync://today")
    }

    func testNothingForOldOrUnknownNotes() {
        XCTAssertNil(line(note([run], day: "2026-11-30")))
        XCTAssertNil(line(note([run], written: "2026-11-29T20:00:00Z")))   // 37 h old
        XCTAssertNotNil(line(note([run], written: "2026-11-29T22:00:00Z")))  // 35 h old
        XCTAssertNil(line(note([run], v: 2)))
        XCTAssertNil(line(note([])))
        XCTAssertNil(line(nil))
        XCTAssertNil(line(Data("not json \u{0}\u{1}".utf8)))
    }

    func testAnotherSchemeIsNeverReturned() {
        let bad = run.replacingOccurrences(of: "amsworkoutsync://session/r", with: "https://example.com/x")
        XCTAssertEqual(line(note([bad]))?.link, "amsworkoutsync://today")
    }
}
