import SwiftUI
import ParagonCore

/// The day's Apple Calendar events as rows for a List section or a VStack. The container
/// loads them with `.task(id: date) { await model.loadEvents(for: date) }`.
struct CalendarEventRows: View {
    @EnvironmentObject private var model: AppModel
    let date: DateOnly
    /// One line per event instead of two, in smaller type — for Today, where the day's events
    /// share a screen with everything else (build 212). The Calendar section and the daily
    /// note keep the roomy rows: those screens are about the day itself.
    var compact = false

    var body: some View {
        if model.calendarAccessGranted == false {
            Text("Calendar access is off. Allow it in System Settings › Privacy & Security › Calendars, or turn events off in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let events = model.events(on: date)
            if events.isEmpty {
                Text(model.calendarAccessGranted == nil ? "Loading events…" : "No events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    CalendarEventRow(event: event, date: date, compact: compact)
                }
            }
        }
    }
}

struct CalendarEventRow: View {
    @EnvironmentObject private var model: AppModel
    let event: CalendarEvent
    let date: DateOnly
    var compact = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 6 : 8) {
            Circle()
                .fill(event.color)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3 }
            Text(event.timeLabel(on: date))
                .font(compact ? .caption.monospacedDigit() : .callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: compact ? 74 : 96, alignment: .leading)
            // **Compact puts the place on the same line as the name**, after a middle dot,
            // rather than under it: a second line is what made this section twice as tall as
            // it needed to be on Today. The name is what you read; the place follows it and
            // gives way first when the row runs out of width.
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(compact ? .callout : .body)
                        .lineLimit(1)
                    if let location = event.location, compact {
                        Text("· \(location)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }
                    if event.isTimeBlock {
                        Text("block")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(event.color.opacity(0.18), in: Capsule())
                    }
                }
                if let location = event.location, !compact {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                model.openInCalendar(event)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(compact ? .caption : .body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open in Calendar")
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.openInCalendar(event) }
        .contextMenu {
            Button("Open in Calendar") { model.openInCalendar(event) }
        }
        .help("\(event.title) (\(event.calendarTitle)). Double-click to open in Calendar.")
    }
}
