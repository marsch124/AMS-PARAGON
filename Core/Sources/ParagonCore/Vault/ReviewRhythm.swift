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

    /// The level's notes all together, for a sentence such as "Goals with a date get a look every
    /// 3 months." (build 270). A goal here is **"Goals with a date"**, the words the app uses
    /// wherever the two kinds of goal could be taken for each other (`GoalWording` in the app,
    /// build 176), because an aspiration is a kind of goal too.
    public var plural: String {
        switch self {
        case .aspiration: return "Aspirations"
        case .goal: return "Goals with a date"
        case .project: return "Projects"
        case .area: return "Areas"
        }
    }

    /// Why this level has the rhythm it has. Shown in Settings beside the number, because a
    /// number with no reason behind it is a number nobody dares change.
    public var reason: String {
        switch self {
        case .aspiration:
            return "What you are becoming changes slowly. Twice a year is enough, and more often makes it feel like a task."
        case .goal:
            return "A goal with a date wants a look every quarter: is it still what you want, and is anything delivering it?"
        case .project:
            return "A project is live work. Once a week, with the rest of the weekly review."
        case .area:
            return "An area has no finish line, so the question is whether the standard is still being kept. Once a month."
        }
    }

    /// The rhythm out of the box. Each is settable per vault; see `ReviewRhythm`.
    ///
    /// **An aspiration is every 6 months, not every year** — his answer from the build 174
    /// field test, and the only box on it he marked as not right.
    public var defaultDays: Int {
        switch self {
        case .aspiration: return 182
        case .goal: return 90
        case .project: return 7
        case .area: return 30
        }
    }

    /// What to offer for this level. **Named lengths, not a number of days**, because that is
    /// how a person thinks about it: he asked for "every 6 months", and a stepper counting
    /// 30 days at a time from 365 never lands on 182 at all — a fault build 174 shipped and
    /// build 136 had already taught ("about forty presses" for one date).
    public var choices: [Int] {
        switch self {
        case .aspiration: return [90, 182, 365, 730]
        case .goal: return [30, 90, 182, 365]
        case .project: return [7, 14, 30]
        case .area: return [14, 30, 90]
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

/// How long ago a note was last looked at, in plain words.
///
/// **In Core because two screens say it** — the Aspirations list and the review — and because
/// it decides what an absence looks like. Build 199.
public enum ReviewWording {
    /// "Looked at today", "Looked at 12 days ago", "Looked at about 4 months ago", and for a
    /// note nobody has ever reviewed, **"Never looked at"**.
    ///
    /// **Never is a sentence, not a big number** (build 141's rule, and `ReviewDue` already
    /// keeps `daysSinceReview` optional for the same reason): "reviewed 9999 days ago" would
    /// read as a measurement of something that never happened.
    ///
    /// The wording follows `DateOnly.timeLeftText(from:)` so the two never disagree about
    /// where days become months and months become years.
    public static func lookedAt(daysAgo days: Int?) -> String {
        guard let days, days >= 0 else { return "Never looked at" }
        if days == 0 { return "Looked at today" }
        if days == 1 { return "Looked at yesterday" }
        if days < 31 { return "Looked at \(days) days ago" }
        let months = Int((Double(days) / 30.44).rounded())
        if months < 12 { return months == 1 ? "Looked at about a month ago" : "Looked at about \(months) months ago" }
        let years = Double(days) / 365.25
        if years < 1.75 { return "Looked at about a year ago" }
        return "Looked at about \(Int(years.rounded())) years ago"
    }

    /// The same words with a small first letter, for the middle of a row: "Area · looked at 12
    /// days ago". **Build 270, his answer 3a: "Looked at" everywhere.** The Weekly review
    /// said "reviewed 12 days ago" while the Aspirations list said "Looked at 12 days ago", and
    /// two words for one thing make you wonder whether they are two things (build 165). One
    /// function, so the two can never drift apart again.
    public static func lookedAtLowercased(daysAgo days: Int?) -> String {
        let words = lookedAt(daysAgo: days)
        return words.prefix(1).lowercased() + String(words.dropFirst())
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
    ///
    /// **"due now" for a note never looked at** (build 270). It said "never looked at", and
    /// since `lastText` says that too, the Weekly review's row would have read "Aspiration ·
    /// never looked at … never looked at": a fact said twice on one row carries nothing the
    /// second time (build 169). This side says when the look is due, which for a note never
    /// looked at is now.
    public var whenText: String {
        guard let days = daysSinceReview else { return "due now" }
        let over = days - every
        if over >= 1 { return over == 1 ? "1 day over" : "\(over) days over" }
        if over == 0 { return "due today" }
        let left = -over
        return left == 1 ? "due tomorrow" : "due in \(left) days"
    }

    /// What to say about the last look itself, which is a different question from when the
    /// next one is due: "looked at 12 days ago", "never looked at". Since build 270 it is
    /// `ReviewWording`'s own words, so the review's rows and the Aspirations list say the same
    /// thing (his answer 3a: "Looked at" everywhere).
    public var lastText: String {
        ReviewWording.lookedAtLowercased(daysAgo: daysSinceReview)
    }

    /// What the **Looked at** button at the top of a note says: "Looked at 12 days ago", or
    /// "Never looked at" (build 270).
    public var lookedAtText: String {
        ReviewWording.lookedAt(daysAgo: daysSinceReview)
    }

    /// How often this kind of note gets a look, as one sentence: "Goals with a date get a look
    /// every 3 months." Built from `ReviewRhythm.label(forDays:)`, the words Settings shows, so
    /// the box and Settings › Review rhythm can never name the same rhythm two ways.
    public var rhythmText: String {
        "\(level.plural) get a look \(ReviewRhythm.label(forDays: every).lowercased())."
    }

    /// When the next look is due, as one sentence: "The next look is due in 78 days.", "The
    /// next look is due today.", "A look was due 3 days ago." A note nobody has looked at yet
    /// is **due now**, never "due 9999 days ago" (build 141's rule: an absence may not look like
    /// a number). The same arithmetic as `whenText`, so the box and the Weekly review agree.
    public var nextText: String {
        guard let days = daysSinceReview else { return "A look is due now." }
        let over = days - every
        if over >= 1 { return over == 1 ? "A look was due 1 day ago." : "A look was due \(over) days ago." }
        if over == 0 { return "The next look is due today." }
        let left = -over
        return left == 1 ? "The next look is due tomorrow." : "The next look is due in \(left) days."
    }
}

public extension ReviewRhythm {
    /// A length of time in the words a person uses. In Core, with tests, because Settings and
    /// the review both show it and a second wording would let them disagree (build 163).
    static func label(forDays days: Int) -> String {
        switch days {
        case 1: return "Every day"
        case 7: return "Every week"
        case 14: return "Every 2 weeks"
        case 30: return "Every month"
        case 90: return "Every 3 months"
        case 182: return "Every 6 months"
        case 365: return "Every year"
        case 730: return "Every 2 years"
        default: return "Every \(days) days"
        }
    }

    /// What to offer for a level, with whatever it is set to now always among them.
    ///
    /// A vault set to something the list does not hold — by an older build, or by hand — must
    /// still show one chip lit, or the screen would say nothing is chosen while something
    /// plainly is. Same reasoning as build 152's `lengthChoices`.
    static func choices(for level: ReviewLevel, including current: Int) -> [Int] {
        var days = level.choices
        if !days.contains(current) { days.append(current) }
        return days.sorted()
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
            reviewDue(of: note, rhythm: rhythm, today: today, calendar: calendar)
        }
        .sorted { a, b in
            if a.overdueBy != b.overdueBy { return a.overdueBy > b.overdueBy }
            return a.note.title.localizedCaseInsensitiveCompare(b.note.title) == .orderedAscending
        }
    }

    /// One note's place on its rhythm: its level, how long since it was last looked at, and
    /// how often it wants a look. **Nil** for a note outside the chain (a resource, the Inbox, a
    /// daily note) and for one that is archived or has ended — a review is a question about
    /// work you are still doing.
    ///
    /// **Build 270: the button at the top of a goal, an aspiration or an area asks this.**
    /// `reviewSchedule` is built from it, one note at a time, so the button and the Weekly
    /// review can never give one note two different answers. The note may be a copy that is
    /// not in this index — the app hands in the latest one it holds.
    func reviewDue(of note: Note, rhythm: ReviewRhythm, today: DateOnly = .today(),
                   calendar: Calendar = .current) -> ReviewDue? {
        guard !note.isArchived, !note.isEnded, let level = reviewLevel(of: note) else { return nil }
        let since = note.reviewedDate.map { today.days(since: $0, calendar: calendar) }
        return ReviewDue(note: note, level: level, daysSinceReview: since,
                         every: rhythm.days(for: level))
    }

    /// Only the ones whose rhythm has come round.
    func dueForReview(rhythm: ReviewRhythm, today: DateOnly = .today(),
                      calendar: Calendar = .current) -> [ReviewDue] {
        reviewSchedule(rhythm: rhythm, today: today, calendar: calendar).filter(\.isDue)
    }
}
