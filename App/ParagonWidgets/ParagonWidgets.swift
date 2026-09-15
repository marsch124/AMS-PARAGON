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
    /// Whether the shared folder could be reached at all (build 177).
    ///
    /// **This is a third answer, and the app cannot fix it.** If the App Group is not switched
    /// on for this build of the widget, `containerURL` is nil and there is nothing to read no
    /// matter how often PARAGON is opened. Before 177 that looked exactly like "the app has
    /// never run here", and he was told to open the app again — which could never have worked.
    var folderFound: Bool = true
}

struct ParagonProvider: TimelineProvider {
    /// What the widget gallery shows while he is choosing one. Real-looking lines rather than
    /// his own, which are not readable from here anyway.
    func placeholder(in context: Context) -> ParagonEntry {
        ParagonEntry(date: Date(), snapshot: ParagonProvider.example)
    }

    func getSnapshot(in context: Context, completion: @escaping (ParagonEntry) -> Void) {
        completion(context.isPreview
                   ? ParagonEntry(date: Date(), snapshot: ParagonProvider.example)
                   : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParagonEntry>) -> Void) {
        // One entry, and ask again after the next midnight. Nothing in the snapshot changes on
        // its own during a day — the app calls `reloadAllTimelines()` whenever the vault does —
        // but "today" does, and a list headed with yesterday's date is exactly what this widget
        // must not show.
        let now = currentEntry()
        let midnight = Calendar.current.nextDate(after: Date(),
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [now], policy: .after(midnight)))
    }

    /// Named `currentEntry`, never `entry`: `let entry = entry()` would be a local
    /// shadowing the method inside its own initial value (build 150).
    private func currentEntry() -> ParagonEntry {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ParagonWidgetBundle.appGroupID) else {
            return ParagonEntry(date: Date(), snapshot: nil, folderFound: false)
        }
        return ParagonEntry(date: Date(),
                            snapshot: WidgetSnapshot.read(fromContainer: container),
                            folderFound: true)
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

// MARK: - The line that is always there

/// The widget's own build number, read out of its own Info.plist.
///
/// The workflow sets `CFBundleShortVersionString` to `1.0.<build>` on every bundle, so this is
/// the build of **the widget**, not of the app beside it. That difference matters: a widget can
/// be left behind by an update, and then nothing else on the phone would say so.
enum WidgetBuild {
    static var number: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return short.split(separator: ".").last.map(String.init) ?? "?"
    }
}

/// One small line at the foot of every widget, saying what this widget found (build 177).
///
/// **His widget came up completely blank** and nothing anywhere could say which of three things
/// had happened: the extension not running at all, the shared folder not reachable, or the file
/// not written yet. This line answers all three at once — if it is on screen the extension is
/// running, and it names what it read. That is build 100's rule ("never let a read failure look
/// like an absence") applied to the one screen that cannot be asked any questions.
struct WidgetFoot: View {
    var entry: ParagonEntry

    private var state: String {
        if !entry.folderFound { return "shared folder missing" }
        guard let snapshot = entry.snapshot else { return "nothing written yet" }
        return "written " + snapshot.written.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        Text("PARAGON \(WidgetBuild.number) · \(state)")
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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
            WidgetFoot(entry: entry)
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

    /// **Four different silences, said as four different things.** Drawing the same blank
    /// box for all of them is the fault build 100 is about. The first one is not about his
    /// vault at all: it is this widget being unable to reach the folder it shares with the
    /// app, and opening PARAGON again would not mend it (build 177).
    @ViewBuilder
    private var emptyLine: some View {
        if !entry.folderFound {
            Text("This widget cannot reach PARAGON's shared folder. Nothing you do on the phone will mend it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if entry.snapshot == nil {
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
                Text(entry.folderFound
                     ? "Open PARAGON once and the counts appear here."
                     : "This widget cannot reach PARAGON's shared folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            WidgetFoot(entry: entry)
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
