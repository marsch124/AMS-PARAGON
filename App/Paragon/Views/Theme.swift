import SwiftUI
import ParagonCore

/// The few numbers and small pieces that keep every screen looking like one app.
enum Theme {
    /// Padding inside a row or a panel.
    static let gutter: CGFloat = 14
    /// Space between a heading and what belongs to it.
    static let tight: CGFloat = 4
    static let gap: CGFloat = 8
    static let radius: CGFloat = 8

    /// The reading font of the note editor: proportional, not code.
    static let editorFont: Font = .system(.body, design: .default)
    static let editorLineSpacing: CGFloat = 3

    /// The planner's own blocks: orange, at his request in build 152. They used to borrow the
    /// review's teal, which put them in the same family as the Calendar column beside them —
    /// the whole point of the two lanes is that they are different things. One place, so the
    /// lane, the card, the "make a block" buttons and the sheet cannot drift apart.
    static let planBlockTint = Color("PlanTint")

    /// The line showing the time it is now, on the planner and on the Calendar's day.
    ///
    /// **Build 182, his ask: "Red is for something that is overdue or dangerous, so take a
    /// friendly colour."** He is right, and it is a rule this app already had — orange is
    /// "look at this" everywhere else, so red on a calendar was borrowed from other apps, not
    /// from PARAGON.
    ///
    /// A soft slate blue, and **deliberately not one of the nine tints**: purple is the
    /// Calendar lane drawn right beside it, orange the plan blocks, pink Areas, green
    /// Projects, blue Resources, teal the review, gold Goals, grey the Archive. The time of
    /// day is not one of those things, so it may not wear one of their colours.
    static let nowTint = Color("NowTint")

    /// **Start the day** and **Close the day**, his colours (build 241): a clear orange for
    /// the morning and a dark lilac for the evening. The button on Today and the screen it
    /// opens use the same one, so the two cannot drift (build 168). The lilac is redder and
    /// darker than the Calendar's violet, so the evening button does not read as a calendar
    /// thing.
    static let morningTint = Color("MorningTint")
    static let eveningTint = Color("EveningTint")
}

/// A quiet heading above a group, used instead of the default list section titles
/// where a list would be too heavy.
struct SectionLabel: View {
    let title: String
    var count: Int?
    /// Kept for the callers that still name one; 1.0 draws no symbol beside a heading.
    var markName: String?
    /// The part's colour (1.0): a heading pops in its part's colour. Nil for the few groups
    /// that belong to no part, which take the quiet grey.
    var tint: Color? = nil

