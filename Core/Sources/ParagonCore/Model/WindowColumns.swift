import Foundation

/// Review round 7 (build 314): how the Mac's main window is laid out.
///
/// **The list takes the whole window until a note is open.** Before, every list lived in a
/// column about 280 points wide beside an empty panel with a grey "New…" button, and the
/// weekly review's headings were cut ("2. Reschedule or drop ove…"). Sections whose right side
/// always has something of its own keep their two parts.
///
/// Sections are named by their key (`SidebarSection.key`), which never changes with the words
/// on screen: Plan is still "Time Blocks" here.
public enum WindowColumns {
    /// The sections whose right side is never empty: where the Inbox's lines can go, the day's
    /// schedule, the planner, the template's text, the chain under a goal.
    public static let alwaysTwoParts: Set<String> = [
        "Inbox", "Calendar", "Time Blocks", "Templates", "Snippets", "Aspirations", "Goals",
    ]

    /// Whether the list fills the window: no note is open, and the section has no right side
    /// of its own.
    public static func listTakesAll(section: String?, noteOpen: Bool) -> Bool {
        guard let section else { return !noteOpen }
        if alwaysTwoParts.contains(section) { return false }
        return !noteOpen
    }

    /// Whether **Close Note** has something to do: a note is open in a section whose list
    /// would then take the whole window again.
    public static func canCloseNote(section: String?, noteOpen: Bool) -> Bool {
        guard noteOpen else { return false }
        guard let section else { return true }
        return !alwaysTwoParts.contains(section)
    }

    /// The list's width beside an open note: his to drag, between these two.
    public static let listWidthRange: ClosedRange<Double> = 220...480
    public static let listWidthAtFirst: Double = 300

    public static func listWidth(_ asked: Double) -> Double {
        min(max(asked, listWidthRange.lowerBound), listWidthRange.upperBound)
    }
}

/// Review round 7 (build 314): the sidebar's four groups, in the iPhone's order, each of which
/// folds. By key, like `WindowColumns`.
public enum SidebarGroups {
    public struct Group: Equatable, Sendable {
        public let name: String
        public let rows: [String]
        /// Folded until he opens it: only Tools, a shelf used now and then.
        public let foldedAtFirst: Bool
    }

    public static let all: [Group] = [
        Group(name: "Do", rows: ["Inbox", "Today", "Time Blocks", "All actions"], foldedAtFirst: false),
        Group(name: "Goals and PARA",
              rows: ["Aspirations", "Goals", "Projects", "Areas", "Resources", "Archive"], foldedAtFirst: false),
        Group(name: "Look back",
              rows: ["Calendar", "Weekly review", "Map", "Recent", "Done", "Deleted"], foldedAtFirst: false),
        Group(name: "Tools", rows: ["Templates", "Snippets", "Tags"], foldedAtFirst: true),
    ]

    /// ⌘1 to ⌘5: the first five rows, top to bottom, where he placed them (round 7). Round 8
    /// adds ⌘6 Projects and ⌘7 Weekly review after them and moves none of the five.
    public static var numbered: [String] { Array(all.flatMap(\.rows).prefix(5)) + ["Projects", "Weekly review"] }

    /// The names of the folded groups as they are kept ("Tools|Look back"), after one is
    /// pressed. Nil = never touched, so the groups are as `foldedAtFirst` says.
    public static func folded(in stored: String?) -> Set<String> {
        guard let stored else { return Set(all.filter(\.foldedAtFirst).map(\.name)) }
        return Set(stored.split(separator: "|").map(String.init))
    }

    public static func toggling(_ group: String, in stored: String?) -> String {
        var names = folded(in: stored)
        if names.contains(group) { names.remove(group) } else { names.insert(group) }
        return all.map(\.name).filter(names.contains).joined(separator: "|")
    }
}
