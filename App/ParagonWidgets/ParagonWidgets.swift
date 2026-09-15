import WidgetKit
import SwiftUI
import ParagonCore

/// PARAGON on the Home Screen and the Lock Screen (build 174, the last of the five he asked
/// for on 14 September).
///
/// **The widget reads one small file and nothing else.** The vault is a folder he picked, held
/// as a security-scoped bookmark that only the app can resolve, and a widget gets a few
/// milliseconds and nobody to ask for permission. So `AppModel.writeWidgetSnapshot()` puts a
/// `WidgetSnapshot` into the shared App Group container on every `reload()`, and this target
/// draws that. It never opens a note, never parses markdown and never writes anything.
///
/// **What it does when there is nothing to draw is half the design** (build 100's rule, on a
/// home screen): no file at all means the app has never been opened on this phone, and it says
/// so; a snapshot from yesterday says the app has not been opened today rather than drawing
/// yesterday's list as if it were this morning's; an empty list is the good news that nothing
/// is waiting, and says that.

// MARK: - The timeline

struct ParagonEntry: TimelineEntry {
    var date: Date
    /// Nil means the file was not there at all — a different answer from "nothing to do".
    var snapshot: WidgetSnapshot?
}

struct ParagonProvider: TimelineProvider {
    /// What the widget gallery shows while he is choosing one. Real-looking lines rather than
    /// his own, which are not readable from here anyway.
    func placeholder(in context: Context) -> ParagonEntry {
        ParagonEntry(date: Date(), snapshot: ParagonProvider.example)
    }

    func getSnapshot(in context: Context, completion: @escaping (ParagonEntry) -> Void) {
        completion(ParagonEntry(date: Date(),
                                snapshot: context.isPreview ? ParagonProvider.example : read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParagonEntry>) -> Void) {
        // One entry, and ask again after the next midnight. Nothing in the snapshot changes on
        // its own during a day — the app calls `reloadAllTimelines()` whenever the vault does —
        // but "today" does, and a list headed with yesterday's date is exactly what this widget
        // must not show.
        let entry = ParagonEntry(date: Date(), snapshot: read())
        let midnight = Calendar.current.nextDate(after: Date(),
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func read() -> WidgetSnapshot? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ParagonWidgetBundle.appGroupID) else { return nil }
        return WidgetSnapshot.read(fromContainer: container)
    }

    static let example = WidgetSnapshot(
        day: .today(),
        written: Date(),
        dueToday: 3,
        overdue: 1,
        inboxCount: 2,
        dueForReview: 1,
        items: [
            .init(id: "1", title: "Book the hotel", noteTitle: "Jönköping 70.3", noteKind: "project",
                  dueText: "today", isOverdue: false, serves: "Still racing at seventy",
                  servesIsGoal: true, url: "amspara://"),
            .init(id: "2", title: "Long ride, 3 h", noteTitle: "Base training", noteKind: "project",
                  dueText: "1 day over", isOverdue: true, serves: "Endurance",
                  servesIsGoal: false, url: "amspara://"),
            .init(id: "3", title: "Order the new saddle", noteTitle: "Bike", noteKind: "project",
                  dueText: nil, isOverdue: false, serves: "Still racing at seventy",
                  servesIsGoal: true, url: "amspara://"),
        ]
    )
}

// MARK: - Colours and symbols

/// The app's own colours and symbols, spelled once here.
///
/// **A widget is a separate target and cannot see the app's asset catalogue or its
/// `SidebarSection`**, so these are written out. That is a real risk of drift, and the comment
/// is the guard: the values match `Assets.xcassets` and `ChainSymbol`, and a change to either
/// belongs here in the same build — the lesson build 168 paid for.
enum WidgetLook {
    static let goal = Color(red: 0.66, green: 0.47, blue: 0.11)
    static let project = Color(red: 0.18, green: 0.48, blue: 0.31)
    static let area = Color(red: 0.75, green: 0.38, blue: 0.56)
    static let resource = Color(red: 0.20, green: 0.43, blue: 0.70)
    static let attention = Color.orange

