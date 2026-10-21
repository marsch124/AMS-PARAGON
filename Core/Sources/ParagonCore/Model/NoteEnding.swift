import Foundation

/// The day a project or a goal ended (build 262).
///
/// Until now a project marked **Done** carried no date at all: `status:` said *that* it was
/// over and nothing said *when*. So no screen could ever say "finished this month", and
/// `ChainActivity` had to stay silent about it on purpose (build 163). He chose the word for
/// the line from the plan page (20 October): **`ended:`**, because a project can end in three
/// ways and `done:` on a dropped project would say something that did not happen.
///
/// **The rule lives here and nowhere else**, so every way of changing how a note stands — the
/// status chip, the Projects list's menu, the Weekly review's menus — writes the day the same
/// way. **A day is written, never guessed**: a project that ended before this build has no
/// `ended:` line, and every screen then shows nothing rather than a made-up date.
public extension Note {
    /// The line the day is written on.
    static let endedKey = "ended"

    /// The day this note ended, when one was written.
    var endedDate: DateOnly? {
        frontmatter.string(Note.endedKey).flatMap { DateOnly($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// The day this note was made. `Vault.createNote` and every template have always written
    /// `created:`; nothing read it until this build.
    var createdDate: DateOnly? {
        frontmatter.string("created").flatMap { DateOnly($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// This note with a new status, and the end day kept in step with it.
    ///
    /// - Going into an ending (Done, Missed, Dropped) writes `ended:` with **today** only when
    ///   the note was not ended before. Done → Missed keeps the day it already has: the project
    ///   ended then, and only the word for how changed. A note that ended before this build
    ///   and has no day keeps having none — today would be a guess.
    /// - **Active** removes both lines (build 165: a note that says nothing is active).
    /// - **On hold** writes the status and removes the day: the project is not over.
    /// - The status it already has changes nothing at all, so pressing it again never moves the
    ///   file's date or sends it round iCloud.
    func settingStatus(_ status: NoteStatus, today: DateOnly) -> Note {
        let before = noteStatus
        guard status != before else { return self }
        var updated = self
        switch status {
        case .active:
            updated.frontmatter.remove("status")
            updated.frontmatter.remove(Note.endedKey)
        case .onHold:
            updated.frontmatter.set("status", status.rawValue)
            updated.frontmatter.remove(Note.endedKey)
        case .done, .missed, .dropped:
            updated.frontmatter.set("status", status.rawValue)
            if !before.isEnded {
                updated.frontmatter.set(Note.endedKey, today.description)
            }
        case .archived:
            updated.frontmatter.set("status", status.rawValue)
        }
        return updated
    }

    /// This note with its end day changed. Nil removes the line.
    func settingEndedDate(_ day: DateOnly?) -> Note {
        var updated = self
        if let day {
            guard day != endedDate else { return self }
            updated.frontmatter.set(Note.endedKey, day.description)
        } else {
            guard frontmatter.string(Note.endedKey) != nil else { return self }
            updated.frontmatter.remove(Note.endedKey)
        }
        return updated
    }
}

/// What the line under a finished project's header says: "Done on 20 October · after 41 days ·
/// 17 tasks finished" (build 262, from the drawing he approved).
///
/// Each part is left out when the note cannot prove it — no `created:` line, no ticked task —
/// and the whole line is nil when there is no `ended:` day. **An absence is never drawn as a
/// zero** (build 141): "after 0 days" or "0 tasks finished" would read as an answer.
public struct ProjectEnding: Equatable, Sendable {
    public var status: NoteStatus
    public var ended: DateOnly?
    public var created: DateOnly?
    /// Top-level tasks ticked off, the count the Projects box uses (`Note.progress`).
    public var finishedTasks: Int

    public init(status: NoteStatus, ended: DateOnly?, created: DateOnly?, finishedTasks: Int) {
        self.status = status
        self.ended = ended
        self.created = created
        self.finishedTasks = finishedTasks
    }

    /// Nil unless the note has ended.
    public init?(note: Note) {
        guard note.isEnded else { return nil }
        self.init(status: note.noteStatus, ended: note.endedDate,
                  created: note.createdDate, finishedTasks: note.progress.done)
    }

    /// "after 1 day", "after 41 days", "after about 3 months", "after about 2 years". Days up to
    /// 60, as in the drawing, because a project of a few weeks is counted in days. Nil when a
    /// date is missing, when it ended on the day it was made, or when the dates are the wrong
    /// way round (a hand-typed line).
    public func durationText(calendar: Calendar = .current) -> String? {
        guard let ended, let created else { return nil }
        let days = ended.days(since: created, calendar: calendar)
        guard days >= 1 else { return nil }
        if days == 1 { return "after 1 day" }
        if days < 60 { return "after \(days) days" }
        if days < 730 {
            let months = max(2, Int((Double(days) / 30.44).rounded()))
            return "after about \(months) months"
        }
        return "after about \(Int((Double(days) / 365.25).rounded())) years"
    }

    /// "1 task finished", "17 tasks finished", or nil for none.
    public var tasksText: String? {
        switch finishedTasks {
        case ..<1: return nil
        case 1: return "1 task finished"
        default: return "\(finishedTasks) tasks finished"
        }
    }

    /// "20 October", with the year when it is not this year's.
    public static func dayText(_ day: DateOnly, today: DateOnly,
                               calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date = day.date(calendar: calendar) else { return day.description }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(day.year == today.year ? "d MMMM" : "d MMMM y")
        return formatter.string(from: date)
    }

    /// The whole line, or nil when no end day was written.
    public func line(today: DateOnly, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard let ended else { return nil }
        var parts = ["\(status.label) on \(Self.dayText(ended, today: today, calendar: calendar, locale: locale))"]
        if let duration = durationText(calendar: calendar) { parts.append(duration) }
        if let tasks = tasksText { parts.append(tasks) }
        return parts.joined(separator: " · ")
    }
}
