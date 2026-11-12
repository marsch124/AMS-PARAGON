import Foundation

/// Premium review round 5 (icons): how big a hand-drawn mark is beside text, and how heavy
/// its line is. Pure numbers, so the app, the widgets and a test all read the same rule.
public enum MarkRule {
    /// Apple's text styles, named here so Core needs no SwiftUI.
    public enum TextStyle: String, CaseIterable, Sendable {
        case largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2
    }

    /// The mark's side in points beside text of that style, at the standard text size.
    /// 16 beside body text, on the iPhone and on the Mac, as it has been since build 280.
    public static func size(for style: TextStyle) -> Double {
        switch style {
        case .largeTitle: return 32
        case .title: return 26
        case .title2: return 21
        case .title3: return 19
        case .headline, .body: return 16
        case .callout: return 15
        case .subheadline: return 14
        case .footnote, .caption: return 12
        case .caption2: return 11
        }
    }

    /// The line the marks are drawn with, on the 24-point grid.
    public static let gridLine: Double = 1.9
    /// The thinnest line a mark may have on screen, in points (his pick: "a floor of 1.3").
    public static let thinnestLine: Double = 1.3

    /// A mark this big or bigger keeps the 1.9 line.
    public static let unchangedFrom: Double = 16

    /// The line width IN GRID UNITS for a mark drawn `size` points wide. 1.9 for 16 points
    /// and up, as before; a smaller mark gets a heavier grid line so that it never comes out
    /// thinner than 1.3 points on screen (1.9 on a 9-point mark was 0.7).
    public static func lineWidth(forSize size: Double) -> Double {
        // 16 points and up stay exactly as they were (his words). 1.9 at 16 points is 1.27
        // on screen, a hair under the floor, and is left alone; the floor is for smaller marks.
        guard size > 0, size < unchangedFrom else { return gridLine }
        return max(gridLine, thinnestLine * 24 / size)
    }
}
