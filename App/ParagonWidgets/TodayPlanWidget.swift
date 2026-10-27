import WidgetKit
import SwiftUI
import ParagonCore

/// **Today's plan** (build 273): a widget for the Mac that shows the time block you are in, or
/// the one that comes next, and a small ruler of the next hours with your blocks and your
/// calendar events on it. A click opens PARAGON on **Time Blocks**, on today.
///
/// **The same rules as the other widgets.** It reads the one small file the app writes and
/// nothing else; it never opens the vault, never parses markdown and never writes. What it says
/// when it has nothing to draw is half the design (build 100's rule): a file from another day, a
/// file from an older build, a day with no blocks and a day that is finished are four different
/// sentences, and none of them is a blank box.
///
/// **Every word and every choice is made in Core, by `PlanGlance`**, which is tested. This file
/// only draws. The big line is chosen by `NowAndNext` (build 266), the type behind the **Now**
/// and **Then** lines on **Today**, so the widget and **Today** always name the same block.
///
/// **Everything here is worked out from `entry.date`**, never from the clock now. WidgetKit
/// draws a timeline's entries ahead of time, one for each moment the widget should change; a
/// view that asked the clock would show the moment the timeline was made on every one of them.
///
/// **Registered on the Mac only** (his answer, 21 October: "Mac only"), in `ParagonWidgetBundle`.
/// The file still compiles for the iPhone, because the widget target builds for both.

// MARK: - Colours

/// The app's own colours for this widget (build 273), read from this target's own copy of three
/// colour sets in `Assets.xcassets` — **byte for byte the app's `PlanTint`, `CalendarTint` and
/// `NowTint`**, so the light and dark values are the app's and nothing is typed in twice by hand.
///
/// **That is still a copy, and it can drift** (build 168): a change to one of the three in the
/// app's catalogue belongs in this one in the same build. `WidgetLookTests` compares the three
/// files with the app's and fails when one differs.
///
/// Kept apart from `WidgetLook` on purpose: that enum holds the other widgets' colours, typed
/// in as numbers, and this build changes none of them.
enum PlanLook {
    /// Orange: plan blocks and the big line.
    static let plan = Color("PlanTint")
    /// Violet: Apple Calendar events.
    static let calendar = Color("CalendarTint")
    /// Soft slate blue: the line for now. It is not a kind of note, so no kind's colour.
    static let now = Color("NowTint")
    /// The symbol of the **Time Blocks** row in the sidebar, written out the same.
    static let symbol = "calendar.badge.clock"
}

// MARK: - The timeline

struct TodayPlanProvider: TimelineProvider {
    /// What the gallery shows while he is choosing a widget: a morning with a block ahead.
    /// **A fixed 09:05**, so the picture always shows "in 25 min", whatever the time is when
    /// he looks.
    func placeholder(in context: Context) -> ParagonEntry {
        TodayPlanProvider.exampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ParagonEntry) -> Void) {
        completion(context.isPreview
                   ? TodayPlanProvider.exampleEntry()
                   : ParagonEntry.read(at: Date()))
    }

    /// **One entry for each moment the words or the line should change**
    /// (`PlanGlance.entryDates`), so "in 25 min" counts down and the line for now moves while
    /// PARAGON is closed. Asks again in an hour: the system decides when it really reloads,
    /// and the quarter-hour entries keep the line and "at 14:00" right if it is late.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ParagonEntry>) -> Void) {
        let now = Date()
        let fresh = ParagonEntry.read(at: now)
        guard let snapshot = fresh.snapshot else {
            // No file, or no shared folder: there is nothing to count down. The app asks for a
            // redraw as soon as it writes, so this only has to be a fallback.
            completion(Timeline(entries: [fresh], policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }
        let dates = PlanGlance.entryDates(from: now, snapshot: snapshot)
        let entries = dates.map { moment in
            ParagonEntry(date: moment, snapshot: snapshot, folderFound: true)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
    }

    static func exampleEntry() -> ParagonEntry {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 9, minute: 5, second: 0,
                                    of: calendar.startOfDay(for: Date())) ?? Date()
        let snapshot = WidgetSnapshot(
            day: DateOnly(morning),
            written: morning,
            dueToday: 0, overdue: 0, inboxCount: 0, dueForReview: 0,
            items: [],
            plan: [
                WidgetSnapshot.Span(title: "Swim", start: 9 * 60 + 30, end: 10 * 60 + 15),
                WidgetSnapshot.Span(title: "Write the report", start: 11 * 60, end: 12 * 60),
            ],
            events: [
                WidgetSnapshot.Span(title: "Team meeting", start: 10 * 60, end: 10 * 60 + 45),
            ])
        return ParagonEntry(date: morning, snapshot: snapshot, folderFound: true)
    }
}

