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
        // **The first `ScrollViewReader` in the app** (build 268): a square at the top goes to
        // its day's card. The reader holds the squares and the `List` both, so the squares stay
        // put above the list while it moves. The card carries `.id(day.day)` on the row itself,
        // never on its `Section`: on the Mac a `List` scrolls through a table, and only a row
        // is something it can scroll to.
        ScrollViewReader { proxy in
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
                if let diary, let count = diary.countText {
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
                    // The squares are drawn exactly when the count is: both need a finished task
                    // that carries a day (build 141).
                    if diary.showsSquares {
                        DoneSquaresView(diary: diary) { day in
                            withAnimation { proxy.scrollTo(day, anchor: .top) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
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

    /// How a day is named on its card and on its square: "Today", "Yesterday", "Tuesday 14
    /// October". One function, so the two can never name one day two ways.
    static func title(for day: DateOnly, today: DateOnly) -> String {
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

/// Build 268: **squares for the last 12 weeks** at the top of Done. One square per day, one
/// column per calendar week, Monday at the top and this week on the right. A square in a stronger
/// colour is a day with more done; a grey one a day with nothing ticked off; no square at all a
/// day the file cannot speak for — later this week, or before the first task ever ticked off with
/// a day (build 141). A day with nothing counted whose daily note is still coming from iCloud is
/// an empty square with an orange dashed edge, never the grey one, and says so (build 100, as
/// step 7 of the review does). Today's square has a frame in the ink colour (dark in light mode,
/// light in dark mode). A day with a card in the list below can be pressed, and the list goes
/// to it.
///
/// `DoneDiary` (Core, tested) decides every square, every shade, what can be pressed and where
/// the month names go; this only draws them.
///
/// - **Fixed squares, no `GeometryReader`**: 22 points on the phone (a finger), 16 on the Mac.
///   A `ViewThatFits` falls back to 12 when the column is narrower than that — the Mac's middle
///   column can be 220 points, and a row that will not shrink is cut off on both sides there
///   (build 250).
/// - **Only a square that can go somewhere is a `Button`.** A press that does nothing is worse
///   than no button (build 175). `.focusEffectDisabled()` on the grid, or the Mac rings the
///   first square in his accent colour (builds 197, 202).
/// - The squares sit outside the `List`, so they always cost their height; the heading folds
///   them away, and each platform remembers that on its own (builds 161, 212).
struct DoneSquaresView: View {
    @EnvironmentObject private var model: AppModel
    let diary: DoneDiary
    /// Goes to a day's card in the list.
    let jump: (DateOnly) -> Void

    @AppStorage("doneSquaresFolded") private var deskFolded = false
    @AppStorage("doneSquaresFoldedPhone") private var phoneFolded = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    /// Written out: the `private` stored properties above would make the generated one private
    /// (build 229).
    init(diary: DoneDiary, jump: @escaping (DateOnly) -> Void) {
        self.diary = diary
        self.jump = jump
    }

    private static let gap: CGFloat = 3
    private static let radius: CGFloat = 3
    /// The size the grid falls back to in a narrow column.
    private static let smallSide: CGFloat = 12

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f
    }()

    private var folded: Binding<Bool> {
        isPhone ? $phoneFolded : $deskFolded
    }

    /// `FoldButton` asks whether the squares are **open**; the setting says whether they are
    /// folded — the same question read the other way round (as on Today).
    private var squaresOpen: Binding<Bool> {
        Binding(get: { !folded.wrappedValue },
                set: { folded.wrappedValue = !$0 })
    }

    private var preferredSide: CGFloat { isPhone ? 22 : 16 }

    var body: some View {
        // Worked out once per drawing and handed to both sizes of the grid.
        let weeks = diary.squareWeeks
        let marks = diary.monthMarks
        VStack(alignment: .leading, spacing: 6) {
            // The whole line is the button, so a press anywhere on it folds — a short button
            // beside a `Spacer` gets a wrong frame on the Mac (build 247).
            FoldButton(isOpen: squaresOpen, accessibilityName: "Last 12 weeks") {
                SectionLabel(title: "Last \(DoneDiary.weeks) weeks")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("done.squares.fold")
            if !folded.wrappedValue {
                ViewThatFits(in: .horizontal) {
                    grid(weeks, marks: marks, side: preferredSide)
                    grid(weeks, marks: marks, side: Self.smallSide)
                }
                .focusEffectDisabled()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("done.squares")
                Text(caption(weeks))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "Press a day" only when some square can be pressed.
    private func caption(_ weeks: [[DoneSquare]]) -> String {
        let canPress = weeks.contains { week in week.contains { $0.canJump } }
        let waits = weeks.contains { week in week.contains { isWaiting($0) } }
        var text = "Each square is one day. A stronger colour means more done."
        if waits { text += " An orange dashed square is a day whose note is still coming from iCloud." }
        if canPress { text += " Press a day to go to it." }
        return text
    }

    /// A day with nothing counted whose daily note has not arrived yet. Its **How was today?**
    /// line and its timer time are in that note, so a grey square would say "nothing done" when
    /// the truth is "the note is not here yet" (build 100; step 7's bars, WeekLookStep).
    private func isWaiting(_ square: DoneSquare) -> Bool {
        guard let count = square.count, count == 0 else { return false }
        guard !model.notesWaitingForCloud.isEmpty else { return false }
        return model.dailyNoteIsWaitingForCloud(square.day)
    }

    /// The month names above the columns, then the columns. Names are placed with `.offset`
    /// inside a top-leading stack (build 85), so a long name never widens the grid; the last
    /// one may run past the right-hand column, where there is room.
    private func grid(_ weeks: [[DoneSquare]], marks: [MonthMark], side: CGFloat) -> some View {
        let step = side + Self.gap
        let width = CGFloat(weeks.count) * step - Self.gap
        return VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .topLeading) {
                ForEach(marks) { mark in
                    Text(monthName(mark.firstDay))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: CGFloat(mark.column) * step)
                }
            }
            .frame(width: width, alignment: .topLeading)
            .accessibilityHidden(true)
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(weeks.indices, id: \.self) { column in
                    VStack(spacing: Self.gap) {
                        ForEach(weeks[column]) { square in
                            cell(square, side: side)
                        }
                    }
                }
            }
        }
    }

    private func monthName(_ day: DateOnly) -> String {
        day.date().map(Self.monthFormatter.string(from:)) ?? ""
    }

    /// One day: a button when it can go somewhere, a plain square when it is drawn, and empty
    /// space when the file cannot speak for the day.
    @ViewBuilder
    private func cell(_ square: DoneSquare, side: CGFloat) -> some View {
        if square.canJump {
            let words = spoken(square)
            Button {
                jump(square.day)
            } label: {
                face(square, side: side)
            }
            .buttonStyle(.plain)
            .help(words)
            .accessibilityLabel(words)
            .accessibilityIdentifier("done.square.\(square.day.description)")
        } else if square.isDrawn {
            let words = spoken(square)
            face(square, side: side)
                .help(words)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(words)
                .accessibilityIdentifier("done.square.\(square.day.description)")
        } else {
            Color.clear
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        }
    }

    private func face(_ square: DoneSquare, side: CGFloat) -> some View {
        let waiting = isWaiting(square)
        return RoundedRectangle(cornerRadius: Self.radius)
            .fill(shade(for: square))
            .frame(width: side, height: side)
            // A waiting day has no fill, so its edge is what keeps it visibly a day. Dashed is
            // "loose, not here yet" everywhere in the app (`StateToggle`, the Map).
            .overlay {
                RoundedRectangle(cornerRadius: Self.radius)
                    .strokeBorder(Color.orange.opacity(waiting ? 1 : 0),
                                  style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.radius)
                    .strokeBorder(Color.primary.opacity(square.isToday ? 1 : 0), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
    }

    /// One colour family only — Done's own teal at four strengths, grey for nothing done. Not
    /// the Calendar grid's dots, where red means overdue.
    private func shade(for square: DoneSquare) -> Color {
        if isWaiting(square) { return Color.clear }
        let tint = SidebarSection.done.tint
        switch square.level {
        case 0: return Color.secondary.opacity(0.15)
        case 1: return tint.opacity(0.3)
        case 2: return tint.opacity(0.5)
        case 3: return tint.opacity(0.75)
        default: return tint
        }
    }

    /// The label and the Mac's tooltip both come from here, so the words and the square agree.
    private func spoken(_ square: DoneSquare) -> String {
        let name = DoneView.title(for: square.day, today: diary.today)
        if isWaiting(square) { return name + ", still coming from iCloud" }
        return square.spoken(dayName: name)
    }
}
