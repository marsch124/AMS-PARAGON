import Foundation

/// The focus timer (build 256), from the drawing he loved
/// (https://claude.ai/artifact/G9Mpn5nAQtx4ByLXtptDZX): *"You start a clock on one task. A small
/// bar shows the task and the time while you work. When you stop, PARAGON writes the time into
/// today's note under a new heading, Worked."*
///
/// **A session is dates, never a counter.** It keeps when each stretch of work started and
/// ended, so the clock is right after the app was closed, the phone slept, or the Mac woke up —
/// nothing has to tick for it to be true. The app keeps the one running session per device in
/// its settings; the vault only ever sees the finished lines under `## Worked`.
public struct FocusSession: Codable, Equatable, Sendable {
    /// One stretch of work between a start (or a resume) and a pause (or the stop).
    public struct Run: Codable, Equatable, Sendable {
        public var start: Date
        public var end: Date

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    /// The note the task lives in. Nil for a block in the day's plan, which is not a task.
    public var notePath: String?
    /// The task's title exactly as the note has it, so **Done, tick it off** can find it again.
    public var taskTitle: String
    /// The task's `^t` id when it has one: the surest way to find it again, since two tasks can
    /// share a title (build 256's review).
    public var taskID: String?
    /// The task's date when the clock started, so a repeating task's next copy — same title,
    /// a later date — is never taken for it.
    public var taskDue: DateOnly?
    /// What the bar shows and what is written under `## Worked`: the title without `#next`.
    public var title: String
    /// The task's own time, or the plan block's length. Nil when it has none.
    public var plannedMinutes: Int?
    /// Stretches that are over: each pause closes one.
    public var runs: [Run]
    /// When the stretch now running began. Nil while paused.
    public var runningSince: Date?

    public init(notePath: String?, taskTitle: String, title: String, plannedMinutes: Int?, startedAt: Date,
                taskID: String? = nil, taskDue: DateOnly? = nil) {
        self.notePath = notePath
        self.taskTitle = taskTitle
        self.taskID = taskID
        self.taskDue = taskDue
        self.title = title
        self.plannedMinutes = plannedMinutes
        self.runs = []
        self.runningSince = startedAt
    }

    public var isPaused: Bool { runningSince == nil }

    /// Every stretch, the running one ended at `now`.
    public func allRuns(endingAt now: Date) -> [Run] {
        guard let since = runningSince else { return runs }
        return runs + [Run(start: since, end: max(now, since))]
    }

