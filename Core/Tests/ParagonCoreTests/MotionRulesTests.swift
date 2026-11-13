import XCTest
import Foundation
@testable import ParagonCore

/// Build 318 (premium review polish-23, his pick "Quick and quiet"): the rules of movement.
///
/// **One set of named movements, all short.** The seconds live in `MotionTiming`; the app's
/// `Motion` gives them names (`Motion.tick`, `Motion.fold` …) and every view uses a name. These
/// tests hold the seconds to the limits and read `App/**/*.swift` (in the way of
/// `LookRulesTests`) so no view writes a duration or a curve of its own again.
final class MotionRulesTests: XCTestCase {
    private var appFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App", isDirectory: true)
    }

    /// The one file that may name a curve and a duration: the set of movements itself.
    private let filesThatMayNameACurve: Set<String> = ["Motion.swift"]

    func testEveryMovementIsShort() {
        XCTAssertEqual(MotionTiming.shortest, 0.15, accuracy: 0.0001)
        XCTAssertEqual(MotionTiming.longest, 0.35, accuracy: 0.0001)
        XCTAssertEqual(MotionTiming.bounded.count, 9, "A new movement must be added to `bounded`, so it is held to the limits too.")
        for movement in MotionTiming.bounded {
            XCTAssertGreaterThanOrEqual(movement.seconds, MotionTiming.shortest, "\(movement.name) is too quick to see")
            XCTAssertLessThanOrEqual(movement.seconds, MotionTiming.longest, "\(movement.name) is slow enough to wait for")
        }
        // His pick: 0.2 s for folding.
        XCTAssertEqual(MotionTiming.fold, 0.2, accuracy: 0.0001)
        // The sync ring's turn is the one number outside the limits, and it stays one second.
        XCTAssertEqual(MotionTiming.spin, 1.0, accuracy: 0.0001)
    }

    func testViewsUseTheNamedMovements() throws {
        guard let walker = FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil) else {
            XCTFail("Cannot read \(appFolder.path)"); return
        }
        var files: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { files.append(url) }
        XCTAssertGreaterThan(files.count, 30, "Too few source files found under \(appFolder.path)")
        XCTAssertTrue(files.contains { $0.lastPathComponent == "Motion.swift" }, "Motion.swift is missing")

        let curves = [".easeInOut", ".easeOut", ".easeIn(", ".linear(", ".spring(", ".interpolatingSpring(",
                      ".bouncy", ".snappy", ".smooth", ".interactiveSpring(", "UIView.animate", "NSAnimationContext"]
        var bad: [String] = []
        for file in files.sorted(by: { $0.path < $1.path }) where !filesThatMayNameACurve.contains(file.lastPathComponent) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                let animates = line.contains("withAnimation") || line.contains(".animation(")
                let ownCurve = curves.contains { line.contains($0) }
                // A movement must take its curve and seconds from `Motion.`; a bare
                // `withAnimation {` (Apple's default, 0.35 s and not ours) breaks the rule too.
                if (animates && !line.contains("Motion.")) || ownCurve {
                    bad.append("\(file.lastPathComponent):\(index + 1): \(trimmed)")
                }
            }
        }
        XCTAssertTrue(bad.isEmpty, "Use a name from Motion.swift (Motion.tick, Motion.fold …), not an own animation:\n" + bad.joined(separator: "\n"))
    }
}