    var body: some View {
        Heading(text: title, color: tint ?? Theme.soft, count: count)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// **This week:** in gold, then the goal for the week (build 251), on one or two lines.
///
/// **One view, two screens** (build 265): **Today** draws it under the date and **Start the
/// day** under last evening's line. One thing drawn in two places is one view, or the two
/// drift (build 168). The text is the one Today drew since build 251, moved here as it was.
///
/// The caller decides whether there is a goal and draws nothing when there is none: a line
/// asking for one every morning would be a nag, and the week screen is where it is written.
/// The padding is the caller's too, since the two screens sit it in different places.
struct WeekGoalLine: View {
    let goal: String
    /// Different on each screen, so a test can tell which one it found.
    let identifier: String

    var body: some View {
        (Text("This week: ").fontWeight(.semibold).foregroundColor(ParaKind.goal.tint.ink)
            + Text(goal))
            .font(Txt.label)
            .lineLimit(2)
            .accessibilityIdentifier(identifier)
    }
}

/// What a screen shows when there is nothing in it yet: an icon, a sentence that says
/// what belongs here, and the one button that fills it.
struct EmptyStateView: View {
    let title: String
    let markName: String
    let message: String
    var tint: Color = .secondary
    var actionTitle: String?
    var action: (() -> Void)?
    /// Build 291: only a page that warns keeps its sentence ("Still coming from iCloud").
    /// Every other empty page is its icon and title — he could read what belongs there.
    var warns = false

    var body: some View {
        // Build 291: the icon sits in a soft circle of the part's colour; no explanation.
        // An empty title draws nothing, so "No note open" is the icon and its button only.
        VStack(spacing: 8) {
            MarkImage(markName, size: 24)
                .foregroundStyle(tint == .secondary ? Color.secondary : tint)
                .frame(width: 52, height: 52)
                .background((tint == .secondary ? Color.secondary : tint).opacity(0.12), in: Circle())
                .padding(.bottom, 2)
            if !title.isEmpty {
                Text(title)
                    .font(Txt.value)
                    .foregroundStyle(.soft)
            }
            if warns || tint == .orange {
                Text(message)
                    .font(Txt.label)
                    .foregroundStyle(Theme.soft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The line at the foot of the sidebar when the vault is not all readable: notes iCloud has
/// not sent, or files that could not be read at all. It is deliberately hard to miss — an
/// app that quietly draws an empty vault looks exactly like an app that has lost everything.
/// Build 285: the sync line is always there (284 showed it only while a sync waited). It says
/// where the sync stands — not yet, syncing, waiting for iCloud, synced at 09:12 — grey while
/// all is well and orange only when the last sync had conflicts. A press opens Settings at the
/// Reminders sync part. On the iPhone the caller wraps it in a link to the Settings page, so it
/// is drawn without its own button there (`pressable: false`).
struct SyncStatusBar: View {
    @EnvironmentObject private var model: AppModel
    var pressable = true
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        if pressable {
            // Build 292: the toolbar's sync button is gone, so a press here syncs now; the
            // rest of that button's menu lives on a right-click (long press on the iPad).
            Button { Task { await model.syncNow() } } label: { label }
                .buttonStyle(.plain)
                .disabled(model.isSyncing || model.vault == nil)
                .help(SyncStatusBar.tip(model.lastReport, every: model.autoSyncMinutes))
                .contextMenu {
                    Button("Sync now") { Task { await model.syncNow() } }
                    Button("Show me what would change…") { Task { await model.previewSync() } }
                    if model.lastReport != nil {
                        Button("Last sync report…") { model.showLastReport() }
                    }
                    Divider()
                    Button("Sync settings…", action: open)
                }
                .accessibilityIdentifier("sync.status")
        } else {
            label.accessibilityIdentifier("sync.status")
        }
    }

    /// Build 301 (his ask): the same clock ring as the iPhone's sync button (build 300), so
    /// all three devices look the same — the ring beside its word, centred at the sidebar foot.
    /// The pill it replaces is gone.
    private var label: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            SyncRingMark(now: context.date, axis: .horizontal, ring: 22)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
        }
    }

    private func open() {
        model.settingsJumpToSync = true
        #if os(macOS)
        openSettings()
        #else
        model.activeSheet = .settings
        #endif
    }
}

/// **The sync clock ring** (build 300 on the iPhone, build 301 on the Mac and iPad sidebar):
/// a ring round the hand-drawn sync mark that runs down over two hours, green under one hour,
/// yellow after that or while it waits for iCloud, a full red ring when the last sync had
/// conflicts, grey before any sync; the short word (10:55, Yesterday, Syncing…) beside or
/// under it. Every rule is Core's `SyncRing`; this only draws it.
struct SyncRingMark: View {
    @EnvironmentObject private var model: AppModel
    let now: Date
    var axis: Axis = .vertical
    var ring: CGFloat = 26

    private var finishedAt: Date? { model.lastReport.map { $0.finishedAt ?? $0.startedAt } }
    private var conflicts: Int { model.lastReport?.conflicts.count ?? 0 }

    private func colour(_ mood: SyncRing.Mood) -> Color {
        switch mood {
        case .none: return .secondary
        case .fresh: return .green
        case .aging: return .yellow
        case .problem: return .red
        }
    }

    var body: some View {
        let syncing = model.isSyncing
        let waiting = model.syncWaitsForCloud
        let mood = SyncRing.mood(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                 conflicts: conflicts, now: now)
        let fill = SyncRing.fill(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                 conflicts: conflicts, now: now)
        let word = SyncRing.word(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                 conflicts: conflicts, now: now)
        let tint = colour(mood)
        let mark = SyncRingGlyph(fill: fill, tint: tint, plain: mood == .none,
                                 syncing: syncing, ring: ring)
        let text = Text(word)
            .font(axis == .vertical ? .caption2 : Txt.listSecond.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(mood == .problem ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .fixedSize()
        // Build 304 fix: one layout that never swaps its kind of view (was `Group { if … }`).
        let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 1)) : AnyLayout(HStackLayout(spacing: 6))
        return layout { mark; text }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sync with Reminders")
        .accessibilityValue(SyncStatus.line(syncing: syncing, waiting: waiting,
                                            finishedAt: finishedAt, conflicts: conflicts, now: now))
    }
}

/// The ring itself, with no model: the sidebar, the iPhone button and the Mac menu bar
/// (build 303, drawn into a picture there) all draw this one.
struct SyncRingGlyph: View {
    let fill: Double
    let tint: Color
    var plain = false
    var syncing = false
    var ring: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: 2.2)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fill)
            MarkImage("arrow.triangle.2.circlepath", size: (ring * 0.54).rounded())
                .foregroundStyle(plain ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                .rotationEffect(.degrees(syncing ? 360 : 0))
                .animation(syncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                           value: syncing)
        }
        .frame(width: ring, height: ring)
    }
}

/// **Build 303 (his yes to my idea): a gentle tap you can feel when a task is ticked done** on
/// the iPhone and iPad — the same soft tap as a finished sync (build 301). Nothing on the Mac.
enum Haptics {
    static func done() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        #endif
    }
}

