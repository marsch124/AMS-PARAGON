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

    func testPastedNamesAndTheGallery() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 20, minute: 14, second: 5))!
        XCTAssertEqual(Pictures.pastedName(at: date, calendar: cal), "Pasted 2026-11-11 201405.png")
        let one = "Hi\n![Picture](../Pictures/a.png)\n"
        XCTAssertEqual(Pictures.galleryPaths(in: one, notePath: "Projects/Boat.md"), [])
        let three = one + "![Sketch](../Sketches/b.png)\n![Again](../Pictures/a.png)\n![x](../Photos/c.jpg)"
        XCTAssertEqual(Pictures.galleryPaths(in: three, notePath: "Projects/Boat.md"),
                       ["Pictures/a.png", "Sketches/b.png", "Photos/c.jpg"])
    }

    func testPastedJPEGNamesAndReorderingTheGallery() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 20, minute: 14, second: 5))!
        XCTAssertEqual(Pictures.pastedName(at: date, calendar: cal, ext: "jpg"), "Pasted 2026-11-11 201405.jpg")
        let text = "A\n![One](../Pictures/1.png)\nB\n![Two](../Pictures/2.png)\nC\n![Three](../Photos/3.jpg)\n"
        XCTAssertEqual(Pictures.reordering(text, notePath: "Projects/Boat.md", moving: "Photos/3.jpg", onto: "Pictures/1.png"),
                       "A\n![Three](../Photos/3.jpg)\nB\n![One](../Pictures/1.png)\nC\n![Two](../Pictures/2.png)\n")
        XCTAssertEqual(Pictures.reordering(text, notePath: "Projects/Boat.md", moving: "Pictures/1.png", onto: "Pictures/2.png"),
                       "A\n![Two](../Pictures/2.png)\nB\n![One](../Pictures/1.png)\nC\n![Three](../Photos/3.jpg)\n")
        XCTAssertEqual(Pictures.reordering(text, notePath: "Projects/Boat.md", moving: "Nope.png", onto: "Pictures/2.png"), text)
    }

    func testCopyWordsAndZoomLimits() {
        XCTAssertEqual(Pictures.wordsToCopy("\n Marina AB\nInvoice 4711 \n\n"), "Marina AB\nInvoice 4711")
        XCTAssertNil(Pictures.wordsToCopy("  \n "))
        XCTAssertNil(Pictures.wordsToCopy(nil))
        XCTAssertEqual(Pictures.zoom(0.4), 1)
        XCTAssertEqual(Pictures.zoom(3), 3)
        XCTAssertEqual(Pictures.zoom(9), Pictures.maxZoom)
    }

    func testShowWordsAndSketchSnippets() {
        let text = "A\n![One](../Pictures/1.png)\nB"
        XCTAssertEqual(Pictures.showingWords("Marina AB\n\n Invoice 4711 ", in: text, linkAt: 2),
                       "A\n![One](../Pictures/1.png)\n> Marina AB\n> Invoice 4711\nB")
        XCTAssertEqual(Pictures.showingWords("Hi", in: "![One](1.png)", linkAt: 0), "![One](1.png)\n> Hi\n")
        XCTAssertEqual(Pictures.showingWords("  \n", in: text, linkAt: 2), text)
        let pad = Note(relativePath: "Areas/Pad.md", kind: .area, text: "# Pad\n\n![Sketch](../Sketches/Sketch%201.png)\n")
        let hits = NoteIndex(notes: [pad]).search(SearchQuery.parse("milk"), pictureText: ["Sketches/Sketch 1.png": "buy milk"])
        XCTAssertEqual(hits.first?.snippets, ["In a sketch: buy milk"])
    }

    func testSearchFindsWordsInsidePictures() {
        let boat = Note(relativePath: "Projects/Boat.md", kind: .project, text: "# Boat\n\n![Picture](../Pictures/receipt.png)\n")
        let index = NoteIndex(notes: [boat])
        XCTAssertTrue(index.search(text: "invoice").isEmpty)
        let hits = index.search(SearchQuery.parse("invoice"),
                                pictureText: ["Pictures/receipt.png": "Marina AB\nInvoice 4711 total 300 kr"])
        XCTAssertEqual(hits.map(\.note.relativePath), ["Projects/Boat.md"])
        XCTAssertEqual(hits.first?.snippets, ["In a picture: Invoice 4711 total 300 kr"])
    }
}
