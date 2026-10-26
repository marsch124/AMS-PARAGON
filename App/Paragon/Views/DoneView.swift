import SwiftUI
import ParagonCore

/// What got done, day by day, for the last twelve calendar weeks — and since build 267, what
/// each day was: how many tasks were ticked off, the time on the focus timer, the line written
/// in **Close the day**, and what the work went towards. He chose it from the plan page
/// (https://claude.ai/artifact/RyZxairjYDdB7KoxiuGZ3S), kept the name **Done**, and asked for
/// the quiet days too: a day with no tick but a line or some timer time is listed.
///
/// `DoneDiary` (Core, tested) decides every number and every word; this only draws them.
struct DoneView: View {
    @EnvironmentObject private var model: AppModel
    /// Worked out when the notes change, **never in `body`**: it walks every note's tasks, and
    /// the screen is redrawn on everything the model publishes. Before build 267 the body asked
    /// `tasksCompleted(on:)` thirty times, each one a parse of the whole vault, on every redraw.
    @State private var diary: DoneDiary?
    /// Only worked out while the screen is on view. On the phone a pushed Done screen stays
    /// alive behind the other tabs (build 232) and would otherwise walk the vault again on every
    /// autosave anywhere in the app.
    @State private var isShown = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    /// A plain stub, so the body never carries an `#if` in the middle of a modifier chain
    /// (build 148).
    private var isPhone: Bool { false }
    #endif

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f
    }()

    var body: some View {
        let today = diary?.today ?? DateOnly.today()
        VStack(spacing: 0) {
            // **On the phone, notes still coming from iCloud are named here** (TodayView's
            // shape, build 261): a day's line in a note that has not arrived cannot be shown,
            // and that must not look like a day with nothing written (build 100). The Mac says
            // so at the foot of its sidebar.
            if isPhone, let warning = model.vaultWarning {
                VaultWarningBar(text: warning) { model.fetchMissingNotes() }
                    .padding(.vertical, Theme.tight)
            }
            // Outside the `List`, or it would be a row with a row's height (build 220). Nothing
            // at all when no finished task in the vault carries a day: a count would then be a
            // zero that only says the file cannot tell (build 141).
            if let count = diary?.countText {
                Label {
                    Text(count)
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(SidebarSection.done.tint)
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("done.count")
                Divider()
            }
            List(selection: model.noteSelection) {
                if let diary, diary.days.isEmpty {
                    // While notes are still coming from iCloud, "nothing" is not something this
                    // screen may say: the days may be in those notes (build 100; the Inbox's
                    // "Still coming from iCloud", build 261).
                    if model.notesWaitingForCloud.isEmpty {
                        Text("Nothing in the last \(DoneDiary.weeks) weeks. A task you tick off shows up here on the day you did it. So does a day you wrote about in **Close the day**, or worked on with the focus timer.")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Some notes are still coming from iCloud, so days may be missing here. They appear as the notes arrive.",
                              systemImage: "icloud")
                            .foregroundStyle(.orange)
                    }
                }
                ForEach(diary?.days ?? []) { day in
                    Section {
                        // The day's card is the first row and is **never tagged**: an untagged
                        // row takes no click and no selection fill (builds 71–74, 201), which is
                        // what keeps its lilac line and coloured labels readable.
                        DoneDayCard(day: day, title: Self.title(for: day.day, today: today),
                                    waiting: model.dailyNoteIsWaitingForCloud(day.day))
                            .id(day.day)
                        ForEach(day.finished) { ref in
                            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                                .tag(ref.notePath)
                        }
                    }
                }
            }
        }
        .onAppear {
            isShown = true
            work(model.index)
        }
        .onDisappear { isShown = false }
        // **The value handed in, never `model.index`**: `@Published` sends in `willSet`, so
        // the property still holds the old index at this moment (build 242).
        .onReceive(model.$index) { index in
            guard isShown else { return }
            work(index)
        }
        // A Mac left open overnight would keep yesterday as "Today" and miss the new week
        // (build 254's rule for anything cached from `.today()`). Once a minute, like `NowLine`.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if isShown, diary?.today != DateOnly.today() {
                    work(model.index)
                }
            }
        }
    }

    private func work(_ index: NoteIndex) {
        diary = index.doneDiary(today: DateOnly.today())
    }

    private static func title(for day: DateOnly, today: DateOnly) -> String {
        if day == today { return "Today" }
        if day == today.adding(days: -1) { return "Yesterday" }
        return day.date().map(dayFormatter.string(from:)) ?? day.description
    }
}

/// One day's card at the top of its section: the day's name, a grey line of facts, the line
/// written in **Close the day** beside the moon, and what the work went towards. Everything in
/// it comes ready-made from `DiaryDay` (Core): a `@ViewBuilder` holds views and nothing else
/// (build 58).
///
/// One element to accessibility with its sentence set explicitly, so both platforms read the
/// same words (build 253), and the identifier the screen test waits for.
private struct DoneDayCard: View {
    let day: DiaryDay
    let title: String
    /// The day's own daily note is still coming from iCloud. Its **How was today?** line and its
    /// timer time are in that note, so the card says so in step 7's words, symbol and colour
    /// (WeekLookStep), rather than look like a day with nothing written (builds 100, 168).
    let waiting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            // On its own line, never squeezed beside the name in a narrow column (build 138).
            Text(day.factsText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let evening = day.eveningLine {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: CloseDayView.symbol)
                        .font(.caption)
                        .foregroundStyle(Theme.eveningTint)
                    // The whole line, as he wrote it: it is his own words.
                    Text(evening)
                        .font(.callout)
                        .italic()
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if waiting {
                Label("Still coming from iCloud", systemImage: "icloud")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !day.served.isEmpty {
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(day.served) { served in
                        ServedRow(served: served, compact: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
        .accessibilityIdentifier("done.day.\(day.day.description)")
    }

    /// The card's sentence, with the waiting note named when it stands in for the evening line.
    /// A plain property, not a ternary inside the modifier (builds 152, 154).
    private var spokenText: String {
        let base = day.spoken(dayName: title)
        guard waiting, day.eveningLine == nil else { return base }
        return base + " This day's note is still coming from iCloud."
    }
}
