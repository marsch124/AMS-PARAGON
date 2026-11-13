import XCTest
import Foundation

/// 1.0 (build 280): the rules of the look, checked against the app's source files.
///
/// Martin's brief for the look release: **no text size appears in the code outside the one
/// type scale**, and **no emoji or stock icons anywhere**. A reviewer can miss one; a test
/// cannot. These tests read `App/Paragon/**/*.swift` straight from the repository (the Core
/// package has no view code of its own) and fail on the first line that breaks a rule, so the
/// message names the file and the line to fix.
///
/// Seen red first: on the morning of 6 November 2026, before the sweep, 457 `.font(…)` calls
/// named their own style and 217 icons came from SF Symbols.
final class LookRulesTests: XCTestCase {
    /// `Core/Tests/ParagonCoreTests/LookRulesTests.swift` → the repository root.
    private var appFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App", isDirectory: true)
    }

    /// The one place sizes are allowed: the scale itself. The two markdown renderers take
    /// their numbers from `Txt.Editor`, which is still the scale, through `Font.system(size:)`.
    /// The widgets are their own target with Apple's small widget styles; they keep theirs.
    private let filesThatMayNameASize: Set<String> = ["Look.swift", "MarkdownSyntaxEditor.swift", "MarkdownPreview.swift",
                                                       "ParagonWidgets.swift", "TodayPlanWidget.swift", "OneListWidget.swift", "WidgetMarks.swift",
                                                       // The share sheet is iPhone-only and uses Apple's text styles, as his brief asks there.
                                                       "ShareViewController.swift"]

    private func swiftFiles() throws -> [URL] {
        let folder = appFolder
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            XCTFail("Cannot read \(folder.path)"); return []
        }
        var files: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append(url)
        }
        XCTAssertGreaterThan(files.count, 30, "Too few source files found under \(folder.path); is the test reading the right folder?")
        return files.sorted { $0.path < $1.path }
    }

    /// Lines that break a rule, as "file:line: text".
    private func offending(_ files: [URL], where breaks: (String) -> Bool) throws -> [String] {
        var found: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                if breaks(line) { found.append("\(file.lastPathComponent):\(index + 1): \(trimmed)") }
            }
        }
        return found
    }

    /// Every `.font(…)` reads the scale: `Txt.something`, never `.caption`, `.headline`, a
    /// `Font.system(size:)` or `.system(.body, …)` of its own.
    func testEveryTextSizeComesFromTheOneScale() throws {
        let files = try swiftFiles().filter { !filesThatMayNameASize.contains($0.lastPathComponent) }
        let styles = ["caption2", "caption", "footnote", "subheadline", "callout", "body", "headline",
                      "title3", "title2", "title", "largeTitle", "system"]
        let bad = try offending(files) { line in
            guard let range = line.range(of: ".font(") else { return false }
            let after = line[range.upperBound...]
            if after.hasPrefix("Txt.") { return false }
            return styles.contains { after.hasPrefix(".\($0)") } || after.contains("size:")
        }
        XCTAssertTrue(bad.isEmpty, "Text sizes outside the type scale (use Txt.…):\n" + bad.joined(separator: "\n"))
    }

    /// No stock icons: nothing is drawn with `Image(systemName:)` or `systemImage:`; every
    /// icon is a hand-drawn mark from the AMS-Icons package.
    func testNoStockIconsAnywhere() throws {
        let bad = try offending(try swiftFiles()) { line in
            line.contains("Image(systemName:") || line.contains("systemImage:") || line.contains("systemSymbolName:")
        }
        XCTAssertTrue(bad.isEmpty, "Stock icons still in use (\(bad.count)); draw a mark instead:\n" + bad.prefix(40).joined(separator: "\n"))
    }

    /// No emoji in the source: the icons are drawings, never characters.
    func testNoEmojiInTheSource() throws {
        let bad = try offending(try swiftFiles()) { line in
            line.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation && scalar.value > 0x238C
            }
        }
        XCTAssertTrue(bad.isEmpty, "Emoji in the source:\n" + bad.joined(separator: "\n"))
    }

    /// **A two-state button is never dashed** (build 281). `StateToggle` — Edit, Note, Month,
    /// Arrange, Hide finished, All of them, The Waiting for list — drew its off state with a
    /// dashed border since build 142, and in a Mac toolbar that read as an empty placeholder
    /// (the reviewer of 280). Off is a thin solid line now; on is the tinted fill. The one
    /// dashed shape left in the app is the Icon… button while nothing is chosen, which is a
    /// placeholder and means to look like one.
    func testTheTwoStateButtonIsNotDashed() throws {
        let theme = appFolder.appendingPathComponent("Paragon/Views/Theme.swift")
        let text = try String(contentsOf: theme, encoding: .utf8)
        guard let start = text.range(of: "struct StateToggle") else {
            XCTFail("Theme.swift has no StateToggle any more; move this test to where it went.")
            return
        }
        let rest = text[start.upperBound...]
        let end = rest.range(of: "\nstruct ")?.lowerBound ?? rest.endIndex
        XCTAssertFalse(rest[..<end].contains("dash:"),
                       "StateToggle draws a dashed line. Its off state is a thin solid border (build 281).")
    }
}
