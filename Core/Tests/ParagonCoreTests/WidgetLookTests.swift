import XCTest
@testable import ParagonCore

/// Build 272: the widget's colours are the app's colours.
///
/// A widget is a separate target and cannot see the app's asset catalogue (build 174), so
/// `WidgetLook` in `App/ParagonWidgets/ParagonWidgets.swift` spells each colour again, and by
/// build 272 four of them had drifted by a few shades without anything saying so. This test
/// reads that table and the catalogue as text and compares them, light and dark. It runs in
/// the package tests, so a drift fails CI instead of waiting for a screenshot.
///
/// It reads files of the repository by their place relative to this file. When they are not
/// there (the package copied out on its own), it skips and says so, rather than failing for
/// a reason that has nothing to do with the colours.
final class WidgetLookTests: XCTestCase {
    private var repositoryRoot: URL {
        // …/Core/Tests/ParagonCoreTests/WidgetLookTests.swift → the repository.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private let widgetSource = "App/ParagonWidgets/ParagonWidgets.swift"

    /// A file of the repository as text, or a skip when it is not there.
    private func read(_ relativePath: String) throws -> String {
        let url = repositoryRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Not next to the package: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private struct Spelled {
        let property: String
        let light: Int
        let dark: Int
        let colourSet: String
    }

    /// Every `static let x = Color(lightHex: 0x…, darkHex: 0x…)  // XxxTint` line in the widget.
    private func spelledInTheWidget() throws -> [Spelled] {
        let source = try read(widgetSource)
        let pattern = #"static let (\w+) = Color\(lightHex: 0x([0-9A-Fa-f]{6}), darkHex: 0x([0-9A-Fa-f]{6})\)\s*//\s*(\w+)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let whole = NSRange(source.startIndex..., in: source)
        var found: [Spelled] = []
        for match in regex.matches(in: source, range: whole) {
            var parts: [String] = []
            for index in 1...4 {
                if let range = Range(match.range(at: index), in: source) { parts.append(String(source[range])) }
            }
            guard parts.count == 4, let light = Int(parts[1], radix: 16), let dark = Int(parts[2], radix: 16) else {
                continue
            }
            found.append(Spelled(property: parts[0], light: light, dark: dark, colourSet: parts[3]))
        }
        return found
    }

    /// The two values of one colour set, read the way Xcode wrote them ("0xA7").
    private func catalogue(_ name: String) throws -> (light: Int, dark: Int) {
        let text = try read("App/Paragon/Assets.xcassets/\(name).colorset/Contents.json")
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let colours = try XCTUnwrap(json["colors"] as? [[String: Any]])
        var light: Int?
        var dark: Int?
        for entry in colours {
            let parts = try XCTUnwrap((entry["color"] as? [String: Any])?["components"] as? [String: String])
            var value = 0
            for key in ["red", "green", "blue"] {
                let raw = try XCTUnwrap(parts[key], "\(name): no \(key)")
                let byte = try XCTUnwrap(Int(raw.replacingOccurrences(of: "0x", with: ""), radix: 16),
                                         "\(name): \(raw)")
                value = value * 256 + byte
            }
            // The entry with no `appearances` is the light one; the other says "dark".
            if entry["appearances"] == nil { light = value } else { dark = value }
        }
        let lightValue = try XCTUnwrap(light, "\(name) has no light value")
        let darkValue = try XCTUnwrap(dark, "\(name) has no dark value")
        return (lightValue, darkValue)
    }

    private func hex(_ value: Int) -> String {
        let digits = String(value, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }

    func testEveryWidgetColourIsTheCataloguesColour() throws {
        let spelled = try spelledInTheWidget()
        // Seven, because the table is read by its spelling: if someone changes how a line is
        // written the test must say so, not pass with nothing compared.
        XCTAssertGreaterThanOrEqual(spelled.count, 7, "The colour table in ParagonWidgets.swift was not found")
        for entry in spelled {
            let app = try catalogue(entry.colourSet)
            XCTAssertEqual(hex(entry.light), hex(app.light),
                           "WidgetLook.\(entry.property) light differs from \(entry.colourSet)")
            XCTAssertEqual(hex(entry.dark), hex(app.dark),
                           "WidgetLook.\(entry.property) dark differs from \(entry.colourSet)")
        }
    }

    func testTheWidgetCoversTheKindsOfNoteThatCanHoldATask() throws {
        let sets = Set(try spelledInTheWidget().map(\.colourSet))
        // ParaKind.tint in the app: project, area, resource, archive, goal, inbox, daily.
        for needed in ["ProjectTint", "AreaTint", "ResourceTint", "ArchiveTint", "GoalTint", "InboxTint", "CalendarTint"] {
            XCTAssertTrue(sets.contains(needed), "WidgetLook has no \(needed)")
        }
    }

    func testTheAppGroupSpellingsAreTheOnesTheEntitlementsCarry() throws {
        // The two spellings of one group (build 178): the widget writes them out because it
        // cannot see the app's code, and a change to one is a change to the other.
        let widget = try read(widgetSource)
        XCTAssertTrue(widget.contains("\"D24ENP83QQ.group.com.schabbauer.amspara\""))
        XCTAssertTrue(widget.contains("\"group.com.schabbauer.amspara\""))
        let mac = try read("App/Config/ParagonWidgets/ParagonWidgets-macOS.entitlements")
        XCTAssertTrue(mac.contains("<string>D24ENP83QQ.group.com.schabbauer.amspara</string>"))
        let phone = try read("App/Config/ParagonWidgets/ParagonWidgets.entitlements")
        XCTAssertTrue(phone.contains("<string>group.com.schabbauer.amspara</string>"))
    }
}
