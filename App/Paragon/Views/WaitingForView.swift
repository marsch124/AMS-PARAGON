import SwiftUI
import ParagonCore

/// **Waiting for** (build 279): the lines he has handed to other people, grouped by person.
///
/// The rule — what a waiting line is, how the person is read, what the row says — lives in Core
/// (`WaitingFor.swift`, tested). This file is the three things the app adds to it:
///
/// - the writers on `AppModel` (`makeWaiting`, `stopWaiting`, `followUpNextWeek`), so the task
///   menu's **Waiting for…** has a control that writes what the list reads (the oldest rule in
///   this project: a screen that shows a field needs the button that sets it);
/// - `WaitingWhoView`, the small window that asks **Who?**;
/// - `WaitingForList`, drawn by **All actions** when its **Waiting for** switch is on.
///
/// **A switch inside All actions, not a sidebar row or a Browse row** (his answer, and build
/// 166's argument: a second door into one room).

/// The switch on **All actions** is one setting read by the screen and by its pointer, so the
/// two cannot drift (the shape `GoalsShowAll` has had since build 166).
enum WaitingShowing {
    static let key = "actionsShowWaiting"
    /// An hourglass: the app has no other use of it, and build 168's rule is that one symbol
    /// means one thing.
    static let symbol = "hourglass"
}

extension AppModel {
    /// The people already waited for, most used first, for the chooser in **Who?**. Read from
    /// the lines themselves: there is no list of people to keep in step with the notes.
    var waitingPeople: [String] {
        WaitingFor.people(in: index.waitingFor(today: DateOnly.today()))
    }

    /// Makes a task a line he is waiting on `person` for (see `TaskItem.makingWaiting`).
    ///
    /// The change is made to the line **as the note holds it now**, not to the copy the row was
    /// drawn from: a row can be a little out of date, and writing it back would undo a change
    /// made a moment ago. Writes nothing when nothing would change.
    func makeWaiting(_ ref: TaskRef, for person: String) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task), !live.isDone else { return }
        let made = live.makingWaiting(for: person, today: DateOnly.today())
        guard made != live, note.rewrite(task: live, with: made) else { return }
        if save(note), let name = WaitingFor.parse(made)?.person {
            flash("Now waiting for \(name).")
        }
    }

    /// Takes a line back out of the waiting list: the words, the tag and the start day go; the
    /// date and everything else stay.
    func stopWaiting(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task) else { return }
        let plain = live.notWaiting()
        // A line with no words and no name at all cannot be given any: say so, never nothing.
        guard !plain.isWaiting else {
            flash("This line has no words to keep. Type something on it in the note first.")
            return
        }
        guard plain != live, note.rewrite(task: live, with: plain) else { return }
        if save(note) {
            flash("Not waiting any more.")
        }
    }

    /// **Follow up next week**: the line's date moves a week on from the later of its date and
    /// today. An overdue follow-up therefore starts again from today.
    func followUpNextWeek(_ ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task) else { return }
        let today = DateOnly.today()
        var moved = live
        moved.dueDate = WaitingFor.followUpNextWeek(from: live.dueDate, today: today)
        guard moved != live, note.rewrite(task: live, with: moved) else { return }
        if save(note), let date = moved.dueDate {
            flash("Follow up on \(WaitingFor.dayText(date, today: today)).")
        }
    }
}

/// The small window behind **Waiting for…** on a task's menu: who is it?
///
/// A text field, the people already used as buttons under it (so Anna is never written two
/// ways), and one line saying what **Add** will write. **Cancel** and **Add** sit in the top
/// row, above the field: on a phone the keyboard covers whatever is at the bottom (builds 160,
/// 231). A macOS alert drops everything that is not a text field (build 93), so this is a
/// popover, the way **Pick a date…** is.
struct WaitingWhoView: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var isPresented: Bool
    @State private var person = ""
    @State private var people: [String] = []
    @FocusState private var focused: Bool

    private var tint: Color { SidebarSection.allActions.tint }
    private var cleaned: String? { WaitingFor.cleanPerson(person) }
    private var writes: String? { WaitingFor.writesText(for: ref.task, person: person) }
    /// A dozen is plenty to choose from; anyone else is typed.
    private var offered: [String] { Array(people.prefix(12)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Who?")
                    .font(Txt.listTitle)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .accessibilityIdentifier("waiting.who.cancel")
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleaned == nil)
                    .accessibilityIdentifier("waiting.who.add")
            }
            TextField("Name", text: $person)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(add)
                .accessibilityIdentifier("waiting.who.field")
            if !offered.isEmpty {
                Text("Already waiting for")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(offered, id: \.self) { name in
                        PickChip(title: name, isOn: isChosen(name), tint: tint) { person = name }
                            .accessibilityIdentifier("waiting.who.choice.\(name)")
                    }
                }
            }
            if let writes {
                Text(writes)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("waiting.who.writes")
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .onAppear {
            people = model.waitingPeople
            if let current = WaitingFor.parse(ref.task)?.person { person = current }
            // Focus does not always take in the turn the view appears (build 119).
            DispatchQueue.main.async { focused = true }
        }
    }

    private func isChosen(_ name: String) -> Bool {
        guard let cleaned else { return false }
        return WaitingFor.key(of: cleaned) == WaitingFor.key(of: name)
    }

    private func add() {
        guard let name = cleaned else { return }
        model.makeWaiting(ref, for: name)
        isPresented = false
    }
}

