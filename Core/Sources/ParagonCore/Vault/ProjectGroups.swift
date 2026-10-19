import Foundation

/// The Projects list, grouped under what each project works towards — build 253, the shape
/// drawn in https://claude.ai/artifact/4ByhCcS4cA5kYYNH41b6ap.
///
/// **Why it exists.** His words: *"The project list is a bit boring … I need to get inspired by
/// the app so that I feel like using it."* The list was one flat run of identical rows: seven of
/// his nine projects had every task ticked and were still Active, so each showed a full bar and
/// "1 of 1" and looked finished. Core already knew the truth — `ProjectHealth.noNextAction`,
/// `ChainProject.hasNothingToDo` — and the list never asked for it.
///
/// It lives in Core, with tests, because it decides two things he reads: **which group a project
/// is in**, and **what its box says it needs**. Both follow the chain the rest of the app uses
/// (`goal(matching:)`, `aspirations()`, `NoteStatus`), so the Projects list, the Goals rooms and
/// the review cannot give three answers to "what is this for?".
///
/// Nothing here writes. Every fact is read from frontmatter and task lines that already exist,
/// and every one of them already has a control that writes it.

/// One project, with what its box says.
public struct ProjectLine: Identifiable, Equatable, Sendable {
    /// What the project needs, in the order the box says it.
    public enum Need: Equatable, Sendable {
        /// At least one open task. The task is the one tagged `#next`, else the first open one —
        /// the same rule `ChainProject` and the planner use.
        case next(TaskItem)
        /// It has tasks and every one is finished. Two true facts at once: the work is done, and
        /// the project is still open. The box says both.
        case allFinished(count: Int)
        /// Not one task yet. Said in words, never as an empty bar (build 141).
        case noTasks
    }

    public var note: Note
    /// Read through `NoteStatus`, never the raw string (build 165).
    public var status: NoteStatus
    public var need: Need
    /// Top-level tasks, cancelled ones left out: the same count `Note.progress` gives.
    public var done: Int
    public var total: Int
    public var openCount: Int
    /// Open tasks whose date has passed, subtasks included — what the review calls overdue.
    public var overdueCount: Int
    /// The goal the `goal:` line resolves to. Nil when there is no line, or it names nothing.
    public var goal: Note?
    /// The `goal:` line names something that cannot be found. Drawn dashed: not connected.
    public var goalIsMissing: Bool
    /// The project's own `due:` date.
    public var deadline: DateOnly?
    public var deadlinePassed: Bool
    /// The deadline is later than the target date of the goal it is meant to deliver — the
    /// review's own `dueAfterGoal`.
    public var dueAfterGoal: Bool

    public var id: String { note.relativePath }

    /// The task to do next, when there is one.
    public var nextTask: TaskItem? {
        guard case .next(let task) = need else { return nil }
        return task
    }

    /// Its title as the box shows it, with `#next` left out: the box shows the task *because*
    /// of that tag, so the word says nothing there — the widget's rule (build 174). His own
    /// tags stay, because those carry information.
    public var nextTitle: String? {
        nextTask.map { WidgetSnapshot.widgetTitle($0.title) }
    }

    init(note: Note, index: NoteIndex, today: DateOnly) {
        self.note = note
        self.status = note.noteStatus
        // Parsed once: `Note.tasks` reads the whole body every time it is asked.
        let tasks = note.tasks
        let top = tasks.filter { !$0.isSubtask && $0.status != .cancelled }
        let open = top.filter { !$0.isDone }
        done = top.filter { $0.status == .done }.count
        total = top.count
        openCount = open.count
        let tagged = open.first { $0.tags.contains(Note.nextActionTag) }
        if let next = tagged ?? open.first {
            need = .next(next)
        } else if total > 0 {
            need = .allFinished(count: total)
        } else {
            need = .noTasks
        }
        overdueCount = tasks.filter { task in
            guard !task.isDone, let due = task.dueDate else { return false }
            return due < today
        }.count
        if let reference = note.goal {
            let found = index.goal(matching: reference)
            goal = found
            goalIsMissing = found == nil
        } else {
            goal = nil
            goalIsMissing = false
        }
        deadline = note.dueDate
        deadlinePassed = note.dueDate.map { $0 < today } ?? false
        if let due = note.dueDate, let target = goal?.targetDate {
            dueAfterGoal = due > target
        } else {
            dueAfterGoal = false
        }
    }

