import Foundation

/// Which of the vault's open tasks the **All actions** screen shows.
///
/// **In Core, not in the view**, for the reason build 174 moved `actionsForPlanning(on:)` here:
/// this decides what a screen leaves out, and a rule that decides what you do not see is
/// exactly the kind that has to be testable. `ActionFilterTests` pins every answer below.
///
/// **The boxes mean what the Search screen's boxes mean** (build 157): within one row the
/// ticks are an **or**, between rows they are **and**ed, and nothing ticked means no
/// narrowing at all. Two screens that filter must not mean different things by a tick.
public struct ActionFilter: Equatable, Sendable {

    /// When the action is wanted.
    ///
    /// **`noDate` is one of the answers, never the absence of one.** The screen this replaces
    /// had "With a date" and "No date" as two of four choices in a Picker that could only hold
    /// one; here "everything with a date" is the other four ticked together, and "no date" is
    /// its own box. Nothing the old Picker could ask has been lost.
    public enum When: String, CaseIterable, Sendable, Identifiable, Codable {
        case overdue, today, soon, later, noDate

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .soon: return "Next 7 days"
            case .later: return "Later"
            case .noDate: return "No date"
            }
        }

        /// `soon` is the seven days **after** today, so today is counted once and only once.
        /// Overlapping boxes would make two ticks show the same task twice in the count.
        func matches(_ task: TaskItem, today: DateOnly) -> Bool {
            guard let due = task.dueDate else { return self == .noDate }
            switch self {
            case .overdue: return due < today
            case .today: return due == today
            case .soon: return due > today && due <= today.adding(days: 7)
            case .later: return due > today.adding(days: 7)
            case .noDate: return false
            }
        }
    }

    /// A mark the task carries on its own line.
    public enum Mark: String, CaseIterable, Sendable, Identifiable, Codable {
        case next, important

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .next: return "Next action"
            case .important: return "Important"
            }
        }

        func matches(_ task: TaskItem) -> Bool {
            switch self {
            case .next: return task.tags.contains { NoteIndex.normalized($0) == Note.nextActionTag }
            case .important: return task.priority > 0
            }
        }
    }

    public var whens: Set<When>
    public var marks: Set<Mark>
    /// Normalized: lower case, no leading `#`, so a box and a task line can never disagree
    /// about what `#Travel` is (build 143's `normalized`, build 187's `TagName`).
    public var tags: Set<String>

    public init(whens: Set<When> = [], marks: Set<Mark> = [], tags: Set<String> = []) {
        self.whens = whens
        self.marks = marks
        self.tags = Set(tags.map { NoteIndex.normalized($0) })
    }

    public var isEmpty: Bool { whens.isEmpty && marks.isEmpty && tags.isEmpty }

    public func matches(_ ref: TaskRef, today: DateOnly) -> Bool {
        if !whens.isEmpty, !whens.contains(where: { $0.matches(ref.task, today: today) }) { return false }
        if !marks.isEmpty, !marks.contains(where: { $0.matches(ref.task) }) { return false }
        if !tags.isEmpty {
            let own = Set(ref.task.tags.map { NoteIndex.normalized($0) })
            if own.isDisjoint(with: tags) { return false }
        }
        return true
    }

    public func apply(to refs: [TaskRef], today: DateOnly) -> [TaskRef] {
        isEmpty ? refs : refs.filter { matches($0, today: today) }
    }

    /// The tags worth offering as boxes: the ones actually on these actions, plus any already
    /// ticked.
    ///
    /// **The ticked ones are always included**, which is build 175's rule about a control that
    /// can show nothing chosen: a tag whose last action another row has just ruled out would
    /// otherwise vanish from the row while still narrowing the list, and there would be no box
    /// left to untick.
    public static func tagChoices(among refs: [TaskRef], including ticked: Set<String> = []) -> [String] {
        var found = Set(ticked.map { NoteIndex.normalized($0) })
        for ref in refs {
            for tag in ref.task.tags {
                let name = NoteIndex.normalized(tag)
                // `#next` has its own box under Marks. Two boxes for one thing is the fault
                // build 165 named: two words for one state, whichever is prettier.
                if name != Note.nextActionTag { found.insert(name) }
            }
        }
        return found.sorted()
    }

    /// The filter in plain words, for the line shown while the boxes are folded away.
    ///
    /// **Never empty**, so the screen can always say what it is showing — build 157's rule
    /// that a search must never be invisible, in a new place.
    public var summary: String {
        var parts: [String] = []
        if !whens.isEmpty {
            parts.append(When.allCases.filter { whens.contains($0) }.map(\.label).joined(separator: " or "))
        }
        if !marks.isEmpty {
            parts.append(Mark.allCases.filter { marks.contains($0) }.map(\.label).joined(separator: " or "))
        }
        if !tags.isEmpty {
            parts.append(tags.sorted().map { "#\($0)" }.joined(separator: " or "))
        }
        return parts.isEmpty ? "Every open action" : parts.joined(separator: " · ")
    }
}