/// The list **All actions** draws while its **Waiting for** switch is on: a count line, then one
/// group per person, each line a real `TaskRow` (build 149) — the tick means the answer came
/// and completes the line — with its caption and the one button that moves the follow-up on.
///
/// It is a `List` **without a selection**: nothing here is tagged, so no row takes a click
/// away from the buttons in it (builds 71–74). The headings are plain section headers, never a
/// `DisclosureGroup` (build 93).
struct WaitingForList: View {
    @EnvironmentObject private var model: AppModel
    let list: WaitingList

    private var tint: Color { SidebarSection.allActions.tint }
    private var today: DateOnly { DateOnly.today() }

    var body: some View {
        VStack(spacing: 0) {
            if !list.isEmpty {
                Text(list.summary)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("waiting.summary")
            }
            // Under the count, in the usual orange: a vault that is not all here cannot say
            // that nothing is waiting (builds 100 and 261).
            if let warning = model.vaultWarning {
                VaultWarningBar(text: warning) { model.fetchMissingNotes() }
                    .padding(.bottom, 8)
            }
            Divider()
            if list.isEmpty {
                empty
            } else {
                rows
            }
        }
    }

    // MARK: Nothing waiting, and why

    /// **Two different sentences**: no line is waiting, or notes are still coming from iCloud
    /// and the list may be short. The second must never claim there is nothing (build 100).
    @ViewBuilder
    private var empty: some View {
        if model.notesWaitingForCloud.isEmpty {
            EmptyStateView(title: "Nothing is waiting for anyone",
                           markName: WaitingShowing.symbol,
                           message: "\(DeviceWords.click) an action\u{2019}s menu (or \(DeviceWords.holdSmall) the action) and choose \u{201C}Waiting for\u{2026}\u{201D}. The action then shows up here, under the person.",
                           tint: tint)
                .accessibilityIdentifier("waiting.empty")
        } else {
            EmptyStateView(title: "Not everything is here yet",
                           markName: "icloud",
                           message: "Some notes are still coming from iCloud, so this list may be missing lines. It fills in by itself.",
                           tint: .orange)
                .accessibilityIdentifier("waiting.emptyCloud")
        }
    }

    // MARK: The groups

    private var rows: some View {
        List {
            ForEach(list.groups) { group in
                Section {
                    ForEach(group.lines) { line in
                        row(line)
                    }
                } header: {
                    heading(group)
                }
            }
        }
        .accessibilityIdentifier("waiting.list")
    }

    private func heading(_ group: WaitingGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(title: group.title, count: group.lines.count,
                         markName: group.name == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle",
                         tint: tint)
            if let note = group.note {
                Text(note)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("waiting.person.\(group.title)")
    }

    private func row(_ line: WaitingLine) -> some View {
        let title = line.ref.task.title
        let overdue = line.followUpState(today: today) == .overdue
        return VStack(alignment: .leading, spacing: 4) {
            TaskRow(ref: line.ref, showNote: true) { model.toggle(line.ref) }
            // The caption above the button, not beside it: the Mac's middle column can be 220
            // points wide, and a caption beside a fixed-width button was left about 66 points,
            // which cut off "waited N days" — the fact **@since** is there for (builds 138, 255).
            VStack(alignment: .leading, spacing: 2) {
                Text(line.captionText(today: today))
                    .font(Txt.label)
                    .foregroundStyle(overdue ? Color.red : Theme.soft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("waiting.caption.\(title)")
                // Borderless, or on the phone a List row with two buttons in it presses both.
                Button("Follow up next week") { model.followUpNextWeek(line.ref) }
                    .buttonStyle(.borderless)
                    .font(Txt.label)
                    .fixedSize()
                    .accessibilityIdentifier("waiting.followUp.\(title)")
            }
            // In line with the title, past the tick.
            .padding(.leading, 26)
        }
    }
}