    static func tint(forKind raw: String) -> Color {
        switch raw {
        case "goal": return goal
        case "area": return area
        case "resource": return resource
        default: return project
        }
    }

    static func symbol(forKind raw: String) -> String {
        switch raw {
        case "goal": return "target"
        case "area": return "circle.grid.2x2"
        case "resource": return "books.vertical"
        case "inbox": return "tray"
        case "daily": return "calendar"
        case "archive": return "archivebox"
        default: return "flag"
        }
    }
}

// MARK: - The actions widget

struct ActionsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ParagonEntry

    private var rowLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let snapshot = entry.snapshot, !snapshot.items.isEmpty {
                ForEach(snapshot.items.prefix(rowLimit)) { item in
                    ActionRow(item: item, compact: family == .systemSmall)
                }
                if snapshot.items.count > rowLimit {
                    Text("and \(snapshot.items.count - rowLimit) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                emptyLine
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "amspara://"))
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetLook.project)
            Text(family == .systemSmall ? "Actions" : "Today's actions")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            if let snapshot = entry.snapshot, snapshot.overdue > 0 {
                Text("\(snapshot.overdue) over")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetLook.attention)
            }
        }
    }

    /// **Three different silences, said as three different things.** Drawing the same blank
    /// box for all of them is the fault build 100 is about.
    @ViewBuilder
    private var emptyLine: some View {
        if entry.snapshot == nil {
            Text("Open PARAGON once and your actions appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let snapshot = entry.snapshot, snapshot.isStale(on: .today()) {
            Text("Nothing since you last opened PARAGON.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("Nothing due, nothing waiting", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionRow: View {
    let item: WidgetSnapshot.Item
    var compact = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: WidgetLook.symbol(forKind: item.noteKind))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WidgetLook.tint(forKind: item.noteKind))
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(compact ? 1 : 2)
                // The chain, in one line: the goal this is in aid of, else the area. A list of
                // actions without it is just a list (build 149).
                if !compact, let serves = item.serves {
                    Text(serves)
                        .font(.system(size: 9))
                        .foregroundStyle(item.servesIsGoal ? WidgetLook.goal : WidgetLook.area)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 2)
            if let due = item.dueText {
                Text(due)
                    .font(.system(size: 9, weight: item.isOverdue ? .semibold : .regular))
                    .foregroundStyle(item.isOverdue ? WidgetLook.attention : .secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct ActionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParagonActions", provider: ParagonProvider()) { entry in
            ActionsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's actions")
        .description("What is due today or earlier, then your next actions, and what each one serves.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - The small counts widget

struct CountsWidgetView: View {
    var entry: ParagonEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let s = entry.snapshot {
                CountLine(number: s.dueToday, word: "due today",
                          symbol: "calendar", tint: WidgetLook.project)
                CountLine(number: s.overdue, word: "overdue",
                          symbol: "clock.badge.exclamationmark", tint: WidgetLook.attention)
                CountLine(number: s.inboxCount, word: "in the Inbox",
                          symbol: "tray", tint: WidgetLook.resource)
                CountLine(number: s.dueForReview, word: "for a look",
                          symbol: "target", tint: WidgetLook.goal)
            } else {
                Text("Open PARAGON once and the counts appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "amspara://"))
    }
}

struct CountLine: View {
    let number: Int
    let word: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(number == 0 ? Color.secondary : tint)
                .frame(width: 13)
            // A zero is grey and a number is not, so the one that wants him reads first.
            Text("\(number)")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(number == 0 ? Color.secondary : tint)
                .monospacedDigit()
            Text(word)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct CountsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParagonCounts", provider: ParagonProvider()) { entry in
            CountsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("What is waiting")
        .description("Due today, overdue, waiting in the Inbox, and due for a look.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - The bundle

@main
struct ParagonWidgetBundle: WidgetBundle {
    /// **The old name on purpose.** The App Group is one of the four identifiers the rename to
    /// PARAGON deliberately kept, because it is enabled under this name in Apple's developer
    /// portal and the share extension already uses it.
    static let appGroupID = "group.com.schabbauer.amspara"

    var body: some Widget {
        ActionsWidget()
        CountsWidget()
    }
}
