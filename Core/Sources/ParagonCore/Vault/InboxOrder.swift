import Foundation

/// Build 367: how the Inbox shows its lines.
///
/// His words, 24 November 2026: "the sorting order has to be the latest on top", and "if the
/// inbox item is a long text, I need to be able to long press it and show the whole text.
/// Otherwise, I cannot tell if it should be today, tomorrow, or do."
public enum InboxOrder {
    /// The lines as the Inbox shows them: **the one captured last comes first.** A capture is
    /// written at the end of its part of the Inbox note, so the order on screen is the file's
    /// order turned round. The file itself is not changed, and a line keeps its place in it.
    public static func newestFirst<Line>(_ lines: [Line]) -> [Line] {
        Array(lines.reversed())
    }

    /// How many lines of its words a row shows: two, and all of them for the line that is
    /// picked, so a long line can be read whole right above the buttons that decide about it.
    /// Nil means no limit.
    public static func titleLines(picked: Bool) -> Int? {
        picked ? nil : 2
    }
}
