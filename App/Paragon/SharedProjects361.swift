import SwiftUI
import ParagonCore

/// Build 361, **shared projects** (his ask, 22 Nov 2026): a project whose Reminders list is
/// shared with Anna in Apple Reminders. The rules live in Core's `SharedTasks`; here are the
/// writers and the two pieces of screen: the **Shared with** chip on the note's panel with its
/// window, and the **Who does it** menu on a task.
extension AppModel {
    /// Who is responsible for a task (his words: "not who shared it or who created it"), or
    /// nobody (nil). Written as `@who(Anna)`; the sync carries it to Reminders as `Who: Anna`.
    func setWho(_ name: String?, for ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task) else { return }
        var changed: TaskItem = live
        changed.who = name.flatMap(SharedTasks.cleanName)
        guard changed != live, note.rewrite(task: live, with: changed) else { return }
        guard save(note) else { return }
        flash(changed.who.map { "\($0) does it." } ?? "Nobody does it yet.")
    }

    /// Shares a note's Reminders list with these people, or stops sharing it (no names). The
    /// owner's own name is kept for the whole notes folder.
    func share(_ note: Note, myName: String, with names: [String]) {
        flushPendingEdits()
        if let mine = SharedTasks.cleanName(myName), mine != config.myName {
            var changed = config
            changed.myName = mine
            config = changed
        }
        guard var live = self.note(at: note.relativePath) else { return }
        if names.isEmpty {
            guard live.frontmatter.string("shared-with") != nil else { return }
            live.frontmatter.remove("shared-with")
        } else {
            guard live.sharedWith != names else { return }
            live.frontmatter.set("shared-with", list: names)
        }
        guard save(live) else { return }
        flash(names.isEmpty ? "Not shared any more." : "\(SharedTasks.sharedWords(names)).")
        Task { await syncNow(quietly: true) }
    }
}

/// On the note's panel, beside **Reminders list**: "Share…" in grey, or "Shared with Anna" in
/// the shared colour. Pressing it opens the window to set it up or change it.
struct SharedListChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var showing = false

    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        Button {
            showing = true
        } label: {
            MarkLabel(live.isShared ? SharedTasks.sharedWords(live.sharedWith) : "Share…", "people")
                .lineLimit(1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .foregroundStyle(live.isShared ? Theme.sharedTint.ink : Theme.soft)
        .frame(maxWidth: 280)
        .help("Share this project's Reminders list with someone, so you both see and tick the same tasks.")
        .accessibilityIdentifier("note.shared")
        .popover(isPresented: $showing) {
            ShareListView(model: model, note: live, isPresented: $showing)
        }
    }
}

/// The window: your name, who it is shared with, and the steps in Apple Reminders.
struct ShareListView: View {
    @ObservedObject var model: AppModel
    let note: Note
    @Binding var isPresented: Bool
    @State private var myName = ""
    @State private var others = ""

    private var names: [String] { SharedTasks.names(from: others) }
    private var canSave: Bool { SharedTasks.cleanName(myName) != nil && !names.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Share")
                    .font(Txt.listTitle)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("share.cancel")
                Button("Save") {
                    model.share(note, myName: myName, with: names)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.sharedTint.ink)
                .disabled(!canSave)
                .accessibilityIdentifier("share.save")
            }
            Text("Your name").font(Txt.label).foregroundStyle(.soft)
            TextField("Martin", text: $myName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("share.myName")
            Text("Shared with").font(Txt.label).foregroundStyle(.soft)
            TextField("Anna", text: $others)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("share.with")
            Text("Then, in Apple Reminders: press and hold the list \u{201C}\(note.remindersListName)\u{201D} (on the Mac, right-click it), choose Share List and invite them. They make a project with the same name in their PARAGON and share it the same way.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
            Text("A task's menu then has Who does it. The name shows at the right end of the task.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
            if note.isShared {
                Button("Stop sharing", role: .destructive) {
                    model.share(note, myName: myName, with: [])
                    isPresented = false
                }
                .accessibilityIdentifier("share.stop")
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .onAppear {
            myName = model.config.myName
            others = note.sharedWith.joined(separator: ", ")
        }
    }
}

/// On a task in a shared note: **Who does it**, the names and **Nobody**.
struct WhoDoesItMenu: View {
    @ObservedObject var model: AppModel
    let ref: TaskRef

    var body: some View {
        if let note = model.note(at: ref.notePath), note.isShared {
            Menu {
                ForEach(SharedTasks.people(me: model.config.myName, sharedWith: note.sharedWith, current: ref.task.who), id: \.self) { name in
                    TickedChoice(title: name, chosen: ref.task.who == name) { model.setWho(name, for: ref) }
                }
                Divider()
                TickedChoice(title: "Nobody", chosen: ref.task.who == nil) { model.setWho(nil, for: ref) }
            } label: {
                MarkLabel("Who does it", "people")
            }
            .accessibilityIdentifier("task.menu.who")
        }
    }
}

extension Theme {
    /// Build 361: the colour of sharing — the **Shared with** chip and the window's Save. A violet
    /// no other part of the app uses, so it means one thing.
    static let sharedTint = Color(day: 0x6A4FC9, night: 0xA996F0)
}
