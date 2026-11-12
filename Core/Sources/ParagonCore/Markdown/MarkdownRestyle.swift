import Foundation

/// Which part of a note has to be drawn again after a change (premium review, hardening-20).
///
/// Drawing the whole note again on every key made a long note slow to type in. Most keys
/// change how one line looks and nothing else, so only those lines are drawn again while
/// typing, and the whole note once typing pauses. A line that opens or closes a code block or
/// the settings block changes how the lines *after* it look, so those always ask for the
/// whole note — being right comes before being fast.
extension MarkdownHighlight {
    public enum Restyle: Equatable {
        /// Draw the whole note again.
        case whole
        /// Draw only these whole lines again. `inCode`: they sit inside a code block.
        case lines(NSRange, inCode: Bool)
    }

    /// The most lines that are drawn on their own; a larger change (a long paste) is drawn whole.
    public static let longestPart = 20_000

    /// True when one of these lines opens or closes a code block or the settings block.
    public static func reachesOtherLines(_ lines: String) -> Bool {
        guard lines.contains("```") || lines.contains("~~~") || lines.contains("---") else { return false }
        for line in lines.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") || trimmed == "---" { return true }
        }
        return false
    }

    /// What to draw again after `changed` (a range in the text as it is now) was typed or
    /// its line was otherwise touched.
    public static func restyle(of text: NSString, around changed: NSRange) -> Restyle {
        guard changed.location >= 0, changed.length >= 0, NSMaxRange(changed) <= text.length, text.length > 0 else { return .whole }
        // One character further, so a change that ends in a line break takes the line after
        // it along: Return in the middle of a heading leaves half of it on the next line.
        let reach = min(changed.length + 1, text.length - changed.location)
        let block = text.lineRange(for: NSRange(location: changed.location, length: reach))
        guard block.length <= longestPart else { return .whole }
        if reachesOtherLines(text.substring(with: block)) { return .whole }

        // The settings block at the top is one block; inside it, the whole note is drawn.
        var bodyStart = 0
        let first = text.lineRange(for: NSRange(location: 0, length: 0))
        if text.substring(with: first).trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            var from = NSMaxRange(first)
            while from < text.length {
                let hit = text.range(of: "---", options: [], range: NSRange(location: from, length: text.length - from))
                guard hit.location != NSNotFound else { break }
                let line = text.lineRange(for: hit)
                if text.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                    bodyStart = NSMaxRange(line)
                    break
                }
                from = NSMaxRange(line)
            }
        }
        if block.location < bodyStart { return .whole }

        // Inside a code block? Count the lines that open or close one above these lines.
        var fences = 0
        for mark in ["```", "~~~"] {
            var from = bodyStart
            while from < block.location {
                let hit = text.range(of: mark, options: [], range: NSRange(location: from, length: block.location - from))
                guard hit.location != NSNotFound else { break }
                let line = text.lineRange(for: hit)
                let before = text.substring(with: NSRange(location: line.location, length: hit.location - line.location))
                if before.trimmingCharacters(in: .whitespaces).isEmpty { fences += 1 }
                from = max(NSMaxRange(line), NSMaxRange(hit))
            }
        }
        return .lines(block, inCode: fences % 2 == 1)
    }

    /// The spans for some whole lines of `text`, placed where they are in the whole text.
    /// Only for lines `restyle(of:around:)` handed out.
    public static func spans(in text: NSString, lines block: NSRange, inCode: Bool) -> [MarkdownSpan] {
        guard block.location >= 0, NSMaxRange(block) <= text.length, block.length > 0 else { return [] }
        if inCode {
            // Line by line without the line breaks, exactly as the whole note is read.
            var found: [MarkdownSpan] = []
            var start = block.location
            for at in block.location..<NSMaxRange(block) where text.character(at: at) == 10 {
                if at > start { found.append(MarkdownSpan(range: NSRange(location: start, length: at - start), style: .code)) }
                start = at + 1
            }
            if NSMaxRange(block) > start {
                found.append(MarkdownSpan(range: NSRange(location: start, length: NSMaxRange(block) - start), style: .code))
            }
            return found
        }
        return spans(in: text.substring(with: block)).map {
            MarkdownSpan(range: NSRange(location: $0.range.location + block.location, length: $0.range.length), style: $0.style)
        }
    }
}
