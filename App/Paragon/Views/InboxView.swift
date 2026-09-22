import SwiftUI
import ParagonCore

/// What the Inbox screen is working with. Both columns read it from here.
/// `@MainActor` because everything here touches `AppModel`, which is main-actor bound.
@MainActor
enum InboxItems {
    static func note(_ model: AppModel) -> Note? { model.notes(in: .inbox).first }

    /// The open, top-level lines waiting to be sorted.
    static func waiting(_ model: AppModel) -> [TaskRef] {
        guard let note = note(model) else { return [] }
        return note.openTasks.filter { !$0.isSubtask }
            .map { TaskRef(notePath: note.relativePath, noteTitle: note.displayTitle, task: $0) }
    }

    static func selected(_ model: AppModel) -> TaskRef? {
        waiting(model).first { $0.triageID == model.inboxSelection }
    }

    /// Where a line can go: the active projects, then the areas with their sub-areas
    /// underneath them, in the same order as the sidebar list.
    static func destinations(_ model: AppModel) -> [Note] {
        let projects = model.notes.filter { $0.kind == .project && isActive($0) }
        let areas = model.index.areasInFamilyOrder().filter(isActive)
        return projects + areas
    }

    static func isActive(_ note: Note) -> Bool {
        !note.isArchived && !note.isEnded
    }

    static func projects(_ model: AppModel) -> [Note] {
        model.notes.filter { $0.kind == .project && isActive($0) }
    }

    /// The areas as families, so the column can draw sub-areas under the area they belong to.
    static func areaBranches(_ model: AppModel) -> [AreaBranch] {
        model.index.areaTree()
            .filter { isActive($0.area) }
            .map { AreaBranch(area: $0.area, subAreas: $0.subAreas.filter(isActive)) }
    }

    /// Moves a line on and selects whatever follows it, so sorting keeps its rhythm.
    static func file(_ ref: TaskRef, into path: String, model: AppModel) {
        let ids = waiting(model).map(\.triageID)
        let after = ids.firstIndex(of: ref.triageID).map { $0 + 1 } ?? 0
        model.moveTask(ref, to: path)
        model.inboxSelection = after < ids.count ? ids[after] : nil
    }
}

extension TaskRef {
    /// Identifies a line while it sits in the list: the note and the line it is on.
    var triageID: String { "\(notePath)#\(task.lineIndex)" }
}

/// The Inbox section's middle column. There is only ever one inbox note, so a list of notes
/// would be a list of one; this is the thing you actually came to do — capture at the top,
/// then sort what is waiting, one line at a time.
struct InboxTriageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newItem = ""
    @State private var pickingDateFor: TaskRef?
    @FocusState private var captureFocused: Bool

    private var inbox: Note? { InboxItems.note(model) }
    private var items: [TaskRef] { InboxItems.waiting(model) }
    private var selected: TaskRef? { InboxItems.selected(model) }

    var body: some View {
        VStack(spacing: 0) {
            captureBar
            Divider()
            if items.isEmpty {
                EmptyStateView(title: "Inbox zero",
                               systemImage: "tray",
                               message: "Nothing left to sort. Anything you capture — here, from the menu bar, or from the share sheet on the phone — lands in this list.",
                               tint: SidebarSection.inbox.tint)
            } else {
                header
                List(selection: $model.inboxSelection) {
                    ForEach(items, id: \.triageID) { ref in
                        InboxRow(ref: ref, pickingDateFor: $pickingDateFor)
                            .tag(ref.triageID)
                    }
                }
            }
        }
        .focusable()
        // Keeps the keyboard focus (the single keys below need it) but not the ring the Mac
        // draws around a focused view: at launch this column is the first thing on screen and
        // took the focus, so a thick ring in the Mac's accent colour sat around the whole
        // Inbox until something else was clicked (build 197).
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { move(-1) }
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(KeyEquivalent("t")) { act { model.setDueDate($0, .today()) } }
        .onKeyPress(KeyEquivalent("m")) { act { model.setDueDate($0, .today().adding(days: 1)) } }
        .onKeyPress(KeyEquivalent("d")) { act { model.toggle($0) } }
        .onKeyPress(.delete) { act { model.deleteTask($0) } }
        .onAppear {
            model.afterUpdate {
                model.inboxShowsNote = false
                model.selectedNotePath = nil
            }
        }
        .onChange(of: model.inboxSelection) { _, new in
            guard new != nil else { return }
            model.afterUpdate {
                model.inboxShowsNote = false
                model.selectedNotePath = nil
            }
        }
        .sheet(item: $pickingDateFor) { ref in
            TaskDatePicker(ref: ref, isPresented: Binding(get: { pickingDateFor != nil },
                                                         set: { if !$0 { pickingDateFor = nil } }))
        }
    }

    @ViewBuilder
    private var captureBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(SidebarSection.inbox.tint)
            TextField("Capture something…", text: $newItem)
                .textFieldStyle(.roundedBorder)
                .focused($captureFocused)
                .onSubmit(capture)
            Button("Add", action: capture)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            SectionLabel(title: items.count == 1 ? "1 to sort" : "\(items.count) to sort",
                         count: nil, systemImage: "tray.full", tint: SidebarSection.inbox.tint)
            Spacer()
            Text("T today · M tomorrow · D done · ⌫ delete")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: Doing things

    private func capture() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let inbox else { return }
        model.addTask(text, to: inbox.relativePath)
        newItem = ""
    }

    /// Runs a single-key action on the selected line, unless you are typing in the capture box.
    private func act(_ work: @escaping (TaskRef) -> Void) -> KeyPress.Result {
        guard !captureFocused, let ref = selected else { return .ignored }
        let ids = items.map(\.triageID)
        let after = ids.firstIndex(of: ref.triageID).map { $0 + 1 } ?? 0
        work(ref)
        model.inboxSelection = after < ids.count ? ids[after] : ids.last
        return .handled
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !captureFocused, !items.isEmpty else { return .ignored }
        let ids = items.map(\.triageID)
        let current = model.inboxSelection.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = min(max(current + delta, 0), ids.count - 1)
        model.inboxSelection = ids[next]
        return .handled
    }
}

