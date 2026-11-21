import SwiftUI
import ParagonCore

/// Round 350 (capture-inbox): what the Inbox gained — **Snooze until…** (pick 30), **Select** and
/// **File N lines** (pick 31) — and the two Control Center / Lock Screen links (picks 21 and 33).

// MARK: - The notes behind it

extension InboxItems {
    /// The open, top-level lines put aside until a later day.
    static func snoozedCount(_ model: AppModel) -> Int {
        guard let note = note(model) else { return 0 }
        let today = DateOnly.today()
        return note.openTasks.filter { !$0.isSubtask && $0.isSnoozed(on: today) }.count
    }
}

extension AppModel {
    /// Puts an Inbox line aside until `day`: it leaves the Inbox list and its counts, and comes
    /// back on that day. A day that is not after today is refused, said out loud.
    func snooze(_ ref: TaskRef, until day: DateOnly) {
        flushPendingEdits()
        guard day > DateOnly.today() else {
            flash("Pick a day after today.")
            return
        }
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task) else { return }
        let changed = live.settingSnooze(day)
        guard changed != live, note.rewrite(task: live, with: changed) else { return }
        var saved = false
        withAnimation(Motion.settle) { saved = save(note) }
        if saved {
            if inboxSelection == ref.triageID { inboxSelection = nil }
            flash(InboxSnooze.message(until: day))
        }
    }

    /// Takes every snooze off the Inbox's lines at once.
    func bringSnoozedBack() {
        flushPendingEdits()
        guard var note = InboxItems.note(self) else { return }
        var count = 0
        for task in note.openTasks where task.snooze != nil {
            if note.rewrite(task: task, with: task.settingSnooze(nil)) { count += 1 }
        }
        guard count > 0 else { return }
        var saved = false
        withAnimation(Motion.settle) { saved = save(note) }
        if saved { flash(count == 1 ? "1 line is back in the Inbox." : "\(count) lines are back in the Inbox.") }
    }

    /// Files every picked Inbox line into one place (pick 31). Each line is found again in the
    /// note as it is now before it moves, because the lines under a moved one shift up.
    func fileInboxLines(_ refs: [TaskRef], to path: String) {
        flushPendingEdits()
        guard let vault, !refs.isEmpty else { return }
        var moved = 0
        var failed = 0
        var leftBehind = 0
        var targetTitle = ""
        // Round 352: the notes as each move wrote them, so the next line is found in the newest
        // copy without reading the whole notes folder again after every line. `vault.move`
        // returns both notes with their new dates. Only after a line that went wrong is
        // everything read again, so the next line starts from what is really on disk.
        var written: [String: Note] = [:]
        for ref in refs {
            guard let source = written[ref.notePath] ?? note(at: ref.notePath),
                  let target = written[path] ?? note(at: path),
                  let live = source.liveTask(for: ref.task) else {
                failed += 1
                continue
            }
            do {
                let move = try vault.move(task: live, from: source, to: target)
                targetTitle = move.target.displayTitle
                moved += 1
                if move.leftInSource {
                    leftBehind += 1
                    written = [:]
                    reload()
                } else {
                    written[move.source.relativePath] = move.source
                    written[move.target.relativePath] = move.target
                }
            } catch {
                failed += 1
                written = [:]
                reload()
            }
        }
        if moved > 0 {
            withAnimation(Motion.settle) { reload() }
            rememberFiledPlace(path)
        }
        inboxSelecting = false
        inboxPickedIDs = []
        inboxSelection = nil
        if failed > 0 || leftBehind > 0 {
            errorMessage = "\(moved) of \(refs.count) lines were moved. The others stayed where they were; look at the Inbox and try again."
        } else {
            flash(moved == 1 ? "Moved to \(targetTitle)" : "Moved \(moved) lines to \(targetTitle).")
        }
    }

    // MARK: Links from Control Center and the Lock Screen

    /// `amspara://capture` with no words opens Quick capture; `amspara://record` starts (or, on
    /// the second press, stops and files) **Record a Thought**. Called first by `handle(url:)`.
    /// Returns true when the link was one of these two.
    func handleCaptureControlLink(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == CaptureItem.urlScheme, let host = url.host?.lowercased() else { return false }
        if host == "capture", CaptureItem(url: url) == nil {
            afterUpdate {
                #if os(iOS)
                // The same screen the round + opens: the New screen with Capture chosen.
                self.newNotePreset = NewNotePreset(thing: .capture, servesGoal: "")
                self.activeSheet = .newNote
                #else
                self.activeSheet = .quickCapture
                #endif
            }
            return true
        }
        #if os(iOS)
        if host == "record" {
            afterUpdate {
                Task { @MainActor in
                    do {
                        _ = try await RecordThoughtIntent.pressed(into: .inbox)
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            return true
        }
        #endif
        return false
    }
}

// MARK: - Snooze: the day window

/// The window **Pick a day…** opens. A host of its own, put on the Inbox's capture bar, so it is
/// not a second `.sheet` on the view that already carries the date window (build 44).
struct SnoozeSheetHost: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.snoozeAsking) { ref in
                DateTimeChoiceView(current: nil, offersTime: false,
                                   cancel: { model.snoozeAsking = nil },
                                   title: "Snooze until", confirmTitle: "Snooze",
                                   tint: SidebarSection.inbox.tint) { picked, _ in
                    if let picked { model.snooze(ref, until: picked) }
                    model.snoozeAsking = nil
                }
            }
    }
}