#if os(macOS)
/// **Build 303 (his yes to my idea): the sync clock ring in the Mac menu bar**, beside the
/// quick-capture tray, so the sync can be seen without opening PARAGON. The menu bar only
/// draws pictures and words, so the ring is drawn into a picture each minute (and whenever
/// the sync changes) and the time goes beside it as words.
struct MenuBarSyncLabel: View {
    @EnvironmentObject private var model: AppModel
    /// Build 304: a plain minute timer — a `TimelineView` inside a menu bar label kept asking
    /// for redraws without pause and the Mac app never opened.
    @State private var now = Date()
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            let finishedAt = model.lastReport.map { $0.finishedAt ?? $0.startedAt }
            let conflicts = model.lastReport?.conflicts.count ?? 0
            let syncing = model.isSyncing
            let waiting = model.syncWaitsForCloud
            let mood = SyncRing.mood(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                     conflicts: conflicts, now: now)
            let fill = SyncRing.fill(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                     conflicts: conflicts, now: now)
            let word = SyncRing.word(syncing: syncing, waiting: waiting, finishedAt: finishedAt,
                                     conflicts: conflicts, now: now)
            // Build 304: the number of tasks due today, right beside the ring (none when 0).
            let due = model.index.openTasks(dueOn: DateOnly(now)).count
            Image(nsImage: Self.picture(fill: fill, mood: mood))
            Text(SyncRing.menuBarTitle(dueToday: due, word: word))
        }
        .onReceive(minute) { now = $0 }
    }

    /// **Build 304 fix — the Mac would not open.** A fresh picture on every redraw made the menu
    /// bar see a "new" image, redraw, and get another fresh one — forever, before any window
    /// appeared. Each picture is now made once per mood and fill step and the SAME one is handed
    /// back, so a redraw with nothing changed changes nothing.
    @MainActor private static var pictures: [String: NSImage] = [:]

    @MainActor
    static func picture(fill: Double, mood: SyncRing.Mood) -> NSImage {
        let step = (min(max(fill, 0), 1) * 24).rounded() / 24
        let key = "\(mood)-\(step)"
        if let made = pictures[key] { return made }
        let image = makePicture(fill: step, mood: mood)
        pictures[key] = image
        return image
    }

    @MainActor
    private static func makePicture(fill: Double, mood: SyncRing.Mood) -> NSImage {
        let tint: Color
        switch mood {
        case .none: tint = .gray
        case .fresh: tint = .green
        case .aging: tint = .yellow
        case .problem: tint = .red
        }
        let renderer = ImageRenderer(content: SyncRingGlyph(fill: fill, tint: tint, ring: 16)
            .padding(1))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// What the menu bar ring opens: where the sync stands, and the same four choices as the
/// sidebar ring's right-click.
struct MenuBarSyncMenu: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let finishedAt = model.lastReport.map { $0.finishedAt ?? $0.startedAt }
        Text(SyncStatus.line(syncing: model.isSyncing, waiting: model.syncWaitsForCloud,
                             finishedAt: finishedAt,
                             conflicts: model.lastReport?.conflicts.count ?? 0))
        Divider()
        Button("Sync now") { Task { await model.syncNow() } }
            .disabled(model.isSyncing || model.vault == nil)
        Button("Show me what would change…") {
            openWindow(id: ParagonApp.mainWindowID)
            Task { await model.previewSync() }
        }
        if model.lastReport != nil {
            Button("Last sync report…") {
                openWindow(id: ParagonApp.mainWindowID)
                model.showLastReport()
            }
        }
        Divider()
        Button("Sync settings…") {
            model.settingsJumpToSync = true
            openSettings()
        }
        Button("Show PARAGON") {
            openWindow(id: ParagonApp.mainWindowID)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
#endif

struct VaultWarningBar: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            MarkLabel(text, "exclamationmark.triangle.fill", text: .footnote)
                .font(Txt.listSecond)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            Button("Ask iCloud again", action: retry)
                .font(Txt.listSecond)
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius))
        .padding(.horizontal, 8)
    }
}

/// The colour of the section you are in, laid evenly over the detail column. Enough to say
/// "you are in Projects" out of the corner of your eye, and not enough to tire you out in a
/// long note. The hairline along the top went in build 113: it read as a border round the
/// panel rather than as part of it.
struct ModeAccent: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        // 1.0 (look B): the wash over the whole column is gone. Colour now sits on the panels
        // that mean something — the facts, the tasks, the linked notes — not over the words.
        content
    }
}

