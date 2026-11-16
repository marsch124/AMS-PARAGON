import XCTest
@testable import ParagonCore

final class DeviceModelNameTests: XCTestCase {
    func testKnownModelsHaveTheirNameAndOthersTheKind() {
        XCTAssertEqual(DeviceModelName.friendly(machine: "iPhone18,1", kind: "iPhone"), "iPhone 17 Pro")
        XCTAssertEqual(DeviceModelName.friendly(machine: "iPad16,1", kind: "iPad"), "iPad mini")
        XCTAssertEqual(DeviceModelName.friendly(machine: "iPad99,9", kind: "iPad"), "iPad")
        XCTAssertEqual(DeviceModelName.friendly(machine: "arm64", kind: "iPhone"), "iPhone")
    }
}