    /// Something about it is late or cannot work: an overdue task, a passed deadline, or a
    /// deadline after its goal's target. The same three the review counts as wanting attention
    /// for a date. **Not** "no next action": that is true of most of his projects today, and a
    /// list painted orange for it would read as a telling-off (build 132's rule).
    public var needsALook: Bool {
        guard !status.isEnded, status != .onHold, status != .archived else { return false }
        return overdueCount > 0 || deadlinePassed || dueAfterGoal
    }

    // MARK: Wording — in Core because it decides what he reads, and two screens may say it

    /// "Its one task is finished" or "All 15 finished".
    public static func finishedText(count: Int) -> String {
        count == 1 ? "Its one task is finished" : "All \(count) finished"
    }

    /// "5 of 8 finished".
    public static func progressText(done: Int, total: Int) -> String {
        "\(done) of \(total) finished"
    }

    /// "Deadline today", "Deadline in 11 days", "Deadline 12 days over". The plain words of
    /// `timeLeftText`, never "Due in 5 d" (invented shorthand).
    public static func deadlineText(_ deadline: DateOnly, today: DateOnly, calendar: Calendar = .current) -> String {
        "Deadline " + deadline.timeLeftText(from: today, calendar: calendar)
    }

    /// "1 overdue", "3 overdue".
    public static func overdueText(_ count: Int) -> String {
        "\(count) overdue"
    }
}

/// One group in the Projects list.
public struct ProjectGroup: Identifiable, Equatable, Sendable {
    public enum Heading: Equatable, Sendable {
        /// The aspiration its projects work towards, directly or through a goal with a date.
        case aspiration(Note)
        /// They serve a goal, but there is no aspiration above it, or the goal cannot be found.
        case notLinked
        /// No `goal:` line at all. The review's own words for them (build 140).
        case noGoal
        /// Over: done, missed or dropped — one group each, never one for all three (build
        /// 165) — or, rarely, archived while still in the Projects folder.
        case ended(NoteStatus)
    }

    public var heading: Heading
    /// In the order they were handed in, which is his own hand order.
    public var lines: [ProjectLine]

    public var id: String {
        switch heading {
        case .aspiration(let note): return "aspiration:" + note.relativePath
        case .notLinked: return "notLinked"
        case .noGoal: return "noGoal"
        case .ended(let status): return "ended:" + status.rawValue
        }
    }

    /// The heading's words. Each is true of every project under it.
    public var title: String {
        switch heading {
        case .aspiration(let note): return note.title
        case .notLinked: return ProjectGroup.notLinkedTitle
        case .noGoal: return ProjectGroup.noGoalTitle
        case .ended(let status): return status.label
        }
    }

    public var isEnded: Bool {
        if case .ended = heading { return true }
        return false
    }

    /// How many of its projects want a look. Shown on the heading, so a folded group still says.
    public var needsALookCount: Int { lines.filter(\.needsALook).count }

    public static let notLinkedTitle = "Not linked to an aspiration"
    public static let noGoalTitle = "Projects with no goal"
}

public extension NoteIndex {
    /// The aspiration a project works towards: its goal, when that goal is an aspiration, or
    /// the aspiration above its goal with a date. Nil when the chain stops before one.
    func aspiration(above project: Note) -> Note? {
        guard let reference = project.goal, let served = goal(matching: reference) else { return nil }
        if (served.horizon ?? .year) == .life { return served }
        guard let upper = served.goal,
              let top = goal(matching: upper),
              top.relativePath != served.relativePath,
              (top.horizon ?? .year) == .life else { return nil }
        return top
    }