extension View {
    /// Marks a column with the colour of the section it belongs to.
    func modeAccent(_ tint: Color) -> some View { modifier(ModeAccent(tint: tint)) }
}

/// The one way to choose a date in PARAGON: write it, or pick it.
///
/// Both are always offered because the dates this app deals in run from tomorrow to a goal
/// five years out, and a calendar you have to press forty times is no way to reach 2031 —
/// which is exactly what he counted when asked to try the "due after its goal" check
/// (build 136). The field is what **Set** reads; the calendar only writes into it.
///
/// Used by the project deadline in the note header and by a task's date. The New Note sheet's
/// target date is deliberately left as a plain field: that screen was designed with him and
/// takes one short line per row.
///
/// **Since build 277 this is a thin shell round `DateTimeChoiceView`**, which is the same
/// window with an optional **At** line for a time of day. The six windows that choose a plain
/// date (a deadline, a goal's target, an ending, Quick capture, Close the day, the New note
/// sheet) keep this exact signature and look; a task's own date window uses the other.
struct DateChoiceView: View {
    /// The date already set, if any. It is what the field and the calendar open on.
    let current: DateOnly?
    /// Shown on the clearing button. Leave it nil for no such button.
    var clearTitle: String? = nil
    /// Shown as **Cancel** when given. A sheet needs it; a popover can also be dismissed by
    /// clicking away, but the button does no harm there.
    var cancel: (() -> Void)? = nil
    /// The chosen date, or nil when the clearing button was pressed.
    let choose: (DateOnly?) -> Void

    var body: some View {
        DateTimeChoiceView(current: current, offersTime: false, clearTitle: clearTitle,
                           cancel: cancel, choose: { date, _ in choose(date) })
    }
}

/// The date window with an optional **At** line (build 277): the field and the calendar of
/// `DateChoiceView`, and, under them, a small field for the time of day, four quick times and
/// **No time of day**. **Set** writes the date and the time together.
///
/// The word is **At**, never "Time": a task's time already means how long it takes (`~45m`,
/// build 248). The line is `offersTime`; with it off this is exactly the plain date window.
///
/// **Empty At means no time of day**, which is a real answer and not an error: a task due on a
/// date, for the whole day. Something typed that is not a time keeps **Set** grey and says so
/// (`TimeOfDay.typed`, Core, tested). The quick times fill the field and **No time of day**
/// empties it; neither writes anything by itself, so there is one way to commit, **Set**, and
/// Return in either field does the same. On the phone a **Set** also sits above the keyboard
/// (the window is taller with the At line, and the buttons row can end up under the keys,
/// builds 160, 231); it is the same `set`, and it is there only while the At line is.
///
/// `choose` gets the date and the time; both are nil when the clearing button was pressed.
/// A written-out `init`: the struct mixes `@State` with stored closures, which is where the
/// generated memberwise one is hard to predict and there is no compiler here to ask.
struct DateTimeChoiceView: View {
    let current: DateOnly?
    /// The time of day already set, if any. It is what the **At** field opens on.
    let time: TimeOfDay?
    /// False draws no **At** line: the plain date window.
    let offersTime: Bool
    let clearTitle: String?
    let cancel: (() -> Void)?
    let choose: (DateOnly?, TimeOfDay?) -> Void

    @State private var typed = ""
    @State private var atText = ""
    @State private var date = Date()

    init(current: DateOnly?, time: TimeOfDay? = nil, offersTime: Bool = true,
         clearTitle: String? = nil, cancel: (() -> Void)? = nil,
         choose: @escaping (DateOnly?, TimeOfDay?) -> Void) {
        self.current = current
        self.time = time
        self.offersTime = offersTime
        self.clearTitle = clearTitle
        self.cancel = cancel
        self.choose = choose
    }

    private var parsed: DateOnly? { DateOnly(typed.trimmingCharacters(in: .whitespaces)) }

    /// What the **At** field holds, read as a time.
    private var reading: TypedTime { TimeOfDay.typed(atText) }

