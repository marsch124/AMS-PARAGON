import XCTest
@testable import ParagonCore

/// Build 289: picture links found in the text, and photo names and links.
final class PicturesTests: XCTestCase {
    func testPictureLinksAndPhotoNames() {
        let text = "Top\n![Sketch](../Sketches/Sketch%201.png)\nSee ![x](pic.JPG) and ![web](https://a.b/c.png) ![doc](../a.pdf)"
        let found = Pictures.matches(in: text, notePath: "Projects/Garden.md")
        XCTAssertEqual(found.map(\.path), ["Sketches/Sketch 1.png", "Projects/pic.JPG"])
        XCTAssertEqual((text as NSString).substring(with: found[0].range), "![Sketch](../Sketches/Sketch%201.png)")
        XCTAssertTrue(Pictures.isSketch(found[0].path))
        XCTAssertFalse(Pictures.isSketch(found[1].path))
        let name = Pictures.newPhotoName(at: Date(timeIntervalSince1970: 0), calendar: Calendar(identifier: .gregorian))
        XCTAssertTrue(name.hasPrefix("Photo 19") && name.hasSuffix(".jpg"), name)
        XCTAssertEqual(Sketches.link(toFile: "Photo 1.jpg", fromNote: "Inbox.md", folder: Pictures.photoFolder, alt: "Photo"),
                       "![Photo](Photos/Photo%201.jpg)")
    }
}
