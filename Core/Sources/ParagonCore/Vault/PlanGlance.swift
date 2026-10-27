import Foundation

/// What the **Today's plan** widget says at one moment (build 273).
///
/// **All of the widget's words and choices are made here, in Core**, so they can be tested and
/// so the widget and **Today** cannot give two answers to "what is next?" (build 162's rule).
/// The widget itself only draws what this hands it.
///
/// - **The block is chosen by `NowAndNext`** (build 266), the very type behind the **Now** and
///   **Then** lines on **Today**: the snapshot's spans are turned back into `PlanBlock`s, so
///   an overlapping block, a block that ends this minute and a tie are settled by one rule.
///   Plan blocks only: his calendar events are in the ruler, in their own colour, and never in
///   the big line (his answer, 21 October: "Time blocks only").
/// - **Everything is worked out from the date it is given**, never from the clock now. A
///   widget's timeline is drawn ahead of time, one entry for each moment it should change, and
///   an entry that read the clock when it was drawn would show the moment the timeline was
///   made on all of them.
public struct PlanGlance: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// The file has no plan in it: written by a build before this one.
        case olderApp
        /// The file is from another day than the date asked about.
        case notToday
        /// The day has no plan blocks.
        case nothingPlanned
        /// There were blocks, and none is running or still to come.
        case allDone
        /// A block is running or still to come: `headline` is it.
        case planned
    }

    public let state: State
    /// Minutes since midnight at the date asked about, from the clock's own hour and minute
    /// (build 238).
    public let nowMinute: Int
    /// The block running now, else the next one to start. Nil unless `state` is `.planned`.
    public let headline: PlanBlock?
    /// Whether `headline` is running now.
    public let isNow: Bool
    /// The block after the headline: after the minute when the headline is running, after the
    /// headline's own start when it is still to come. Nil when the headline is the last one.
    public let then: PlanBlock?

    public init(snapshot: WidgetSnapshot, at date: Date, calendar: Calendar = .current) {
        let minute = NowAndNext.minute(of: date, calendar: calendar)
        let reading = PlanGlance.read(snapshot, minute: minute,
                                      day: DateOnly(date, calendar: calendar))
        self.nowMinute = minute
        self.state = reading.state
        self.headline = reading.headline
        self.isNow = reading.isNow
        self.then = reading.then
    }

    /// The answer for one moment. A small struct, so the initialiser sets each property once.
    private struct Reading {
        var state: State
        var headline: PlanBlock?
        var isNow: Bool
        var then: PlanBlock?
    }

    private static func read(_ snapshot: WidgetSnapshot, minute: Int, day: DateOnly) -> Reading {
        guard let spans = snapshot.plan else {
            return Reading(state: .olderApp, headline: nil, isNow: false, then: nil)
        }
        guard snapshot.day == day else {
            return Reading(state: .notToday, headline: nil, isNow: false, then: nil)
        }
        guard !spans.isEmpty else {
            return Reading(state: .nothingPlanned, headline: nil, isNow: false, then: nil)
        }
        // Not `let blocks = blocks(from:)`: a local shadows the method of the same name inside
        // its own initial value (build 150).
        let blocks = planBlocks(from: spans)
        let reading = NowAndNext(blocks: blocks, minute: minute)
        guard let headline = reading.now ?? reading.next else {
            return Reading(state: .allDone, headline: nil, isNow: false, then: nil)
        }
        // After the minute while the headline is running; after the headline's own start while
        // it is still to come. Either way it is the earliest block that starts later.
        let after = NowAndNext(blocks: blocks, minute: max(minute, headline.start)).next
        return Reading(state: .planned, headline: headline, isNow: reading.now != nil, then: after)
    }

    /// The snapshot's spans as plan blocks, numbered by their place in the list — which is how
    /// `DayPlan` numbers them, so `NowAndNext` settles ties the way **Today** does.
    private static func planBlocks(from spans: [WidgetSnapshot.Span]) -> [PlanBlock] {
        var blocks: [PlanBlock] = []
        for (position, span) in spans.enumerated() {
            blocks.append(PlanBlock(start: span.start, end: span.end, title: span.title,
                                    index: position))
        }
        return blocks
    }

    // MARK: Words

    /// Where the headline's block ends, as `PlanBlock.minutes` counts it: a block never runs
    /// for less than a minute, so "now" always has at least a minute left.
    private var headlineEnd: Int {
        guard let headline else { return nowMinute }
        return headline.start + headline.minutes
    }

    /// When the headline happens, in a few words:
    /// - running, under an hour left: "Now · 20 min left"
    /// - running, an hour or more left: "Now · until 11:00"
    /// - still to come, under an hour away: "in 25 min"
    /// - still to come, an hour or more away: "at 14:00"
    ///
    /// Nil when there is no headline.
    public var whenText: String? {
        guard let headline else { return nil }
        if isNow {
            let left = headlineEnd - nowMinute
            return left < 60 ? "Now \u{00B7} \(left) min left"
                             : "Now \u{00B7} until \(PlanBlock.clock(headlineEnd))"
        }
        let away = headline.start - nowMinute
        return away < 60 ? "in \(away) min" : "at \(headline.startText)"
    }

    /// The headline's start and end, "09:30 – 10:15", **only when `whenText` names no clock
    /// time of its own**. "at 14:00" and "until 11:00" already say one of the two, and the
    /// other would be said twice on a few lines of a small widget (build 169).
    public var rangeText: String? {
        guard let headline else { return nil }
        let soon = isNow ? (headlineEnd - nowMinute) < 60 : (headline.start - nowMinute) < 60
        return soon ? headline.timeText : nil
    }

    /// "Then 11:00 Write the report", or nil when nothing comes after the headline.
    public var thenText: String? {
        guard let then else { return nil }
        return "Then \(then.startText) \(then.title)"
    }

    // MARK: The ruler and the timeline

    /// The stretch of the day the ruler draws, in minutes since midnight: it starts at the
    /// hour of `minute`, and is moved earlier when that would run past 24:00, so it never
    /// draws hours that do not exist. At 22:40 with 3 hours it is 21:00 to 24:00.
    public static func window(at minute: Int, hours: Int) -> Range<Int> {
        let length = min(max(hours, 1), 24) * 60
        var start = (min(max(minute, 0), 24 * 60 - 1) / 60) * 60
        if start + length > 24 * 60 { start = 24 * 60 - length }
        return start..<(start + length)
    }

    /// The moments the widget's timeline has an entry for, from `date` to midnight: `date`
    /// itself, then **each whole minute for the next 60** (so "in 25 min" counts down for an
    /// hour), then **every quarter hour** and **every minute where a plan block or an event
    /// starts or ends** until midnight, and midnight itself, when the day on the file stops
    /// being the day. Oldest first, none twice, none after midnight.
    ///
    /// A widget is not drawn every minute for ever: the system reloads it when it likes, and
    /// the provider asks to be asked again in an hour (build 273). The quarter hours are what
    /// keeps the line and "at 14:00" right if that reload is late; only "in 25 min" can then
    /// be up to a quarter of an hour old.
    public static func entryDates(from date: Date, snapshot: WidgetSnapshot? = nil,
                                  calendar: Calendar = .current) -> [Date] {
        let dayStart = calendar.startOfDay(for: date)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: dayStart),
              midnight > date else { return [date] }

        // Minutes of the day where something starts or ends.
        var edges = Set<Int>()
        for span in (snapshot?.plan ?? []) + (snapshot?.events ?? []) {
            edges.insert(span.start)
            edges.insert(span.end)
        }

        var dates: [Date] = [date]
        // The whole minute at or before `date`; the loop starts one minute after it.
        let wholeMinute = (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60
        var moment = Date(timeIntervalSinceReferenceDate: wholeMinute + 60)
        var step = 1
        while moment < midnight {
            let minute = NowAndNext.minute(of: moment, calendar: calendar)
            if step <= 60 || minute % 15 == 0 || edges.contains(minute) {
                dates.append(moment)
            }
            moment = moment.addingTimeInterval(60)
            step += 1
        }
        dates.append(midnight)
        return dates
    }
}
