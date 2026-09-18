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

/// What has actually happened under a goal lately — the answer to "is this alive?".
///
/// Build 163, his pick from the small extras. **"This month" is the last 30 days**, which is
/// what `GoalHealth` already counts, and the wording says so rather than pretending to mean a
/// calendar month.
///
/// **Projects carry no date of their own when they are finished** — `isFinishedProject` reads
/// `status:`, and nothing stamps the day — so this counts how many of the goal's projects are
/// finished in all, never "finished this month". Inventing a date to fill a sentence is the
/// fault build 141 avoided by making `fraction` nil rather than 0.
public struct ChainActivity: Equatable, Sendable {
    /// Tasks ticked in the last 30 days, across everything serving the goal.
    public var tasksFinished: Int
    /// Days since anything under the goal was touched. Nil when nothing can be dated.
    public var daysSinceActivity: Int?
    public var projectsFinished: Int
    public var projectsTotal: Int

    public init(tasksFinished: Int, daysSinceActivity: Int?, projectsFinished: Int, projectsTotal: Int) {
        self.tasksFinished = tasksFinished
        self.daysSinceActivity = daysSinceActivity
        self.projectsFinished = projectsFinished
        self.projectsTotal = projectsTotal
    }

    /// One plain line, or **nil when there is nothing to say** — a line reading "0 tasks
    /// finished, no activity" is worse than no line at all (build 141's rule).
    public var summary: String? {
        var parts: [String] = []
        if tasksFinished > 0 {
            parts.append(tasksFinished == 1 ? "1 task finished in 30 days"
                                            : "\(tasksFinished) tasks finished in 30 days")
        }
        if projectsTotal > 0, projectsFinished > 0 {
            parts.append("\(projectsFinished) of \(projectsTotal) projects finished")
        }
        if let days = daysSinceActivity {
            if days <= 0 { parts.append("something moved today") }
            else if days == 1 { parts.append("last activity yesterday") }
            else { parts.append("last activity \(days) days ago") }
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }
}

public extension DateOnly {
    /// How long there is to go, in plain words: "today", "in 11 days", "in about 3 months",
    /// "11 days over". Build 163, beside a goal's target date.
    ///
    /// It lives here, with tests, because it decides wording the user reads on three screens.
    func timeLeftText(from today: DateOnly, calendar: Calendar = .current) -> String {
        let days = days(since: today, calendar: calendar)
        if days == 0 { return "today" }
        if days < 0 {
            let over = -days
            return over == 1 ? "1 day over" : "\(over) days over"
        }
        if days == 1 { return "tomorrow" }
        if days < 31 { return "in \(days) days" }
        let months = Int((Double(days) / 30.44).rounded())
        if months < 12 { return months == 1 ? "in about a month" : "in about \(months) months" }
        let years = Double(days) / 365.25
        if years < 1.75 { return "in about a year" }
        return "in about \(Int(years.rounded())) years"
    }
}

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
    /// What has happened under this goal lately (build 163).
    public var activity: ChainActivity

    public var id: String { note.relativePath }
    public var needsAttention: Bool { !flags.isEmpty && flags != [.achieved] }
    /// Over, whichever way. It is the `status:` that says so, never the boxes (build 141).
    public var isEnded: Bool { note.isEnded }
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
    /// Goals under it that are over, whichever way they ended (build 165). Kept out of
    /// `goals` so the live chain is short, and shown folded away at the foot under the name
    /// of the ending — a group called **Done** may not hold a goal that was missed.
    public var endedGoals: [ChainGoal]
    public var activity: ChainActivity

    public var id: String { note.relativePath }

    /// Nothing at all works towards this aspiration yet.
    public var isBare: Bool {
        goals.isEmpty && endedGoals.isEmpty && projects.isEmpty && areas.isEmpty
    }

    /// Every dated goal under it that wants looking at.
    public var goalsNeedingAttention: [ChainGoal] { goals.filter(\.needsAttention) }

    /// The aspiration itself wants looking at — the same test `ChainGoal` uses, so the two
    /// rows in the list cannot disagree.
    public var needsAttention: Bool { !flags.isEmpty && flags != [.achieved] }
}