/// One line waiting to be sorted, with everything you might do to it.
struct InboxRow: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var pickingDateFor: TaskRef?
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    /// A plain stub, so the body never carries an `#if` in the middle of a modifier chain
    /// (build 148's lesson).
    private var isPhone: Bool { false }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.toggle(ref)
                } label: {
                    Image(systemName: "circle")
                        .rowTint(SidebarSection.inbox.tint)
                }
                .buttonStyle(.plain)
                .help("Mark as done")

                VStack(alignment: .leading, spacing: 2) {
                    if editing {
                        TextField("Title", text: $draft)
                            .textFieldStyle(.roundedBorder)
                            .focused($fieldFocused)
                            .onSubmit(commit)
                    } else {
                        Text(Note.removingTag(Note.nextActionTag, from: ref.task.title))
                            .lineLimit(2)
                    }
                    if let due = ref.task.dueDate {
                        Label(due.description, systemImage: "calendar")
                            .font(.caption2)
                            .rowTint(due < .today() ? Color.red : .secondary)
                    }
                }
                Spacer(minLength: 6)
            }
            // **Shape B, the phone's half.** The line you are on opens and shows the four
            // buttons full width; every other line stays one short row, so the whole Inbox is
            // still in view. The Mac never draws them here — its **File it** column is always
            // on screen and carries the same quadrant, and one control drawn twice on one
            // screen is two doors into one room (build 166).
            if isPhone, isSelected {
                InboxQuadrant(ref: ref,
                              pickDate: { pickingDateFor = ref },
                              rename: startEditing)
                    // Lines up under the words, past the tick: the circle plus the gap.
                    .padding(.leading, 23)
                    .padding(.trailing, 2)
                    .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // Nothing here may take the row's click: `.draggable` and `.onTapGesture` both do, and
        // between them they cost builds 71 to 74 — a line could no longer be picked at all.
        // Renaming is on the menu instead, and a line is filed by clicking a destination.
        .contextMenu { InboxLineMenu(ref: ref, rename: startEditing) }
        // The row is one thing to accessibility, named by its line, and it says out loud
        // whether it is the selected one (build 191). That is what lets a screen test check
        // the very fault of builds 71 to 74 — a line that cannot be picked — and it is also
        // what VoiceOver should have been told all along.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inbox.\(ref.task.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var isSelected: Bool { model.inboxSelection == ref.triageID }

    private func startEditing() {
        draft = Note.removingTag(Note.nextActionTag, from: ref.task.title)
        editing = true
        fieldFocused = true
    }

    private func commit() {
        editing = false
        model.renameTask(ref, to: draft)
    }

}

/// Everything else a line can have done to it. **One list, two callers** — the line's own
/// context menu and the quadrant's **File it** button — so the two can never come to offer
/// different things (build 168's rule about one thing drawn in two places).
struct InboxLineMenu: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    /// Renaming needs a field to type in, and that field belongs to the line's own row. Nil
    /// in the **File it** column, where the line on the left still carries Rename… on its
    /// context menu.
    var rename: (() -> Void)?

    private var projects: [Note] { InboxItems.destinations(model) }

    var body: some View {
        Menu("Move to") {
            ForEach(projects) { note in
                Button(note.displayTitle) { model.moveTask(ref, to: note.relativePath) }
            }
        }
        .disabled(projects.isEmpty)
        Menu("Turn into a note") {
            Button("Project") { model.makeNote(from: ref, kind: .project) }
            Button("Area") { model.makeNote(from: ref, kind: .area) }
            Button("Resource") { model.makeNote(from: ref, kind: .resource) }
            Button("Goal") { model.makeNote(from: ref, kind: .goal) }
        }
        Divider()
        Button("Block time for this…") { model.blockTime(for: ref) }
        Button("Remove the date") { model.setDueDate(ref, nil) }
            .disabled(ref.task.dueDate == nil)
        if let rename {
            Button("Rename…") { rename() }
        }
        Divider()
        Button("Delete", role: .destructive) { model.deleteTask(ref) }
    }
}

