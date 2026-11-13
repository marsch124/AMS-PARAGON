import Foundation

/// What the focus timer's Live Activity draws (build 317): the Lock Screen banner and the
/// Dynamic Island on the iPhone.
///
/// **Dates, never a counter** — the same rule as `FocusSession`. While the clock runs the
/// system draws the time itself from `countsFrom`, so the Live Activity is right every second
/// without the app saying anything; the app only speaks when something changes (pause, go on,
/// stop). `countsFrom` is worked out from the session's own dates, never from the clock now, so
/// the same session always gives the same value and an unchanged session is never sent twice.
public struct FocusGlance: Codable, Hashable, Sendable {
    public var isPaused: Bool
    /// **Stop** was pressed and the question (**Done, tick it off** / **Not done yet**) is
    /// waiting in PARAGON. Pause and Go on do nothing then, so no buttons are drawn.
    public var awaitingAnswer: Bool
    /// Whole seconds worked when this was made. What a paused clock shows.
    public var workedSeconds: Int
    /// The moment a clock showing 0:00 would have started, for a running clock: the start of
    /// the running stretch, moved back by the stretches before it. While paused it is the
    /// moment of the pause moved back by the time worked, and is not drawn.
    public var countsFrom: Date
    /// The planned time, when the task or block has one.
    public var plannedSeconds: Int?

    public init(session: FocusSession, at now: Date, awaitingAnswer: Bool = false) {
        let closed = session.runs.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        self.isPaused = session.isPaused
        self.awaitingAnswer = awaitingAnswer && session.isPaused
        if let since = session.runningSince {
            self.countsFrom = since.addingTimeInterval(-closed)
            self.workedSeconds = max(0, Int(session.workedSeconds(at: now)))
        } else {
            self.countsFrom = (session.runs.last?.end ?? now).addingTimeInterval(-closed)
            self.workedSeconds = max(0, Int(closed))
        }
        self.plannedSeconds = session.plannedMinutes.flatMap { $0 > 0 ? $0 * 60 : nil }
    }

    /// When the planned time is reached, for a running clock's bar. Nil with nothing planned.
    public var plannedEnd: Date? {
        plannedSeconds.map { countsFrom.addingTimeInterval(TimeInterval($0)) }
    }

    /// How full a paused clock's bar is, 0 to 1. Nil with nothing planned.
    public var fraction: Double? {
        guard let planned = plannedSeconds, planned > 0 else { return nil }
        return min(1, Double(workedSeconds) / Double(planned))
    }

    /// The clock of a paused timer, as the bar in the app writes it: "4:09", "1:02:05".
    public var clock: String { FocusSession.clock(TimeInterval(workedSeconds)) }

    /// The small words after the clock: "of 45 min", "of 45 min · paused", "paused",
    /// "stopped". Nil for a running clock with nothing planned.
    public var note: String? {
        let planned = plannedSeconds.map { "of " + TaskTime.label($0 / 60) }
        if awaitingAnswer { return "stopped" }
        if isPaused { return planned.map { $0 + " \u{00B7} paused" } ?? "paused" }
        return planned
    }

    /// The line under a stopped clock: what he has to do next, and where.
    public static let answerHint = "Open PARAGON to save the time"
}

public extension FocusSession {
    /// When the clock was first started. With the title it tells one session from another, so
    /// a Live Activity left behind by a session that is over is recognised and ended.
    var startedAt: Date? { runs.first?.start ?? runningSince }
}
