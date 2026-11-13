import WidgetKit
import SwiftUI
import AppIntents
import ParagonCore

/// **One list** (round 9, build 316): a small widget that shows one number and opens one list,
/// and **he chooses which** with the widget's own **Edit Widget**: Today, Overdue, Inbox or
/// Review. A small widget can open one place only (Apple's rule), so the small **What is
/// waiting** opens the first list with something in it; with this one he places one small
/// widget per list.
///
/// **A widget of its own, on purpose.** The two widgets he has placed (`ParagonActions`,
/// `ParagonCounts`) are not touched: same kind, same code, same behaviour. This one reads the
/// same small file through `ParagonEntry.read`, and never anything else.

/// The choice in **Edit Widget**. The raw values are `WidgetList`'s, so the link is the same
/// `amspara:///list/<name>` the other widgets send.
enum OneListChoice: String, AppEnum {
    case today, overdue, inbox, review

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "List"
    static var caseDisplayRepresentations: [OneListChoice: DisplayRepresentation] = [
        .today: "Today",
        .overdue: "Overdue",
        .inbox: "Inbox",
        .review: "Review",
    ]

    var list: WidgetList { WidgetList(rawValue: rawValue) ?? .today }
}

struct OneListIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a list"
    static var description = IntentDescription("Which list this widget shows and opens.")

    @Parameter(title: "List", default: .today)
    var list: OneListChoice
}

struct OneListEntry: TimelineEntry {
    var date: Date
    var base: ParagonEntry
    var list: WidgetList
}

struct OneListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneListEntry {
        OneListEntry(date: Date(), base: ParagonEntry(date: Date(), snapshot: ParagonProvider.example), list: .today)
    }

    func snapshot(for configuration: OneListIntent, in context: Context) async -> OneListEntry {
        let base = context.isPreview
            ? ParagonEntry(date: Date(), snapshot: ParagonProvider.example)
            : ParagonEntry.read(at: Date())
        return OneListEntry(date: base.date, base: base, list: configuration.list.list)
    }

    func timeline(for configuration: OneListIntent, in context: Context) async -> Timeline<OneListEntry> {
        // One entry, and again after the next midnight: the same rhythm as the other widgets.
        let base = ParagonEntry.read(at: Date())
        let midnight = Calendar.current.nextDate(after: Date(),
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [OneListEntry(date: base.date, base: base, list: configuration.list.list)],
                        policy: .after(midnight))
    }
}

/// What one list looks like on the widget: its name, mark, colour and words. The marks and
/// colours are the ones **What is waiting** draws for the same four numbers.
struct OneListLook {
    let name: String
    let symbol: String
    let tint: Color
    let words: String
    let emptyWords: String

    init(_ list: WidgetList) {
        switch list {
        case .today:
            name = "Today"; symbol = "calendar"; tint = WidgetLook.project
            words = "due today"; emptyWords = "Nothing due today"
        case .overdue:
            name = "Overdue"; symbol = "clock.badge.exclamationmark"; tint = WidgetLook.attention
            words = "overdue"; emptyWords = "Nothing overdue"
        case .inbox:
            name = "Inbox"; symbol = "tray"; tint = WidgetLook.resource
            words = "in the Inbox"; emptyWords = "The Inbox is empty"
        case .review:
            name = "Review"; symbol = "target"; tint = WidgetLook.goal
            words = "for a look"; emptyWords = "Nothing for a look"
        }
    }

    static func number(_ list: WidgetList, in snapshot: WidgetSnapshot) -> Int {
        switch list {
        case .today: return snapshot.dueToday
        case .overdue: return snapshot.overdue
        case .inbox: return snapshot.inboxCount
        case .review: return snapshot.dueForReview
        }
    }
}

struct OneListWidgetView: View {
    var entry: OneListEntry

    var body: some View {
        let look = OneListLook(entry.list)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                WidgetMark(name: look.symbol, size: 14)
                Text(look.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(look.tint)
            if let snapshot = entry.base.snapshot {
                let number = OneListLook.number(entry.list, in: snapshot)
                // A zero is grey and a number is not, as on What is waiting.
                Text("\(number)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(number == 0 ? Color.secondary : look.tint)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(number == 0 ? look.emptyWords : look.words)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(entry.base.folderFound
                     ? "Open PARAGON once and the number appears here."
                     : "This widget cannot reach PARAGON's shared folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
            WidgetFoot(entry: entry.base)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: WidgetSnapshot.link(toList: entry.list)))
    }
}

struct OneListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ParagonOneList", intent: OneListIntent.self, provider: OneListProvider()) { entry in
            OneListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("One list")
        .description("One number, and a press opens its list. Choose the list with Edit Widget: Today, Overdue, Inbox or Review.")
        .supportedFamilies([.systemSmall])
    }
}
