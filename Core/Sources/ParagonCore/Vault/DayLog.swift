import Foundation

/// What you say about a day when you close it.
///
/// It lives in that day's daily note under `## Looking back` — he chose the heading on
/// 24 September 2026 — as plain markdown, so it reads in any editor and syncs like the rest of
/// the vault:
///
///     ## Looking back
///
///     Good morning, slow afternoon. The saddle can wait.
///
/// **It is prose, and nothing else.** No parser reads it, no screen counts it, and it never
/// becomes a task or a block. That is deliberate: the value of the line is that you wrote it,
/// not that the app can do something with it. `CloseDayView` writes it for a day.
///
/// **Build 272: a weekly note can carry it too** (**How was the week?** in step 7 of the
/// Weekly review). Nothing here knows which kind of note it is given. In a weekly note made
/// from the Weekly template the section lands at the end, below the template's own `## Review`
/// and its two questions, which are never touched. That is the point of using this heading:
/// his words and the template's questions can never be taken for each other.
public enum DayLog {
    public static let heading = "## Looking back"

    /// What is written there now, or an empty string.
    ///
    /// Blank lines at either end are dropped, so a section someone typed by hand with extra
    /// space around it reads exactly like one the app wrote.
    public static func text(in note: Note) -> String {
        withoutEdgeBlanks(MarkdownSection.find(heading, in: note.body).lines)
            .joined(separator: "\n")
    }

    /// The note with that text in place, and nothing else in the note touched.
    ///
    /// **Empty text removes the section, heading and all.** A heading with nothing under it is a
    /// promise the note does not keep, and clearing what you wrote should leave the note as it
    /// was — the same reasoning that makes `setStatus(.active)` remove the `status:` line rather
    /// than write `status: active` (build 165).
    ///
    /// **A new section goes at the end.** `## Plan` is made above `## Tasks`, because a plan is
    /// read before the work is done; looking back is written after it.
    public static func note(_ note: Note, settingText text: String) -> Note {
        var updated = note
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = note.body.components(separatedBy: "\n")
        let found = MarkdownSection.find(heading, in: note.body)

        if let range = found.range {
            let headingLine = max(range.lowerBound - 1, 0)
            if clean.isEmpty {
                lines.removeSubrange(headingLine..<range.upperBound)
                // Two blank lines can meet where the section was. That one seam is closed and
                // nothing else: collapsing every run of blank lines in the note would be
                // rewriting his own prose to tidy up after ourselves.
                if headingLine > 0, headingLine < lines.count,
                   lines[headingLine - 1].trimmingCharacters(in: .whitespaces).isEmpty,
                   lines[headingLine].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: headingLine)
                }
            } else {
                // A blank line under the heading and one after the text, so the section still
                // reads as markdown — the shape `DayPlan` writes.
                lines.replaceSubrange(range, with: [""] + clean.components(separatedBy: "\n") + [""])
            }
        } else {
            guard !clean.isEmpty else { return note }
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
            lines.append("")
            lines.append(heading)
            lines.append("")
            lines.append(contentsOf: clean.components(separatedBy: "\n"))
            lines.append("")
        }
        updated.body = lines.joined(separator: "\n")
        return updated
    }

    /// The words to write, given what he typed, what the field showed when he began, and what
    /// the note holds now (build 261's rule, in one tested place since build 272).
    ///
    /// **A line on file that differs from what the field showed is never replaced or removed
    /// unseen.** With the note still coming from iCloud the field opens empty, and the line may
    /// have been written on the other device. It is kept, and his new words go below it. When
    /// the note holds what the field showed, his words are simply what is written. Both
    /// **Close the day** (a day) and **How was the week?** (a week) ask this.
    ///
    /// **A space at the edge of the line on file is not a difference.** `text(in:)` drops blank
    /// lines at the ends but keeps the spaces on the first and last text line, and the field's
    /// words are trimmed. A line typed by hand as `A calm week. ` would otherwise look like a
    /// line the field never showed: emptying the field could not remove it, and an edit would
    /// be written below it as a second line.
    public static func words(typed: String, shown: String, onFile: String) -> String {
        let clean = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let before = shown.trimmingCharacters(in: .whitespacesAndNewlines)
        let disk = onFile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !disk.isEmpty, disk != before else { return clean }
        return (clean.isEmpty || onFile.contains(clean)) ? onFile : onFile + "\n\n" + clean
    }

    private static func withoutEdgeBlanks(_ lines: [String]) -> [String] {
        var kept = lines
        while kept.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { kept.removeFirst() }
        while kept.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { kept.removeLast() }
        return kept
    }
}

public extension Note {
    /// The line about this day (or, in a weekly note, this week), or an empty string.
    var lookingBack: String { DayLog.text(in: self) }

    /// This note with that line in place. An empty string takes the section out.
    func settingLookingBack(_ text: String) -> Note { DayLog.note(self, settingText: text) }
}
