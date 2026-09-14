import Foundation

/// How often each link in the chain wants looking at, and which notes are due.
///
/// **Build 172, the last piece of the Aspiration Chain spec he brought** (build 132 on). The
/// spec asks for a review cadence per level, and until now PARAGON had exactly one: a project
/// not marked reviewed for `reviewIntervalDays` was flagged, and nothing else was ever asked
/// about. So a goal could sit untouched for two years without the app ever mentioning it.
///
/// Everything here is computed from the `reviewed:` line that `AppModel.markReviewed` has
/// written since the review was first built. **Nothing new is stored in a note** — the rule
/// this project keeps earning is the other way round (a screen that reads a field needs the
/// control that writes it), and here that control already exists.

/// One link in the chain, as far as reviewing is concerned.
public enum ReviewLevel: String, CaseIterable, Sendable {
    case aspiration
    case goal
    case project
    case area

    public var label: String {
        switch self {
        case .aspiration: return "Aspiration"
        case .goal: return "Goal"
        case .project: return "Project"
        case .area: return "Area"
        }
    }

    /// Why this level has the rhythm it has. Shown in Settings beside the number, because a
    /// number with no reason behind it is a number nobody dares change.
    public var reason: String {
        switch self {
        case .aspiration:
            return "What you are becoming changes slowly. Once a year is enough, and more often makes it feel like a task."
        case .goal:
            return "A goal with a date wants a look every quarter: is it still what you want, and is anything delivering it?"
        case .project:
            return "A project is live work. Once a week, with the rest of the weekly review."
        case .area:
            return "An area has no finish line, so the question is whether the standard is still being kept. Once a month."
        }
    }

    /// The rhythm out of the box. Each is settable per vault; see `ReviewRhythm`.
    public var defaultDays: Int {
        switch self {
        case .aspiration: return 365
        case .goal: return 90
        case .project: return 7
        case .area: return 30
        }
    }
}

/// The four intervals this vault uses.
///
/// The project one is `VaultConfig.reviewIntervalDays`, which has existed since the review was
/// built and already means exactly this. **It is not duplicated here**: a second number for the
/// same thing is how two screens come to disagree.
public struct ReviewRhythm: Equatable, Sendable {
    public var aspirationDays: Int
    public var goalDays: Int
    public var projectDays: Int
    public var areaDays: Int

    public init(aspirationDays: Int = ReviewLevel.aspiration.defaultDays,
                goalDays: Int = ReviewLevel.goal.defaultDays,
                projectDays: Int = ReviewLevel.project.defaultDays,
                areaDays: Int = ReviewLevel.area.defaultDays) {
        self.aspirationDays = aspirationDays
        self.goalDays = goalDays
        self.projectDays = projectDays
        self.areaDays = areaDays
    }

    public init(config: VaultConfig) {
        self.init(aspirationDays: config.aspirationReviewDays,
                  goalDays: config.goalReviewDays,
                  projectDays: config.reviewIntervalDays,
                  areaDays: config.areaReviewDays)
    }

    public func days(for level: ReviewLevel) -> Int {
        switch level {
        case .aspiration: return aspirationDays
        case .goal: return goalDays
        case .project: return projectDays
        case .area: return areaDays
        }
    }
}

/// One note and when it was last looked at.
public struct ReviewDue: Identifiable, Equatable, Sendable {
    public var note: Note
    public var level: ReviewLevel
    /// Days since the `reviewed:` line. **Nil means never reviewed**, which is not the same as
    /// "reviewed a very long time ago" and is never drawn as a number (build 141's rule: an
    /// absence may not look like a value).
    public var daysSinceReview: Int?
    /// The rhythm this level is on.
    public var every: Int

    public var id: String { note.relativePath }

    public init(note: Note, level: ReviewLevel, daysSinceReview: Int?, every: Int) {
        self.note = note
        self.level = level
        self.daysSinceReview = daysSinceReview
        self.every = every
    }

    /// A note nobody has ever looked at is due. So is one whose rhythm has come round.
    public var isDue: Bool {
        guard let days = daysSinceReview else { return true }
        return days >= every
    }

    /// How far past the rhythm it is, for sorting. Never reviewed sorts above everything.
    public var overdueBy: Int {
        guard let days = daysSinceReview else { return Int.max }
        return days - every
    }

    /// In plain words. One place, so the review, the note row and Settings agree.
    public var whenText: String {
        guard let days = daysSinceReview else { return "never looked at" }
        let over = days - every
        if over >= 1 { return over == 1 ? "1 day over" : "\(over) days over" }
        if over == 0 { return "due today" }
        let left = -over
        return left == 1 ? "due tomorrow" : "due in \(left) days"
    }

    /// What to say about the last look itself, which is a different question from when the
    /// next one is due.
    public var lastText: String {
        guard let days = daysSinceReview else { return "never reviewed" }
        if days == 0 { return "reviewed today" }
        if days == 1 { return "reviewed yesterday" }
        return "reviewed \(days) days ago"
    }
}

public extension NoteIndex {
    /// Which level a note is reviewed at, or nil for anything that is not part of the chain.
    ///
    /// **`declaredKind`, not `kind`** — archiving moves the file, so an archived project reads
    /// as `.archive` from its folder (build 141). Archived and ended notes are dropped anyway
    /// by `reviewSchedule`, but the level itself should still answer honestly.
    func reviewLevel(of note: Note) -> ReviewLevel? {
        switch note.declaredKind {
        case .goal: return (note.horizon ?? .year) == .life ? .aspiration : .goal
        case .project: return .project
        case .area: return .area
        case .resource, .archive, .inbox, .daily: return nil
        }
    }

    /// Every live note in the chain with when it was last looked at, the ones wanting a look
    /// first. Never reviewed comes above everything, then the most overdue.
    ///
    /// Archived, done, missed and dropped notes are left out: a review is a question about
    /// work you are still doing, and asking about something you dropped would be noise of
    /// exactly the kind build 132 refused for `noGoal`.
    func reviewSchedule(rhythm: ReviewRhythm, today: DateOnly = .today(),
                        calendar: Calendar = .current) -> [ReviewDue] {
        notes.compactMap { note -> ReviewDue? in
            guard !note.isArchived, !note.isEnded, let level = reviewLevel(of: note) else { return nil }
            let since = note.reviewedDate.map { today.days(since: $0, calendar: calendar) }
            return ReviewDue(note: note, level: level, daysSinceReview: since,
                             every: rhythm.days(for: level))
        }
        .sorted { a, b in
            if a.overdueBy != b.overdueBy { return a.overdueBy > b.overdueBy }
            return a.note.title.localizedCaseInsensitiveCompare(b.note.title) == .orderedAscending
        }
    }

    /// Only the ones whose rhythm has come round.
    func dueForReview(rhythm: ReviewRhythm, today: DateOnly = .today(),
                      calendar: Calendar = .current) -> [ReviewDue] {
        reviewSchedule(rhythm: rhythm, today: today, calendar: calendar).filter(\.isDue)
    }
}
