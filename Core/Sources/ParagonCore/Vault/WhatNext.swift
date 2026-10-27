import Foundation

/// **What is next for this goal?** (build 271)
///
/// A project ends, and the goal it worked for is left with nothing working on it. Nothing in
/// PARAGON said so: `GoalHealth.Flag.nothingServing` stays silent once any project under a goal
/// has ended ("served, not neglected", by design, build 132), so a goal could sit with its last
/// project finished and no sign that it needed a next step. He chose to be **asked at once**
/// (the plan page, 21 October): a short question when the project is marked, from any screen,
/// because he marks projects from the Projects list and the Weekly review too, where he does not
/// open the note.
///
/// **The rule lives here** so that it can be tested in both directions. It is a question about
/// *live* work: `serving(_:)` already leaves out everything that has ended or been archived, so
/// a project finished last year does not keep a goal "working".
public extension NoteIndex {
    /// The goal a project's ending has just left with no project and no sub-goal working on it,
    /// or nil.
    ///
    /// Nil when:
    /// - the note is not a project, or has not ended (Done, Missed or Dropped). An archived
    ///   project is not ended: archiving does not change what is working on a goal;
    /// - its `goal:` line names no goal;
    /// - that goal has itself ended or been archived: a question about a finished goal is noise;
    /// - another project (on hold counts: it is not over) or a sub-goal still works on it.
    ///
    /// **Areas do not count.** An area keeps a standard and does not deliver a goal, the same
    /// reasoning as `GoalHealth.Flag.noProjectYet` (build 132).
    ///
    /// The project itself is left out by its path, so the answer is the same whether or not the
    /// index has caught up with the ending yet.
    func goalLeftWithoutWork(after project: Note) -> Note? {
        guard project.declaredKind == .project, project.isEnded else { return nil }
        guard let reference = project.goal, let target = goal(matching: reference) else { return nil }
        guard target.relativePath != project.relativePath, !target.isArchived, !target.isEnded else { return nil }
        let working = serving(target)
        let otherProjects = working.projects.filter { $0.relativePath != project.relativePath }
        guard otherProjects.isEmpty, working.subgoals.isEmpty else { return nil }
        return target
    }
}

/// The question and its words, in one place because the dialog reads all of them and a test
/// pins each (the owner reads every one of them).
///
/// It holds the goal's **path and name**, not the `Note`: a press on a button looks the goal up
/// again, so it never writes over a copy that is one save behind (build 144).
public struct WhatNextQuestion: Equatable, Sendable {
    public var goalPath: String
    /// The goal's name as the screens show it.
    public var goalName: String
    /// An aspiration is never finished, so it is not offered **Mark the goal done**, and the new
    /// work it is offered is a goal, not a project (build 269: nothing is made straight under an
    /// aspiration).
    public var isAspiration: Bool
    /// The project was marked **Done**, not Missed or Dropped. Only then is the goal itself
    /// likely to be done.
    public var projectWasDone: Bool

    public init(goal: Note, projectWasDone: Bool) {
        goalPath = goal.relativePath
        goalName = goal.displayTitle
        isAspiration = (goal.horizon ?? .year) == .life
        self.projectWasDone = projectWasDone
    }

    /// "What is next for this goal?" or, for an aspiration, "... this aspiration?".
    public var title: String {
        isAspiration ? "What is next for this aspiration?" : "What is next for this goal?"
    }

    /// The line under the question.
    public var line: String {
        "Nothing is working on \u{201C}\(goalName)\u{201D} now."
    }

    /// The button that makes new work: a project for a goal, a goal for an aspiration.
    public var addTitle: String {
        isAspiration ? "Add a goal\u{2026}" : "Add a project\u{2026}"
    }

    /// **Mark the goal done** is offered only after Done, and never for an aspiration.
    public var offersDone: Bool { projectWasDone && !isAspiration }

    public static let doneTitle = "Mark the goal done"
    public static let notNowTitle = "Not now"

    /// What is said after **Mark the goal done**.
    public var doneMessage: String {
        "\u{201C}\(goalName)\u{201D} is marked done."
    }
}
