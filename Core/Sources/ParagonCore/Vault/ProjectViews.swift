import Foundation

/// The four ways the Projects page can be shown — build 344, his pick from a numbered picture
/// on 20 Nov 2026: *"I would like an easy way to find an overview of all projects"*, then
/// *"Build 1, 2 and a version of two where all projects have some minimal info in the (larger)
/// box each. We need a premium way to choose between the four views."*
///
/// Everything that decides **which project is where** lives here, with tests: which column of
/// the board a project stands in, what dropping a card there does, and the order of the List.
/// The views only draw it.
public enum ProjectsLayout: String, CaseIterable, Identifiable, Sendable {
    /// The page as it was: grouped under the aspiration and goal each project serves.
    case byGoal
    /// One line per project, in columns, sortable.
    case list
    /// Columns by state; drag a card to change its state.
    case board
    /// A grid of larger boxes: icon, name, progress, deadline, goal (his pick of what a card shows).
    case cards

    public var id: String { rawValue }

    /// The word on the switch.
    public var title: String {
        switch self {
        case .byGoal: return "By goal"
        case .list: return "List"
        case .board: return "Board"
        case .cards: return "Cards"
        }
    }

    /// Where the last view used is kept, per device (his pick: "The last one I used").
    public static let storageKey = "projectsLayout"

    /// Command-Option and this number chooses it on the Mac.
    public var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}

/// A column of the board — his pick: "By state", with dragging.
public enum BoardColumn: String, CaseIterable, Identifiable, Sendable {
    case needsALook, running, onHold, done

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .needsALook: return "Needs a look"
        case .running: return "Running"
        case .onHold: return "On hold"
        case .done: return "Done"
        }
    }

    /// The state a card dropped here gets. Nil for Needs a look: a project comes there by its
    /// dates (an overdue task, a passed deadline, a deadline after its goal), never by a drag —
    /// a drag cannot make a date late.
    public var dropStatus: NoteStatus? {
        switch self {
        case .needsALook: return nil
        case .running: return .active
        case .onHold: return .onHold
        case .done: return .done
        }
    }

    /// The column a project stands in. Running projects with a late date go to Needs a look —
    /// the very rule of the orange "needs a look" count above the list (`ProjectLine.needsALook`),
    /// so the board and the count can never disagree. Missed, dropped and archived projects are
    /// not on the board: they keep their own groups in By goal.
    public static func column(of line: ProjectLine) -> BoardColumn? {
        switch line.status {
        case .active: return line.needsALook ? .needsALook : .running
        case .onHold: return .onHold
        case .done: return .done
        case .missed, .dropped, .archived: return nil
        }
    }
}

/// One column of the board with its projects.
public struct BoardStack: Identifiable, Equatable, Sendable {
    public var column: BoardColumn
    public var lines: [ProjectLine]
    public var id: String { column.rawValue }
}

/// How the List is sorted. `attention` is the order it opens in (his pick: "Needs a look first").
public enum ProjectSort: String, CaseIterable, Identifiable, Sendable {
    case attention, name, goal, state, next, deadline

    public var id: String { rawValue }

    /// The column heading. `attention` has none: it is the order before any heading is pressed.
    public var heading: String {
        switch self {
        case .attention: return ""
        case .name: return "Project"
        case .goal: return "Goal"
        case .state: return "State"
        case .next: return "Next"
        case .deadline: return "Deadline"
        }
    }
}

public enum ProjectOverview {
    /// Every project of the groups once, in the groups' order (his own order inside each).
    /// `includeEnded: false` leaves out Done, Missed, Dropped and Archived: the List and the
    /// Cards show the projects still in play.
    public static func lines(of groups: [ProjectGroup], includeEnded: Bool) -> [ProjectLine] {
        var seen = Set<String>()
        var result: [ProjectLine] = []
        for group in groups {
            for line in group.lines where seen.insert(line.id).inserted {
                if !includeEnded, line.status.isEnded || line.status == .archived { continue }
                result.append(line)
            }
        }
        return result
    }