/// The four things you do to a line, as a two-by-two of buttons with a word under each
/// symbol. His ask, in his words: *"maybe we could put the four buttons in a quadrant so that
/// they can be a bit larger and a bit cooler."*
///
/// **Two places draw it and never both at once** (he picked shapes B and C from a preview,
/// https://claude.ai/artifact/6iM9P8KrBH2mcTSmURxdLN): the **File it** column on the Mac,
/// where the line being sorted already lives, and inside the selected line itself on the
/// phone, which has no third column.
///
/// The three date buttons use build 142's two-state language — the tint filled with a solid
/// border for the one the line is already set to, grey with a dashed border for the others —
/// so the quadrant also says where the line stands. **File it keeps a solid grey border**: it
/// opens a menu rather than setting anything, so "off" is not a state it can be in, and
/// drawing it dashed would say something untrue.
struct InboxQuadrant: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    /// Opens the date sheet. The state lives in whichever column drew the quadrant, because
    /// the sheet belongs to that screen (build 44: one `.sheet` per screen, never two).
    let pickDate: () -> Void
    var rename: (() -> Void)?

    private var tint: Color { SidebarSection.inbox.tint }
    /// Both written out rather than compared as `dueDate == .today()`: the left side is an
    /// optional there, and leaning on Swift to find `today()` through it is the kind of
    /// inference that costs a whole build when there is no compiler in this container.
    private var today: DateOnly { DateOnly.today() }
    private var tomorrow: DateOnly { DateOnly.today().adding(days: 1) }

    /// A date that is neither today nor tomorrow, so the third button can light up too.
    private var hasOtherDate: Bool {
        guard let due = ref.task.dueDate else { return false }
        return due != today && due != tomorrow
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                button("sun.max", "Today", id: "today", isOn: ref.task.dueDate == today) {
                    model.setDueDate(ref, today)
                }
                button("sunrise", "Tomorrow", id: "tomorrow", isOn: ref.task.dueDate == tomorrow) {
                    model.setDueDate(ref, tomorrow)
                }
            }
            HStack(spacing: 6) {
                button("calendar", "Pick a date", id: "date", isOn: hasOtherDate, action: pickDate)
                Menu {
                    InboxLineMenu(ref: ref, rename: rename)
                } label: {
                    face("tray.and.arrow.down", "File it", isOn: false, dashed: false)
                }
                .menuIndicator(.hidden)
                .accessibilityIdentifier("inbox.quad.file")
            }
        }
        // Reaches the Menu as well, which macOS would otherwise draw with a border of its own.
        .buttonStyle(.plain)
    }

    private func button(_ symbol: String, _ title: String, id: String,
                        isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            face(symbol, title, isOn: isOn, dashed: true)
        }
        .accessibilityIdentifier("inbox.quad.\(id)")
        .help(title)
    }

    private func face(_ symbol: String, _ title: String, isOn: Bool, dashed: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(isOn ? tint : Color.primary.opacity(0.62))
        .background {
            if isOn {
                RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.18))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isOn ? tint.opacity(0.75) : Color.primary.opacity(0.3),
                              style: StrokeStyle(lineWidth: isOn ? 1.3 : 1.1,
                                                 dash: (isOn || !dashed) ? [] : [3.5, 2.5]))
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// The Inbox section's right-hand column: the line you are sorting, and where it can go.
/// Drag a line onto a destination, or select it and click one.
struct InboxFileItView: View {
    @EnvironmentObject private var model: AppModel

    @State private var foldedAreas: Set<String> = []
    /// The quadrant's **Pick a date**. This column's one and only sheet (build 44).
    @State private var pickingDate: TaskRef?

