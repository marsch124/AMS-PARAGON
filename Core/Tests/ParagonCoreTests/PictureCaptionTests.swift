import XCTest
@testable import ParagonCore

final class PictureCaptionTests: XCTestCase {
    func testCaptionsDropsAndDayWords() {
        XCTAssertNil(Pictures.caption(ofLink: "![Sketch](../Sketches/a.png)"))
        XCTAssertNil(Pictures.caption(ofLink: "![](x.png)"))
        XCTAssertEqual(Pictures.caption(ofLink: "![The bay at dusk](x.jpg)"), "The bay at dusk")
        XCTAssertEqual(Pictures.settingCaption("Our [old] boat", inLink: "![Photo](../Photos/p.jpg)"),
                       "![Our old boat](../Photos/p.jpg)")
        XCTAssertEqual(Pictures.settingCaption("  ", inLink: "![Boat](p.jpg)"), "![Picture](p.jpg)")
        XCTAssertEqual(Pictures.freeName(for: "a.jpg", taken: []), "a.jpg")
        XCTAssertEqual(Pictures.freeName(for: "a.jpg", taken: ["a.jpg", "a 2.jpg"]), "a 3.jpg")
        let today = DateOnly(year: 2026, month: 11, day: 11)
        XCTAssertEqual(DayDistance.words(from: today, to: today), "Today")
        XCTAssertEqual(DayDistance.words(from: DateOnly(year: 2026, month: 11, day: 10), to: today), "Yesterday")
        XCTAssertEqual(DayDistance.words(from: DateOnly(year: 2026, month: 11, day: 14), to: today), "In 3 days")
        XCTAssertEqual(DayDistance.words(from: DateOnly(year: 2026, month: 11, day: 1), to: today), "10 days ago")
    }
}