    /// The four columns, always all four (an empty column is still a place to drop a card).
    /// Inside a column the order is the groups' order; Done shows the newest ending first, as
    /// the Done group does.
    public static func board(of groups: [ProjectGroup]) -> [BoardStack] {
        let all = lines(of: groups, includeEnded: true)
        return BoardColumn.allCases.map { column in
            var lines = all.filter { BoardColumn.column(of: $0) == column }
            if column == .done { lines = ProjectGroup.newestFirst(lines) }
            return BoardStack(column: column, lines: lines)
        }
    }

    /// A running project with no next task: all its tasks finished, only waiting lines, or no
    /// tasks yet — what its row calls "No next action". Build 345, his pick of my idea: a
    /// button above the List shows only these. A project on hold is never counted: it is
    /// paused on purpose.
    public static func needsNextAction(_ line: ProjectLine) -> Bool {
        guard line.status == .active else { return false }
        if case .next = line.need { return false }
        return true
    }

    /// The words on that button.
    public static func needsNextActionText(_ count: Int) -> String {
        count == 1 ? "1 needs a next action" : "\(count) need a next action"
    }

    /// How urgent a project is for the "needs a look first" order: a late date, then running
    /// with nothing to do next, then running with a next task, then on hold, then the rest.
    public static func attentionRank(_ line: ProjectLine) -> Int {
        if line.needsALook { return 0 }
        switch line.status {
        case .active:
            if case .next = line.need { return 2 }
            return 1
        case .onHold: return 3
        default: return 4
        }
    }

    /// The List in the chosen order. Stable: equal projects keep his own order. A project
    /// without the value sorted by (no goal, no next task, no deadline) always goes last, in
    /// either direction — an empty cell at the top would push the answers down.
    public static func sorted(_ lines: [ProjectLine], by sort: ProjectSort, ascending: Bool = true) -> [ProjectLine] {
        let indexed = Array(lines.enumerated())
        let ordered = indexed.sorted { a, b in
            let result = compare(a.element, b.element, by: sort)
            switch result {
            case .orderedSame: return a.offset < b.offset
            case .missingFirst: return false
            case .missingSecond: return true
            case .ascending: return ascending
            case .descending: return !ascending
            }
        }
        return ordered.map(\.element)
    }

    private enum Order { case ascending, descending, orderedSame, missingFirst, missingSecond }

    private static func compare(_ a: ProjectLine, _ b: ProjectLine, by sort: ProjectSort) -> Order {
        switch sort {
        case .attention:
            let ra = attentionRank(a), rb = attentionRank(b)
            if ra != rb { return ra < rb ? .ascending : .descending }
            // Inside one rank: the soonest deadline first, no deadline after.
            return optional(a.deadline, b.deadline) { $0 < $1 }
        case .name:
            return text(a.note.title, b.note.title)
        case .goal:
            return optionalText(a.goal?.title, b.goal?.title)
        case .state:
            let ra = stateRank(a), rb = stateRank(b)
            return ra == rb ? .orderedSame : (ra < rb ? .ascending : .descending)
        case .next:
            return optionalText(a.nextTitle, b.nextTitle)
        case .deadline:
            return optional(a.deadline, b.deadline) { $0 < $1 }
        }
    }

    /// Running first, then Needs a look's own kind of running, on hold, and the ended ones.
    private static func stateRank(_ line: ProjectLine) -> Int {
        switch line.status {
        case .active: return 0
        case .onHold: return 1
        case .done: return 2
        case .missed: return 3
        case .dropped: return 4
        case .archived: return 5
        }
    }

    private static func text(_ a: String, _ b: String) -> Order {
        switch a.localizedStandardCompare(b) {
        case .orderedAscending: return .ascending
        case .orderedDescending: return .descending
        case .orderedSame: return .orderedSame
        }
    }

    private static func optionalText(_ a: String?, _ b: String?) -> Order {
        switch (a, b) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .missingFirst
        case (_, nil): return .missingSecond
        case let (x?, y?): return text(x, y)
        }
    }

    private static func optional<T: Equatable>(_ a: T?, _ b: T?, less: (T, T) -> Bool) -> Order {
        switch (a, b) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .missingFirst
        case (_, nil): return .missingSecond
        case let (x?, y?): return x == y ? .orderedSame : (less(x, y) ? .ascending : .descending)
        }
    }
}