/// **Snooze until…** on a line's menu: tomorrow, next Monday, or a day of your own.
struct InboxSnoozeMenu: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef

    var body: some View {
        Menu("Snooze until\u{2026}") {
            Button("Tomorrow") { model.snooze(ref, until: DateOnly.today().adding(days: 1)) }
                .accessibilityIdentifier("inbox.snooze.tomorrow")
            Button("Next Monday") { model.snooze(ref, until: InboxSnooze.nextMonday(after: DateOnly.today())) }
                .accessibilityIdentifier("inbox.snooze.monday")
            Button("Pick a day\u{2026}") { model.snoozeAsking = ref }
                .accessibilityIdentifier("inbox.snooze.pick")
        }
        .accessibilityIdentifier("inbox.snooze")
    }
}

// MARK: - Select, then file once

/// The places a group of picked lines can go: the places filed to lately, then the whole list.
struct FilingPlacesMany: View {
    @EnvironmentObject private var model: AppModel
    let refs: [TaskRef]
    let places: [Note]

    private var recent: [FilingOrder.Place] {
        guard let first = refs.first else { return [] }
        return model.filingOffer(for: first, among: places).recent
    }

    var body: some View {
        if refs.isEmpty {
            Text("Pick the lines first")
        } else if places.isEmpty {
            Text("No project or area yet")
        } else {
            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(recent, id: \.path) { place in
                        Button(place.title) { model.fileInboxLines(refs, to: place.path) }
                            .accessibilityIdentifier("inbox.select.recent.\(place.title)")
                    }
                }
            }
            Section("All projects and areas") {
                ForEach(places) { note in
                    Button(note.displayTitle) { model.fileInboxLines(refs, to: note.relativePath) }
                        .accessibilityIdentifier("inbox.select.place.\(note.displayTitle)")
                }
            }
        }
    }
}

/// The row above the Inbox list: **Select** to start, and while selecting **Cancel**, the count,
/// **All** and **File N lines**.
struct InboxSelectBar: View {
    @EnvironmentObject private var model: AppModel
    let items: [TaskRef]

    private var picked: [TaskRef] { items.filter { model.inboxPickedIDs.contains($0.triageID) } }
    private var tint: Color { SidebarSection.inbox.tint }

    var body: some View {
        if model.inboxSelecting {
            selecting
        } else if items.count > 1 {
            HStack {
                Spacer()
                Button("Select") {
                    model.inboxSelection = nil
                    model.inboxSelecting = true
                }
                .buttonStyle(.borderless)
                .font(Txt.label)
                .accessibilityIdentifier("inbox.select")
            }
            .padding(.horizontal, Theme.rowEdge)
            .padding(.vertical, 2)
        }
    }

    private var selecting: some View {
        let chosen: [TaskRef] = picked
        let count: Int = chosen.count
        let everything: Bool = !items.isEmpty && count == items.count
        return HStack(spacing: 10) {
            Button("Cancel") {
                model.inboxSelecting = false
                model.inboxPickedIDs = []
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("inbox.select.cancel")
            Text(Self.countWords(count))
                .foregroundStyle(.soft)
                .accessibilityIdentifier("inbox.select.count")
            Spacer()
            Button(everything ? "None" : "All") {
                model.inboxPickedIDs = everything ? [] : Set(items.map(\.triageID))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("inbox.select.all")
            Menu {
                FilingPlacesMany(refs: chosen, places: InboxItems.destinations(model))
            } label: {
                Text(count == 0 ? "File lines" : (count == 1 ? "File 1 line" : "File \(count) lines"))
                    .font(Txt.label.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(tint.deep, in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityIdentifier("inbox.select.file")
        }
        .font(Txt.label)
        .padding(.horizontal, Theme.rowEdge)
        .padding(.vertical, 4)
    }

    static func countWords(_ count: Int) -> String {
        count == 0 ? "Pick lines" : (count == 1 ? "1 picked" : "\(count) picked")
    }
}

/// The small round tick in front of a line while selecting. Its own button, never a gesture on
/// the row, which would take the row's click (builds 71 to 74).
struct InboxPickButton: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef

    private var isPicked: Bool { model.inboxPickedIDs.contains(ref.triageID) }

    var body: some View {
        Button {
            if isPicked {
                model.inboxPickedIDs.remove(ref.triageID)
            } else {
                model.inboxPickedIDs.insert(ref.triageID)
            }
        } label: {
            MarkImage(isPicked ? "checkmark.circle" : "circle")
                .rowTint(SidebarSection.inbox.tint)
        }
        .buttonStyle(.plain)
        .help("Pick this line")
        .accessibilityLabel(isPicked ? "Picked" : "Not picked")
        .accessibilityIdentifier("inbox.pick.\(ref.task.title)")
    }
}

/// The last row of the list: how many lines are snoozed, and a way to bring them back.
struct InboxSnoozedRow: View {
    @EnvironmentObject private var model: AppModel
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(count == 1 ? "1 line is snoozed" : "\(count) lines are snoozed")
                .foregroundStyle(.soft)
            Spacer()
            Button("Bring back") { model.bringSnoozedBack() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("inbox.snoozed.bringBack")
        }
        .font(Txt.listSecond)
        .accessibilityIdentifier("inbox.snoozed")
    }
}
