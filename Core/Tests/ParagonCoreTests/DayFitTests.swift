import XCTest
@testable import ParagonCore

final class DayFitTests: XCTestCase {
    func testFreeMinutesLeavesOutWhatIsBusy() {
        // 08:00–16:00 with lunch 12–13 and a meeting 14:00–16:30 that runs past the end.
        let busy = [720..<780, 840..<990]
        XCTAssertEqual(DayPlan.freeMinutes(from: 480, until: 960, busy: busy), 480 - 60 - 120)
    }

    func testFreeMinutesCountsOverlapsOnce() {
        XCTAssertEqual(DayPlan.freeMinutes(from: 0, until: 600, busy: [60..<180, 120..<240, 200..<210]), 600 - 180)
        XCTAssertEqual(DayPlan.freeMinutes(from: 600, until: 500, busy: []), 0)
    }

    func testEachBlockGetsItsOwnLength() {
        let starts = DayPlan.freeStarts(lengths: [45, 15, 30], from: 8 * 60, until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [480, 525, 540])
    }

    func testABlockThatDoesNotFitDoesNotStopTheNextOne() {
        // Free from 22:00 to midnight: two hours. Three hours does not fit, 30 minutes does.
        let starts = DayPlan.freeStarts(lengths: [180, 30], from: 22 * 60, until: 24 * 60, busy: [])
        XCTAssertEqual(starts, [nil, 1320])
    }

    func testBlocksGoAroundTheCalendar() {
        let starts = DayPlan.freeStarts(lengths: [60, 60], from: 9 * 60, until: 24 * 60, busy: [600..<690])
        XCTAssertEqual(starts, [540, 690])
    }

    func testTheWorkingDayIsAMeasureNotAWall() {
        XCTAssertEqual(DayFit(picked: 120, freeInWorkday: 180, freeToday: 400).verdict, .fitsWorkday)
        XCTAssertEqual(DayFit(picked: 240, freeInWorkday: 180, freeToday: 400).verdict, .runsIntoEvening(60))
        XCTAssertEqual(DayFit(picked: 500, freeInWorkday: 180, freeToday: 400).verdict, .tooMuch(100))
    }

    func testAfterTheWorkingDayEverythingIsEvening() {
        // 17:00, the working day ended at 16:00: nothing is free in it, the evening still is.
        let fit = DayFit(picked: 90, from: 17 * 60, workdayEnds: 16 * 60, busy: [])
        XCTAssertEqual(fit.freeInWorkday, 0)
        XCTAssertEqual(fit.freeToday, 7 * 60)
        XCTAssertEqual(fit.verdict, .runsIntoEvening(90))
    }
}
