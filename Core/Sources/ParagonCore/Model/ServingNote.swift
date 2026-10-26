import Foundation

/// The line that ties a new note to the note it was made from (build 269).
///
/// **The link key is a parameter, not a fixed `goal:`.** Build 269 makes a project from its
/// goal and a goal from its aspiration, both through `goal:`; the area page (planned as build
/// 275) makes a project from its area through `area:`, with the same button. One rule for both,
/// so the two can never come to write different lines for the same idea.
public enum ServingLink: String, CaseIterable, Sendable {
    /// `goal:` — a project serves a goal with a date; a goal with a date serves an aspiration.
    case goal
    /// `area:` — a project is kept in an area.
    case area

    /// The key the line is written under in the new note's settings block.
    public var key: String { rawValue }
}

/// What **Add a project…** or **Add a goal…** makes, and the lines it writes (build 269).
///
/// **In Core, with tests, because it decides a stored value.** The `goal:` line a new project
/// is given is the very line the chain reads back, so a test pins that a note made this way is
/// among `chainGoal(of:).projects` — otherwise the button could make a project that looks
/// linked and is not.
///
/// The value is the parent's `displayTitle`, the same value `AppModel.setGoal` and `setArea`
/// write. A note made here and a note linked by hand are therefore the same note.
///
/// **An aspiration makes a goal with a date, never a project** (his answer, 21 October): the
/// chain is aspiration, then goal, then project, and a project straight under an aspiration
/// skips the step that gives the work a date. The new goal has no `target:` yet; the goal's
/// own **Set a target date…** (build 268) is where it gets one.
public struct ServingNote: Equatable, Sendable {
    /// One line of the new note's settings block. A struct rather than a tuple, so two plans
    /// can be compared in a test.
    public struct Line: Equatable, Sendable {
        public let key: String
        public let value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    /// The kind of note that is made.
    public let kind: ParaKind
    /// The lines written into the new note's settings block, in the order they are written.
    public let lines: [Line]
    /// The parent's title, exactly as the link line carries it.
    public let parentTitle: String
    /// Which line ties the new note to its parent.
    public let link: ServingLink

    public init(under parent: Note, link: ServingLink) {
        let title = parent.displayTitle
        self.parentTitle = title
        self.link = link
        if link == .goal, parent.kind == .goal, (parent.horizon ?? .year) == .life {
            self.kind = .goal
            self.lines = [Line(key: "horizon", value: GoalHorizon.year.rawValue),
                          Line(key: link.key, value: title)]
        } else {
            self.kind = .project
            self.lines = [Line(key: link.key, value: title)]
        }
    }

    /// True when the note made is a goal with a date, false when it is a project.
    public var makesAGoal: Bool { kind == .goal }

    /// The lines in the shape `Vault.createNote(extraFrontmatter:)` takes.
    public var frontmatter: [(String, String)] {
        lines.map { ($0.key, $0.value) }
    }

    /// A note of the same kind that already goes by this name, or nil.
    ///
    /// **Asked before anything is written**, so the popover can say so itself and stay open
    /// with the words in it, never an alert behind it (builds 238 and 246). Both the title and
    /// the file name count, without regard to capitals: a Mac disk treats "buy the maps.md" and
    /// "Buy the maps.md" as one file, and two goals with one name would make a `goal:` line
    /// point at either.
    public static func existing(named name: String, kind: ParaKind, among notes: [Note]) -> Note? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        let file = Vault.sanitizeFileName(wanted)
        return notes.first { note in
            guard note.kind == kind else { return false }
            if note.title.caseInsensitiveCompare(wanted) == .orderedSame { return true }
            return !file.isEmpty && note.fileName.caseInsensitiveCompare(file) == .orderedSame
        }
    }
}
