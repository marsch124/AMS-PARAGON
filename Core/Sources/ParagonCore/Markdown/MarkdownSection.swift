import Foundation

/// A `## Heading` section of a note's body, and where it sits in that body's lines.
///
/// `DayPlan` has owned `## Plan` since build 147; `DayLog` owns `## Looking back` from build
/// 223. "Where does this section start and stop" is the same question in both, so it is asked
/// in one place: two copies of a markdown parser is exactly how two parts of this app came to
/// give different answers about one file before (build 168).
public enum MarkdownSection {
    /// The lines **inside** `heading`, and the range they occupy.
    ///
    /// A section runs to the next `## ` heading, or to the end of the note. The heading itself
    /// is not included, so the heading's own line is `range.lowerBound - 1`.
    ///
    /// A `nil` range means the heading is not in the note at all, which is a different answer
    /// from a section that is there with nothing in it (build 100's rule, in a small place).
    /// Matching ignores case, so a heading typed by hand still counts.
    public static func find(_ heading: String, in body: String) -> (lines: [String], range: Range<Int>?) {
        let lines = body.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).lowercased() == heading.lowercased()
        }) else { return ([], nil) }
        var end = start + 1
        while end < lines.count, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
            end += 1
        }
        let inside = (start + 1)..<end
        return (Array(lines[inside]), inside)
    }
}
