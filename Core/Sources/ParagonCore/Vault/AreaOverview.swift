import Foundation

/// The top of an area note (build 270, idea 4 "Areas come alive"): what the area holds and
/// whether work in it is moving.
///
/// **In Core, with tests, because it decides what he reads.** Which projects are listed, which
/// are only counted, what each project's box says it needs, and which finished tasks go into
/// the bars. The box line is `ProjectLine` — the very line the **Projects** list draws — so a
/// project cannot say "Next: Buy shoes" in one place and "No next action" in the other
/// (`Note.nextThing`, build 254).
///
/// **His answers (21 October).** Only the `area:` line puts a project in an area
/// (`link_rule`, build 269's `projects(in:)`), and the projects of a sub-area are **not**
/// listed on its parent: the parent gets one row per sub-area instead (`subarea_projects`),
/// so each project is shown in one place.
///
/// Nothing here writes.
public struct AreaOverview: Equatable, Sendable {
    /// The area itself.
    public var area: Note
    /// Its projects that are running or on hold, in his own hand order (`order:`, then by
    /// title) — the order of the **Projects** list's flat search and the Inbox's **File it**.
    public var projects: [ProjectLine]
    /// Its projects that are over: done, missed, dropped or archived. Counted, never listed:
    /// the page is about the work that is going on.
    public var overCount: Int
    /// Its sub-areas, in list order, one row each.
    public var subAreas: [SubAreaLine]
    /// Tasks finished in each of the last eight weeks, in the area's own text and in every
    /// project in it — the over ones too, because finished work counts in the week it was done.
    /// A sub-area's work is on the sub-area's own page, not here.
    public var weekly: WeeklyFinished

    public init(area: Note, projects: [ProjectLine], overCount: Int,
                subAreas: [SubAreaLine], weekly: WeeklyFinished) {
        self.area = area
        self.projects = projects
        self.overCount = overCount
        self.subAreas = subAreas
        self.weekly = weekly
    }

    // MARK: Wording — in Core because it decides what he reads

    /// What the list says when no project is running or on hold. Two sentences, because "yet"
    /// would be untrue of an area whose projects have all ended.
    public var emptyText: String {
        overCount == 0 ? "No projects in this area yet." : "No projects in this area right now."
    }

    /// The line under the list about the projects that are over, or nil when there are none —
    /// never "0 projects" (build 141).
    public var overText: String? {
        switch overCount {
        case 0: return nil
        case 1: return "Not shown here: 1 project that is done, missed, dropped or archived."
        default: return "Not shown here: \(overCount) projects that are done, missed, dropped or archived."
        }
    }

    /// "No projects", "1 project", "3 projects". A word for none, never a zero.
    public static func projectsText(_ count: Int) -> String {
        switch count {
        case 0: return "No projects"
        case 1: return "1 project"
        default: return "\(count) projects"
        }
    }

    /// A project that is still work: not over and not archived. On hold is still work.
    static func isLive(_ project: Note) -> Bool {
        !project.isArchived && !project.isEnded
    }
}

/// One sub-area as a row on its parent's page: "Yoga · 1 project · 3 open". Press it to open
/// the sub-area, where its own projects are listed.
public struct SubAreaLine: Identifiable, Equatable, Sendable {
    public var note: Note
    /// Its own projects that are running or on hold.
    public var projectCount: Int
    /// Open tasks in the sub-area's own text and in those projects.
    public var openTaskCount: Int

    public var id: String { note.relativePath }

    public init(note: Note, projectCount: Int, openTaskCount: Int) {
        self.note = note
        self.projectCount = projectCount
        self.openTaskCount = openTaskCount
    }

    /// "1 project · 3 open", "2 projects", "No projects · 2 open", "No projects". The open
    /// count is left out when it is nothing, never written as "0 open".
    public var factsText: String {
        let projects = AreaOverview.projectsText(projectCount)
        return openTaskCount > 0 ? projects + " \u{00B7} \(openTaskCount) open" : projects
    }
}

public extension NoteIndex {
    /// What the top of an area note shows (build 270).
    ///
    /// - The projects are `projects(in:)` (build 269): every note that says it is a project and
    ///   whose `area:` line names this area, archived ones too, in hand order. The running and
    ///   on-hold ones are listed as `ProjectLine`s; the rest are only counted.
    /// - The sub-areas are `subAreas(of:)`, each with its own live projects and open tasks.
    /// - The bars count the area's own finished tasks and those of every project in it.
    func areaOverview(of area: Note, today: DateOnly = .today()) -> AreaOverview {
        let all = projects(in: area)
        let live = all.filter(AreaOverview.isLive)
        let lines = live.map { ProjectLine(note: $0, index: self, today: today) }
        let subLines = subAreas(of: area).map { sub -> SubAreaLine in
            let theirs = projects(in: sub).filter(AreaOverview.isLive)
            let open = theirs.reduce(sub.openTasks.count) { $0 + $1.openTasks.count }
            return SubAreaLine(note: sub, projectCount: theirs.count, openTaskCount: open)
        }
        var tasks = area.tasks
        for project in all { tasks += project.tasks }
        return AreaOverview(area: area,
                            projects: lines,
                            overCount: all.count - live.count,
                            subAreas: subLines,
                            weekly: WeeklyFinished(tasks: tasks, today: today))
    }
}
