import SwiftUI
import ParagonCore

/// The evening step: what you finished, what did not happen, and one line about the day.
///
/// He asked for it in the same breath as three other things — *"to make my day more efficient
/// and in harmony"* — and picked this shape from a drawing of three
/// (https://claude.ai/artifact/NrbS7bxiaBin21sLjwzvEg), shape **A**: a screen you open on
/// purpose, work down, and **finish**.
///
/// **Why not at the foot of Today** (shape B): builds 213, 214 and 219 were all about making
/// that screen shorter, and a new box on it would undo some of that. **Why not its own sidebar
/// row** (shape C): the phone's five tabs are full, so it would sit inside **Browse** — two taps
/// away, every evening.
///
/// It is a sheet, through the app's single `.sheet` (build 44), so it can never argue with
/// another one.
struct CloseDayView: View {
    @EnvironmentObject private var model: AppModel

    /// What he has written, loaded once from the note and written back only on **Done**.
    @State private var lookingBack = ""
    /// `onAppear` runs again when the sheet is re-laid-out, and reading the note a second time
    /// would throw away what he has typed since.
    @State private var loaded = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    private var day: DateOnly { DateOnly.today() }
    private var tint: Color { SidebarSection.review.tint }

    /// Still open and dated today or earlier. Undated tasks are deliberately left out: a task
    /// with no date was never promised to this day, so it did not "not happen".
    private var leftovers: [TaskRef] { model.index.openTasks(dueOnOrBefore: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    counts
                    if leftovers.isEmpty {
                        allClear
                    } else {
                        didNotHappen
                    }
                    lookingBackField
                }
                .padding(isPhone ? 14 : 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            SheetFooter(actionTitle: "Done", tint: tint, cancel: { close() }, act: { finish() })
                .padding(isPhone ? 14 : 20)
        }
        // One name the screen test can wait for: what it is really checking is that this view
        // builds at all, on both platforms (build 190). Accessibility only — nothing here takes
        // a press.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("closeDay.screen")
        .frame(minWidth: isPhone ? nil : 480)
        .frame(maxWidth: fillOnPhone, maxHeight: fillOnPhone, alignment: .topLeading)
        .onAppear {
            guard !loaded else { return }
            lookingBack = model.lookingBack(for: day)
            loaded = true
        }
    }

    /// Written out rather than a ternary with `nil` in one arm: `.infinity` is a member of
    /// `CGFloat`, not of `CGFloat?`, and there is no compiler here to settle it (build 199).
    private var fillOnPhone: CGFloat? {
        if isPhone { return CGFloat.infinity }
        return nil
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Close the day", systemImage: "moon")
                .font(.headline)
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            Text(day.date()?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                 ?? day.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, isPhone ? 14 : 20)
        .padding(.vertical, 12)
    }

    /// **Counts, not two more lists.** The **Done** screen already lists what you finished, day
    /// by day, and drawing the same names here would be a second door into one room (build 166).
    /// The number is what an evening needs: it says the day had something in it.
    private var counts: some View {
        WrappingHStack(spacing: 8, lineSpacing: 8) {
            CountPill(text: pillText(model.index.tasksCompleted(on: day).count, "finished today"),
                      systemImage: "checkmark.circle", tint: .green)
            if !leftovers.isEmpty {
                CountPill(text: "\(leftovers.count) did not happen",
                          systemImage: "exclamationmark.circle", tint: .orange)
            }
        }
    }

    /// "1 task finished today", never "1 tasks".
    private func pillText(_ count: Int, _ tail: String) -> String {
        count == 1 ? "1 task \(tail)" : "\(count) tasks \(tail)"
    }

    /// Nothing open and dated is worth saying in words. An empty list with a heading over it
    /// reads as a screen that failed to load (build 100).
    private var allClear: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing was left over.")
                .font(.callout.weight(.semibold))
            Text("Everything with a date for today or earlier is done or dropped.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var didNotHappen: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Did not happen", count: leftovers.count)
            // Real `TaskRow`s: a tick here ticks the task in its own note, and the task menu and
            // the date popover come with it. Build 149's rule — reach for `TaskRow` for any list
            // of tasks, because a second one only repeats work and then drifts. Its `.draggable`
            // is safe: this is not a `List(selection:)` (builds 71 to 74).
            ForEach(leftovers) { ref in
                HStack(alignment: .top, spacing: 8) {
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                    Button {
                        model.moveTasks([ref], to: day.adding(days: 1))
                    } label: {
                        // The padding goes **inside** the label: a Button's tap area is its
                        // label, and padding put outside only moves it (build 186).
                        Text("Tomorrow")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Move this to tomorrow")
                }
            }
            if leftovers.count > 1 {
                Button("Move all \(leftovers.count) to tomorrow") {
                    model.moveTasks(leftovers, to: day.adding(days: 1))
                }
                .font(.caption)
                .padding(.top, 2)
            }
        }
    }

    private var lookingBackField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "How was today?")
            TextField("One line, if you feel like it", text: $lookingBack, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.35)))
            Text("Goes into today's daily note, under **Looking back**.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// **Done saves the line; Cancel does not.** The tick boxes and the Tomorrow buttons have
    /// already written their notes when they were pressed, so nothing there waits for this — the
    /// footer only decides the fate of the words in the field.
    private func finish() {
        model.saveLookingBack(lookingBack, for: day)
        close()
    }

    private func close() {
        model.activeSheet = nil
    }
}

/// One fact about the day as a capsule.
///
/// Its own small view rather than the review's `ReviewStat`: that one is built around a week's
/// report and its worries. If a third screen ever wants this shape, that is the moment to move
/// it into `Theme.swift` and share them — the note build 214 left about `HeaderActionButton`.
private struct CountPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.45)))
    }
}