    private var selected: TaskRef? { InboxItems.selected(model) }
    private var destinations: [Note] { InboxItems.destinations(model) }
    private var projects: [Note] { InboxItems.projects(model) }
    private var branches: [AreaBranch] { InboxItems.areaBranches(model) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "File it", count: nil, systemImage: "tray.and.arrow.down",
                         tint: SidebarSection.inbox.tint)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            selectedCard
                .padding(.horizontal, 16)
                .padding(.top, 10)
            // **Shape C, the Mac's half.** The lines on the left lost their four small grey
            // symbols; the quadrant lives here instead, right under the line it acts on and
            // above the places that line can go, so everything you can do to one line is in
            // one column.
            if let ref = selected {
                InboxQuadrant(ref: ref, pickDate: { pickingDate = ref })
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            SectionLabel(title: destinationsTitle, count: nil, systemImage: nil)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            if destinations.isEmpty {
                Text("You have no active projects or areas yet. Make one from a line with the button below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if !projects.isEmpty {
                        groupLabel("Projects", tint: ParaKind.project.tint)
                        ForEach(projects) { note in
                            DestinationRow(note: note, selected: selected)
                        }
                    }
                    if !branches.isEmpty {
                        groupLabel("Areas", tint: ParaKind.area.tint)
                            .padding(.top, projects.isEmpty ? 0 : 8)
                        ForEach(branches) { branch in
                            AreaDestinationGroup(branch: branch, selected: selected, folded: $foldedAreas)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            footer
                .padding(16)
        }
        .sheet(item: $pickingDate) { ref in
            TaskDatePicker(ref: ref, isPresented: Binding(get: { pickingDate != nil },
                                                         set: { if !$0 { pickingDate = nil } }))
        }
    }

    private var destinationsTitle: String {
        selected == nil ? "Where things go" : "Click where it should go"
    }

    /// A coloured heading over each group. `SectionLabel` paints itself secondary, and the
    /// point here is that green means project and pink means area.
    private func groupLabel(_ title: String, tint: Color) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var selectedCard: some View {
        if let ref = selected {
            VStack(alignment: .leading, spacing: 6) {
                Text(Note.removingTag(Note.nextActionTag, from: ref.task.title))
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                if let due = ref.task.dueDate {
                    Label(due.description, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(due < .today() ? Color.red : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        } else {
            Text("Pick a line on the left, then click where it should go.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button("Project") { make(.project) }
                Button("Area") { make(.area) }
                Button("Resource") { make(.resource) }
            } label: {
                Label("New note from this line…", systemImage: "plus")
            }
            .disabled(selected == nil)
            Button("Open the Inbox note") {
                model.inboxShowsNote = true
                model.selectedNotePath = InboxItems.note(model)?.relativePath
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
    }

    private func make(_ kind: ParaKind) {
        guard let ref = selected else { return }
        model.inboxSelection = nil
        model.makeNote(from: ref, kind: kind)
    }
}

/// An area with its sub-areas under it: the same cards, joined by a thin rail so a family
/// reads as one thing, and foldable when the list gets long.
struct AreaDestinationGroup: View {
    let branch: AreaBranch
    let selected: TaskRef?
    @Binding var folded: Set<String>

    private var isFolded: Bool { folded.contains(branch.area.relativePath) }

    private func toggle() {
        if isFolded {
            folded.remove(branch.area.relativePath)
        } else {
            folded.insert(branch.area.relativePath)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                DestinationRow(note: branch.area, selected: selected)
                if !branch.subAreas.isEmpty {
                    Button(action: toggle) {
                        Image(systemName: isFolded ? "chevron.right" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .help(isFolded ? "Show the sub-areas" : "Hide the sub-areas")
                }
            }
            if !branch.subAreas.isEmpty, !isFolded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(branch.subAreas) { child in
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(width: 10, height: 1)
                            DestinationRow(note: child, selected: selected)
                        }
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1)
                        .padding(.vertical, 2)
                }
            }
        }
    }
}

/// One place a line can be filed, as a click target and a drop target.
struct DestinationRow: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let selected: TaskRef?
    @State private var hovering = false

    var body: some View {
        Button {
            if let selected { InboxItems.file(selected, into: note.relativePath, model: model) }
        } label: {
            HStack(spacing: 10) {
                TintStripe(color: note.kind.tint, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selected == nil)
        .onHover { hovering = $0 }
        .acceptsTaskDrop { ref in InboxItems.file(ref, into: note.relativePath, model: model) }
        .help(selected == nil ? "Select a line on the left first" : "Move it to \(note.displayTitle)")
    }

    private var isSubArea: Bool { model.index.parentArea(of: note) != nil }

    /// Hovering while a line is picked shows where it would land; a sub-area otherwise sits
    /// on a faint tint of its own colour, so a family reads as a family.
    private var background: Color {
        if hovering, selected != nil { return Color.accentColor.opacity(0.10) }
        return isSubArea ? note.kind.tint.opacity(0.05) : .clear
    }

    private var subtitle: String {
        let open = note.openTasks.count
        let kind = note.kind == .project ? "Project" : (isSubArea ? "Sub-area" : "Area")
        return open == 0 ? kind : "\(kind) · \(open) open"
    }
}
