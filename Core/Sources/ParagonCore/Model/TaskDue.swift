import Foundation

// A time of day on a task (build 277): the rules behind the **At** line in a task's date window,
// and behind the two places that use the time, **Plan** and **Start the day**.
//
// The app could always *read* `>2026-11-04T14:00` (the parser, the Reminders sync, the Calendar
// section's day all carry `dueTime`), and nothing in it could *write* one. Everything that
// decides what is stored, or what two screens must agree on, is here, where it is tested
// (build 146's rule).
//
// The word is **At**, never "Time": a task's *time* already means how long it takes (`~45m`,
// build 248).

/// What was typed into the **At** line. Three answers, because "nothing typed" is a real answer
/// (no time of day) and must not be confused with "typed something that is not a time".
public enum TypedTime: Equatable, Sendable {
    /// Nothing typed: the task has a date and no time of day.
    case empty
    case time(TimeOfDay)
    /// Something is typed and it is not a time. The window says so and keeps **Set** grey.
    case invalid
}

public extension TimeOfDay {
    /// The quick times under the **At** line, in the order they are drawn.
    static let quickChoices: [TimeOfDay] = [
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
    ]

    /// Reads what was typed into the **At** line.
    ///
    /// `HH:mm`, with one or two digits for the hour and **exactly two for the minutes**: `9:30`
    /// and `14:00` are times, `14:0` is a time still being typed and says so, and `14.00`,
    /// `1400` and `24:00` are not accepted (the file format is `T14:00`, and a reading that
    /// guessed would write something he did not mean). Spaces around it are ignored.
    static func typed(_ text: String) -> TypedTime {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return .invalid }
        let hourText = String(parts[0])
        let minuteText = String(parts[1])
        guard (1...2).contains(hourText.count), minuteText.count == 2,
              hourText.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              minuteText.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let hour = Int(hourText), let minute = Int(minuteText),
              (0...23).contains(hour), (0...59).contains(minute) else { return .invalid }
        return .time(TimeOfDay(hour: hour, minute: minute))
    }

    /// Minutes since midnight, the unit the planner and `DayPlan` work in.
    var minutesSinceMidnight: Int { hour * 60 + minute }
}

public extension TaskItem {
    /// This task with a new date **and** time of day, written together. **A time needs a date**:
    /// with no date there is no time either. Everything else on the line is untouched.
    func settingDue(date: DateOnly?, time: TimeOfDay?) -> TaskItem {
        var copy = self
        copy.dueDate = date
        copy.dueTime = date == nil ? nil : time
        return copy
    }

    /// This task moved to another date and **keeping its time of day**: a call at 14:00 moved to
    /// tomorrow is a call at 14:00 tomorrow (**Reschedule**, the Inbox keys, **Move to today**).
    /// With no date, the time goes too. This is the rule `AppModel.setDueDate` has always
    /// followed, now in one tested place.
    func settingDueDate(_ date: DateOnly?) -> TaskItem {
        settingDue(date: date, time: dueTime)
    }

    /// The due date and, when there is one, the time of day, as a row shows them:
    /// `2026-11-04` or `2026-11-04 14:00`. Nil when the task has no date. **One place**, so a
    /// task row, an Inbox line and the card in **File it** cannot word the same fact three ways.
    var dueText: String? {
        guard let dueDate else { return nil }
        guard let dueTime else { return dueDate.description }
        return "\(dueDate) \(dueTime)"
    }
}

/// A task that has a date and a time of day is a **fixed point in the day**, and three screens
/// have to agree on how long it lasts: **Plan** draws it, **Start the day** keeps the hour free,
/// and the Calendar section's day draws it. One rule, here.
public enum TimedTask {
    /// How long a timed task lasts when it has no length of its own: half an hour. This is the
    /// length the Calendar section's day has always drawn.
    public static let defaultMinutes = 30

    /// How long a timed task lasts: its own `~45m` when **Use task times** is on and it has one,
    /// else half an hour. With the setting off a hidden `~45m` must not change what is drawn.
    public static func minutes(of task: TaskItem, usesTaskTimes: Bool) -> Int {
        if usesTaskTimes, let own = task.minutes, own > 0 { return own }
        return defaultMinutes
    }

    /// Where the task lies on its day, in minutes since midnight: from its time, for its length,
    /// **cut at midnight** (a task at 23:50 is busy until 24:00, not into the next day). Nil for
    /// a task with no time of day. Never empty: the end is always after the start.
    public static func span(of task: TaskItem, usesTaskTimes: Bool) -> Range<Int>? {
        guard let time = task.dueTime else { return nil }
        let start = min(time.minutesSinceMidnight, 24 * 60 - 1)
        let end = min(24 * 60, start + minutes(of: task, usesTaskTimes: usesTaskTimes))
        return start..<max(start + 1, end)
    }
}

public extension NoteIndex {
    /// The open tasks due on this day that have a time of day, earliest first. **The one query**
    /// behind the cards on **Plan**, the busy hours in **Start the day** and the Calendar
    /// section's day (build 168): all three used to ask `openTasks(dueOn:)` and filter for
    /// themselves, which is how they would have come to disagree. Work notes are never in the
    /// index, so they never appear.
    func timedTasks(on day: DateOnly) -> [TaskRef] {
        openTasks(dueOn: day).filter { $0.task.dueTime != nil }
    }

    /// The hours those tasks take on the day, as the ranges **Start the day** places blocks
    /// around. `excluding` holds the `TaskRef.id` of tasks that are being placed right now: a
    /// picked task's own slot must not be busy, or it could never be put where it is due.
    func timedTaskRanges(on day: DateOnly, usesTaskTimes: Bool,
                         excluding picked: Set<String> = []) -> [Range<Int>] {
        timedTasks(on: day).compactMap { ref -> Range<Int>? in
            guard !picked.contains(ref.id) else { return nil }
            return TimedTask.span(of: ref.task, usesTaskTimes: usesTaskTimes)
        }
    }
}