    /// Seconds worked so far, pauses left out.
    public func workedSeconds(at now: Date) -> TimeInterval {
        allRuns(endingAt: now).reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    public mutating func pause(at now: Date) {
        guard let since = runningSince else { return }
        runs.append(Run(start: since, end: max(now, since)))
        runningSince = nil
    }

    public mutating func resume(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// The open task this session was started on, found again in `tasks`: by its `^t` id
    /// first, else by its exact title **and** the date it had. Nil when it is gone — renamed,
    /// moved, ticked elsewhere — and then **Done** must say so rather than tick another task.
    public func task(in tasks: [TaskItem]) -> TaskItem? {
        let open = tasks.filter { !$0.isDone }
        if let id = taskID {
            if let byID = open.first(where: { $0.id == id }) { return byID }
            // The task with that id is there but already ticked (in Reminders, say): it is done,
            // and another task with the same words must not be ticked in its place.
            if tasks.contains(where: { $0.id == id }) { return nil }
        }
        let sameTitle = open.filter { $0.title == taskTitle && $0.dueDate == taskDue }
        // Two open tasks with the same words and the same date cannot be told apart, so
        // neither is ticked.
        return sameTitle.count == 1 ? sameTitle.first : nil
    }

    /// A clock that has run longer than this was almost certainly left running, and its time
    /// is not written down without being asked (build 256's review).
    public static let forgottenAfter: TimeInterval = 12 * 3600

    /// The clock on the bar: "4:09", "23:14", "1:02:05".
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// One line under `## Worked`: `- 08:02-08:54 Write the offer for the shed`.
public struct WorkedSpan: Equatable, Sendable {
    /// Minutes since midnight. `end` may be 1440, written as 24:00, for a stretch that ran to
    /// midnight.
    public var start: Int
    public var end: Int
    public var title: String

    public init(start: Int, end: Int, title: String) {
        self.start = start
        self.end = max(end, start)
        self.title = title
    }

    public var minutes: Int { end - start }

    /// The line as written: always a bullet, so markdown keeps each on its own row (build 153).
    public var line: String {
        "- \(Self.clock(start))-\(Self.clock(end)) \(title)"
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// A span with the day it belongs to, since a stretch past midnight is written on two days.
public struct DatedSpan: Equatable, Sendable {
    public var day: DateOnly
    public var span: WorkedSpan

    public init(day: DateOnly, span: WorkedSpan) {
        self.day = day
        self.span = span
    }
}

/// The `## Worked` section of a daily note: what the timer measured, one line per stretch.
///
/// **Liberal in what it reads, strict in what it writes** — the rule `DayPlan` has had since
/// build 147. It reads any dash and a line without a bullet; it writes `- 08:02-08:54 Title`.
/// **It only adds.** A line he has corrected or deleted by hand stays as he left it: the timer's
/// job is to write down what happened, not to own the section.
public enum WorkLog {
    public static let heading = "## Worked"

    static let lineRegex = try! NSRegularExpression(
        // The dashes are written out as themselves, as in `DayPlan.lineRegex` (build 147).
        pattern: #"^\s*(?:[-*]\s*)?(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})\s+(\S.*)$"#)

    /// One written line as a span, or nil.
    public static func span(in line: String) -> WorkedSpan? {
        let ns = line as NSString
        guard let match = lineRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              let h1 = Int(ns.substring(with: match.range(at: 1))),
              let m1 = Int(ns.substring(with: match.range(at: 2))),
              let h2 = Int(ns.substring(with: match.range(at: 3))),
              let m2 = Int(ns.substring(with: match.range(at: 4))),
              (0...23).contains(h1), (0...59).contains(m1), (0...24).contains(h2), (0...59).contains(m2),
              h2 < 24 || m2 == 0
        else { return nil }
        let title = ns.substring(with: match.range(at: 5)).trimmingCharacters(in: .whitespaces)
        return WorkedSpan(start: h1 * 60 + m1, end: h2 * 60 + m2, title: title)
    }

    /// The spans written in a note, in the order they stand.
    public static func spans(in note: Note) -> [WorkedSpan] {
        MarkdownSection.find(heading, in: note.body).lines.compactMap(span(in:))
    }

    /// The finished stretches of a session as lines, each on the day it ran.
    ///
    /// A stretch starts on its own minute and lasts its length **rounded to the minute**, so the
    /// lines add up to exactly what the stop question says was worked. A stretch under half a
    /// minute is no line at all. One that runs past midnight is split there, so each daily note
    /// holds only its own day.
    public static func spans(from runs: [FocusSession.Run], title: String, calendar: Calendar = .current) -> [DatedSpan] {
        var result: [DatedSpan] = []
        for run in runs {
            let length = Int((run.end.timeIntervalSince(run.start) / 60).rounded())
            guard length > 0 else { continue }
            let parts = calendar.dateComponents([.hour, .minute], from: run.start)
            var day = DateOnly(run.start, calendar: calendar)
            var start = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            var left = length
            while left > 0 {
                let piece = min(left, 1440 - start)
                result.append(DatedSpan(day: day, span: WorkedSpan(start: start, end: start + piece, title: title)))
                left -= piece
                day = day.adding(days: 1, calendar: calendar)
                start = 0
            }
        }
        return result
    }

    /// The note with `spans` added at the end of its `## Worked` section.
    ///
    /// The section is made when it is missing: **above `## Looking back`** when that is there,
    /// because the work is done before the day is looked back on; at the end of the note
    /// otherwise. Nothing else in the note is touched.
    public static func note(_ note: Note, adding spans: [WorkedSpan]) -> Note {
        guard !spans.isEmpty else { return note }
        var updated = note
        var lines = note.body.components(separatedBy: "\n")
        let added = spans.map(\.line)
        let found = MarkdownSection.find(heading, in: note.body)
        if let range = found.range {
            // After the last line that says something, so a blank line before the next heading
            // stays where it was.
            var at = range.upperBound
            while at > range.lowerBound, lines[at - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                at -= 1
            }
            if at == range.lowerBound {
                // An empty section — nothing in it, or only blank lines — is given the shape the
                // section is made in below: a blank line, the lines, a blank line. Its own blank
                // lines are replaced, not added to.
                // Always a blank line after: before a heading that follows, or as the note's own
                // final newline when the section is the last thing in it.
                lines.replaceSubrange(range, with: [""] + added + [""])
            } else {
                lines.insert(contentsOf: added, at: at)
            }
        } else {
            let lookingBack = MarkdownSection.find(DayLog.heading, in: note.body).range
            if let lookingBack {
                let headingLine = max(lookingBack.lowerBound - 1, 0)
                let gapAbove = headingLine > 0
                    && !lines[headingLine - 1].trimmingCharacters(in: .whitespaces).isEmpty
                lines.insert(contentsOf: (gapAbove ? [""] : []) + [heading, ""] + added + [""], at: headingLine)
            } else {
                while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
                lines.append("")
                lines.append(heading)
                lines.append("")
                lines.append(contentsOf: added)
                lines.append("")
            }
        }
        updated.body = lines.joined(separator: "\n")
        return updated
    }
}

public extension Note {
    /// What the timer wrote in this daily note.
    var workedSpans: [WorkedSpan] { WorkLog.spans(in: self) }

    /// This note with more worked lines.
    func addingWorkedSpans(_ spans: [WorkedSpan]) -> Note { WorkLog.note(self, adding: spans) }
}