// MARK: - The widget

struct TodayPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParagonPlan", provider: TodayPlanProvider()) { entry in
            TodayPlanView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's plan")
        .description("The time block on now or next, and the next hours with your blocks and calendar events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

enum PlanSize {
    case small, medium, large
}

struct TodayPlanView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ParagonEntry

    /// The three sizes this widget has, whatever the family says: anything that is not small or
    /// large is drawn as medium, so a family added later cannot leave a blank. A plain property,
    /// not a `switch` inside the view builder.
    private var size: PlanSize {
        switch family {
        case .systemSmall: return .small
        case .systemLarge: return .large
        default: return .medium
        }
    }

    /// Nil when there is no file, or no folder to read one from.
    private var glance: PlanGlance? {
        guard entry.folderFound, let snapshot = entry.snapshot else { return nil }
        return PlanGlance(snapshot: snapshot, at: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            middle
            WidgetFoot(entry: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The existing scheme, `amspara://`, with an empty host and the path /plan: the app
        // opens Time Blocks on today. A link to a note has the note's title as its host.
        .widgetURL(URL(string: WidgetSnapshot.planLink))
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: PlanLook.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PlanLook.plan)
            Text("Today's plan")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var middle: some View {
        if let glance, let snapshot = entry.snapshot {
            filled(glance, snapshot)
        } else {
            Text(missingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The ruler is drawn whenever the file is from today: with no blocks left it still shows
    /// the calendar events and where the day is. It is left out on the small size, and when the
    /// file cannot say anything about today.
    @ViewBuilder
    private func filled(_ glance: PlanGlance, _ snapshot: WidgetSnapshot) -> some View {
        if !showsRuler(for: glance) || size == .small {
            PlanHeadline(glance: glance, size: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if size == .large {
            VStack(alignment: .leading, spacing: 8) {
                PlanHeadline(glance: glance, size: size)
                PlanRuler(snapshot: snapshot, date: entry.date, hours: 6, labelled: true)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                PlanHeadline(glance: glance, size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                PlanRuler(snapshot: snapshot, date: entry.date, hours: 3, labelled: false)
                    .frame(width: 132)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func showsRuler(for glance: PlanGlance) -> Bool {
        switch glance.state {
        case .planned, .nothingPlanned, .allDone: return true
        case .olderApp, .notToday: return false
        }
    }

    /// Short on the small size: a message that fills the card pushes the foot line, which
    /// explains the message, off the bottom (build 179).
    private var missingText: String {
        let small = size == .small
        if !entry.folderFound {
            return small ? "Shared folder missing."
                         : "This widget cannot reach PARAGON's shared folder. Opening PARAGON will not mend it."
        }
        return small ? "Open PARAGON once." : "Open PARAGON once and your plan appears here."
    }
}

// MARK: - The big line

/// The words on the left (or on top): the block that is on now or comes next, when it is, and
/// the block after it — or, when there is nothing to say about blocks, why not.
struct PlanHeadline: View {
    var glance: PlanGlance
    var size: PlanSize

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            lines
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // One sentence for VoiceOver, not four separate texts.
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var lines: some View {
        switch glance.state {
        case .planned:
            planned
        case .nothingPlanned:
            message("No blocks planned today.", "Click to plan the day.")
        case .allDone:
            message("Nothing more planned today.", nil)
        case .notToday:
            message(size == .small ? "Not opened today." : "Nothing since you last opened PARAGON.", nil)
        case .olderApp:
            message(size == .small ? "Open PARAGON once." : "Open PARAGON once and your plan appears here.", nil)
        }
    }

    @ViewBuilder
    private var planned: some View {
        if let headline = glance.headline {
            Text(headline.title)
                .font(.system(size: size == .small ? 17 : 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PlanLook.plan)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        if let when = glance.whenText {
            Text(when)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        if size != .small, let range = glance.rangeText {
            Text(range)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        if let then = glance.thenText {
            Text(then)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(size == .small ? 2 : 1)
                .padding(.top, 2)
        }
    }

    private func message(_ first: String, _ second: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(first)
                .font(.caption.weight(.semibold))
            if let second {
                Text(second)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - The ruler

/// Where things sit on the ruler. Worked out once from the size, so the hour rows, the boxes and
/// the line for now cannot disagree about where a minute is.
struct RulerGeometry {
    let size: CGSize
    let window: Range<Int>
    let gutter: CGFloat
    let gap: CGFloat

    init(size: CGSize, window: Range<Int>, gutter: CGFloat) {
        self.size = size
        self.window = window
        self.gutter = gutter
        self.gap = 3
    }

    var laneWidth: CGFloat { max(0, (size.width - gutter - gap) / 2) }
    /// The left lane: Apple Calendar events.
    var calendarX: CGFloat { gutter }
    /// The right lane: plan blocks.
    var blocksX: CGFloat { gutter + laneWidth + gap }

    func y(forMinute minute: Int) -> CGFloat {
        let length = CGFloat(max(1, window.upperBound - window.lowerBound))
        return CGFloat(minute - window.lowerBound) / length * size.height
    }

    func contains(_ minute: Int) -> Bool { window.contains(minute) }
}

/// One box on the ruler, ready to draw. A struct with an id, never a tuple: a `ForEach` id is a
/// key path and a key path cannot address a tuple member (build 61).
struct RulerBox: Identifiable {
    let id: Int
    let title: String
    let isBlock: Bool
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    /// A name fits only in a box that is tall and wide enough to hold a line of small text.
    var showsTitle: Bool { height >= 13 && width >= 36 }
}

struct HourMark: Identifiable {
    let id: Int
    let y: CGFloat
}

/// The next hours of the day, as two lanes like the Plan screen: **Calendar** on the left and
/// **Time blocks** on the right, with a line for now across both.
///
/// **A block is filled and has a solid edge; an event has an outline and no fill.** On a desktop that is
/// not in front macOS draws a widget in grey with no colour, and orange and violet then look
/// alike — the shape still tells them apart.
///
/// **Every box is placed with `.offset` inside a top-leading stack, never `.position`**
/// (build 85): the view keeps its own size.
struct PlanRuler: View {
    let snapshot: WidgetSnapshot
    let date: Date
    let hours: Int
    /// The large size names the two lanes above the ruler.
    let labelled: Bool

    /// The clock's own hour and minute at the entry's date (build 238).
    private var minute: Int { NowAndNext.minute(of: date) }

    private var window: Range<Int> { PlanGlance.window(at: minute, hours: hours) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if labelled {
                laneNames
            }
            GeometryReader { proxy in
                canvas(in: proxy.size)
            }
        }
    }

    private var laneNames: some View {
        HStack(spacing: 3) {
            Color.clear.frame(width: 17, height: 1)
            Text(snapshot.events == nil ? "Calendar not shown" : "Calendar")
                .foregroundStyle(snapshot.events == nil ? Color.secondary : PlanLook.calendar)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Time blocks")
                .foregroundStyle(PlanLook.plan)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 9, weight: .medium))
        .lineLimit(1)
    }

    private func canvas(in size: CGSize) -> some View {
        let geometry = RulerGeometry(size: size, window: window, gutter: 20)
        return ZStack(alignment: .topLeading) {
            ForEach(hourMarks(in: geometry)) { mark in
                hourRow(mark, geometry)
            }
            calendarNotShown(geometry)
            ForEach(boxes(in: geometry)) { box in
                boxView(box)
            }
            nowMarker(geometry)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// **An empty Calendar lane must not look like a day with no events** (build 100). With no
    /// Calendar to show (`events` is nil: no access, or switched off in Settings), the lane says
    /// so in its own words. The large size already says it in the lane names above the ruler,
    /// so it is drawn here only when `labelled` is false — the medium size, which has no names.
    /// Placed with `.offset` (build 85); it wraps to two lines in the lane's width.
    @ViewBuilder
    private func calendarNotShown(_ geometry: RulerGeometry) -> some View {
        if snapshot.events == nil && !labelled {
            Text("Calendar not shown")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(width: geometry.laneWidth, alignment: .topLeading)
                .offset(x: geometry.calendarX, y: 2)
        }
    }

    // MARK: Hours

    private func hourMarks(in geometry: RulerGeometry) -> [HourMark] {
        var marks: [HourMark] = []
        var hour = geometry.window.lowerBound / 60
        let last = geometry.window.upperBound / 60
        while hour < last {
            marks.append(HourMark(id: hour, y: geometry.y(forMinute: hour * 60)))
            hour += 1
        }
        return marks
    }

    private func hourRow(_ mark: HourMark, _ geometry: RulerGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: max(0, geometry.size.width - geometry.gutter), height: 0.5)
                .offset(x: geometry.gutter, y: 0)
            Text(String(format: "%02d", mark.id))
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .frame(width: geometry.gutter - 4, alignment: .trailing)
                .offset(x: 0, y: 1)
        }
        .frame(width: geometry.size.width, alignment: .topLeading)
        .offset(x: 0, y: mark.y)
    }

    // MARK: Boxes

    /// Events first, so a block drawn on the same hours is on top of them.
    private func boxes(in geometry: RulerGeometry) -> [RulerBox] {
        var result: [RulerBox] = []
        var id = 0
        for span in snapshot.events ?? [] {
            if let box = box(for: span, id: id, isBlock: false, in: geometry) { result.append(box) }
            id += 1
        }
        for span in snapshot.plan ?? [] {
            if let box = box(for: span, id: id, isBlock: true, in: geometry) { result.append(box) }
            id += 1
        }
        return result
    }

    /// The part of a span that falls inside the window, or nil when none of it does. A span is
    /// at least a minute long, and a box is never drawn less than 4 points tall.
    private func box(for span: WidgetSnapshot.Span, id: Int, isBlock: Bool,
                     in geometry: RulerGeometry) -> RulerBox? {
        let lower = geometry.window.lowerBound
        let upper = geometry.window.upperBound
        let start = max(span.start, lower)
        let end = min(max(span.end, span.start + 1), upper)
        guard end > start else { return nil }
        let top = geometry.y(forMinute: start)
        let height = min(max(4, geometry.y(forMinute: end) - top), max(4, geometry.size.height - top))
        return RulerBox(id: id,
                        title: span.title,
                        isBlock: isBlock,
                        x: isBlock ? geometry.blocksX : geometry.calendarX,
                        y: top,
                        width: geometry.laneWidth,
                        height: height)
    }

    private func boxView(_ box: RulerBox) -> some View {
        let tint = box.isBlock ? PlanLook.plan : PlanLook.calendar
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        return shape
            .fill(box.isBlock ? tint.opacity(0.30) : Color.clear)
            .overlay(shape.strokeBorder(tint, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if box.showsTitle {
                    Text(box.title)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                        .padding(.top, 1)
                }
            }
            .frame(width: box.width, height: box.height)
            .offset(x: box.x, y: box.y)
    }

    // MARK: Now

    /// The same line as the app's `NowLine` (Theme.swift): 1.5 points, with a 7-point dot.
    @ViewBuilder
    private func nowMarker(_ geometry: RulerGeometry) -> some View {
        if geometry.contains(minute) {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(PlanLook.now)
                    .frame(height: 1.5)
                Circle()
                    .fill(PlanLook.now)
                    .frame(width: 7, height: 7)
                    .offset(x: -3)
            }
            .frame(width: max(0, geometry.size.width - geometry.gutter), height: 7, alignment: .leading)
            .offset(x: geometry.gutter, y: geometry.y(forMinute: minute) - 3.5)
        }
    }
}