    /// The Projects list in groups (build 253).
    ///
    /// - One group per aspiration that has a live project under it, in the order of the
    ///   **Aspirations** room (`aspirations()`, by title), so the two screens agree. An
    ///   aspiration that has itself ended but still has live projects under it comes after the
    ///   live ones, by title — the projects are still work and must not vanish (build 100).
    /// - **Not linked to an aspiration**, then **Projects with no goal**.
    /// - **Done**, **Missed**, **Dropped**, then **Archived** for the rare note whose status says
    ///   archived but which still sits in the Projects folder.
    ///
    /// Inside a group the projects keep the order they were handed in, which is his own hand
    /// order. Groups with nothing in them are left out. Every project lands in exactly one
    /// group, so no list ever draws it twice (builds 71–74).
    func projectGroups(_ projects: [Note], today: DateOnly = .today()) -> [ProjectGroup] {
        var underAspiration: [String: [ProjectLine]] = [:]
        var aspirationNotes: [String: Note] = [:]
        var notLinked: [ProjectLine] = []
        var noGoal: [ProjectLine] = []
        var ended: [NoteStatus: [ProjectLine]] = [:]
        for project in projects {
            let line = ProjectLine(note: project, index: self, today: today)
            if line.status.isEnded || line.status == .archived {
                ended[line.status, default: []].append(line)
            } else if project.goal == nil {
                noGoal.append(line)
            } else if let top = aspiration(above: project) {
                underAspiration[top.relativePath, default: []].append(line)
                aspirationNotes[top.relativePath] = top
            } else {
                notLinked.append(line)
            }
        }
        let live = aspirations()
        let livePaths = Set(live.map(\.relativePath))
        let others = aspirationNotes.values
            .filter { !livePaths.contains($0.relativePath) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        var groups: [ProjectGroup] = []
        for top in live + others {
            guard let lines = underAspiration[top.relativePath], !lines.isEmpty else { continue }
            groups.append(ProjectGroup(heading: .aspiration(top), lines: lines))
        }
        if !notLinked.isEmpty { groups.append(ProjectGroup(heading: .notLinked, lines: notLinked)) }
        if !noGoal.isEmpty { groups.append(ProjectGroup(heading: .noGoal, lines: noGoal)) }
        for status in NoteStatus.endings + [.archived] {
            if let lines = ended[status], !lines.isEmpty {
                groups.append(ProjectGroup(heading: .ended(status), lines: lines))
            }
        }
        return groups
    }
}

/// His own order, inside a grouped list.
public enum ProjectOrder {
    /// A drag inside one group, mapped back onto the whole list of projects.
    ///
    /// **The group's projects keep the slots they already hold in `whole`.** Numbering one group
    /// on its own from 10 would collide with the next group's numbers, and every other place that
    /// lists projects in this order — the Inbox's **File it** column, the task's **Move to**
    /// menu — would come out interleaved. So the projects outside the group never move, and
    /// the ones inside it trade places among themselves.
    ///
    /// `source` and `destination` mean what SwiftUI's `onMove` means by them: offsets in
    /// `group`, with `destination` counted before anything is taken out.
    public static func moving(_ group: [Note], within whole: [Note], from source: IndexSet, to destination: Int) -> [Note] {
        let arranged = moved(group, from: source, to: destination)
        let members = Set(group.map(\.relativePath))
        var next = arranged.makeIterator()
        return whole.map { note in
            guard members.contains(note.relativePath) else { return note }
            return next.next() ?? note
        }
    }

    /// `Array.move(fromOffsets:toOffset:)`, which lives in SwiftUI and so not here.
    static func moved(_ items: [Note], from source: IndexSet, to destination: Int) -> [Note] {
        let picked = source.sorted().filter { items.indices.contains($0) }
        guard !picked.isEmpty else { return items }
        var rest = items
        let moving = picked.map { items[$0] }
        for index in picked.reversed() { rest.remove(at: index) }
        let before = picked.filter { $0 < destination }.count
        let at = max(0, min(rest.count, destination - before))
        rest.insert(contentsOf: moving, at: at)
        return rest
    }
}