    private var canSet: Bool {
        if parsed == nil { return false }
        return !(offersTime && reading == .invalid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("2031-12-01", text: $typed)
                .textFieldStyle(.roundedBorder)
                .font(Txt.value.monospacedDigit())
                .onSubmit(set)
                // Named for the screen tests (build 268). Accessibility only.
                .accessibilityIdentifier("date.field")
            Text(parsed == nil ? "Write the date as 2031-12-01." : "Or pick it below.")
                .font(Txt.label)
                .foregroundStyle(parsed == nil ? Color.red : Theme.soft)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: date) { _, picked in typed = DateOnly(picked).description }
            if offersTime {
                atLine
            }
            HStack {
                if let clearTitle {
                    Button(clearTitle, role: .destructive) { choose(nil, nil) }
                        .accessibilityIdentifier("date.clear")
                }
                Spacer()
                if let cancel {
                    Button("Cancel", action: cancel)
                        .accessibilityIdentifier("date.cancel")
                }
                Button("Set", action: set).buttonStyle(.filled(Theme.fallbackTint))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSet)
                    .accessibilityIdentifier("date.set")
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            let start = current ?? DateOnly(Date())
            typed = start.description
            date = start.date() ?? Date()
            atText = time?.description ?? ""
        }
#if os(iOS)
        // A Set above the keys, as Search has its Done (build 160). Only with the At line: the
        // plain date windows keep their look. No identifier: the screen tests find `date.set`
        // with the first match, and this one exists only while a field has the keyboard.
        .toolbar {
            if offersTime {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Set", action: set).buttonStyle(.filled(Theme.fallbackTint))
                        .disabled(!canSet)
                }
            }
        }
#endif
    }

    /// **At**, the time of day (build 277). Views only, so the `@ViewBuilder` rule holds.
    ///
    /// The quick times sit in a `WrappingHStack`, because the window is 300 points wide and an
    /// `HStack` in a column too narrow squeezes its words rather than overflowing (build 138).
    /// Return in the field acts as **Set**, which is also the way out on the phone when the
    /// keyboard is covering the button row (builds 160, 231).
    private var atLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("At")
                    .font(Txt.value.weight(.semibold))
                TextField("14:00", text: $atText)
                    .textFieldStyle(.roundedBorder)
                    .font(Txt.value.monospacedDigit())
                    .frame(width: 84)
                    .submitLabel(.done)
                    .onSubmit(set)
                    .accessibilityIdentifier("date.time")
                Button("No time of day") { atText = "" }
                    .disabled(atText.isEmpty)
                    .accessibilityIdentifier("date.time.clear")
                Spacer(minLength: 0)
            }
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(TimeOfDay.quickChoices, id: \.self) { quick in
                    Button(quick.description) { atText = quick.description }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("date.time.\(quick.description)")
                }
            }
            Text(atHint)
                .font(Txt.label)
                .foregroundStyle(reading == .invalid ? Color.red : Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var atHint: String {
        switch reading {
        case .invalid: return "Write the time as 14:00."
        case .empty: return "No time of day: the task is for the whole day."
        case .time: return "If this note syncs to Reminders, it rings there at this time."
        }
    }

    private func set() {
        guard let parsed else { return }
        guard offersTime else {
            choose(parsed, nil)
            return
        }
        switch reading {
        case .invalid: return
        case .empty: choose(parsed, nil)
        case .time(let at): choose(parsed, at)
        }
    }
}

/// Lays its children out along a row and starts a new line when the next one will not fit.
///
/// SwiftUI has no flow layout of its own, and an `HStack` in a column too narrow for it does
/// not overflow — it squeezes every child until the text inside wraps. That is how the weekly
/// review came to draw "2031-08-01" over three lines and the word "projects" as "project s"
/// (build 138). Children are measured unconstrained, so each one keeps its natural width and
/// only whole items move down a line.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        let rows = rows(of: subviews, within: limit)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: limit == .infinity ? widest : min(widest, limit), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(of: subviews, within: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(of subviews: Subviews, within limit: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let wanted = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, wanted > limit {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = wanted
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// How far the work under a goal has come, drawn the same way everywhere it appears: the
/// weekly review's row, the Goals list, and the goal's own dashboard.
///
/// Nothing is drawn when there is nothing to measure. A goal with no projects under it yet is
/// not at zero per cent — there is no figure at all, and an empty bar would say the opposite.
/// Cancel and the one doing button at the foot of a sheet, drawn the way each platform draws
/// them.
///
/// **Build 186's fix, made one thing in build 191.** A plain `Button` is a proper button on a
/// Mac and two blue words in a corner on a phone, which is what his screenshot of the New note
/// sheet showed. The New note sheet was fixed on its own; the sheet a `[[link]]` opens still
/// had the two words. One footer for both, so a third sheet cannot get it wrong either.
///
/// On the phone the doing button is full width in the sheet's own colour and grey until it may
/// be pressed, the same shape as the capture screen's **Save**; Cancel sits beside it with the
/// padding *inside* its label, because a Button's tap area is its label. On the Mac the two
/// stay bottom right, where a Mac sheet keeps them, with Return and Escape wired to them.
struct SheetFooter: View {
    /// The word on the doing button: "Create", "Save".
    let actionTitle: String
    let tint: Color
    var canAct = true
    let cancel: () -> Void
    let act: () -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif

