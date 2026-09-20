import SwiftUI
import ParagonCore

/// Every tag in the vault, and what carries it.
///
/// Until build 143 a tag could only be reached through the **Tag** chip in Search, which
/// listed the names and nothing else — no counts, no way to see what a tag was actually on.
/// His own description of what a tag is decided the shape of this screen: "ett system för att
/// filtrera eller gruppera".
///
/// One screen, not a two-column one. A tag opens in place, so the Mac and the phone show the
/// same thing and there is no second route to keep working.
struct TagsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = ""
    /// Tags folded shut, by their lower-case name. Everything starts folded: the list is the
    /// point, and forty open tags is not a list.
    @State private var opened: Set<String> = []
    @State private var newTag = ""
    @State private var renaming: String?
    @State private var renameDraft = ""
    @State private var deleting: String?

    private var uses: [TagUse] {
        let all = model.tagUses()
        let needle = NoteIndex.normalized(filter)
        guard !needle.isEmpty else { return all }
        return all.filter { $0.tag.lowercased().contains(needle) }
    }

    var body: some View {
        Group {
            if model.allTagNames.isEmpty {
                EmptyStateView(title: "No tags yet",
                               systemImage: SidebarSection.tags.systemImage,
                               message: "Write #travel, #waiting or any other word with a # in front of it, in a note or in a task. Or make one here and put it on a note later.",
                               tint: SidebarSection.tags.tint)
            } else {
                // A plain List, and every row a Button. Nothing is tagged for selection: one
                // note can carry two tags and would then appear twice, and two rows with the
                // same selection tag is what left the Inbox unclickable in builds 71 to 74.
                List {
                    ForEach(uses) { use in
                        Section {
                            if opened.contains(use.tag.lowercased()) {
                                contents(of: use.tag)
                            }
                        } header: {
                            header(for: use)
                        }
                    }
                }
                .searchable(text: $filter, prompt: "Find a tag")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { makeBar }
        .navigationTitle("Tags")
        // The same pair Templates has used since build 93: an alert whose only content is a
        // TextField (a macOS alert silently drops anything else), and a confirmation dialog
        // for the destructive one.
        .alert("Rename #\(renaming ?? "")",
               isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name", text: $renameDraft)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") {
                if let renaming { model.changeTag(renaming, to: renameDraft) }
                renaming = nil
            }
        } message: {
            Text("Every note and every task that carries it is changed.")
        }
        .confirmationDialog("Delete #\(deleting ?? "") everywhere?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let deleting { model.changeTag(deleting, to: nil) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The tag is taken out of every note and every task. The notes and the tasks themselves are kept.")
        }
    }

    /// Making a tag before anything carries it. A tag with nothing on it has nowhere to live
    /// in a markdown vault, so the app remembers it in the vault's own state folder until a
    /// note or a task picks it up.
    private var makeBar: some View {
        HStack(spacing: 8) {
            TextField("New tag", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .onSubmit(make)
            Button("Make", action: make)
                .disabled(AppModel.cleanTag(newTag) == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func make() {
        model.makeTag(newTag)
        newTag = ""
    }

    private func header(for use: TagUse) -> some View {
        let isOpen = opened.contains(use.tag.lowercased())
        return Button {
            toggle(use.tag)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text("#\(use.tag)")
                    .font(.headline)
                    .foregroundStyle(SidebarSection.tags.tint)
                Spacer(minLength: 6)
                Text(summary(of: use))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .contextMenu {
            Button("Rename\u{2026}") {
                renameDraft = use.tag
                renaming = use.tag
            }
            Button("Delete\u{2026}", role: .destructive) { deleting = use.tag }
            Divider()
            Button("Search for #\(use.tag)") {
                model.queryText = "#\(use.tag)"
                model.show(section: .search, notePath: nil)
            }
        }
    }

    /// Built outside the ViewBuilder, where a `var` is allowed.
    private func summary(of use: TagUse) -> String {
        guard !use.isUnused else { return "not used yet" }
        var parts: [String] = []
        if use.noteCount > 0 { parts.append("\(use.noteCount) \(use.noteCount == 1 ? "note" : "notes")") }
        if use.openTaskCount > 0 { parts.append("\(use.openTaskCount) open") }
        if use.finishedTaskCount > 0 { parts.append("\(use.finishedTaskCount) done") }
        return parts.joined(separator: " \u{00b7} ")
    }

    @ViewBuilder
    private func contents(of tag: String) -> some View {
        let notes = model.index.notesTagged(tag)
        let tasks = model.index.tasksTagged(tag)
        if notes.isEmpty && tasks.isEmpty {
            Text("Nothing carries this tag any more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        ForEach(notes) { note in
            Button {
                // Stay in Tags: on the Mac the note opens in the third column with this list
                // still beside it, on the phone the back arrow comes straight back here.
                model.show(section: .tags, notePath: note.relativePath)
            } label: {
                HStack(spacing: 8) {
                    KindBadge(kind: note.declaredKind, size: 18)
                    Text(note.displayTitle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        ForEach(tasks) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
        }
    }

    private func toggle(_ tag: String) {
        let key = tag.lowercased()
        if opened.contains(key) {
            opened.remove(key)
        } else {
            opened.insert(key)
        }
    }
}

/// The blocks of tasks kept in Templates/Snippets.md.
///
/// They had no row of their own before build 143: they were one line inside the Templates
/// list, and he asked twice where snippets are edited. The list says what is in the file; the
/// file itself is edited beside it on the Mac, and one tap away on the phone.
struct SnippetsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.snippets.isEmpty {
                EmptyStateView(title: "No snippets yet",
                               systemImage: SidebarSection.snippets.systemImage,
                               message: "A snippet is a block of tasks you use again and again \u{2014} packing for a trip, closing a project. They live in one file, Templates \u{203a} Snippets, with a ## heading above each block.",
                               tint: SidebarSection.snippets.tint)
            } else {
                List {
                    Section {
                        ForEach(model.snippets) { snippet in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snippet.name)
                                    .font(.headline)
                                Text(firstLines(of: snippet))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    } footer: {
                        Text("Add one from the Snippet button beside Add a task in any note. To change them, edit the file itself \u{2014} each ## heading starts a new block.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    #if os(iOS)
                    Section {
                        NavigationLink("Edit the Snippets file", value: PhoneRoute.template(Snippets.fileName))
                    }
                    #endif
                }
            }
        }
        .navigationTitle("Snippets")
    }

    /// What the block contains, as one line of prose. Built outside the ViewBuilder.
    private func firstLines(of snippet: Snippet) -> String {
        let written = snippet.lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return written.isEmpty ? "Empty" : written.joined(separator: " \u{00b7} ")
    }
}

/// The note's tags, in the note's own header — and the one control in the app that writes
/// them.
///
/// Build 143 gave tags a screen of their own and left the same gap this project has now paid
/// for four times: the screen asked a question nothing could answer. A tag could only be put
/// on a note by typing the `tags:` line by hand. That still works; this writes the same line.
struct NoteTagsChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var showing = false

    /// Read back from the model rather than kept: a toggle saves and reloads, and the copy
    /// handed to this view a moment ago is then one behind.
    private var live: Note { model.note(at: note.relativePath) ?? note }

    private var title: String {
        live.tags.isEmpty ? "Tags…" : live.tags.map { "#\($0)" }.joined(separator: " ")
    }

    /// The note's tags as something that can be written to. `setTags` cleans and de-duplicates,
    /// so the list that comes back may differ from the one handed in — which is the point.
    private var chosen: Binding<[String]> {
        Binding(get: { live.tags }, set: { model.setTags($0, on: live) })
    }

    var body: some View {
        Button {
            showing = true
        } label: {
            Label(title, systemImage: "number")
                .contentShape(Rectangle())
                .helpWhenClosed("Add or remove this note's tags", open: showing)
        }
        .buttonStyle(.plain)
        .foregroundStyle(live.tags.isEmpty ? Color.secondary : SidebarSection.tags.tint)
        .popover(isPresented: $showing) {
            TagChoices(model: model, title: "Tags on this note", chosen: chosen)
        }
    }
}

/// Every tag the vault knows, with a tick on the ones chosen, and a field to make a new one.
///
/// **One view, used by the note header and by the New note sheet (build 187).** His ask:
/// *"It's not always too easy to know what tags I have defined, and I don't want two tags the
/// same meaning, but slightly different names."* Seeing the whole list at the moment of
/// choosing is the answer to that, so the list has to be the same list in both places — two
/// of them is how the Map, the review and the goal dashboard came to give three answers to
/// "what serves what" before build 162.
///
/// **The counts are read once, in `onAppear`.** `tagUses()` walks every note and every task;
/// reading it from `body` would do that walk again on every keystroke in the new-tag field.
struct TagChoices: View {
    @ObservedObject var model: AppModel
    let title: String
    /// The sentence under the list. It differs by where the tags end up: a note keeps them on
    /// its `tags:` line, a capture keeps them in the words as `#tag`.
    var hint = "A tag can also be written straight into the note's tags: line, or as #tag on a task."
    @Binding var chosen: [String]
    @State private var draft = ""
    @State private var totals: [String: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                TextField("New tag", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDraft)
                Button("Add", action: addDraft)
                    .disabled(TagName.clean(draft) == nil)
            }
            choices
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        // One place, so the note header, the New note sheet and the Capture screen all lose
        // the accent-coloured focus ring on the first row together (build 202).
        .focusEffectDisabled()
        .onAppear {
            var counts: [String: Int] = [:]
            for use in model.tagUses() { counts[use.tag.lowercased()] = use.total }
            totals = counts
        }
    }

    @ViewBuilder
    private var choices: some View {
        let tags = offered
        if tags.isEmpty {
            Text("No tags anywhere yet. Write the first one above.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tags, id: \.self) { tag in
                        row(tag)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func row(_ tag: String) -> some View {
        Button {
            toggle(tag)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn(tag) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn(tag) ? SidebarSection.tags.tint : Color.secondary)
                Text("#\(tag)")
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(countText(for: tag))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// How much of the vault carries it, so a tag that means the same as another one but is
    /// spelled differently stands out as the one with almost nothing on it.
    private func countText(for tag: String) -> String {
        let total = totals[tag.lowercased()] ?? 0
        return total == 0 ? "not used yet" : "\(total)"
    }

    /// The chosen tags first, in their own order, then every other tag in the vault. Built
    /// outside the ViewBuilder, where a `var` is not allowed (build 58).
    private var offered: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in chosen where seen.insert(tag.lowercased()).inserted {
            result.append(tag)
        }
        for tag in model.allTagNames where seen.insert(tag.lowercased()).inserted {
            result.append(tag)
        }
        return result
    }

    private func isOn(_ tag: String) -> Bool {
        chosen.contains { $0.lowercased() == tag.lowercased() }
    }

    private func toggle(_ tag: String) {
        guard let clean = TagName.clean(tag) else { return }
        var tags = chosen
        if let index = tags.firstIndex(where: { $0.lowercased() == clean.lowercased() }) {
            tags.remove(at: index)
        } else {
            tags.append(clean)
        }
        chosen = tags
    }

    private func addDraft() {
        guard let clean = TagName.clean(draft) else { return }
        if !isOn(clean) { toggle(clean) }
        draft = ""
    }
}
