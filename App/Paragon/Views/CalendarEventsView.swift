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
            Text("Calendar access is off. Allow it in \(DeviceWords.systemSettings) › Privacy & Security › Calendars, or turn events off in Settings.")
                .font(Txt.label)
                .foregroundStyle(.soft)
        } else {
            let events = model.events(on: date)
            if events.isEmpty {
                Text(model.calendarAccessGranted == nil ? "Loading events…" : "No events")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            } else if compact {
                // **One list row holding every event, not one row each** (build 213). A `List`
                // gives every row a minimum height — about 44pt on the iPhone, the size Apple
                // treats as a comfortable target — plus its own padding above and below, so
                // build 212's smaller text shrank the text and left the rows exactly as tall.
                // Stacked inside a single row, the list pays that cost once and the spacing
                // between events is ours. Each event keeps its double-tap and its menu; they
                // simply stop being separate rows, which they never needed to be.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events) { event in
                        CalendarEventRow(event: event, date: date, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(events) { event in
                    CalendarEventRow(event: event, date: date)
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
                // Build 346: a thin edge, so a pale calendar colour (yellow) still shows on a
                // tinted card; and the dot's middle on the middle of the line.
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                .centredOnFirstLine()
            Text(event.timeLabel(on: date))
                .font(compact ? .caption.monospacedDigit() : .callout.monospacedDigit())
                .foregroundStyle(.soft)
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
                            .font(Txt.label)
                            .foregroundStyle(.soft)
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }
                    if event.isTimeBlock {
                        Text("block")
                            .font(Txt.listSecond)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(event.color.opacity(0.18), in: Capsule())
                    }
                }
                if let location = event.location, !compact {
                    Text(location)
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button {
                model.openInCalendar(event)
            } label: {
                // Build 291: a small round button in the event's calendar colour.
                // Build 346, his picture ("poor readability"): a yellow calendar drew a pale
                // yellow arrow on a pale yellow ring, unreadable on Today's lilac card. The
                // button is now plain and strong in every colour: the arrow in the text colour
                // on the page's own ground. The calendar's colour stays on the dot.
                MarkImage("arrow.up.right", size: compact ? 10 : 12)
                    .foregroundStyle(Color.primary)
                    .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                    .background(Color(PlatformColor.systemBackgroundColour), in: Circle())
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open in Calendar")
            .accessibilityLabel("Open in Calendar")
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.openInCalendar(event) }
        .contextMenu {
            Button("Open in Calendar") { model.openInCalendar(event) }
        }
        .help("\(event.title) (\(event.calendarTitle)). Double-click to open in Calendar.")
    }
}