    var body: some View {
        if isPhone {
            phoneBar
        } else {
            deskRow
        }
    }

    private var phoneBar: some View {
        HStack(spacing: 12) {
            Button(action: cancel) {
                Text("Cancel")
                    .font(Txt.listTitle)
                    .foregroundStyle(.soft)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sheet.cancel")
            Button(actionTitle, action: act)
                .buttonStyle(.main(tint))
            .disabled(!canAct)
            .accessibilityIdentifier("sheet.action")
        }
    }

    private var deskRow: some View {
        HStack {
            Spacer()
            Button("Cancel", action: cancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("sheet.cancel")
            Button(actionTitle, action: act)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.filled(tint))
                .disabled(!canAct)
                .accessibilityIdentifier("sheet.action")
        }
    }
}

struct GoalProgressBar: View {
    let progress: GoalProgress
    var width: CGFloat? = nil
    var showsCounts = true
    /// The goal family's gold unless the bar belongs to an aspiration, which has worn the
    /// deeper gold since build 189. Handed in for the same reason `KindBadge` takes one: the
    /// bar sits beside a badge, and two golds in one row would say they are two things.
    var tint: Color = ParaKind.goal.tint

    var body: some View {
        if let fraction = progress.fraction, let percent = progress.percent {
            HStack(spacing: 6) {
                ProgressView(value: fraction)
                    .tint(tint)
                    .frame(width: width)
                Text("\(percent)%")
                    .foregroundStyle(tint.ink)
                if showsCounts {
                    Text(counts)
                        .foregroundStyle(.soft)
                }
            }
            .font(Txt.label)
            .lineLimit(1)
        }
    }

    /// Built outside the ViewBuilder, where a `var` is allowed.
    private var counts: String {
        var parts = ["\(progress.projectsDone) of \(progress.projectsTotal) \(progress.projectsTotal == 1 ? "project" : "projects") done"]
        if progress.tasksTotal > 0 {
            parts.append("\(progress.tasksDone) of \(progress.tasksTotal) tasks")
        }
        return parts.joined(separator: " \u{00b7} ")
    }
}

/// The Archive button's symbol: an arrow coming down into a tray, because the button
/// **moves** the note rather than showing an archive. His idea, build 154 — "is it possible to
/// make a small down arrow so that it shows the movement somehow?"
///
/// Since build 311 it is one hand-drawn mark of its own ("archivebox.and.arrow.down"), the
/// same height as every other toolbar icon. A fixed 16 points: it sits in a toolbar, which
/// does not grow with the text size.
struct MoveToArchiveIcon: View {
    var body: some View {
        MarkImage("archivebox.and.arrow.down", size: 16)
            .accessibilityLabel("Move to the Archive")
    }
}

/// One symbol in two states.
///
/// The mode button used to swap the symbol itself — an eye for Read, a pencil for Edit — and
/// there is no way to read that: an eye means both "you are reading" and "press to read". One
/// symbol that is either lit or not has a single reading, and it is the reading everything
/// else in the app already uses: a tinted fill is "on", grey is "off". The dashed border says
/// the same thing a second way, which is what the Map's dashed boxes have always meant here.
struct StateToggle: View {
    let markName: String
    /// What the symbol stands for, e.g. "Edit". Read aloud and shown as the tooltip.
    let title: String
    let isOn: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // A fixed 16: the 30 by 26 box does not grow with the text size.
            MarkImage(markName, size: 16)
                .frame(width: 30, height: 26)
                .foregroundStyle(isOn ? tint : Color.primary.opacity(0.62))
                .background { fill }
                .overlay { border }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "\(title), on" : "\(title), off")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .help(isOn ? "\(title) is on. Press to turn it off." : "\(title) is off. Press to turn it on.")
    }

    @ViewBuilder
    private var fill: some View {
        if isOn {
            RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.24))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 6)
            // Build 154: both states were too faint to read in a macOS toolbar, which draws
            // everything at low emphasis to begin with. Build 281: the off state is a thin
            // solid line, no longer dashed — in the window's toolbar the dashes read as an
            // empty placeholder (the reviewer of 280), and no Mac control is dashed. On stays
            // the tinted fill with a stronger line, so the two states are still told apart at
            // a glance (build 142's two-state language, in solid lines). `LookRulesTests`
            // fails this struct if a dash comes back.
            .strokeBorder(isOn ? tint.opacity(0.7) : Color.primary.opacity(0.28),
                          lineWidth: isOn ? 1.4 : 1)
    }
}

