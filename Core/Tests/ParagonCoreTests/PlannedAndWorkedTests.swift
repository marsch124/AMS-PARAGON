import XCTest
@testable import ParagonCore

/// Build 259: **Planned and worked** in **Close the day** — what was planned next to what the
/// focus timer measured, and **All of today** under them.
final class PlannedAndWorkedTests: XCTestCase {
    private func block(_ start: String, _ end: String, _ title: String) -> PlanBlock {
        PlanBlock(start: minutes(start), end: minutes(end), title: title)
    }

    private func span(_ start: String, _ end: String, _ title: String) -> WorkedSpan {
        WorkedSpan(start: minutes(start), end: minutes(end), title: title)
    }

    private func minutes(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    /// The drawing's own example: four planned, three worked, one of them over.
    func testTheDrawingsDay() {
        let table = PlannedAndWorked(
            blocks: [block("08:00", "08:45", "Write the offer"),
                     block("08:45", "09:00", "Call the bank"),
                     block("09:30", "11:00", "Garden beds"),
                     block("13:00", "15:00", "Photo archive")],
            worked: [span("08:02", "08:54", "Write the offer"),
                     span("09:05", "09:15", "Call the bank"),
                     span("09:30", "10:10", "Garden beds"),
                     span("10:20", "11:00", "Garden beds")])
        XCTAssertEqual(table.rows.map(\.title), ["Write the offer", "Call the bank", "Garden beds", "Photo archive"])
        XCTAssertEqual(table.rows.map(\.planned), [45, 15, 90, 120])
        XCTAssertEqual(table.rows.map(\.worked), [52, 10, 80, nil])
        XCTAssertEqual(table.rows.map(\.isOver), [true, false, false, false])
        XCTAssertEqual(table.plannedTotal, 270)
        XCTAssertEqual(table.workedTotal, 142)
    }

    /// Worked with no block: the task's own time is what was planned. Not found: nothing is
    /// guessed, and the row still counts towards the worked total.
    func testWorkWithNoBlockTakesTheTasksTime() {
        let table = PlannedAndWorked(
            blocks: [],
            worked: [span("10:00", "10:20", "Renew the boat insurance"),
                     span("11:00", "11:30", "Read the club minutes")],
            tasks: [TaskItem(title: "Renew the boat insurance #next", minutes: 30),
                    TaskItem(title: "Read the club minutes")])
        XCTAssertEqual(table.rows.map(\.planned), [30, nil])
        XCTAssertEqual(table.rows.map(\.worked), [20, 30])
        XCTAssertEqual(table.plannedTotal, 30)
        XCTAssertEqual(table.workedTotal, 50)
    }

    /// A block is what was planned for today, so it wins over the task's own time.
    func testABlockWinsOverTheTasksTime() {
        let table = PlannedAndWorked(
            blocks: [block("09:00", "10:00", "Write the offer")],
            worked: [span("09:00", "09:40", "Write the offer")],
            tasks: [TaskItem(title: "Write the offer", minutes: 45)])
        XCTAssertEqual(table.rows.first?.planned, 60)
    }

    /// Two tasks under one name that disagree give no time: one task's time is never lent to
    /// another. The same task handed in twice agrees with itself.
    func testTasksThatDisagreeGiveNoTime() {
        let worked = [span("09:00", "09:40", "Stretch")]
        let unclear = PlannedAndWorked(blocks: [], worked: worked,
                                       tasks: [TaskItem(title: "Stretch"), TaskItem(title: "Stretch", minutes: 15)])
        XCTAssertNil(unclear.rows.first?.planned)
        let different = PlannedAndWorked(blocks: [], worked: worked,
                                         tasks: [TaskItem(title: "Stretch", minutes: 15), TaskItem(title: "Stretch", minutes: 30)])
        XCTAssertNil(different.rows.first?.planned)
        let same = PlannedAndWorked(blocks: [], worked: worked,
                                    tasks: [TaskItem(title: "Stretch", minutes: 15), TaskItem(title: "Stretch #next", minutes: 15)])
        XCTAssertEqual(same.rows.first?.planned, 15)
    }

    /// Case and spaces are ignored, so a block retyped by hand still finds its work; the row
    /// keeps the block's spelling.
    func testNamesAreMatchedLoosely() {
        let table = PlannedAndWorked(
            blocks: [block("09:00", "10:00", "Write  the Offer")],
            worked: [span("09:05", "09:50", "write the offer")])
        XCTAssertEqual(table.rows.count, 1)
        XCTAssertEqual(table.rows.first?.title, "Write the Offer")
        XCTAssertEqual(table.rows.first?.worked, 45)
    }

    /// Two blocks under one name are one row, planned for both.
    func testTwoBlocksUnderOneNameAddUp() {
        let table = PlannedAndWorked(
            blocks: [block("09:00", "10:00", "Write"), block("14:00", "14:30", "Write")],
            worked: [])
        XCTAssertEqual(table.rows.map(\.planned), [90])
        XCTAssertNil(table.workedTotal)
    }

    /// Rows follow the day: work that started before the first block comes first.
    func testRowsFollowTheDay() {
        let table = PlannedAndWorked(
            blocks: [block("13:00", "14:00", "Afternoon"), block("09:00", "10:00", "Morning")],
            worked: [span("07:30", "08:00", "Early mail")])
        XCTAssertEqual(table.rows.map(\.title), ["Early mail", "Morning", "Afternoon"])
    }

    /// A line typed by hand that ends before it starts says nothing about the work.
    func testABackwardsLineIsLeftOut() {
        let table = PlannedAndWorked(blocks: [], worked: [span("10:00", "09:00", "Odd")])
        XCTAssertTrue(table.isEmpty)
        XCTAssertNil(table.plannedTotal)
        XCTAssertNil(table.workedTotal)
    }

    /// Worked exactly as planned is not over.
    func testExactlyAsPlannedIsNotOver() {
        let table = PlannedAndWorked(
            blocks: [block("09:00", "09:45", "Write")],
            worked: [span("09:00", "09:45", "Write")])
        XCTAssertEqual(table.rows.first?.isOver, false)
    }

    /// The clock's line and a block made from the same task carry the same name.
    func testThePlanTitleDropsOnlyNext() {
        XCTAssertEqual(TaskItem(title: "Order the saddle #next #horse").planTitle, "Order the saddle #horse")
        XCTAssertEqual(TaskItem(title: "Plan #nextweek").planTitle, "Plan #nextweek")
    }
}
