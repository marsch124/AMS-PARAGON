import WidgetKit
import SwiftUI
import ParagonCore

#if os(iOS)
/// PARAGON on the iPhone's Lock Screen (build 317): three small widgets beside the clock.
///
/// - **Round**: how many open tasks are due today or earlier.
/// - **Wide**: the same in words, and the next two actions.
/// - **The line above the clock**: "3 due today".
///
/// They read the same small file as the other widgets and nothing else, and every word is
/// chosen in Core by `LockGlance`, which is tested. A task ticked on a Home Screen widget is
/// already left out here (`WidgetSnapshot.settled`). A file from another day says **Open
/// PARAGON** — never yesterday's number beside today's clock. A tap opens **Today**.
struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ParagonLock", provider: ParagonProvider()) { entry in
            LockWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Due today")
        .description("How much is due today, and your next two actions.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ParagonEntry

    private var today: DateOnly { DateOnly(entry.date) }
    /// With the ticks that are waiting already taken off.
    private var snapshot: WidgetSnapshot? { entry.snapshot?.settled(entry.ticks) }

    var body: some View {
        content
            .widgetURL(URL(string: WidgetSnapshot.link(toList: .today)))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(LockGlance.inline(snapshot, on: today))
        case .accessoryCircular:
            circular
        default:
            rectangular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let count = LockGlance.count(snapshot, on: today) {
                if count == 0 {
                    WidgetMark(name: "checkmark.circle", size: 30)
                        .widgetAccentable()
                } else {
                    VStack(spacing: -1) {
                        Text("\(count)")
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .widgetAccentable()
                        Text("due")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                }
            } else {
                // No file, or yesterday's: the mark of Today, and a tap opens PARAGON.
                WidgetMark(name: "sun.max", size: 26)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LockGlance.inline(snapshot, on: today))
    }

    private var rectangular: some View {
        let lines = LockGlance.lines(snapshot, on: today)
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                WidgetMark(name: "sun.max", size: 13)
                Text(LockGlance.heading(snapshot, on: today))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .widgetAccentable()
            if lines.isEmpty {
                // Said once: with no file the heading already says "Open PARAGON".
                if LockGlance.count(snapshot, on: today) != nil {
                    Text(LockGlance.emptyText(snapshot, on: today))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 4) {
                        WidgetMark(name: "circle", size: 11)
                        // One step under the heading, so "Book the night train" fits whole
                        // and the heading stays the largest line (designer, build 317).
                        Text(line)
                            .font(.footnote)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