/// A heading you open by pressing its words (build 205).
///
/// **`DisclosureGroup` only opens from its small triangle.** The label itself does nothing,
/// which is a target of about eleven points on a Mac — and it is why the screen test for
/// build 30's window scramble had to be abandoned in build 198 after four runs: nothing a
/// test could click would open the **Linked notes** box.
///
/// So the whole header is one plain `Button`: a chevron, then whatever label is handed in,
/// with `.contentShape(Rectangle())` so the gap between them is pressable too. The caller
/// draws the contents itself under an `if`, exactly the shape `TemplatesView` and the
/// sidebar have used since build 93 — a `DisclosureGroup` inside a `List` drew its rows over
/// each other there, and this replaces the last two in the app.
///
/// **Anything else that belongs in the header stays outside this button.** A button inside a
/// button is the builds 71–74 fault in a new place: one press, two meanings.
struct FoldButton<Label: View>: View {
    @Binding var isOpen: Bool
    /// Read aloud, so the row says what it is even though the chevron carries no words.
    /// Not optional: an empty label would leave a screen reader with nothing to say, and a
    /// branch around the modifier would change the button's identity for no good reason.
    let accessibilityName: String
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                MarkImage("chevron.right")
                    .foregroundStyle(.soft)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                label()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isOpen ? [.isSelected] : [])
        .help(isOpen ? "Press to close." : "Press to open.")
    }
}

/// The line across a day column showing where *now* is, the way every calendar app draws it
/// (build 180). His ask: *"add an indication with a line for where we are in the day… as a
/// normal calendar app does it."*
///
/// **One component, two screens.** The Calendar section's day had a line of its own since
/// build 61 and the planner had none, which is the drift this project keeps paying for. Both
/// draw this now.
///
/// - It keeps its own time and moves every minute; a line that stands still where the screen
///   happened to open is worse than none.
/// - **A soft slate blue, `Theme.nowTint`** (build 182). It was red for one build; he asked
///   for a friendly colour, because red means overdue or dangerous. It is not one of the
///   nine tints, since the time of day is not a kind of note.
/// - `allowsHitTesting(false)`: it lies over the cards, and nothing that lies over a card may
///   take its click (builds 71–74).
struct NowLine: View {
    /// Nothing is drawn on any day but today.
    var isToday: Bool
    var firstHour: Int
    /// The last hour drawn, inclusive: the line disappears after `lastHour + 1`.
    var lastHour: Int
    var hourHeight: CGFloat
    /// Where the dot sits across the column, matching the cards' own inset.
    var leading: CGFloat = 0

    @State private var now = Date()

    /// Assembled outside the body, since a `@ViewBuilder` takes views only (build 58).
    private var offset: CGFloat? {
        guard isToday else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let first = firstHour * 60
        let last = (lastHour + 1) * 60
        guard minutes >= first, minutes <= last else { return nil }
        return CGFloat(minutes - first) / 60 * hourHeight
    }