public extension NoteIndex {
    /// The aspirations: goals with no date, which say what you are becoming rather than what
    /// you will have done. Archived ones are left out.
    func aspirations() -> [Note] {
        notes(kind: .goal)
            .filter { !$0.isArchived && !$0.isEnded && ($0.horizon ?? .year) == .life }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// **Every live goal that has a date, soonest first.** The Goals screen's own list
    /// (build 199).
    ///
    /// Before it there was no such list. `Goals` in the sidebar drew the *aspirations*, and a
    /// dated goal only appeared once you had picked the aspiration above it — so a goal whose
    /// aspiration you had not thought to click was off the screen entirely. His words about
    /// that screen: *"I am not choosing an aspiration, no goals are visible on the Goals
    /// page."* One list, no choosing first.
    ///
    /// Ended and archived goals are left out; they have `endedGoals()`, which the screen
    /// folds away at the foot with its count showing.
    func datedGoals() -> [Note] {
        notes(kind: .goal)
            .filter { !$0.isArchived && !$0.isEnded && ($0.horizon ?? .year) != .life }
            .sorted(by: NoteIndex.byTargetThenTitle)
    }

    /// Dated goals with no aspiration above them. They are not a fault either — a goal can
    /// stand on its own — but they have to be drawn somewhere, or picking an aspiration would
    /// hide them (build 100's rule: an absence has to be visible).
    func goalsOutsideAnyAspiration() -> [Note] {
        notes(kind: .goal)
            .filter { note in
                guard !note.isArchived, !note.isEnded, (note.horizon ?? .year) != .life else { return false }
                guard let reference = note.goal else { return true }
                return goal(matching: reference).map { $0.horizon != .life } ?? true
            }
            .sorted(by: NoteIndex.byTargetThenTitle)
    }

    /// Goals that are over, gathered under the name of the ending (build 165). They leave the
    /// live lists — a goal you dropped is not work — and sit in closed groups at the foot,
    /// because hiding them altogether would be build 100's rule broken.
    ///
    /// **One group per ending, never one group for all three.** A group called **Done** that
    /// held a goal you missed would be exactly the naming fault this project keeps catching:
    /// the name has to be true of every member.
    func endedGoals() -> [(status: NoteStatus, notes: [Note])] {
        let over = notes(kind: .goal).filter { !$0.isArchived && $0.isEnded }
        return NoteStatus.endings.compactMap { ending in
            let matching = over.filter { $0.noteStatus == ending }
                .sorted(by: NoteIndex.byTargetThenTitle)
            return matching.isEmpty ? nil : (ending, matching)
        }
    }

    /// Soonest target first, then by name. One place, so the three lists agree.
    static func byTargetThenTitle(_ a: Note, _ b: Note) -> Bool {
        let far = DateOnly(year: 9999, month: 12, day: 31)
        let ta = a.targetDate ?? far, tb = b.targetDate ?? far
        if ta != tb { return ta < tb }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }

    /// One dated goal with the work under it.
    func chainGoal(of goal: Note, today: DateOnly = .today(), calendar: Calendar = .current) -> ChainGoal {
        let health = goalHealth(of: goal, today: today, calendar: calendar)
        let projects = health.projects.map(ChainProject.init)
        let finished = health.endedNotes.map(ChainProject.init)
        return ChainGoal(note: goal,
                         progress: health.progress,
                         projects: projects,
                         finishedProjects: finished,
                         areas: health.areas,
                         flags: health.flags,
                         activity: NoteIndex.activity(health: health, projects: projects, finished: finished))
    }

    /// An aspiration and the whole chain beneath it.
    func chain(of aspiration: Note, today: DateOnly = .today(), calendar: Calendar = .current) -> AspirationChain {
        let health = goalHealth(of: aspiration, today: today, calendar: calendar)
        let live = health.subgoals
            .sorted(by: NoteIndex.byTargetThenTitle)
            .map { chainGoal(of: $0, today: today, calendar: calendar) }
        let area = aspiration.area.flatMap { reference in
            notes(kind: .area).first { $0.title.localizedCaseInsensitiveCompare(reference) == .orderedSame }
                ?? note(matching: reference).flatMap { $0.kind == .area ? $0 : nil }
        }
        // `serving` drops everything that has ended, so an ended **sub-goal** is not in
        // `health.subgoals` at all — it is in `endedNotes`, together with the ended projects.
        // Splitting them apart here is what a failing test caught: `endedGoals` was always
        // empty, because it was being filtered out of a list it could never be in.
        let ended = health.endedNotes
        let endedGoals = ended.filter { $0.declaredKind == .goal }
            .sorted(by: NoteIndex.byTargetThenTitle)
            .map { chainGoal(of: $0, today: today, calendar: calendar) }
        let projects = health.projects.map(ChainProject.init)
        let endedProjects = ended.filter { $0.declaredKind != .goal }.map(ChainProject.init)
        let activity = NoteIndex.activity(health: health, projects: projects, finished: endedProjects)
        return AspirationChain(note: aspiration,
                               area: area,
                               goals: live,
                               projects: projects + endedProjects,
                               areas: health.areas,
                               progress: health.progress,
                               flags: health.flags,
                               endedGoals: endedGoals,
                               activity: activity)
    }

    /// What has happened lately, counted the same way the per cent is (build 165): **only a
    /// project that is done counts as finished**, and one that was missed or dropped is left
    /// out of both halves of "N of M". `GoalProgress` skips them too, so the line and the bar
    /// beside it can never tell different stories.
    static func activity(health: GoalHealth, projects: [ChainProject], finished: [ChainProject]) -> ChainActivity {
        let delivered = finished.filter { $0.note.noteStatus.isDelivered }
        return ChainActivity(tasksFinished: health.completedLast30Days,
                             daysSinceActivity: health.daysSinceActivity,
                             projectsFinished: delivered.count,
                             projectsTotal: projects.count + delivered.count)
    }

    /// Every aspiration with its chain, the ones wanting attention first — the same order the
    /// review uses, so the two screens put the same thing on top.
    func aspirationChains(today: DateOnly = .today(), calendar: Calendar = .current) -> [AspirationChain] {
        aspirations().map { chain(of: $0, today: today, calendar: calendar) }
    }
}
