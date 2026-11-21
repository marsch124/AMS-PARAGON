import XCTest
@testable import ParagonCore

/// Round 352: ready-made places for **Remind me at a place…**.
final class PlaceChoicesTests: XCTestCase {
    func testUsedPlacesAreGatheredOnceEachMostUsedFirst() {
        let one = Note(relativePath: "Projects/House.md", kind: .project, text: """
        # House
        - [ ] Buy paint @place(Hornbach|55.60000,13.00000|arrive)
        - [x] Buy nails @place(hornbach|55.60000,13.00000|leave)
        - [ ] Post the letter @place(Post office|55.61000,13.01000|arrive)
        - [ ] No place here
        """)
        let two = Note(relativePath: "Inbox.md", kind: .inbox, text: """
        # Inbox
        - [ ] Return the drill @place(Hornbach|55.60000,13.00000|leave)
        - [ ] Coffee @place(Cafe|55.62000,13.02000|arrive)
        """)
        let places = NoteIndex(notes: [one, two]).usedPlaces()
        XCTAssertEqual(places.map(\.name), ["Hornbach", "Cafe", "Post office"])
        XCTAssertEqual(places.first?.latitude ?? 0, 55.6, accuracy: 0.00001)
        XCTAssertEqual(NoteIndex(notes: [one, two]).usedPlaces(limit: 1).count, 1)
        XCTAssertTrue(NoteIndex(notes: []).usedPlaces().isEmpty)
    }

    func testHomeAndWorkAreStoredAndReadBack() throws {
        let text = SavedPlace.stored(address: "Storgatan 5 | Malmö", latitude: 55.604981, longitude: 13.003822)
        XCTAssertEqual(text, "Storgatan 5 Malmö|55.60498,13.00382")
        let home = try XCTUnwrap(SavedPlace.home.read(text))
        XCTAssertEqual(home.name, "Home")
        XCTAssertEqual(home.address, "Storgatan 5 Malmö")
        XCTAssertEqual(home.latitude, 55.60498, accuracy: 0.00001)
        XCTAssertEqual(SavedPlace.work.read(text)?.name, "Work")
        XCTAssertNil(SavedPlace.home.read(nil))
        XCTAssertNil(SavedPlace.home.read("nowhere"))
        XCTAssertNil(SavedPlace.home.read("x|200,13"))
        XCTAssertEqual(home.reminder(arriving: false).words, "Leaving Home")
    }

    func testTheChipsAreHomeWorkThenUsedPlacesWithoutTheSameSpotTwice() {
        let home = KnownPlace(name: "Home", latitude: 55.6, longitude: 13.0, address: "Storgatan 5")
        let work = KnownPlace(name: "Work", latitude: 55.7, longitude: 13.1)
        let used = [KnownPlace(name: "My flat", latitude: 55.6, longitude: 13.0),
                    KnownPlace(name: "Cafe", latitude: 55.62, longitude: 13.02)]
        XCTAssertEqual(PlaceChoices.chips(home: home, work: work, used: used).map(\.name), ["Home", "Work", "Cafe"])
        XCTAssertEqual(PlaceChoices.chips(home: nil, work: nil, used: used).map(\.name), ["My flat", "Cafe"])
        XCTAssertEqual(PlaceChoices.chips(home: home, work: work, used: used, limit: 2).count, 2)
    }
}