    var body: some View {
        Group {
            if let offset {
                HStack(spacing: 0) {
                    Circle()
                        .fill(Theme.nowTint)
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(Theme.nowTint)
                        .frame(height: 1.5)
                }
                .offset(x: leading - 3, y: offset)
                .allowsHitTesting(false)
            }
        }
        // The clock is kept here rather than by each screen, so the line cannot be live in one
        // place and stuck in another. Once a minute is as exact as this line has to be.
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

/// A colour for text inside a row of a `List(selection:)` — one that gets out of the way when
/// the row is selected.
///
/// **Build 200, from his screenshot, and it is a fault of the whole app rather than one
/// screen.** On macOS a selected row is filled with the **user's own accent colour**, and his
/// is orange. SwiftUI turns a plain `Text` white on such a row by itself, but **an explicit
/// `.foregroundStyle(Color…)` wins and stays exactly as it was** — so "No project or area
/// serves this" in orange sat on an orange fill and could not be read at all. His words:
/// *"When the aspiration is chosen, then the text cannot be read."*
///
/// `\.backgroundProminence` is `.increased` for precisely that state: a row drawn as a
/// prominent selection. There the text takes the inherited foreground, which the list has
/// already set to read against its own fill; everywhere else it takes the tint as before.
///
/// **Only explicit colours need this.** `.secondary` and the other hierarchical styles already
/// resolve against the row's foreground, so they were never the problem and are left alone —
/// which is what keeps this change small enough to be safe without a compiler here.
///
/// **Not applied to shapes** — `KindBadge` and `GoalProgressBar` keep their tints. A filled
/// badge on a selected row is quieter than it was but still a shape you can see, and a bar
/// that changed colour with selection would say something about the goal that is not true.
private struct RowTintStyle: ViewModifier {
    @Environment(\.backgroundProminence) private var prominence
    let tint: Color

    func body(content: Content) -> some View {
        content.foregroundStyle(style)
    }

    /// The hierarchical style is written out with its type name: `.primary` on its own is
    /// ambiguous between `Color.primary` (a fixed ink, dark in light mode — wrong here) and
    /// `HierarchicalShapeStyle.primary` (the inherited foreground, which is what a prominent
    /// selection sets). There is no Swift compiler in this container to settle an overload
    /// (build 168), so neither is left to inference.
    private var style: AnyShapeStyle {
        prominence == .increased
            ? AnyShapeStyle(HierarchicalShapeStyle.primary)
            : AnyShapeStyle(tint)
    }
}

extension View {
    /// Use instead of `.foregroundStyle(_:)` for text and symbols inside a row that can be
    /// selected. Outside such a row it is exactly `.foregroundStyle(tint)`.
    func rowTint(_ tint: Color) -> some View { modifier(RowTintStyle(tint: tint)) }
}

/// A help tag that goes quiet while the control's own popover is open.
///
/// **Build 202, from his screenshot of the New note sheet.** macOS draws a help tag beside the
/// pointer, and these chips sit one row above the sheet's footer — so the tag landed squarely
/// on **Cancel** and **Create** and cut both words in half. While the popover is open the tag
/// is also pure repetition: the popover's own first line already says the same word, which is
/// build 169's rule (a label that repeats what the screen already says carries no information).
///
/// **The branch goes inside the button's label, never around the button.** An `if`/`else` in a
/// `@ViewBuilder` changes that subtree's identity, and the popover is attached to the *button*
/// — rebuilding it would close the popover the instant it opened.
private struct HelpWhenClosed: ViewModifier {
    let text: String
    let open: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if open { content } else { content.help(text) }
    }
}

extension View {
    /// Use on a button's **label** when that button also presents a popover.
    func helpWhenClosed(_ text: String, open: Bool) -> some View {
        modifier(HelpWhenClosed(text: text, open: open))
    }
}

/// Tasks as small tiles you drag onto something: a day on the week screen (build 225), an hour
/// on the phone's **Plan** screen (build 227).
///
/// **One view in two places** (build 168). His field test of 225 proved this shape drags on the
/// iPhone — the one thing CI can never check — so when Plan needed a way to drag an action onto
/// an hour, the answer was to reuse it rather than draw a second tray that might not.
///
/// **Dashed and grey, with no tint of its own.** Dashed already means "loose, not connected"
/// everywhere in this app — `StateToggle` off, a `ReadChip`, a Map box that is not linked — and
/// that is exactly what a task not yet placed is. Orange would have been a claim that these are
/// plan blocks (build 152), and a colour is a claim (build 180).
///
/// **Nothing at all is drawn when there is nothing waiting.** A heading with no tiles under it
/// would take a strip of the screen to say nothing. This is not build 203's vanishing control:
/// there is no way to put something *into* the tray from here, so an empty one offers nothing.
struct TaskTray: View {
    let items: [TaskRef]
    let title: String
    /// What a tile is for, as the Mac's tooltip and the spoken hint.
    let dropHint: String
    /// A line under the heading, for a screen where dragging is not obvious. Nil on the week.
    var caption: String?
    /// How many tiles before "N more not shown". Enough to plan from without the tray becoming
    /// the screen: a vault can hold hundreds of undated tasks, and an uncapped wrapping row would
    /// push everything else off the bottom — build 213's lesson about what a list costs.
    var shown = 12
    var identifier: String

    var body: some View {
        if !items.isEmpty {
            // One container, not a loose pair: a `body` that returns two views relies on a
            // custom view being transparent to the enclosing stack, and there is no screen
            // here to check that it laid out the way it reads.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        SectionLabel(title: title, count: items.count)
                        Spacer(minLength: 0)
                        if items.count > shown {
                            Text("\(items.count - shown) more not shown")
                                .font(Txt.listSecond)
                                .foregroundStyle(.faint)
                        }
                    }
                    if let caption {
                        Text(caption)
                            .font(Txt.listSecond)
                            .foregroundStyle(.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    WrappingHStack(spacing: 6, lineSpacing: 6) {
                        ForEach(Array(items.prefix(shown))) { ref in
                            tile(ref)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
                Divider()
            }
        }
    }

    private func tile(_ ref: TaskRef) -> some View {
        HStack(spacing: 5) {
            Text(ref.task.title)
                .lineLimit(1)
            Text(ref.noteTitle)
                .font(Txt.listSecond)
                .foregroundStyle(.faint)
                .lineLimit(1)
        }
        .font(Txt.label)
        // 1.0: a tile is never wider than a phone; a long title truncates instead.
        .frame(maxWidth: 340, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.secondary.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .draggable(TaskTransfer(ref))
        .help(dropHint)
    }
}
