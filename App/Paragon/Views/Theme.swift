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
}

/// A quiet heading above a group, used instead of the default list section titles
/// where a list would be too heavy.
struct SectionLabel: View {
    let title: String
    var count: Int?
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
    }
}

/// What a screen shows when there is nothing in it yet: an icon, a sentence that says
/// what belongs here, and the one button that fills it.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    var tint: Color = .secondary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(tint.opacity(0.8))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The line at the foot of the sidebar when the vault is not all readable: notes iCloud has
/// not sent, or files that could not be read at all. It is deliberately hard to miss — an
/// app that quietly draws an empty vault looks exactly like an app that has lost everything.
struct VaultWarningBar: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            Button("Ask iCloud again", action: retry)
                .font(.caption2)
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
        content
            .background {
                // One even tint over the whole column, at the strength he picked from the
                // preview. The gradient at the top went out in build 110: he wanted the colour
                // to sit evenly rather than pool under the toolbar.
                tint.opacity(0.085).allowsHitTesting(false)
            }
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

    @State private var typed = ""
    @State private var date = Date()

    private var parsed: DateOnly? { DateOnly(typed.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("2031-12-01", text: $typed)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
                .onSubmit(set)
            Text(parsed == nil ? "Write the date as 2031-12-01." : "Or pick it below.")
                .font(.caption)
                .foregroundStyle(parsed == nil ? Color.red : Color.secondary)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: date) { _, picked in typed = DateOnly(picked).description }
            HStack {
                if let clearTitle {
                    Button(clearTitle, role: .destructive) { choose(nil) }
                }
                Spacer()
                if let cancel {
                    Button("Cancel", action: cancel)
                }
                Button("Set", action: set)
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsed == nil)
            }
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            let start = current ?? DateOnly(Date())
            typed = start.description
            date = start.date() ?? Date()
        }
    }

    private func set() {
        guard let parsed else { return }
        choose(parsed)
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
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sheet.cancel")
            Button(action: act) {
                Text(actionTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAct ? tint : Color.secondary.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
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
                .buttonStyle(.borderedProminent)
                .tint(tint)
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
                    .foregroundStyle(tint)
                if showsCounts {
                    Text(counts)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
    }

    /// Built outside the ViewBuilder, where a `var` is allowed.
    private var counts: String {
        var parts = ["\(progress.projectsDone) of \(progress.projectsTotal) projects done"]
        if progress.tasksTotal > 0 {
            parts.append("\(progress.tasksDone) of \(progress.tasksTotal) tasks")
        }
        return parts.joined(separator: " \u{00b7} ")
    }
}

/// One symbol in two states.
///
/// The mode button used to swap the symbol itself — an eye for Read, a pencil for Edit — and
/// there is no way to read that: an eye means both "you are reading" and "press to read". One
/// symbol that is either lit or not has a single reading, and it is the reading everything
/// else in the app already uses: a tinted fill is "on", grey is "off". The dashed border says
/// the same thing a second way, which is what the Map's dashed boxes have always meant here.
/// The Archive button's symbol: a small arrow coming down into the box, because the button
/// **moves** the note rather than showing an archive. His idea, build 154 — "is it possible to
/// make a small down arrow so that it shows the movement somehow?"
///
/// Drawn here rather than named, because SF Symbols has no archivebox carrying an arrow. A
/// `VStack`, not a `ZStack` with offsets: the two pieces then cannot drift over each other at
/// another text size.
struct MoveToArchiveIcon: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.down")
                .font(.system(size: 7, weight: .bold))
            Image(systemName: "archivebox")
                .font(.system(size: 12))
        }
        .frame(height: 21)
        .accessibilityLabel("Move to the Archive")
    }
}

struct StateToggle: View {
    let systemImage: String
    /// What the symbol stands for, e.g. "Edit". Read aloud and shown as the tooltip.
    let title: String
    let isOn: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
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
            // everything at low emphasis to begin with. Same two-state language he chose in
            // build 142 — tinted and solid for on, grey and dashed for off — only stronger.
            .strokeBorder(isOn ? tint.opacity(0.7) : Color.primary.opacity(0.3),
                          style: StrokeStyle(lineWidth: isOn ? 1.4 : 1.2, dash: isOn ? [] : [3.5, 2.5]))
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
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
/// - **Red, and only here.** Red appears nowhere else in PARAGON — orange is "look at this" and
///   is already the plan block's own colour — so a red line cannot be read as a warning about
///   anything. It is also what every calendar draws, which is what he asked for.
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
