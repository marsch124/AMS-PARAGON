import Foundation

/// The chain the whole app is built on, gathered in one place: Area → Aspiration → Goal →
/// Project → Task.
///
/// He chose this shape for the Goals screen from a preview of three
/// (https://claude.ai/code/artifact/5ccd27ac-0b62-4895-8e62-b575ca226861), build 162: the
/// middle column lists the aspirations, and picking one draws everything working towards it
/// under it. Nothing here writes; it is all read out of frontmatter that already exists.
///
/// It lives in Core, with tests, because it decides what serves what — and that is the same
/// question the Map, the review and the goal dashboard each answer in their own way. One
/// answer, shared, is the only way the four screens can agree.

/// One project under a goal, with the one thing to do next on it.
public struct ChainProject: Identifiable, Equatable, Sendable {
    public var note: Note
    public var openTaskCount: Int
    /// The task tagged `#next`, else the first open top-level task, else nil.
    public var nextAction: TaskItem?
    /// True when the project is live and has no open task at all. That is a real finding for
    /// the review: a project nobody can act on.
    public var hasNothingToDo: Bool
    public var isFinished: Bool

    public var id: String { note.relativePath }

    public init(note: Note) {
        self.note = note
        let open = note.tasks.filter { !$0.isDone && !$0.isSubtask && $0.status != .cancelled }
        self.openTaskCount = open.count
        self.nextAction = note.nextAction ?? open.first
        self.isFinished = note.isFinishedProject
        self.hasNothingToDo = !note.isFinishedProject && open.isEmpty
    }
}

/// One dated goal under an aspiration, with the projects that deliver it.
public struct ChainGoal: Identifiable, Equatable, Sendable {
    public var note: Note
    public var progress: GoalProgress
    /// The live projects. Finished ones are kept apart, the same split `GoalHealth` makes.
    public var projects: [ChainProject]
    public var finishedProjects: [ChainProject]
    /// Areas that serve this goal. An area is a standard you keep up, not a path to an
    /// outcome, so it is listed but never counted in `progress` (build 141).
    public var areas: [Note]
    public var flags: [GoalHealth.Flag]

    public var id: String { note.relativePath }
    public var needsAttention: Bool { !flags.isEmpty && flags != [.achieved] }
}

/// An aspiration and everything working towards it.
public struct AspirationChain: Identifiable, Equatable, Sendable {
    public var note: Note
    /// The area this aspiration sits in, when its `area:` line names one that exists.
    public var area: Note?
    public var goals: [ChainGoal]
    /// Projects and areas pointing straight at the aspiration, with no dated goal between.
    /// Not a fault — some things are held rather than delivered — so they are shown, not
    /// flagged.
    public var projects: [ChainProject]
    public var areas: [Note]
    public var progress: GoalProgress
    public var flags: [GoalHealth.Flag]

    public var id: String { note.relativePath }

    /// Nothing at all works towards this aspiration yet.
    public var isBare: Bool { goals.isEmpty && projects.isEmpty && areas.isEmpty }

    /// Every dated goal under it that wants looking at.
    public var goalsNeedingAttention: [ChainGoal] { goals.filter(\.needsAttention) }
}

public extension NoteIndex {
    /// The aspirations: goals with no date, which say what you are becoming rather than what
    /// you will have done. Archived ones are left out.
    func aspirations() -> [Note] {
        notes(kind: .goal)
            .filter { !$0.isArchived && ($0.horizon ?? .year) == .life }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Dated goals with no aspiration above them. They are not a fault either — a goal can
    /// stand on its own — but they have to be drawn somewhere, or picking an aspiration would
    /// hide them (build 100's rule: an absence has to be visible).
    func goalsOutsideAnyAspiration() -> [Note] {
        notes(kind: .goal)
            .filter { note in
                guard !note.isArchived, (note.horizon ?? .year) != .life else { return false }
                guard let reference = note.goal else { return true }
                return goal(matching: reference).map { $0.horizon != .life } ?? true
            }
            .sorted { a, b in
                let ta = a.targetDate, tb = b.targetDate
                if ta != tb { return (ta ?? DateOnly(year: 9999, month: 12, day: 31)) < (tb ?? DateOnly(year: 9999, month: 12, day: 31)) }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
    }

    /// One dated goal with the work under it.
    func chainGoal(of goal: Note, today: DateOnly = .today(), calendar: Calendar = .current) -> ChainGoal {
        let health = goalHealth(of: goal, today: today, calendar: calendar)
        return ChainGoal(note: goal,
                         progress: health.progress,
                         projects: health.projects.map(ChainProject.init),
                         finishedProjects: health.finishedProjects.map(ChainProject.init),
                         areas: health.areas,
                         flags: health.flags)
    }

    /// An aspiration and the whole chain beneath it.
    func chain(of aspiration: Note, today: DateOnly = .today(), calendar: Calendar = .current) -> AspirationChain {
        let health = goalHealth(of: aspiration, today: today, calendar: calendar)
        let goals = health.subgoals
            .sorted { a, b in
                let ta = a.targetDate, tb = b.targetDate
                if ta != tb { return (ta ?? DateOnly(year: 9999, month: 12, day: 31)) < (tb ?? DateOnly(year: 9999, month: 12, day: 31)) }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
            .map { chainGoal(of: $0, today: today, calendar: calendar) }
        let area = aspiration.area.flatMap { reference in
            notes(kind: .area).first { $0.title.localizedCaseInsensitiveCompare(reference) == .orderedSame }
                ?? note(matching: reference).flatMap { $0.kind == .area ? $0 : nil }
        }
        return AspirationChain(note: aspiration,
                               area: area,
                               goals: goals,
                               projects: health.projects.map(ChainProject.init)
                                   + health.finishedProjects.map(ChainProject.init),
                               areas: health.areas,
                               progress: health.progress,
                               flags: health.flags)
    }

    /// Every aspiration with its chain, the ones wanting attention first — the same order the
    /// review uses, so the two screens put the same thing on top.
    func aspirationChains(today: DateOnly = .today(), calendar: Calendar = .current) -> [AspirationChain] {
        aspirations().map { chain(of: $0, today: today, calendar: calendar) }
    }
}
