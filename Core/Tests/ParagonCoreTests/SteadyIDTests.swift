import XCTest
@testable import ParagonCore

/// Build 342: two devices that give the same task an id at the same minute must write the same line.
final class SteadyIDTests: XCTestCase {
    func testTheSameTaskGetsTheSameIDOnEveryDevice() {
        let key = "Inbox.md\nKolla Alfred 6"
        let mac = TaskItem.steadyID(for: key, avoiding: [])
        let phone = TaskItem.steadyID(for: key, avoiding: [])
        XCTAssertEqual(mac, phone)
        XCTAssertNotNil(mac.range(of: #"^t[0-9a-f]{6}$"#, options: .regularExpression))
        XCTAssertNotEqual(mac, TaskItem.steadyID(for: "Inbox.md\nSecond thought", avoiding: []))
        // A taken id is stepped past, the same way everywhere.
        let next = TaskItem.steadyID(for: key, avoiding: [mac])
        XCTAssertNotEqual(next, mac)
        XCTAssertEqual(next, TaskItem.steadyID(for: key, avoiding: [mac]))
    }
}
