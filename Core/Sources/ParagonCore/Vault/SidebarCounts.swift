import Foundation

/// The sidebar's numbers that come from reading every note, worked out **once per change of
/// the notes** and never while a row is drawn (hardening 07, the same rule as build 253's
/// `projectGroups`). Each used to be asked in the sidebar's body, per row, on every change the
/// model publishes; on 5,000 notes that was seconds per redraw.
///
/// Four of them compare against today, so the value carries the `day` it was counted for and
/// whoever keeps it works it out again once the date has moved (build 254's rule: a cache
/// built from today has to know which today).
public struct SidebarCounts: Equatable, Sendable {
    public var day: DateOnly
    /// Open tasks due today or earlier, archived notes left out: `openTasks(dueOnOrBefore: day)`.
    public var dueByToday = 0
    /// Every open task outside the archive: `openTasks(includeArchived: false)`.
    public var openTasks = 0
    /// Tasks ticked on `day`: `tasksCompleted(on: day)`.
    public var doneToday = 0
    /// `allTags.count`.
    public var tags = 0
    /// `review(config:).projectsNeedingAttention.count`.
    public var projectsNeedingAttention = 0
    public var aspirations = 0
    public var datedGoals = 0
    /// Projects still running: not ended, not archived (build 253).
    public var liveProjects = 0
    public var notesByKind: [ParaKind: Int] = [:]

    public init(day: DateOnly = .today()) { self.day = day }
}

public extension NoteIndex {
    /// One pass over the notes; each note's tasks are read once (`Note.tasks` keeps them).
    /// Every number is the count of the list its screen draws — `SidebarCountsTests` pins each
    /// against that list, so a rule changed there cannot leave the sidebar behind unnoticed.
    func sidebarCounts(today: DateOnly = .today(), config: VaultConfig, calendar: Calendar = .current) -> SidebarCounts {
        var counts = SidebarCounts(day: today)
        var tags = Set<String>()
        for note in notes {
            counts.notesByKind[note.kind, default: 0] += 1
            note.tags.forEach { tags.insert($0) }
            let archived = note.isArchived
            for task in note.tasks {
                task.tags.forEach { tags.insert($0) }
                if task.doneDay == today { counts.doneToday += 1 }
                if !archived, !task.isDone {
                    counts.openTasks += 1
                    if let due = task.dueDate, due <= today { counts.dueByToday += 1 }
                }
            }
            switch note.kind {
            case .project where !archived && !note.isEnded:
                counts.liveProjects += 1
                if health(of: note, today: today, config: config, calendar: calendar).needsAttention {
                    counts.projectsNeedingAttention += 1
                }
            case .goal where !archived && !note.isEnded:
                if (note.horizon ?? .year) == .life { counts.aspirations += 1 } else { counts.datedGoals += 1 }
            default: break
            }
        }
        counts.tags = tags.count
        return counts
    }
}
