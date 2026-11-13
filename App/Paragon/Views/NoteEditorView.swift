import SwiftUI
import ParagonCore
#if os(iOS)
import PencilKit
import PhotosUI
#endif

struct NoteEditorView: View {
    @EnvironmentObject private var model: AppModel
    let path: String

    @State private var text = ""
    @State private var newTask = ""
    /// Build 316: date words in **Add a task…** that he took away with the chip's x.
    @State private var ignoredDateWords: String?
    /// Round 9 (build 316): the cursor is in **Add a task…**.
    @FocusState private var addFieldFocused: Bool
    /// True while the find bar is up on the iPhone; the Add a task bar hides meanwhile.
    @State private var findBarUp = false
    @State private var isDirty = false
    @State private var pendingSave: Task<Void, Never>?
    @State private var showTasks = true
    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false
    @State private var showLinks = false
    @State private var confirmTrash = false
    @State private var snippetToFill: Snippet?
    @State private var renamingNote = false
    #if os(iOS)
    /// Round 8 (build 315): the copy **Share…** made, waiting for the share sheet.
    @State private var sharedFile: SharedFile?
    #endif
    @State private var noteTitleDraft = ""
    /// A `[[` being typed, with where the caret is; nil when nothing is.
    @State private var linkDraft: LinkDraftOnScreen?
    /// The title to write in, handed to the editor.
    @State private var linkCompletion: LinkCompletion?
    /// Which suggestion the arrow keys are on.
    @State private var linkChoice = 0
    @State private var vaultPath: String?
    /// The note's real text (markers included) that the shown text was made from.
    @State private var baseText = ""
    /// The shown text of the last save this editor made itself. When the model hands that same
    /// text back, it is our own save coming home, not a change from outside (build 240).
    @State private var lastWritten: String?
    /// Build 288: the sketch being drawn or looked at.
    @State private var sketch: SketchRequest?
    @AppStorage("editorMode") private var mode: EditorMode = .edit
    /// The settings block at the top folded out of the editor (build 246). One setting for
    /// every note: he asked to compress "this area of each note", not one at a time.
    /// **Build 312 (flow-02): folded to begin with.** A fresh install starts folded, and an
    /// older one is folded once at the first start of 312 (`AppModel.foldSettingsBlockOnce`,
    /// Core's `SettingsBlockFold`); after that it is whatever he last chose.
    @AppStorage(SettingsBlockFold.key) private var frontmatterFolded = true
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    /// Whether this editor's window is the one in front (review round 8, for ⌘F).
    @Environment(\.controlActiveState) private var controlActiveState
    #endif

    /// Edit or Read, and nothing else. Split was a third choice he never used and asked to
    /// have removed (build 142). A stored "split" no longer decodes and falls back to Edit,
    /// so there is nothing to migrate.
    enum EditorMode: String, CaseIterable, Identifiable {
        case edit, preview
        var id: String { rawValue }
        var label: String { self == .edit ? "Edit" : "Read" }
    }

    private var note: Note? { model.note(at: path) }
    private var storedText: String { note?.text ?? "" }
    /// What the editor shows: the note's text with the `^t` sync markers hidden, and the
    /// settings block folded away when he has asked for that.
    private var displayText: String { shownText(from: storedText, folded: frontmatterFolded) }

    private func shownText(from stored: String, folded: Bool) -> String {
        // Asked for on every key (`scheduleSave`) and every redraw, and reading a very long
        // note line by line each time made typing in it slow (premium review, hardening-20).
        // The answer for the same text is the same, so the last one is kept.
        if let last = shownMemo.last, last.folded == folded, last.stored == stored { return last.shown }
        let masked = TaskIDMasking.hidden(in: stored)
        let shown = folded ? FrontmatterFold.body(of: masked) : masked
        shownMemo.last = (stored, folded, shown)
        return shown
    }

    /// The last answer of `shownText`. A plain box, not state: filling it redraws nothing.
    private final class ShownMemo {
        var last: (stored: String, folded: Bool, shown: String)?
    }
    @State private var shownMemo = ShownMemo()

    /// The whole text to write, from what the editor shows. The settings block comes from
    /// `baseText`, the latest copy of the file, so a line a button wrote while the block was
    /// folded (**Serves…**, **Tags…**) is kept rather than overwritten by an older copy.
    private func wholeText(from shown: String, folded: Bool) -> String {
        let unfolded = folded ? FrontmatterFold.joined(head: FrontmatterFold.head(of: baseText), body: shown) : shown
        return TaskIDMasking.restored(unfolded, from: baseText)
    }

    /// Only drawn while there is a block to fold and the text is being edited.
    private var hasFrontmatter: Bool { FrontmatterFold.head(of: storedText) != nil }

    var body: some View {
        Group {
            if isPhone { phoneBody } else { deskBody }
        }
        .onAppear {
            baseText = storedText
            text = displayText
            vaultPath = model.vaultPath
            model.flushEditor = flushSave
        }
        .onDisappear {
            model.flushEditor = nil
            // Runs while SwiftUI is swapping views; save after the update, not inside it.
            pendingSave?.cancel()
            pendingSave = nil
            if isDirty {
                let unsaved = wholeText(from: text, folded: frontmatterFolded)
                let startedFrom = baseText
                let openedIn = vaultPath
                isDirty = false
                model.afterUpdate {
                    // Only into the vault the note was opened from.
                    if model.vaultPath == openedIn { model.saveText(unsaved, forNoteAt: path, startedFrom: startedFrom) }
                }
            }
        }
        .onChange(of: storedText) { _, newValue in
            // The open note went back to iCloud (build 261): "" is not its text. Keep the screen
            // and the text it came from; a save meanwhile keeps the typing as a copy beside the
            // note (`saveText`), and the note's return is the next change seen here.
            if note == nil, model.notesWaitingForCloud.contains(path) { return }
            // The file changed (a sync assigned markers, another device edited it). While
            // nothing is being typed, follow it; the shown text often does not change at all
            // because only hidden markers moved.
            let shown = shownText(from: newValue, folded: frontmatterFolded)
            // **Our own save coming back is never a reason to replace what is on screen**
            // (build 240). The save clears `isDirty`, and a key pressed in the moment before
            // this runs had not set it again yet — so the editor was put back to the saved
            // text and the last letters typed were lost. The screen test caught it twice.
            // **Used once** (build 242): left in place, a later change that happened to bring
            // the file back to that same text — tick a task, then untick it — was taken for our
            // echo and ignored, and the next keystroke saved the stale screen over the file.
            if shown == lastWritten {
                lastWritten = nil
                baseText = newValue
                return
            }
            guard !isDirty else { return }
            lastWritten = nil
            baseText = newValue
            if shown != text { text = shown }
        }
        .onChange(of: frontmatterFolded) { wasFolded, _ in
            // What is on screen was shaped by the old setting, so it is saved with that
            // before the editor is given the new shape.
            pendingSave?.cancel()
            pendingSave = nil
            if isDirty {
                lastWritten = nil
                model.saveText(wholeText(from: text, folded: wasFolded), forNoteAt: path, startedFrom: baseText)
                isDirty = false
                baseText = model.note(at: path)?.text ?? baseText
            }
            text = displayText
        }
        .confirmationDialog("Delete \u{201C}\(note?.displayTitle ?? "")\u{201D}?", isPresented: $confirmTrash) {
            Button("Delete", role: .destructive) {
                guard let note else { return }
                pendingSave?.cancel()
                pendingSave = nil
                isDirty = false
                model.trash(note)
            }
        } message: {
            Text("It goes to the Deleted list, where you can put it back.")
        }
        .alert("Rename \u{201C}\(note?.displayTitle ?? "")\u{201D}", isPresented: $renamingNote) {
            TextField("Title", text: $noteTitleDraft)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                guard let note else { return }
                flushSave()
                model.renameNote(note, to: noteTitleDraft)
            }
        } message: {
            Text("The file is renamed too, and every note that links to it is pointed at the new name.")
        }
        .sheet(item: $sketch) { request in
            SketchSheet(request: request, tint: note?.tint ?? Theme.fallbackTint) { png, drawing in
                saveSketch(request, png: png, drawing: drawing)
            }
            .environmentObject(model)
        }
        .sheet(item: $snippetToFill) { snippet in
            SnippetSheet(snippet: snippet) { answers in
                model.insert(snippet, answers: answers, into: path)
            }
        }
        // Round 9 (build 316): a daily note's date is not written in the iPhone's top bar
        // any more. The band right under the bar says it in large letters, so the bar only
        // said it a second time. The Mac and the iPad keep it: there it names the window.
        .navigationTitle(isPhone && note?.kind == .daily && note?.dailyDate != nil ? "" : (note?.displayTitle ?? path))
        // Round 8 (build 315): ⌘F from the Mac's Edit menu.
        // Every open editor hears the count; only the one in the window in front acts.
        .onChange(of: model.findInNoteRequests) { _, _ in
            #if os(macOS)
            guard controlActiveState == .key else { return }
            #endif
            findInNote()
        }
        .modifier(SharesNoteFile(file: sharedFileBinding))
        .toolbar {
            // The phone's navigation bar has room for a back button, a title and one control.
            // Everything went in as separate items and the segmented picker was squeezed to
            // three overlapping letters, so on a phone it is all one menu.
            if isPhone {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // Round 8 (build 315): find a word in this note, and send the note on.
                        Button {
                            findInNote()
                        } label: {
                            MarkLabel("Find in note", "magnifyingglass", size: 16)
                        }
                        .accessibilityIdentifier("note.find")
                        shareMenu
                        if let note, note.kind != .inbox, note.kind != .daily {
                            Button {
                                noteTitleDraft = note.displayTitle
                                renamingNote = true
                            } label: {
                                MarkLabel("Rename", "pencil", size: 16)
                            }
                        }
                        if let note, model.canArchive(note) {
                            Button {
                                flushSave()
                                model.archive(note)
                            } label: {
                                MarkLabel("Archive", "archivebox", size: 16)
                            }
                        }
                        if let note, note.kind != .inbox {
                            Button(role: .destructive) {
                                confirmTrash = true
                            } label: {
                                MarkLabel("Delete", "trash", size: 16)
                            }
                        }
                    } label: {
                        MarkLabel("More", "ellipsis.circle", size: 16)
                    }
                    .accessibilityIdentifier("note.more")
                }
            } else {
            // Where a browser keeps them, at the leading edge. Not on the phone: its
            // navigation bar has its own back button and no room besides (build 88).
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    model.goBack()
                } label: {
                    MarkLabel("Back", "chevron.backward", size: 16)
                }
                .disabled(!model.canGoBack)
                .help("Back to the note you came from (\u{2303}\u{2318}\u{2190})")
                Button {
                    model.goForward()
                } label: {
                    MarkLabel("Forward", "chevron.forward", size: 16)
                }
                .disabled(!model.canGoForward)
                .help("Forward again (\u{2303}\u{2318}\u{2192})")
            }
            ToolbarItemGroup {
                // The same control as the phone's, for the same reason: one symbol whose
                // state you can see, rather than a row of words where the selected one is
                // easy to miss.
                StateToggle(markName: "pencil", title: "Edit", isOn: mode == .edit,
                            tint: note?.tint ?? Theme.fallbackTint) {
                    mode = mode == .edit ? .preview : .edit
                }
                // Build 316: the iPad at full width had no way to Find in note (the Mac has
                // ⌘F in the Edit menu, the iPhone its ⋯ menu). Beside the note's other actions.
                #if os(iOS)
                Button {
                    findInNote()
                } label: {
                    MarkLabel("Find in note", "magnifyingglass", size: 16)
                }
                .accessibilityIdentifier("note.find")
                #endif
                if let note, model.canArchive(note) {
                    Button {
                        flushSave()
                        model.archive(note)
                    } label: {
                        MoveToArchiveIcon()
                    }
                    .accessibilityIdentifier("note.moveToArchive")
                    .help("Move this note to the Archive folder and stop syncing its tasks")
                }
                // Round 8 (build 315): Share… and, on the Mac, Show in Finder.
                shareMenu
                    .help("Send this note on: as a PDF, as plain text, or the file itself")
                // No Rename button. It was a second pencil beside the Edit toggle and a whole
                // toolbar slot for one rare action — "exaggerated", his word, build 154. The
                // note's name in the header is what renames it now.
                if let note, note.kind != .inbox {
                    Button {
                        confirmTrash = true
                    } label: {
                        MarkLabel("Delete", "trash", size: 16)
                    }
                    .help("Delete this note; it waits in Deleted (⌘⌫)")
                    .keyboardShortcut(.delete, modifiers: [.command])
                }
            }
            }
        }
    }

    // MARK: Find and Share (review round 8, build 315)

    /// Shows Apple's find bar over the note's text. The bar belongs to the text you edit, so a
    /// note that is in Read is turned to Edit first.
    private func findInNote() {
        guard note != nil else { return }
        let wait = mode == .preview ? 0.3 : 0.0
        if mode == .preview { mode = .edit }
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            #if os(macOS)
            NoteFind.run(.show)
            #else
            NoteFind.show()
            findBarUp = true
            #endif
        }
    }

    /// **Share…**: three ways to send the note on, and on the Mac where its file is.
    private var shareMenu: some View {
        Menu {
            // Build 315 polish: a mark on each, like every other row of the menu.
            Button { share(.pdf) } label: { MarkLabel("As PDF", "doc.text", size: 16) }
                .accessibilityIdentifier("note.share.pdf")
            Button { share(.text) } label: { MarkLabel("As plain text", "list.bullet.indent", size: 16) }
                .accessibilityIdentifier("note.share.text")
            Button { share(.file) } label: { MarkLabel("The file itself", "folder", size: 16) }
                .accessibilityIdentifier("note.share.file")
            #if os(macOS)
            Divider()
            Button("Show in Finder") {
                flushSave()
                if let url = model.vault?.url(for: path) { NoteSharing.showInFinder(url) }
            }
            .accessibilityIdentifier("note.showInFinder")
            #endif
        } label: {
            MarkLabel("Share…", "square.and.arrow.up", size: 16)
        }
        .accessibilityIdentifier("note.share")
    }

    private func share(_ form: NoteShare.Form) {
        // What is on screen first, so the copy carries the last words typed.
        flushSave()
        guard let note = model.note(at: path) else { return }
        guard let url = NoteSharing.file(form, for: note) else {
            model.errorMessage = "PARAGON could not make the copy to share. Nothing was changed."
            return
        }
        #if os(macOS)
        NoteSharing.present(url)
        #else
        sharedFile = SharedFile(url: url)
        #endif
    }

    #if os(iOS)
    private var sharedFileBinding: Binding<SharedFile?> { $sharedFile }
    #else
    private var sharedFileBinding: Binding<SharedFile?> { .constant(nil) }
    #endif

    /// Mac and iPad, unchanged: a fixed column whose editor absorbs the leftover height.
    /// Builds 30 and 34 are both about this — anything here that reports its full
    /// intrinsic height makes the window grow past itself — so it is left alone.
    /// Below this height the header is drawn compact (a small title, small chips, no panel), so
    /// the text keeps room on a short column: the test runners' 450-point window, a laptop
    /// with a small window. Build 280 tried two other ways first — a capped, scrolling header
    /// hid the Tasks panel from a press, and one scrolling page put the text below the window.
    private static let shortColumn: CGFloat = 620
    /// The text never gets less than this. On a column too short for the header, the panels
    /// and this much text, the part above the text scrolls instead (1.0's third Mac run: the
    /// editor had been given nothing at all and the test could not press it).
    private static let minEditorHeight: CGFloat = 60

    /// The laid-out heights of the part above the editor and of the rows under it, measured,
    /// so the column can give the sections exactly their height while there is room.
    @State private var sectionsHeight: CGFloat = 0
    @State private var frontmatterHeight: CGFloat = 0
    @State private var addBarHeight: CGFloat = 0

    /// What the sections may take: their own height, or what is left once the text has its
    /// minimum and the rows under it have theirs.
    private func sectionsRoom(in column: CGFloat) -> CGFloat? {
        guard sectionsHeight > 0 else { return nil }
        let room = column - frontmatterHeight - 1 - addBarHeight - Self.minEditorHeight
        return max(0, min(sectionsHeight, room))
    }

    private var deskBody: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 1.0: the header, the panels and the text stop at the reading width and sit
                // centred; on a wide window the rest is calm margin. The sections are as tall
                // as their content while the column has room, and scroll when it has not.
                ScrollView {
                    VStack(spacing: 0) {
                        sections
                            .readingWidth()
                    }
                    .measureHeight($sectionsHeight)
                }
                .frame(height: sectionsRoom(in: geo.size.height))
                frontmatterRow
                    .readingWidth()
                    .measureHeight($frontmatterHeight)
                // The editor takes whatever height is left and never asks for more (builds 30
                // and 34): the GeometryReader's frame is the column, and this is what is left.
                editorPane(scrolls: true)
                    .frame(maxWidth: Theme.readingWidth + 2 * Theme.gutter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                Divider()
                addTaskBar
                    .readingWidth()
                    .measureHeight($addBarHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { compactHeader = geo.size.height < Self.shortColumn }
            .onChange(of: geo.size.height) { _, height in compactHeader = height < Self.shortColumn }
        }
    }

    /// The phone.
    ///
    /// The same column would not fit and could not be moved: nothing in it scrolled, so a
    /// note with two dozen tasks ran off both ends of the screen at once — the first tasks
    /// hidden under the navigation bar, the last under the tab bar, and no way to reach
    /// either. On a screen this size the whole page has to be one scrolling thing.
    ///
    /// The editor is given a height rather than the leftover space, because inside a scroll
    /// view there is no leftover space to take. The add-a-task bar is pinned as a safe-area
    /// inset instead of being the last row: it is the reason the screen is open, and it
    /// should not have to be scrolled to.
    private var phoneBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                sections
                // While editing, the text asks for its own height and this page does the
                // scrolling: two scroll views stacked is why a tap was ambiguous and it took
                // a press and hold to put the cursor in. `minHeight` rather than `height`
                // is the lesson of build 123, which had no floor and collapsed the editor to
                // nothing — the worst this can now do is leave the box it always had.
                //
                // Preview and Split are untouched: `MarkdownPreview` is itself a scroll view
                // and needs a height handed to it.
                frontmatterRow
                if mode == .edit {
                    editorPane(scrolls: false)
                        .frame(minHeight: 320)
                } else {
                    editorPane(scrolls: true)
                        .frame(height: 320)
                }
            }
        }
        // The phone has no third column, so the note screen itself carries the section's
        // colour (build 111). Same tint, same rule as the Mac's right-hand panel.
        // Review round 4: the open note sits on the app's page, like the lists it came from.
        .phonePage()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Build 315 polish: while Apple's find bar is up, this bar is away. Before, it
            // peeked out half hidden behind the find bar.
            if !findBarUp {
                VStack(spacing: 0) {
                    Divider()
                    addTaskBar
                }
                .background(.bar)
            }
        }
        #if os(iOS)
        // The tabs step aside too: with no keys on screen the find bar sits at the very foot.
        .toolbar(findBarUp ? .hidden : .automatic, for: .tabBar)
        // Round 9 (build 316): while the find bar is up the top bar is solid. Stepping to a
        // match scrolls the page from code, and the bar stayed see-through, so the note's
        // title in it sat on top of the scrolled text.
        .toolbarBackground(findBarUp ? .visible : .automatic, for: .navigationBar)
        .task(id: findBarUp) {
            // The find bar is Apple's and closes by itself (its tick, or the keyboard going
            // away); asking it is the one sure way to know. Only while it is up.
            guard findBarUp else { return }
            try? await Task.sleep(for: .milliseconds(700))
            while !Task.isCancelled, NoteFind.isUp {
                try? await Task.sleep(for: .milliseconds(250))
            }
            if !Task.isCancelled { findBarUp = false }
        }
        #endif
    }

    /// Renaming this note, or nil when the name is not his to change. A function, not a
    /// ternary with a closure in one arm: that is where Swift's inference gives up, and there
    /// is no compiler in this container (the same reason as build 152's `openEventAction`).
    private func renameAction(for note: Note) -> (() -> Void)? {
        guard note.kind != .inbox, note.kind != .daily else { return nil }
        return {
            noteTitleDraft = note.displayTitle
            renamingNote = true
        }
    }

    /// Everything above the editor: the note's own header, whatever agenda it carries, its
    /// tasks and its links.
    /// Set by the Mac's `deskBody` from the column's height: on a short column (under 620
    /// points — the test runners' 450-point window, a laptop with a small window) the header is
    /// drawn compact, so the text under it keeps room.
    @State private var compactHeader = false

    @ViewBuilder
    private var sections: some View {
        if let note {
            NoteHeader(note: note, rename: renameAction(for: note), compact: compactHeader)
            if note.declaredKind == .project && note.isEnded {
                ProjectEndedLine(model: model, note: note)
            }
            Divider()
            if let date = note.dailyDate {
                DayAgendaView(date: date)
                Divider()
            }
            if let week = note.weekRef {
                WeekAgendaView(week: week)
                Divider()
            }
            if note.kind == .goal {
                GoalDashboardView(goal: note)
                Divider()
            }
            if note.kind == .area {
                // Build 270: the area's projects, its sub-areas and its weekly bars.
                AreaDashboardView(area: note)
                Divider()
            }
            if !note.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // **The whole name opens it, not a triangle** (build 205). The
                        // `StateToggle` beside it stays its own button, outside this one: a
                        // button inside a button is the builds 71–74 fault in a new place.
                        FoldButton(isOpen: $showTasks, accessibilityName: "Tasks") {
                            SectionLabel(title: note.openTasks.isEmpty ? "Tasks" : "Tasks, \(note.openTasks.count) open",
                                         count: nil, markName: "checklist", tint: note.tint)
                        }
                        Spacer()
                        let finished = note.tasks.count - note.openTasks.count
                        if finished > 0 {
                            // Build 159: the same two-state control as the Edit pencil. The
                            // symbol no longer swaps with the state — it is always the closed
                            // eye, lit when finished tasks are hidden — and the count is a
                            // plain caption beside it, because it is a fact about the note
                            // rather than part of the button.
                            Text("\(finished) finished")
                                .font(Txt.label)
                                .foregroundStyle(.soft)
                            StateToggle(markName: "eye.slash", title: "Hide finished",
                                        isOn: hideFinishedTasks, tint: note.tint) {
                                hideFinishedTasks.toggle()
                            }
                        }
                    }
                    if showTasks {
                        TaskChecklist(note: note, beforeToggle: flushSave)
                    }
                }
                .panel(note.tint)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 6)
            }
            // Build 293: every picture in the note together, once there are two or more.
            let gallery = Pictures.galleryPaths(in: text, notePath: path)
            if !gallery.isEmpty {
                NoteGallery(paths: gallery, version: sketchVersion, tint: note.tint,
                            open: { pictureHooks?.open($0) },
                            copyWords: { model.copyPictureWords($0) },
                            move: { moving, onto in
                                text = Pictures.reordering(text, notePath: path, moving: moving, onto: onto)
                            })
                    .panel(note.tint)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 6)
            }
            let linksTo = notesLinkedTo(from: note)
            let linkedFrom = notesLinking(to: note)
            let notYetMade = missingLinks(from: note)
            if !linksTo.isEmpty || !linkedFrom.isEmpty || !notYetMade.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // **Pressing the words opens it.** Until build 205 this was a
                    // `DisclosureGroup`, where only the small triangle works: the label does
                    // nothing at all on the Mac. That is why four attempts at a screen test
                    // for build 30's window scramble failed — nothing a test could click
                    // would open the box — and it was a real annoyance with a mouse too.
                    // `TemplatesView` and `TagsView` have used a fold button in the header
                    // since build 93 for a different reason; this is the same shape.
                    FoldButton(isOpen: $showLinks, accessibilityName: "Linked notes") {
                        SectionLabel(title: "Linked notes",
                                     count: linksTo.count + linkedFrom.count + notYetMade.count,
                                     markName: "link", tint: note.tint)
                            .font(Txt.label.weight(.medium))
                    }
                    .accessibilityIdentifier("note.links")
                    if showLinks {
                        VStack(alignment: .leading, spacing: 8) {
                            if !linksTo.isEmpty {
                                Text("Links to").font(Txt.label).foregroundStyle(Theme.soft)
                                LinkedNotesList(notes: linksTo)
                            }
                            if !notYetMade.isEmpty {
                                Text("Not made yet").font(Txt.label).foregroundStyle(Theme.soft)
                                MissingLinksList(titles: notYetMade, notePath: note.relativePath)
                            }
                            if !linkedFrom.isEmpty {
                                Text("Linked from").font(Txt.label).foregroundStyle(Theme.soft)
                                LinkedNotesList(notes: linkedFrom)
                            }
                        }
                        // Drawn only while the box is open, so its presence is the proof
                        // that the press landed — what the Mac screen test waits for.
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("note.links.open")
                    }
                }
                .panel(note.tint)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 6)
            }
        }
    }

    /// One line above the text: a fold for the settings block (build 246). `FoldButton`,
    /// the shape every other fold in the app has had since build 205. Drawn only while there
    /// is a block to fold and the text is being edited; the Read view never shows the block.
    @ViewBuilder private var frontmatterRow: some View {
        if mode == .edit && hasFrontmatter {
            // The whole line is the button, not a label with a spacer after it: the Mac's
            // accessibility frame for a short button here pointed the screen test's click
            // into the note list, which deselected the note (build 247's first three runs).
            FoldButton(isOpen: frontmatterOpen, accessibilityName: "Settings block at the top of the note") {
                Text(frontmatterFolded ? "Settings block hidden" : "Settings block")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("note.frontmatter")
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            Divider()
        }
    }

    /// `FoldButton` asks whether the box is open; the setting says whether it is folded.
    private var frontmatterOpen: Binding<Bool> {
        Binding(get: { !frontmatterFolded }, set: { frontmatterFolded = !$0 })
    }

    /// Build 288/289: pictures in the text, the pencil and the photo button.
    private var pictureHooks: PictureHooks? {
        guard let root = model.vault?.rootURL else { return nil }
        return PictureHooks(notePath: path, root: root, version: sketchVersion,
                            sketch: { offset in sketch = SketchRequest(offset: offset, picturePath: nil) },
                            photo: { offset, camera in
                                photoOffset = offset
                                if camera { takingPhoto = true } else { choosingPhoto = true }
                            },
                            open: { picture in sketch = SketchRequest(offset: nil, picturePath: picture) },
                            caption: { offset, link in
                                captionEdit = CaptionEdit(offset: offset, link: link)
                                captionDraft = Pictures.caption(ofLink: link) ?? ""
                            },
                            drop: { offset, urls in dropPictures(urls, at: offset) },
                            paste: { offset, data, ext in pastePicture(data, ext: ext, at: offset) },
                            copyWords: { model.copyPictureWords($0) },
                            showWords: { offset, picture in showWords(of: picture, at: offset) },
                            makeTasks: { offset, picture in makeTasks(of: picture, at: offset) })
    }

    /// Build 290: the picture whose caption is being written, and the words so far.
    struct CaptionEdit { var offset: Int; var link: String }
    @State private var captionEdit: CaptionEdit?
    @State private var captionDraft = ""

    /// Save on the caption window: the picture's link with the new words, if it is still there.
    private func saveCaption() {
        guard let edit = captionEdit else { return }
        captionEdit = nil
        let ns = text as NSString
        let range = NSRange(location: edit.offset, length: (edit.link as NSString).length)
        guard NSMaxRange(range) <= ns.length, ns.substring(with: range) == edit.link else { return }
        text = ns.replacingCharacters(in: range, with: Pictures.settingCaption(captionDraft, inLink: edit.link))
    }

    /// Build 290 (Mac): pictures dragged in from Finder, copied into the Pictures folder, each
    /// on its own line where they were dropped. The originals stay where they were.
    private func dropPictures(_ urls: [URL], at offset: Int) {
        guard let vault = model.vault else { return }
        let folder = vault.rootURL.appendingPathComponent(Pictures.droppedFolder)
        var taken = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        var at = min(offset, (text as NSString).length)
        var result = text
        for url in urls {
            let reading = url.startAccessingSecurityScopedResource()
            defer { if reading { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                model.errorMessage = "\u{201C}\(url.lastPathComponent)\u{201D} could not be read."
                continue
            }
            let name = Pictures.freeName(for: url.lastPathComponent, taken: taken)
            do {
                try vault.writeFile(data, at: Pictures.droppedFolder + "/" + name)
            } catch {
                model.errorMessage = "The picture could not be saved: \(error.localizedDescription)"
                continue
            }
            taken.insert(name)
            let link = Sketches.link(toFile: name, fromNote: path, folder: Pictures.droppedFolder, alt: "Picture")
            let put = Sketches.inserting(link: link, into: result, at: at)
            result = put.text
            at = put.cursor
        }
        text = result
    }

    /// Build 293 (Mac): a picture pasted with ⌘V, saved as a PNG in the Pictures folder and
    /// put on its own line where the cursor was.
    private func pastePicture(_ data: Data, ext: String, at offset: Int) {
        guard let vault = model.vault else { return }
        let folder = vault.rootURL.appendingPathComponent(Pictures.droppedFolder)
        let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let name = Pictures.freeName(for: Pictures.pastedName(ext: ext), taken: taken)
        do {
            try vault.writeFile(data, at: Pictures.droppedFolder + "/" + name)
        } catch {
            model.errorMessage = "The picture could not be saved: \(error.localizedDescription)"
            return
        }
        let link = Sketches.link(toFile: name, fromNote: path, folder: Pictures.droppedFolder, alt: "Picture")
        text = Sketches.inserting(link: link, into: text, at: min(offset, (text as NSString).length)).text
    }

    /// Build 289: where a photo goes, and which way it is coming.
    @State private var photoOffset = 0
    @State private var takingPhoto = false
    @State private var choosingPhoto = false
    #if os(iOS)
    @State private var chosenPhoto: PhotosPickerItem?
    #endif

    /// A photo into the Photos folder (a JPEG, longest side 2048) and its line where the
    /// cursor was.
    private func savePhoto(_ jpeg: Data) {
        guard let vault = model.vault else { return }
        let fileName = Pictures.newPhotoName()
        do {
            try vault.writeFile(jpeg, at: Pictures.photoFolder + "/" + fileName)
        } catch {
            model.errorMessage = "The photo could not be saved: \(error.localizedDescription)"
            return
        }
        let link = Sketches.link(toFile: fileName, fromNote: path, folder: Pictures.photoFolder, alt: "Photo")
        text = Sketches.inserting(link: link, into: text, at: min(photoOffset, (text as NSString).length)).text
    }

    /// Done on the drawing page: the picture and drawing written into the Sketches folder,
    /// and for a new sketch its line put where the cursor was.
    private func saveSketch(_ request: SketchRequest, png: Data, drawing: Data) {
        guard let vault = model.vault else { return }
        let fileName = request.picturePath.map { ($0 as NSString).lastPathComponent } ?? Sketches.newFileName()
        let picture = request.picturePath ?? Sketches.folder + "/" + fileName
        do {
            try vault.writeFile(png, at: picture)
            try vault.writeFile(drawing, at: Sketches.drawingPath(for: picture))
        } catch {
            model.errorMessage = "The sketch could not be saved: \(error.localizedDescription)"
            return
        }
        sketchVersion += 1
        // Build 296: a sketch drawn on again has new words; the note's text did not change,
        // so nothing else would read them.
        model.readPicturesSoon()
        guard request.picturePath == nil else { return }
        let put = Sketches.inserting(link: Sketches.link(toFile: fileName, fromNote: path),
                                     into: text, at: request.offset ?? (text as NSString).length)
        text = put.text
    }

    /// Build 296: Show words — the picture's words as a quote under it, read now if need be.
    private func showWords(of picture: String, at offset: Int) {
        Task {
            guard let words = await model.pictureWords(picture) else {
                model.flash("No words found in this picture")
                return
            }
            text = Pictures.showingWords(words, in: text, linkAt: offset)
        }
    }

    /// Build 298: Make tasks — each line of the picture's words as an open task under it.
    private func makeTasks(of picture: String, at offset: Int) {
        Task {
            guard let words = await model.pictureWords(picture) else {
                model.flash("No words found in this picture")
                return
            }
            text = Pictures.makingTasks(words, in: text, linkAt: offset)
            model.flash("Tasks made")
        }
    }

    /// Raised after a save so the row under the text loads the new picture.
    @State private var sketchVersion = 0

    /// The markdown itself: the raw text, or the rendered version.
    private func editorPane(scrolls: Bool) -> some View {
        editorColumns(scrolls: scrolls)
            .alert("Caption", isPresented: Binding(get: { captionEdit != nil },
                                                   set: { if !$0 { captionEdit = nil } })) {
                TextField("Words under the picture", text: $captionDraft)
                    .accessibilityIdentifier("caption.field")
                Button("Cancel", role: .cancel) { captionEdit = nil }
                Button("Save") { saveCaption() }
                    .keyboardShortcut(.defaultAction)
            } message: {
                Text("Shown in small words under the picture. Leave it empty for none.")
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $takingPhoto) {
                CameraPicker { image in if let jpeg = PhotoFile.jpeg(from: image) { savePhoto(jpeg) } }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $choosingPhoto, selection: $chosenPhoto, matching: .images)
            .onChange(of: chosenPhoto) { _, item in
                guard let item else { return }
                chosenPhoto = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data), let jpeg = PhotoFile.jpeg(from: image) {
                        savePhoto(jpeg)
                    }
                }
            }
            #endif
    }

    private func editorColumns(scrolls: Bool) -> some View {
        HStack(spacing: 0) {
            if mode != .preview {
                MarkdownSyntaxEditor(text: $text, tint: note?.tint ?? Theme.fallbackTint,
                                     linkDraft: $linkDraft, completion: $linkCompletion,
                                     openLink: { model.openWikiLink($0, from: path) },
                                     onLinkKey: handleLinkKey,
                                     scrolls: scrolls,
                                     pictures: pictureHooks)
                    .onChange(of: text) { _, newValue in
                        scheduleSave(newValue)
                    }
                    // The list of titles sits over the editor, under the caret.
                    .overlay(alignment: .topLeading) { linkSuggestions }
                    .onChange(of: linkDraft) { _, _ in linkChoice = 0 }
            }
            if mode != .edit, let note {
                MarkdownPreview(note: note, beforeToggle: flushSave)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// What `[[` offers: the titles this note may link to, closest match first.
    private var linkTitles: [String] {
        guard let draft = linkDraft?.draft else { return [] }
        return WikiLinks.suggestions(for: draft.query, among: model.linkableTitles(from: path))
    }

    /// The arrow keys, Return and Escape while the list is up. They arrive from the text view,
    /// which has the focus; returning false lets the keystroke do its ordinary job.
    private func handleLinkKey(_ key: LinkKey) -> Bool {
        guard let draft = linkDraft?.draft, !linkTitles.isEmpty else { return false }
        switch key {
        case .down:
            linkChoice = min(linkChoice + 1, linkTitles.count - 1)
        case .up:
            linkChoice = max(linkChoice - 1, 0)
        case .enter:
            guard linkTitles.indices.contains(linkChoice) else { return false }
            linkCompletion = LinkCompletion(draft: draft, title: linkTitles[linkChoice])
        case .escape:
            linkDraft = nil
        }
        return true
    }

    @ViewBuilder
    private var linkSuggestions: some View {
        if let linkDraft, !linkTitles.isEmpty {
            // Inside the editor, whatever the cursor is doing: below the line when there is
            // room, above it when the cursor is near the bottom, and never off the right edge.
            // Build 114 put it under the caret and let it fall off the bottom (build 115).
            GeometryReader { geo in
                let height = min(CGFloat(linkTitles.count) * 30 + 10, 250)
                let below = linkDraft.caret.y + linkDraft.lineHeight + 4
                let fits = below + height <= geo.size.height
                let y = fits ? below : max(linkDraft.caret.y - height - 4, 0)
                WikiLinkList(titles: linkTitles, choice: $linkChoice, tint: note?.tint ?? Theme.fallbackTint,
                             kindFor: { model.index.note(matching: $0)?.kind ?? model.note(at: path)?.kind ?? .resource },
                             pick: { title in linkCompletion = LinkCompletion(draft: linkDraft.draft, title: title) })
                    .frame(width: min(320, max(geo.size.width - 24, 160)))
                    .offset(x: min(max(linkDraft.caret.x - 6, 8), max(geo.size.width - 328, 8)),
                            y: min(max(y, 0), max(geo.size.height - height, 0)))
            }
            .zIndex(10)
        }
    }

    /// Build 316: the bar is the row it always was, and under it — only while date words are
    /// read in the field ("tomorrow 14:00") — the chip that says what was understood.
    private var addTaskBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            addTaskRow
            // Round 9 (build 316): the chip starts where the field starts (on the iPhone the
            // Edit button stands before the field), in the note's own colour.
            HStack(spacing: 8) {
                if isPhone {
                    Color.clear.frame(width: 30, height: 1)
                }
                PlainDateChip(text: newTask, ignored: $ignoredDateWords,
                              tint: note?.tint ?? Theme.fallbackTint)
            }
        }
        .padding(8)
    }

    private var addTaskRow: some View {
        HStack(spacing: 8) {
            // Which mode you are in used to be a Picker three taps deep in the ⋯ menu, and a
            // note left in Preview looks exactly like an editor that refuses to type — it
            // cost a day to work that out (build 127). One button, always on screen.
            //
            // Build 142 stopped swapping the symbol. It was an eye in Edit and a pencil in
            // Read — the thing you would get, not the thing you are in — and an eye reads
            // just as easily as "you are reading now". It is always a pencil now, lit while
            // Edit is on. No Split on the phone: he asked for it gone.
            if isPhone {
                StateToggle(markName: "pencil", title: "Edit", isOn: mode == .edit,
                            tint: note?.tint ?? Theme.fallbackTint) {
                    mode = mode == .edit ? .preview : .edit
                }
            }
            // Three words, not eighty-four characters. What can be typed here moved behind
            // the ⓘ: the old placeholder was cut off after "for a" on the phone, and it
            // vanished the moment he started typing anyway.
            // Round 9 (build 316): on the iPhone the app's own field (surface and hairline);
            // Apple's rounded field was a pure black box at night.
            TextField("Add a task…", text: $newTask)
                .modifier(DateFieldLook(isPhone: isPhone))
                .focused($addFieldFocused)
                .onSubmit(addTask)
            TaskSyntaxButton()
            if isPhone {
                // The phone has no room for two words beside the field. Both become symbols.
                // Round 9 (build 316): the send arrow keeps its full colour while the field
                // is empty (it was pale); pressed with nothing typed it puts the cursor in
                // the field. The same on the Mac's and the iPad's **Add**.
                snippetMenu(iconOnly: true)
                Button(action: pressAdd) {
                    MarkImage("arrow.up.circle.fill", size: 26)
                        .foregroundStyle(ParaKind.project.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add")
                .accessibilityIdentifier("note.addTask.send")
            } else {
                Button("Add", action: pressAdd)
                    .buttonStyle(.filled(ParaKind.project.tint))
                snippetMenu(iconOnly: false)
            }
        }
    }

    private var canAdd: Bool { !newTask.trimmingCharacters(in: .whitespaces).isEmpty }

    private func snippetMenu(iconOnly: Bool) -> some View {
        Menu {
            ForEach(model.snippets) { snippet in
                Button(snippet.name) { start(snippet) }
            }
        } label: {
            if iconOnly {
                MarkLabel("Snippet", "text.append")
                    .labelStyle(.iconOnly)
            } else {
                MarkLabel("Snippet", "text.append")
            }
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.snippets.isEmpty)
        .help("Add a ready-made block of tasks. Edit them in Templates › Snippets.")
    }

    /// A snippet with nothing to ask goes straight in; otherwise the sheet collects the
    /// words it wants first.
    private func start(_ snippet: Snippet) {
        guard !snippet.questions.isEmpty else {
            model.insert(snippet, answers: [:], into: path)
            return
        }
        snippetToFill = snippet
    }

    /// The notes this one points at: its `goal`/`area`/`parent`/`related` lines and its
    /// `[[links]]`.
    private func notesLinkedTo(from note: Note) -> [Note] {
        let index = model.index
        var seen = Set<String>()
        var result: [Note] = []
        for title in note.outgoingReferences + WikiLinks.titles(in: note.text) {
            guard let candidate = index.note(matching: title) ?? model.workNote(titled: title, near: note) else { continue }
            guard candidate.relativePath != note.relativePath,
                  seen.insert(candidate.relativePath).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    /// The `[[links]]` in this note that name no note yet. Shown as their own short list,
    /// because a link to something not written yet is a to-do, not a mistake.
    private func missingLinks(from note: Note) -> [String] {
        // While notes are still coming from iCloud, "there is no such note" is not something
        // this app is entitled to say (build 100). Say nothing rather than something wrong.
        guard model.notesWaitingForCloud.isEmpty else { return [] }
        let index = model.index
        var seen = Set<String>()
        var result: [String] = []
        for title in WikiLinks.titles(in: note.text) {
            guard index.note(matching: title) == nil,
                  model.workNote(titled: title, near: note) == nil,
                  seen.insert(title.lowercased()).inserted else { continue }
            result.append(title)
        }
        return result
    }

    /// The notes that point at this one.
    private func notesLinking(to note: Note) -> [Note] {
        var seen = Set<String>()
        var result: [Note] = []
        for candidate in model.backlinks(to: note) {
            guard candidate.relativePath != note.relativePath,
                  seen.insert(candidate.relativePath).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    private func scheduleSave(_ newValue: String) {
        guard newValue != displayText else {
            // Back to exactly what the file holds: ⌘Z straight after typing, ⇧⌘Z straight
            // after ⌘Z, or a letter typed and deleted. The save still waiting from the last
            // key would write the older text over it, and the screen would never show it
            // (build 252).
            pendingSave?.cancel()
            pendingSave = nil
            isDirty = false
            return
        }
        isDirty = true
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            write(newValue)
        }
    }

    private func flushSave() {
        pendingSave?.cancel()
        pendingSave = nil
        if isDirty { write(text) }
    }

    /// Puts the hidden markers and the folded block back and saves.
    private func write(_ shown: String) {
        lastWritten = shown
        // `baseText` is the version this typing started from. While he types it is not moved
        // on by a reload (`onChange(of: storedText)` leaves a dirty editor alone), so the save
        // can tell that the note changed under him (premium review, hardening-03).
        let outcome = model.saveText(wholeText(from: shown, folded: frontmatterFolded), forNoteAt: path, startedFrom: baseText)
        isDirty = false
        baseText = model.note(at: path)?.text ?? baseText
        if outcome == .replaced, let now = model.note(at: path)?.text {
            // The note changed on the other device meanwhile: it now holds both changes put
            // together, or the other version (this one is kept as a copy beside it). Shown
            // here and now, before another key — typing on over the old screen would save a
            // text that knows nothing of the other change, as if it had been deleted.
            lastWritten = nil
            let merged = shownText(from: now, folded: frontmatterFolded)
            if merged != text { text = merged }
        }
    }

    /// The button beside **Add a task…**: adds the line, or — with nothing typed — puts the
    /// cursor in the field (round 9, build 316).
    private func pressAdd() {
        guard canAdd else {
            addFieldFocused = true
            return
        }
        addTask()
    }

    private func addTask() {
        // Return on the empty field adds nothing (and, on the iPhone, closes the keyboard).
        guard canAdd else { return }
        flushSave()
        // Build 316: date words that were read ("tomorrow 14:00") are saved as the date mark.
        model.addTask(PlainDateChip.line(newTask, ignoring: ignoredDateWords), to: path)
        newTask = ""
        ignoredDateWords = nil
    }
}

/// A project's deadline, set from the note header. The review checks a project against its
/// goal's target date, and against today — neither could ever fire while `due:` was a line
/// only a text editor could write.
struct ProjectDeadlineChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            MarkLabel(note.dueDate.map { "Due \(DayWords.plain($0))" } ?? "Set a deadline\u{2026}", "calendar")
        }
        .buttonStyle(.bordered)
        .foregroundStyle(note.dueDate == nil ? Theme.soft : ParaKind.project.tint.ink)
        .help("When this project has to be finished. The weekly review compares it with the goal it serves.")
        .popover(isPresented: $picking) {
            DateChoiceView(current: note.dueDate,
                           clearTitle: note.dueDate == nil ? nil : "Clear",
                           cancel: { picking = false }) { chosen in
                model.setDeadline(note, chosen)
                picking = false
            }
        }
    }
}

/// A goal's target date, set from the goal itself (build 268). Until this build `target:` was
/// written only when a goal was made, so a goal's date could not be moved from the app, though
/// the Goals list, the chain and the weekly review all read it.
///
/// **One view, two looks, chosen by a Bool** (`CalendarEventRow(compact:)`, build 212): a label
/// in a note's header, where the deadline is a label too, or a capsule on the Goals screen's
/// chain page, where every fact about the goal is one. Never a closure handed in for the face:
/// that is where Swift's inference has given up before (builds 152, 154). On the chain page a
/// set date is solid and a missing one grey and dashed (build 142).
struct GoalTargetChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    var onChainPage: Bool = false
    @State private var picking = false

    /// Read back out of the model: a chip beside this one may have just saved and reloaded the
    /// note, and the copy handed in is then one behind (build 144).
    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let current = live
        let target = current.targetDate
        Button { picking = true } label: {
            face(target, ended: current.isEnded)
                .helpWhenClosed("The day this goal should be reached by. The weekly review compares it with today and with the deadlines of the projects under the goal.",
                                open: picking)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(Self.spoken(target)))
        .accessibilityIdentifier("goal.target")
        .popover(isPresented: $picking) {
            DateChoiceView(current: target,
                           clearTitle: target == nil ? nil : "Clear",
                           cancel: { picking = false }) { chosen in
                model.setTarget(current, chosen)
                picking = false
            }
        }
    }

    @ViewBuilder
    private func face(_ target: DateOnly?, ended: Bool) -> some View {
        if onChainPage {
            if let target {
                ChainChip(text: Self.words(for: target, withTimeLeft: true),
                          tint: Self.color(for: target, ended: ended), filled: false)
            } else {
                ChainChip(text: "Set a target date\u{2026}", tint: .secondary, filled: false, dashed: true)
            }
        } else {
            MarkLabel(Self.headerWords(target), "flag.checkered")
                .foregroundStyle(Self.color(for: target, ended: ended))
        }
    }

    /// "Target 2027-08-15 · in about 10 months" on the chain page, where the date alone never
    /// says whether it is close (build 163); "Target 2027-08-15" in a header, beside the other
    /// short facts. The one place both are spelled, so the goals drawn inside an aspiration's
    /// chain, which carry no button, say it the same way.
    static func words(for target: DateOnly, withTimeLeft: Bool) -> String {
        guard withTimeLeft else { return "Target \(DayWords.plain(target))" }
        let left = target.timeLeftText(from: DateOnly.today())
        return "Target \(DayWords.plain(target)) · \(left)"
    }

    /// What the header's label says. Written out as a function returning `String`, never an
    /// optional's `map` with a string literal inside: `Label` and `Text` also take a
    /// `LocalizedStringKey`, and there is no compiler here to settle which one is meant.
    private static func headerWords(_ target: DateOnly?) -> String {
        guard let target else { return "Set a target date\u{2026}" }
        return words(for: target, withTimeLeft: false)
    }

    /// What a screen reader says, and what the screen test reads.
    private static func spoken(_ target: DateOnly?) -> String {
        guard let target else { return "Set a target date" }
        return "Target \(DayWords.plain(target))"
    }

    /// Grey when no date is set, orange when the date has passed on a goal that is still
    /// running, the goal's gold otherwise.
    static func color(for target: DateOnly?, ended: Bool) -> Color {
        guard let target else { return Color.secondary }
        if !ended && target < DateOnly.today() { return Theme.attention.ink }
        return ChainTint.datedGoal
    }
}

/// A goal's measure: one line that says how you will know the goal is reached (build 268).
/// **Nothing in the app wrote `measure:` before this build**, though the Goals list, the chain
/// and the aspiration's page all read it — the fault of `due:` (132), an area's `goal:` (134),
/// a project's `goal:` (140), `tags:` (144) and `status:` (165), in a sixth place.
///
/// The same two looks as `GoalTargetChip`. The words can be long, so they are cut in the middle
/// at 260 points, as the name chip is (build 250): a wrapping row measures each item at its
/// natural width, and a long measure would otherwise be wider than the column on its own line.
struct GoalMeasureChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    var onChainPage: Bool = false
    @State private var editing = false

    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let current = live
        let measure = current.measure
        Button { editing = true } label: {
            face(measure, tint: ChainTint.forGoal(current))
                .helpWhenClosed("How you will know this goal is reached, in one line.", open: editing)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(Self.spoken(measure)))
        .accessibilityIdentifier("goal.measure")
        .popover(isPresented: $editing) {
            // The box stays open when the measure was changed while it stood open (review of
            // 271): `setMeasure` then wrote nothing, and the editor says what it is now.
            GoalMeasureEditor(current: measure, cancel: { editing = false }) { (text: String, started: String?) -> AppModel.MeasureChangedMeanwhile? in
                let changed = model.setMeasure(text, on: current, startedFrom: started)
                if changed == nil { editing = false }
                return changed
            }
        }
    }

    @ViewBuilder
    private func face(_ measure: String?, tint: Color) -> some View {
        if onChainPage {
            if let measure {
                ChainChip(text: Self.words(measure), tint: tint, filled: false)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .leading)
            } else {
                ChainChip(text: "Set a measure\u{2026}", tint: .secondary, filled: false, dashed: true)
            }
        } else {
            MarkLabel(Self.words(measure), "ruler")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
                .foregroundStyle(measure == nil ? Theme.soft : tint.ink)
        }
    }

    /// "Measure: All 440 km in 30 days", or **Set a measure…** when there is none. A function
    /// returning `String` rather than a `map` with a literal inside, for the reason given at
    /// `GoalTargetChip.headerWords`.
    private static func words(_ measure: String?) -> String {
        guard let measure else { return "Set a measure\u{2026}" }
        return "Measure: \(measure)"
    }

    /// What a screen reader says, and what the screen test reads.
    private static func spoken(_ measure: String?) -> String {
        guard let measure else { return "Set a measure" }
        return "Measure: \(measure)"
    }
}

/// What **Set a measure…** opens: a heading, one sentence, one line to write in, and **Clear**,
/// **Cancel** and **Set**. Return sets, as **Set** does. A small popover on the phone too, the
/// way the tag list is (`TagChoices`), rather than a whole sheet for one line — and it hangs
/// under the note's header, near the top of the screen, so the keyboard does not cover **Set**
/// (builds 160 and 231).
///
/// **A measure changed while the box stood open is never replaced unseen** (review of 271, the
/// rule of the week goal box, 264). The box remembers the measure it opened on and hands it on
/// with the words; when the note holds another one by then, nothing is written, the box stays
/// open with his words, and an orange line says what the measure is now. A second press then
/// replaces it on purpose.
struct GoalMeasureEditor: View {
    let current: String?
    let cancel: () -> Void
    /// The words to store, and the measure the box started from. An empty string clears the
    /// measure. The answer is nil when it was written, or what the measure says now when it was
    /// changed while the box stood open.
    let choose: (String, String?) -> AppModel.MeasureChangedMeanwhile?

    @State private var typed = ""
    /// The measure the box showed when it opened. After a refusal it is what the note holds
    /// now: he has just been told what it says, so the next press replaces it on purpose.
    @State private var startedFrom: String? = nil
    /// Why the last press wrote nothing. Said inside the popover, never in an alert over it: a
    /// popover's messages belong in the popover (build 238).
    @State private var notice: String? = nil
    @FocusState private var focused: Bool

    /// What would be stored, by the same rule `GoalFields` stores it with (Core, tested).
    private var cleaned: String { GoalFields.cleaned(typed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Measure")
                .font(Txt.label.weight(.semibold))
            Text("One line that says how you will know this goal is reached.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
            TextField("All 440 km in 30 days", text: $typed)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(set)
                .accessibilityIdentifier("measure.field")
            if let notice {
                Text(notice)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("measure.notice")
            }
            HStack {
                if current != nil {
                    Button("Clear", role: .destructive) { write("", clearing: true) }
                        .accessibilityIdentifier("measure.clear")
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .accessibilityIdentifier("measure.cancel")
                Button("Set", action: set)
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleaned.isEmpty)
                    .accessibilityIdentifier("measure.set")
            }
        }
        .padding(14)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        .onAppear {
            typed = current ?? ""
            startedFrom = current
            notice = nil
            // Focus does not always take in the turn the popover appears (build 119).
            DispatchQueue.main.async { focused = true }
        }
    }

    /// An empty line does nothing here: **Clear** is the way to take a measure away, so a
    /// Return in an emptied field cannot do it by accident.
    private func set() {
        guard !cleaned.isEmpty else { return }
        write(cleaned, clearing: false)
    }

    /// Hands the words on with the measure the box started from. When nothing was written
    /// because the measure changed meanwhile, the box keeps his words and says what it is now.
    private func write(_ value: String, clearing: Bool) {
        guard let changed = choose(value, startedFrom) else { return }
        startedFrom = changed.onFile
        notice = Self.message(onFile: changed.onFile, clearing: clearing)
    }

    /// The orange line after a refusal. **Clear** never meets a removed measure: clearing what
    /// is already gone is not a refusal, so only **Set** gets that sentence.
    private static func message(onFile: String?, clearing: Bool) -> String {
        guard let onFile else {
            return "The measure was removed on your other device. Press Set again to use your words."
        }
        let what = "The measure was changed on your other device to \u{201C}\(onFile)\u{201D}."
        if clearing {
            return what + " Press Clear again to take it away."
        }
        return what + " Press Set again to use your words instead."
    }
}

/// The calm line under a finished project's header (build 262): "Done on 20 October · after
/// 41 days · 17 tasks finished". The words come from `ProjectEnding` in Core, so this view
/// assembles nothing (build 58). Pressing the line changes the day; Set active or Put on hold
/// in the status chip is what takes it away, so the date box has no clearing button.
///
/// **A project that ended before build 262 has no day**, and then the line is a dashed grey
/// **Set the day it ended…** — build 142's "not set" look — never a guessed date. It sits
/// outside `NoteHeader`'s wrapping row on purpose: a sentence among chips wraps badly
/// (build 250), and the whole line is the button, so the Mac's accessibility frame is the
/// line and not a short word beside a gap (build 247).
struct ProjectEndedLine: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var picking = false

    var body: some View {
        // Read back out of the model: a change saves and reloads, so the note handed in may be
        // one behind (build 144).
        let live = model.note(at: note.relativePath) ?? note
        let words = sentence(for: live)
        Button { picking = true } label: {
            face(for: live, words: words)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(words ?? "Set the day it ended"))
        .accessibilityIdentifier("project.ended")
        .help("The day this project ended. Press to change it.")
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .popover(isPresented: $picking) {
            DateChoiceView(current: live.endedDate ?? DateOnly.today(),
                           cancel: { picking = false }) { chosen in
                if let chosen { model.setEndedDate(chosen, on: live) }
                picking = false
            }
        }
    }

    private func sentence(for live: Note) -> String? {
        ProjectEnding(note: live)?.line(today: DateOnly.today())
    }

    @ViewBuilder
    private func face(for live: Note, words: String?) -> some View {
        let status = live.noteStatus
        if let words {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                MarkImage(status.markName)
                    .foregroundStyle(status.tint(onNote: live.tint))
                Text(words)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(Txt.label)
        } else {
            MarkLabel("Set the day it ended\u{2026}", status.markName, text: .footnote)
                .font(Txt.label)
                .foregroundStyle(.soft)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(Color.secondary,
                                                style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        }
    }
}

struct NoteHeader: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    /// Renames the note. Nil for the Inbox and for daily notes, whose names are not theirs to
    /// change. Build 154 put it here: the name is a fact about the note like its goal, its tags
    /// and its deadline, and every one of those is changed by pressing it where it is shown.
    var rename: (() -> Void)? = nil

    private func listName(for note: Note) -> String {
        switch note.kind {
        case .inbox: return model.config.inboxListName
        case .daily: return model.config.dailyNotesListName
        default: return note.remindersListName
        }
    }

    /// The word at the start of the header. A goal note says which of the two it is —
    /// **Goal with a date** or **Aspiration** (build 268) — where it used to say "Goals", the
    /// name of the list rather than of the note, and the same for both kinds.
    private func kindWord(for note: Note) -> String {
        switch note.kind {
        case .daily: return "Daily note"
        case .goal: return GoalWording.name(for: note)
        case .project: return "Project"
        case .area: return "Area"
        case .resource: return "Resource"
        case .archive: return "Archived"
        case .inbox: return "Inbox"
        }
    }

    /// **Icon…** for the kinds `ParaKind.takesIcon` names, the very rule `AppModel.setIcon`
    /// asks (build 168). A work note is a resource by kind but gets no button: `setIcon` would
    /// refuse it, and a button that does nothing is worse than none (build 175).
    private func showsIconChip(for note: Note) -> Bool {
        note.kind.takesIcon && !model.isWorkNote(note)
    }

    /// A goal with a date, as opposed to an aspiration. Only this kind has a target date and
    /// serves something above it.
    private func isDatedGoal(_ note: Note) -> Bool {
        note.kind == .goal && !GoalWording.isAspiration(note)
    }

    /// 1.0: the title at 26 pt above, and under it the **facts panel** in the note's colour —
    /// the heading says what kind of note this is, and every fact is either a bordered control
    /// (a pop-up or a button that opens a small window) or a plain value. The twelve chips of
    /// build 250 are the same twelve facts; only how they are drawn changed. Nothing was taken
    /// away.
    /// True on a short Mac column: the same title and the same facts, drawn small and without
    /// the panel, so the text under them keeps room. Nothing is left out.
    var compact = false
    /// False on the goal and aspiration pages, which lay their own gutter round the whole page.
    var inset = true
    /// A goal's roll-up, handed in by its page (1.0): the header holds one note and cannot work
    /// the per cent out itself (`NoteRow` takes it the same way).
    var progress: GoalProgress? = nil
    /// Short orange notices for the panel — "Target date passed", "No project delivers this" —
    /// the flags the goal pages used to draw as chips.
    var notices: [String] = []

    var body: some View {
        if compact {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(kindWord(for: note))
                        .font(Txt.label)
                        .foregroundStyle(note.tint.ink)
                    if showsIconChip(for: note) {
                        NoteIconChip(model: model, note: note)
                    }
                    Spacer(minLength: 0)
                }
                titleRow
                // One row that scrolls sideways, never three or four rows of wrapped chips: on
                // the test runners' 900×450 window the wrapped rows left the tasks and the text
                // no room (build 280's fourth Mac run).
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        factItems
                    }
                    .padding(.vertical, 2)
                }
                .font(Txt.value)
                .lineLimit(1)
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .tint(note.tint)
                .controlSize(.small)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("note.facts")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                // Build 282, the band: the title in white on the note's colour, with the
                // note's one number under it. Edge to edge where the header lays its own
                // gutter; a rounded band on the goal pages, which lay theirs round the page.
                VStack(alignment: .leading, spacing: 2) {
                    titleRow
                    bandLine
                }
                .band(note.tint, inset: inset ? Theme.gutter : Theme.panelPad,
                      radius: inset ? 0 : Theme.panelRadius)
                VStack(alignment: .leading, spacing: Theme.headGap) {
                    HStack(spacing: 8) {
                        Heading(text: kindWord(for: note), color: note.tint)
                        if showsIconChip(for: note) {
                            NoteIconChip(model: model, note: note)
                        }
                        Spacer(minLength: 0)
                    }
                    facts
                }
                .panel(note.tint)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("note.facts")
                .padding(.horizontal, inset ? Theme.gutter : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
        }
    }

    /// A daily or weekly note's title is a date ("Monday 9 November 2026"), and a date cut in
    /// two reads wrong; the reviewer of 280 saw the 26-point date wrap in the Calendar's column.
    /// So a date keeps one line and shrinks a little in a narrow column (build 281); any other
    /// title wraps to two lines as before, since a name has no such seam.
    /// The band's number (build 282): a goal's per cent of the way, any other note's open
    /// tasks. A note with no tasks says only what kind it is.
    @ViewBuilder
    private var bandLine: some View {
        let tasks = note.tasks
        let open = tasks.filter { !$0.isDone }.count
        if let fraction = progress?.fraction {
            BandNumber(number: "\(Int((fraction * 100).rounded())) %",
                       words: note.targetDate.map { "of the way · Target \(DayWords.plain($0))" } ?? "of the way",
                       identifier: "note.band")
        } else if !tasks.isEmpty {
            BandNumber(number: "\(open)",
                       words: "open \(open == 1 ? "task" : "tasks") · \(tasks.count - open) of \(tasks.count) done",
                       identifier: "note.band")
        } else {
            // Build 290: the panel under the band already says the kind; the band says
            // something new — how far a daily note's day is from today.
            Text(note.dailyDate.map { DayDistance.words(from: $0, to: .today()) } ?? "No tasks yet")
                .font(Txt.label)
                .foregroundStyle(.white)
                .accessibilityIdentifier("note.band")
        }
    }

    private var titleLines: Int { note.kind == .daily ? 1 : 2 }
    private var titleShrink: CGFloat { note.kind == .daily ? 0.7 : 1 }

    /// The name, big. Pressing it renames the note where that is allowed (build 154).
    @ViewBuilder
    private var titleRow: some View {
        if let rename {
            Button(action: rename) {
                Text(note.displayTitle)
                    .font(compact ? Txt.sectionTitle : Txt.pageTitle)
                    .foregroundStyle(compact ? Color.primary : Color.white)
                    .lineLimit(titleLines)
                    .minimumScaleFactor(titleShrink)
                    .multilineTextAlignment(.leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Press to rename this note. The file is renamed too, and links to it follow.")
            .accessibilityIdentifier("note.title")
        } else {
            Text(note.displayTitle)
                .font(compact ? Txt.sectionTitle : Txt.pageTitle)
                .foregroundStyle(compact ? Color.primary : Color.white)
                .lineLimit(titleLines)
                .minimumScaleFactor(titleShrink)
                .accessibilityIdentifier("note.title")
        }
    }

    /// A plain fact: a small label in soft grey, the value beside it at text size — one
    /// line, level with the buttons next to it (build 290; it used to sit under the label).
    private func fact(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label).font(Txt.label).foregroundStyle(Theme.soft)
            Text(value).font(Txt.value).foregroundStyle(tint ?? Color.primary)
        }
    }

    /// The facts, as a row that wraps (build 250's reason stands: an `HStack` of things that
    /// will not shrink makes its width the column's smallest width).
    private var facts: some View {
        WrappingHStack(spacing: 10, lineSpacing: 8) {
            factItems
        }
        .font(Txt.value)
        .lineLimit(1)
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .tint(note.tint)
    }

    /// The facts themselves, in their one order; `facts` wraps them and the compact header
    /// puts them in a row.
    @ViewBuilder
    private var factItems: some View {
            if note.kind != .inbox, note.kind != .daily {
                NoteStatusChip(model: model, note: note)
            }
            if note.kind == .project {
                ProjectAreaChip(model: model, note: note)
            } else if let area = note.area {
                fact("In area", area, tint: ParaKind.area.tint)
            }
            if note.kind == .area {
                AreaParentChip(model: model, note: note)
            }
            if note.kind == .area || note.kind == .project || isDatedGoal(note) {
                NoteGoalChip(model: model, note: note)
            } else if let goal = note.goal {
                Button { model.openGoal(reference: goal) } label: {
                    fact("Serves", goal, tint: ChainTint.forGoal(named: goal, in: model.index))
                }
                .buttonStyle(.plain)
            }
            if isDatedGoal(note) {
                GoalHorizonChip(model: model, note: note)
                GoalTargetChip(model: model, note: note)
            } else if let target = note.targetDate {
                fact("Target", target.description)
            }
            if let progress, let percent = progress.percent {
                fact("Progress", "\(percent) %", tint: ChainTint.forGoal(note))
            }
            if note.kind == .goal {
                GoalMeasureChip(model: model, note: note)
            }
            if isDatedGoal(note) {
                // Build 318: a number to track, beside the measure's words.
                GoalNumberChip(model: model, note: note)
            }
            if note.kind == .goal || note.kind == .area {
                LookedAtChip(model: model, note: note)
            }
            if note.kind == .project {
                ProjectDeadlineChip(model: model, note: note)
            } else if let due = note.dueDate {
                fact("Due", due.description)
            }
            if note.kind != .inbox {
                NoteTagsChip(model: model, note: note)
            }
            if note.kind.isTaskKind {
                fact("Reminders list:", note.isSyncEnabled && !note.isArchived ? listName(for: note) : "Not synced")
            }
            ForEach(notices, id: \.self) { notice in
                Pill(text: notice, color: Theme.attention)
            }
    }
}

struct TaskChecklist: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let beforeToggle: () -> Void
    @State private var subtaskParent: TaskItem?
    @State private var subtaskTitle = ""

    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false

    /// The tasks to draw. Finished ones can be hidden, but never one that still has open
    /// work under it: a done parent with an open subtask stays, or the subtask would vanish.
    var visibleTasks: [TaskItem] {
        guard hideFinishedTasks else { return note.tasks }
        let tasks = note.tasks
        var keep = [Bool](repeating: true, count: tasks.count)
        for (i, task) in tasks.enumerated() where task.isDone {
            var hasOpenDescendant = false
            var j = i + 1
            while j < tasks.count, tasks[j].indentLevel > task.indentLevel {
                if !tasks[j].isDone { hasOpenDescendant = true; break }
                j += 1
            }
            keep[i] = hasOpenDescendant
        }
        return zip(tasks, keep).compactMap { $1 ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(visibleTasks, id: \.lineIndex) { task in
                TaskRow(ref: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task), showNote: false,
                        onAddSubtask: { subtaskTitle = ""; subtaskParent = task }) {
                    beforeToggle()
                    model.toggle(TaskRef(notePath: note.relativePath, noteTitle: note.title, task: task))
                }
                .padding(.leading, CGFloat(task.indentLevel) * 14)
            }
        }
        .padding(.top, 4)
        .alert("New subtask", isPresented: Binding(get: { subtaskParent != nil }, set: { if !$0 { subtaskParent = nil } })) {
            TextField("Subtask", text: $subtaskTitle)
            Button("Add") {
                if let parent = subtaskParent {
                    beforeToggle()
                    model.addSubtask(subtaskTitle, to: TaskRef(notePath: note.relativePath, noteTitle: note.title, task: parent))
                }
                subtaskParent = nil
            }
            Button("Cancel", role: .cancel) { subtaskParent = nil }
        } message: {
            Text(subtaskParent.map { "Under \"\($0.title)\". It syncs to Reminders as \"\($0.title) › …\"." } ?? "")
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var model: AppModel
    /// False inside the two day sheets and the Mac's planner window, where no timer bar is
    /// drawn: Focus on this is then left out of both the time list and the menu (build 256).
    @Environment(\.focusBarShown) private var focusBarShown
    let ref: TaskRef
    let showNote: Bool
    /// Where the row is drawn (build 312, flow-19): only **Start the day** and **Plan the day**
    /// ask "How long?" on a task without a time. Every other list leaves this alone.
    var place: TaskTimePill.Place = .list
    var onAddSubtask: (() -> Void)? = nil
    let toggle: () -> Void
    @State private var pickingDate = false
    /// **Who?** (build 279), opened by **Waiting for…** on the task menu.
    @State private var askingWho = false
    @State private var renaming = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    /// Tasks take the colour of the note they live in.
    private var tint: Color {
        model.note(at: ref.notePath)?.tint ?? Theme.fallbackTint
    }

    private var isNext: Bool { ref.task.tags.contains(Note.nextActionTag) }

    /// Mac (build 316): the pointer is over this row.
    @State private var hovering = false

    /// Whether the row draws its own **Focus on this** button (Mac, build 316): where a timer
    /// bar is shown, on a task that can be focused on, and not where the time button — which
    /// already holds Focus on this — is drawn.
    private var offersFocusButton: Bool {
        guard focusBarShown, !renaming, model.canFocus(on: ref) else { return false }
        return TaskTimePill.shown(in: place, minutes: ref.task.minutes, usesTaskTimes: useTaskTimes) == .nothing
    }

    /// Whether the small line under the title has anything to show.
    private var hasFacts: Bool {
        ref.task.priority > 0 || ref.task.dueDate != nil || ref.task.deadline != nil
            || ref.task.repeatRule != nil || showNote
    }

    /// The tick's state in words, for VoiceOver and the screen tests.
    private var tickState: String {
        if ref.task.status == .cancelled { return "cancelled" }
        return ref.task.isDone ? "done" : "not done"
    }

    /// The note's own symbol, not one grey page for everything: a goal is a star, a project a
    /// flag, an area the grid, a daily note a calendar. He asked what the two identical pages
    /// in the planner's Actions column were (build 153) — which is the question an icon that
    /// says nothing always gets. `declaredKind` reads `type:` first, so an archived project
    /// still shows as a project.
    private var noteSymbol: String {
        let kind = model.note(at: ref.notePath)?.declaredKind ?? .resource
        return SidebarSection.kind(kind).markName
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: toggle) {
                // 1.0: the circle is the size of the text (15) and sits in a 22-point box that
                // takes the press anywhere inside it — a stroked ring alone only took a press on
                // its line, which is what the first Mac run of build 280 found.
                MarkImage(ref.task.status == .cancelled ? "xmark.circle" : (ref.task.isDone ? "checkmark.circle.fill" : "circle"), size: 15)
                    .rowTint(ref.task.isDone ? Color.secondary : tint)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // For the screen tests (build 255): the tick a test presses to finish a task.
            .accessibilityIdentifier("task.tick.\(ref.task.title)")
            // What the circle shows, in words (build 268): a screen reader said only "button",
            // and a test could not tell a press that ticked from one that did nothing.
            .accessibilityValue(tickState)
            VStack(alignment: .leading, spacing: 2) {
                if renaming {
                    TextField("Task", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                        .onSubmit(commitRename)
                } else {
                    HStack(spacing: 6) {
                        Text(isNext ? Note.removingTag(Note.nextActionTag, from: ref.task.title) : ref.task.title)
                            .strikethrough(ref.task.isDone)
                            .foregroundStyle(ref.task.isDone ? .secondary : .primary)
                        if isNext && !ref.task.isDone {
                            Text("next")
                                .font(Txt.listSecond.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(tint.opacity(0.2), in: Capsule())
                                .rowTint(tint.capsuleWords)
                        }
                    }
                }
                // Round 9 (build 316): each fact keeps one line and its whole width; when the
                // row is full the facts move to a second line as whole pieces, and only the
                // project's name may shorten with "…". Before, one `HStack` squeezed them:
                // "Every / Mon, / Wed, Fri" on three lines and a name cut inside a word. Every
                // mark has 5 points to its words and 12 points to the next fact.
                if hasFacts {
                    WrappingHStack(spacing: RowFact.gap, lineSpacing: 2) {
                        if ref.task.priority > 0 {
                            Text(String(repeating: "!", count: ref.task.priority))
                                .lineLimit(1)
                                .fixedSize()
                                .rowTint(Theme.attention.ink)
                        }
                        if let due = ref.task.dueDate {
                            // The date and, since build 277 when the **At** line can write one, the
                            // time of day: `dueText` in Core is the one wording of it.
                            RowFact(ref.task.dueText ?? due.description, ref.task.dueTime == nil ? "calendar" : "clock")
                                // Build 316: with a deadline, late means past the deadline; a
                                // do-day that has gone by stays grey and the deadline's mark carries the red.
                                .rowTint(due < .today() && !ref.task.isDone && ref.task.deadline == nil ? Color.red : Color.secondary)
                        }
                        DeadlineLabel(task: ref.task)
                        if let rule = ref.task.repeatRule {
                            RowFact(rule.label, "repeat")
                        }
                        if showNote {
                            RowFact(ref.noteTitle, noteSymbol, shortens: true)
                                .rowTint(tint.ink)
                        }
                    }
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                }
            }
            // **Who?** hangs off the title, not off the row: the row already carries the date
            // popover, and a second presentation on one view is not reliable on the phone
            // (build 44). The time button does the same with its own.
            .popover(isPresented: $askingWho) {
                WaitingWhoView(ref: ref, isPresented: $askingWho)
            }
            Spacer()
            // How long it takes (build 248). A finished task keeps its time as plain words and
            // asks for nothing: "time?" on a ticked line would be a question with no use.
            // **Build 312 (flow-19): the dashed question only where the day is planned.** Core's
            // `TaskTimePill` decides; on every other list a row without a time shows nothing
            // here, and **How long** on the row's menu is where a time is given.
            if useTaskTimes && !renaming {
                if !ref.task.isDone {
                    if TaskTimePill.shown(in: place, minutes: ref.task.minutes, usesTaskTimes: useTaskTimes) != .nothing {
                        TaskTimeButton(ref: ref, tint: tint, offersFocus: focusBarShown)
                    }
                } else if let minutes = ref.task.minutes {
                    Text(TaskTime.label(minutes))
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                }
            }
            // **Build 316, Mac: Focus on this as the row's own small button**, seen while the
            // pointer is over the row. Only where the time button (which holds Focus on this
            // in Start the day and Plan the day) is not drawn, so nothing is offered twice and
            // no existing button moves. Its place is kept when it is not seen, so the row
            // does not jump. The right-click menu keeps its item.
            #if os(macOS)
            if offersFocusButton {
                Button {
                    model.startFocus(on: ref)
                } label: {
                    MarkImage("timer", size: 14)
                        .foregroundStyle(Theme.planBlockTint.ink)
                        .frame(width: 20, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0)
                .help("Focus on this: start a clock on this task")
                .accessibilityLabel("Focus on this")
                .accessibilityIdentifier("task.focus.\(ref.task.title)")
            }
            #endif
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
        // **Build 304 (his yes to my idea): swipe a task to tick it.** A swipe from the left
        // edge does what the circle does — the same `toggle`, so the same gentle tap (build 303)
        // and the same repeat rule. A full swipe ticks at once. Only inside a list (SwiftUI
        // shows swipe actions in `List` rows only); the circle stays for everywhere else.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if ref.task.status != .cancelled {
                Button(action: toggle) {
                    Label {
                        Text(ref.task.isDone ? "Not done" : "Done")
                    } icon: {
                        // The app's own hand-drawn tick and circle, never a stock symbol.
                        Marks.templateImage(ref.task.isDone ? "circle" : "checkmark.circle.fill", size: 20)
                    }
                }
                .tint(ref.task.isDone ? .gray : .green)
                .accessibilityIdentifier("task.swipeDone.\(ref.task.title)")
            }
        }
        // **Build 305 (his ask): swipe from the right to move a task to tomorrow.** The same
        // `setDueDate` the date window uses, so the time of day and the repeat rule stay. Only
        // for a task still open: a ticked or cancelled line has nothing to put off.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !ref.task.isDone && ref.task.status != .cancelled {
                Button {
                    // Build 306: through `moveTasks`, so the message carries an Undo that
                    // gives the old date back. The time of day stays, as before.
                    model.moveTasks([ref], to: DateOnly.today().adding(days: 1),
                                    offersUndo: true, message: "Moved to tomorrow.")
                } label: {
                    Label {
                        Text("Tomorrow")
                    } icon: {
                        Marks.templateImage("sunrise", size: 20)
                    }
                }
                .tint(Theme.eveningTint)
                .accessibilityIdentifier("task.swipeTomorrow.\(ref.task.title)")
                // **Build 316: Focus on this, beside Tomorrow.** Since build 312 the time button
                // (which holds it) is shown only in Start the day and Plan the day, so on every
                // other list it was in the long-press menu alone. The second button of the same
                // swipe: Tomorrow stays first, and stays what a full swipe does.
                if focusBarShown, model.canFocus(on: ref) {
                    Button {
                        model.startFocus(on: ref)
                    } label: {
                        Label {
                            Text("Focus")
                        } icon: {
                            Marks.templateImage("timer", size: 20)
                        }
                    }
                    .tint(Theme.planBlockTint)
                    .accessibilityIdentifier("task.swipeFocus.\(ref.task.title)")
                }
            }
        }
        .draggable(TaskTransfer(ref))
        .contextMenu {
            TaskContextMenu(ref: ref, showNote: showNote, pickingDate: $pickingDate,
                            askingWho: $askingWho,
                            onAddSubtask: onAddSubtask, onRename: startRenaming,
                            offersFocus: focusBarShown)
        }
        .popover(isPresented: $pickingDate) {
            TaskDatePicker(ref: ref, isPresented: $pickingDate)
        }
        // One thing to accessibility, named by its line — the same shape `InboxRow` has had
        // since build 191, and what lets a screen test see a list narrow (build 211).
        // Accessibility only: nothing here may take the row's click (builds 71–74).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.\(ref.task.title)")
    }

    /// The field shows the task the way the row does: without the #next marker, which
    /// `AppModel.renameTask` puts back so a rename never clears the next action.
    private func startRenaming() {
        draft = isNext ? Note.removingTag(Note.nextActionTag, from: ref.task.title) : ref.task.title
        renaming = true
        fieldFocused = true
    }

    private func commitRename() {
        renaming = false
        model.renameTask(ref, to: draft)
    }
}

struct LinkedNotesList: View {
    @EnvironmentObject private var model: AppModel
    let notes: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(notes) { linked in
                Button {
                    model.show(linked)
                } label: {
                    HStack(spacing: 8) {
                        KindBadge(kind: linked.kind, size: 18)
                        Text(linked.displayTitle)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// The links that name a note nobody has written. Clicking one offers to make it — the
/// same offer a Command-click on the link itself gives, in a place that is easier to find.
struct MissingLinksList: View {
    @EnvironmentObject private var model: AppModel
    let titles: [String]
    let notePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(titles, id: \.self) { title in
                Button {
                    model.openWikiLink(title, from: notePath)
                } label: {
                    HStack(spacing: 8) {
                        MarkImage("plus.circle")
                        Text(title)
                    }
                    .foregroundStyle(.soft)
                }
                .buttonStyle(.plain)
                .help("No note is called this yet \u{2014} click to make it")
            }
        }
        .padding(.top, 4)
    }
}

/// Tasks from the whole vault that are due on the day of a daily note.
struct DayAgendaView: View {
    @EnvironmentObject private var model: AppModel
    let date: DateOnly

    var body: some View {
        let refs = model.index.openTasks(dueOn: date).filter { $0.notePath != model.selectedNotePath }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Due on this day")
                    .font(Txt.label.weight(.medium))
                Spacer()
                Button {
                    model.openDailyNote(for: date.adding(days: -1))
                } label: {
                    MarkImage("chevron.left")
                }
                Button("Today") { model.openDailyNote(for: .today()) }
                Button {
                    model.openDailyNote(for: date.adding(days: 1))
                } label: {
                    MarkImage("chevron.right")
                }
            }
            .buttonStyle(.borderless)
            if model.showsCalendarEvents {
                CalendarEventRows(date: date)
            }
            if refs.isEmpty {
                Text("Nothing from other notes is due on this day")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            } else {
                ForEach(refs) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .task(id: date) { await model.loadEvents(for: date) }
    }
}

/// Tasks due during the week of a weekly note, grouped by day.
struct WeekAgendaView: View {
    @EnvironmentObject private var model: AppModel
    let week: WeekRef
    @State private var expanded = true

    var body: some View {
        let overview = model.index.weekOverview(for: week)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Due this week (\(overview.dueCount))")
                    .font(Txt.label.weight(.medium))
                Spacer()
                Button { model.openWeeklyNote(for: week.adding(weeks: -1)) } label: { MarkImage("chevron.left") }
                Button("This week") { model.openWeeklyNote(for: .current()) }
                Button { model.openWeeklyNote(for: week.adding(weeks: 1)) } label: { MarkImage("chevron.right") }
            }
            .buttonStyle(.borderless)
            Text("Drag a task onto a day to plan it there. Tick it here when it is done.")
                .font(Txt.listSecond)
                .foregroundStyle(.faint)
            ForEach(overview.days) { day in
                HStack {
                    Text(DayWords.withWeekday(day.date))
                        .font(Txt.label.weight(day.date == .today() ? .bold : .semibold))
                    Spacer()
                    if !day.due.isEmpty {
                        Text("\(day.due.count)")
                            .font(Txt.listSecond)
                            .foregroundStyle(.soft)
                    }
                    if !day.completed.isEmpty {
                        HStack(spacing: 3) {
                            MarkImage("checkmark", size: 11)
                            Text("\(day.completed.count)")
                                .font(Txt.listSecond)
                        }
                        .foregroundStyle(.soft)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.completed.count) done")
                    }
                }
                .foregroundStyle(day.date == .today() ? ParaKind.daily.tint.ink : .secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .acceptsTaskDrop { ref in model.setDueDate(ref, day.date) }
                ForEach(day.due + day.undated) { ref in
                    TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                        .padding(.leading, 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// What serves a goal and whether it is moving: linked projects and areas, rolled-up tasks, recent completions.
struct GoalDashboardView: View {
    @EnvironmentObject private var model: AppModel
    let goal: Note

    var body: some View {
        let health = model.index.goalHealth(of: goal, today: .today())
        VStack(alignment: .leading, spacing: 8) {
            // The roll-up first: one line that answers "how far have I come?" before any of
            // the counts below explain it. Not on an aspiration (build 199, finished in 275): you
            // never finish one, so a per cent on it promises something the idea does not.
            if !GoalWording.isAspiration(goal) {
                GoalProgressBar(progress: health.progress, width: 160, tint: ChainTint.forGoal(goal))
                // Build 318: the goal's own number, as a second bar with its curve.
                GoalNumberPanel(model: model, note: goal)
            }
            HStack(spacing: 14) {
                stat("\(health.projects.count)", "projects")
                stat("\(health.areas.count)", "areas")
                stat("\(health.openTaskCount)", "open tasks")
                stat("\(health.completedLast30Days)", "done in 30 days")
                if let days = health.daysSinceActivity {
                    stat(days == 0 ? "today" : "\(days)d", "last activity")
                }
                Spacer()
            }
            if !health.flags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(health.flags, id: \.self) { flag in
                        Text(flag.label)
                            .font(Txt.listSecond)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(flag == .achieved ? goal.tint.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(flag == .achieved ? goal.tint.capsuleWords : Theme.attention.capsuleWords)
                    }
                }
            }
            // No measure line here since build 268: the header just above carries it as a
            // button, and saying it twice on one screen carries no information (build 169).
            let serving = health.subgoals + health.projects + health.areas + health.endedNotes
            if serving.isEmpty {
                // Build 269: the old line asked him to type `goal:` into another note's
                // settings block. The button under it makes the note that serves this one.
                Text(emptyText)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            } else {
                ForEach(serving) { note in
                    Button {
                        model.show(note)
                    } label: {
                        HStack(spacing: 8) {
                            KindBadge(kind: note.declaredKind, size: 18)
                            Text(note.title)
                                .strikethrough(note.isFinishedProject)
                            Spacer()
                            let open = note.openTasks.count
                            if note.isFinishedProject {
                                Text("done")
                                    .font(Txt.label)
                                    .foregroundStyle(.soft)
                            } else if open > 0 {
                                Text("\(open) open")
                                    .font(Txt.label)
                                    .foregroundStyle(.soft)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    // Named by its path for the screen tests (build 269), the same name the
                    // project carries in the chain's rail.
                    .accessibilityIdentifier("serves.\(note.relativePath)")
                }
            }
            // **Always at the foot** (build 269): **Add a project…** on a goal with a date,
            // **Add a goal…** on an aspiration. It stays on this page and the new note appears
            // in the list above at once.
            AddServingNoteButton(model: model, parent: goal)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Txt.listTitle).foregroundStyle(goal.tint.ink)
            Text(label).font(Txt.listSecond).foregroundStyle(.soft)
        }
    }

    /// What the page says when nothing serves the goal yet. An aspiration uses the chain's own
    /// words (`AspirationChainBody`), so the two pages say it alike.
    private var emptyText: String {
        GoalWording.isAspiration(goal) ? "Nothing works towards this yet" : "Nothing serves this goal yet"
    }
}

/// The list of titles that drops under the cursor while a `[[link]]` is being typed.
///
/// It only ever reads the text and hands a chosen title back: it never writes into the editor
/// itself, so typing cannot be interrupted by it. The arrow keys are taken only while it is on
/// screen, and Escape puts it away.
struct WikiLinkList: View {
    let titles: [String]
    @Binding var choice: Int
    let tint: Color
    let kindFor: (String) -> ParaKind
    let pick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.element) { index, title in
                Button {
                    pick(title)
                } label: {
                    HStack(spacing: 8) {
                        KindBadge(kind: kindFor(title), size: 16)
                        Text(title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(index == choice ? tint.opacity(0.22) : .clear,
                                in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(tint.opacity(0.35)))
        .shadow(radius: 12, y: 4)
    }
}

/// The ⓘ beside the add-a-task field.
///
/// What can be typed there used to be the field's own placeholder: eighty-four characters that
/// fit nowhere on a phone — it was cut off at "for a" — and that disappeared the moment he
/// started typing. A button keeps it available instead of almost readable once.
struct TaskSyntaxButton: View {
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            MarkImage("info.circle", size: 16)
                .foregroundStyle(.soft)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What can I type here?")
        .help("What can I type here?")
        // Its own presentation on its own button, never a second `.sheet` on the note screen:
        // two sheet modifiers on one view is what build 44 paid for.
        .popover(isPresented: $showing) { TaskSyntaxHelp() }
    }
}

/// The one place the task syntax is written out for the reader.
private struct TaskSyntaxHelp: View {
    /// A struct, not a tuple: a `ForEach` id is a key path, and a key path cannot address a
    /// tuple member (the lesson of build 61's `PlacedItem`).
    private struct Row: Identifiable {
        let code: String
        let meaning: String
        var id: String { code }
    }

    private static let rows = [
        Row(code: "tomorrow 14:00", meaning: "A date in words. Also next Friday, in 3 days, 13 Dec"),
        Row(code: ">2026-09-10", meaning: "A date"),
        Row(code: ">2026-09-10T14:30", meaning: "A date and a time"),
        Row(code: "!  !!  !!!", meaning: "Priority, lowest to highest"),
        Row(code: "~45m  ~1h30m", meaning: "How long it takes"),
        Row(code: "#tag", meaning: "A tag"),
        Row(code: "@repeat(weekly)", meaning: "Comes back every week. Also 2w, monthly, yearly"),
        Row(code: "@repeat(mon,wed,fri)", meaning: "Comes back on these days. Also weekdays, monthend, 10d after done"),
        Row(code: "@deadline(2026-09-20)", meaning: "Must be finished by this day"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What can I type here?")
                .font(Txt.label.weight(.semibold))
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 7) {
                ForEach(Self.rows) { row in
                    GridRow {
                        Text(row.code)
                            .font(Txt.mono)
                            .foregroundStyle(ParaKind.project.tint.ink)
                        Text(row.meaning)
                            .font(Txt.label)
                            .foregroundStyle(.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("Write them in any order, after the task's own words. What you add here becomes a task in this note and a reminder in Apple Reminders.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Sketches (build 288)

/// A sketch to draw (a new one at `offset`) or to open again (`picturePath`, from the root).
struct SketchRequest: Identifiable {
    let id = UUID()
    let offset: Int?
    let picturePath: String?
}

/// One picture from the Sketches folder, or a word while iCloud has not sent it yet.
/// Build 293: a note's pictures together, small and square; a press opens one big.
struct NoteGallery: View {
    let paths: [String]
    let version: Int
    let tint: Color
    let open: (String) -> Void
    /// Build 295: long press (right-click on the Mac) › Copy words.
    var copyWords: (String) -> Void = { _ in }
    /// Build 294: one picture dragged onto another takes its place.
    var move: (String, String) -> Void = { _, _ in }
    @AppStorage("galleryFolded") private var folded = false
    @EnvironmentObject private var model: AppModel
    /// Build 297: the gallery's search box.
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FoldButton(isOpen: Binding(get: { !folded }, set: { folded = !$0 }), accessibilityName: "Pictures") {
                SectionLabel(title: "Pictures", count: paths.count, markName: "photo", tint: tint)
            }
            if !folded {
                TextField("Search pictures", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .font(Txt.label)
                    .accessibilityIdentifier("gallery.search")
                let shown = Pictures.filtered(paths, by: search, pictureText: model.pictureText)
                if shown.isEmpty {
                    Text("No picture has these words")
                        .font(Txt.label).foregroundStyle(.soft)
                        .accessibilityIdentifier("gallery.none")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(shown, id: \.self) { picture in
                            Button { open(picture) } label: {
                                GalleryThumb(path: picture, version: version)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel((picture as NSString).lastPathComponent)
                            .accessibilityIdentifier("gallery.thumb")
                            .contextMenu {
                                Button("Copy words") { copyWords(picture) }
                            }
                            .draggable(picture)
                            .dropDestination(for: String.self) { items, _ in
                                guard let moving = items.first, moving != picture, paths.contains(moving) else { return false }
                                move(moving, picture)
                                return true
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("note.gallery")
    }
}

/// One square picture in the gallery, cut to fill; grey while iCloud has not sent it.
struct GalleryThumb: View {
    @EnvironmentObject private var model: AppModel
    let path: String
    let version: Int
    var side: CGFloat = 64
    @State private var image: Image?

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .frame(width: side, height: side)
            .overlay { if let image { image.resizable().scaledToFill() } }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            .task(id: "\(path)#\(version)") { image = load() }
    }

    private func load() -> Image? {
        guard let data = model.vault?.fileData(at: path) else { return nil }
        #if os(iOS)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #else
        return NSImage(data: data).map { Image(nsImage: $0) }
        #endif
    }
}

struct SketchThumb: View {
    @EnvironmentObject private var model: AppModel
    let path: String
    let version: Int
    var height: CGFloat = 96
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image.resizable().scaledToFit()
            } else {
                Text("On its way from iCloud")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .padding(8)
            }
        }
        .frame(height: height)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        .task(id: "\(path)#\(version)") { image = load() }
    }

    private func load() -> Image? {
        guard let data = model.vault?.fileData(at: path) else { return nil }
        #if os(iOS)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #else
        return NSImage(data: data).map { Image(nsImage: $0) }
        #endif
    }
}

#if os(iOS)
/// The drawing page: Apple's own pen tools, Apple Pencil or a finger. Cancel throws it away,
/// Done saves the picture (on white, as it was seen) and the drawing to open again.
struct SketchSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: SketchRequest
    let tint: Color
    let save: (Data, Data) -> Void
    @State private var drawing = PKDrawing()
    @State private var loaded = false
    /// A picture made elsewhere, without its drawing: shown, not drawn on.
    @State private var pictureOnly: Image?

    var body: some View {
        NavigationStack {
            Group {
                if pictureOnly != nil, let path = request.picturePath {
                    PictureZoom(path: path, tint: tint)
                } else if loaded {
                    SketchCanvas(drawing: $drawing)
                        .accessibilityIdentifier("sketch.canvas")
                }
            }
            .background(Color.white)
            .navigationTitle(pictureOnly == nil ? "Sketch" : "Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: pictureOnly == nil ? .cancellationAction : .confirmationAction) {
                    Button(pictureOnly == nil ? "Cancel" : "Done") { dismiss() }
                        .accessibilityIdentifier("sketch.cancel")
                }
                if let path = request.picturePath {
                    ToolbarItem(placement: pictureOnly == nil ? .topBarTrailing : .cancellationAction) {
                        CopyWordsButton(path: path, tint: tint)
                    }
                }
                if pictureOnly == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let png = picture() { save(png, drawing.dataRepresentation()) }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(tint)
                        .accessibilityIdentifier("sketch.done")
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear(perform: load)
    }

    private func load() {
        defer { loaded = true }
        guard let picture = request.picturePath, let vault = model.vault else { return }
        if Pictures.isSketch(picture), let data = vault.fileData(at: Sketches.drawingPath(for: picture)),
           let old = try? PKDrawing(data: data) {
            drawing = old
        } else if let data = vault.fileData(at: picture), let image = UIImage(data: data) {
            pictureOnly = Image(uiImage: image)
        }
    }

    /// The strokes on white with a margin; nil for an empty page (nothing to save).
    private func picture() -> Data? {
        guard !drawing.strokes.isEmpty else { return nil }
        let rect = drawing.bounds.insetBy(dx: -24, dy: -24)
        let ink = UITraitCollection(userInterfaceStyle: .light)
        var strokes: UIImage!
        ink.performAsCurrent { strokes = drawing.image(from: rect, scale: 2) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            strokes.draw(in: CGRect(origin: .zero, size: rect.size))
        }
    }
}

/// Build 289: Apple's camera screen. The photo comes back as it was taken.
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let taken: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.taken(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// A photo as the JPEG that goes into the vault: longest side at most 2048 pixels.
enum PhotoFile {
    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let factor = min(2048 / max(longest, 1), 1)
        let size = CGSize(width: (image.size.width * image.scale * factor).rounded(),
                          height: (image.size.height * image.scale * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.8)
    }
}

/// PKCanvasView with the tool picker, light like paper so the ink looks as it is saved.
struct SketchCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.overrideUserInterfaceStyle = .light
        canvas.alwaysBounceVertical = true
        context.coordinator.picker.overrideUserInterfaceStyle = .light
        context.coordinator.picker.addObserver(canvas)
        DispatchQueue.main.async {
            context.coordinator.picker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let picker = PKToolPicker()
        var drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }
        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) { drawing.wrappedValue = canvas.drawing }
    }
}
#else
/// The Mac cannot draw (no Pencil): the sketch, bigger, and Done (Escape closes it too).
struct SketchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: SketchRequest
    let tint: Color
    let save: (Data, Data) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(request.picturePath.map(Pictures.isSketch) ?? false ? "Sketch" : "Picture")
                    .font(Txt.sectionTitle).foregroundStyle(tint.ink)
                Spacer()
                if let picture = request.picturePath {
                    CopyWordsButton(path: picture, tint: tint)
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.filled(tint))
            }
            if let picture = request.picturePath {
                PictureZoom(path: picture, tint: tint)
                    .frame(height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            if request.picturePath.map(Pictures.isSketch) ?? false {
                Text("Sketches are drawn on the iPhone or iPad.")
                    .font(Txt.label).foregroundStyle(.soft)
            }
        }
        .padding(16)
        .frame(minWidth: 520)
    }
}
#endif

// MARK: - Build 295: copy a picture's words, pinch to zoom

/// Copy words on a picture opened big. Says what happened right on the button for two
/// seconds (the app's own short notes sit under the open picture).
struct CopyWordsButton: View {
    @EnvironmentObject private var model: AppModel
    let path: String
    let tint: Color
    @State private var said: String?

    var body: some View {
        Button(said ?? "Copy words") {
            Task {
                if let words = await model.pictureWords(path) {
                    MapExport.copyToPasteboard(words)
                    said = "Words copied"
                } else {
                    said = "No words found"
                }
                try? await Task.sleep(for: .seconds(2))
                said = nil
            }
        }
        .tint(tint)
        .accessibilityIdentifier("picture.copyWords")
    }
}

/// A picture opened big: pinch to zoom (up to `Pictures.maxZoom`), drag to move around
/// while zoomed, double-tap to zoom in or back to normal. Build 297: Select part — drag a
/// box over some words and only those are read and copied.
struct PictureZoom: View {
    @EnvironmentObject private var model: AppModel
    let path: String
    var tint: Color = .accentColor
    @State private var image: Image?
    @State private var imageSize: CGSize = .zero
    @State private var scale: Double = 1
    @State private var lastScale: Double = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selecting = false
    @State private var box: CGRect?
    @State private var said: String?
    /// Build 298: where the searched words sit on the picture (0…1, origin bottom left).
    @State private var found: [CGRect] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Group {
                    if let image {
                        image.resizable().scaledToFit()
                    } else {
                        Text("On its way from iCloud").font(Txt.label).foregroundStyle(.soft)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                ForEach(Array(found.enumerated()), id: \.offset) { _, part in
                    if let fitted = Pictures.frameBox(of: part, imageSize: imageSize, frame: geo.size) {
                        let b = Pictures.zoomedBox(fitted.insetBy(dx: -2, dy: -2), scale: scale, offset: offset, frame: geo.size)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint.opacity(0.22))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(tint.opacity(0.8), lineWidth: 1))
                            .frame(width: b.width, height: b.height)
                            .position(x: b.midX, y: b.midY)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("picture.found")
                if let box {
                    Rectangle()
                        .fill(tint.opacity(0.15))
                        .overlay(Rectangle().stroke(tint, lineWidth: 1.5))
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(selecting ? nil : zoomGesture(geo.size))
            .simultaneousGesture(dragGesture(geo.size))
            .onTapGesture(count: 2) {
                guard !selecting else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    if scale > 1 { reset() } else { scale = Pictures.doubleTapZoom; lastScale = scale }
                }
            }
        }
        .background(Color.white)
        .clipped()
        .overlay(alignment: .bottom) { selectBar }
        .accessibilityIdentifier("picture.zoom")
        .task(id: path) { load(); await findSearchedWords() }
    }

    /// Build 298: marks where the words of the current search sit on the picture.
    private func findSearchedWords() async {
        let terms = Pictures.searchTerms(model.queryText)
        guard !terms.isEmpty, let root = model.vault?.rootURL else { found = []; return }
        let file = root.appendingPathComponent(path)
        found = await Task.detached(priority: .userInitiated) {
            PictureReader.boxes(of: terms, in: file)
        }.value
    }

    /// Select part, the hint while selecting, and what happened.
    private var selectBar: some View {
        HStack(spacing: 8) {
            if let said {
                Text(said).font(Txt.label).foregroundStyle(.soft)
            } else if selecting {
                Text("Drag over the words to copy").font(Txt.label).foregroundStyle(.soft)
            }
            Button(selecting ? "Stop selecting" : "Select part") {
                selecting.toggle()
                box = nil
                if selecting { withAnimation(.easeOut(duration: 0.2)) { reset() } }
            }
            .buttonStyle(.filled(tint))
            .controlSize(.small)
            .accessibilityIdentifier("picture.selectPart")
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .padding(8)
    }

    private func zoomGesture(_ size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = Pictures.zoom(lastScale * value.magnification) }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { withAnimation(.easeOut(duration: 0.2)) { reset() } }
                else { offset = clamped(offset, in: size); lastOffset = offset }
            }
    }

    /// Moves a zoomed picture around; while selecting, draws the box instead.
    private func dragGesture(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if selecting {
                    box = CGRect(x: min(value.startLocation.x, value.location.x),
                                 y: min(value.startLocation.y, value.location.y),
                                 width: abs(value.location.x - value.startLocation.x),
                                 height: abs(value.location.y - value.startLocation.y))
                } else if scale > 1 {
                    offset = clamped(CGSize(width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height), in: size)
                }
            }
            .onEnded { _ in
                if selecting {
                    if let box { copyPart(box, frame: size) }
                } else {
                    lastOffset = offset
                }
            }
    }

    /// Reads only the words inside the box, copies them, and says so.
    private func copyPart(_ box: CGRect, frame: CGSize) {
        guard let region = Pictures.region(of: box, imageSize: imageSize, frame: frame),
              let root = model.vault?.rootURL else { tell("No words in that part"); return }
        let file = root.appendingPathComponent(path)
        Task {
            let read = await Task.detached(priority: .userInitiated) {
                PictureReader.recognize(file, region: region)
            }.value
            if let words = Pictures.wordsToCopy(read) {
                MapExport.copyToPasteboard(words)
                tell("Words copied")
                selecting = false
            } else {
                tell("No words in that part")
            }
            self.box = nil
        }
    }

    private func tell(_ text: String) {
        said = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if said == text { said = nil }
        }
    }

    private func reset() { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }

    /// Moving stops where the picture's edge reaches the frame's edge.
    private func clamped(_ o: CGSize, in size: CGSize) -> CGSize {
        let maxX = size.width * (scale - 1) / 2, maxY = size.height * (scale - 1) / 2
        return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
    }

    private func load() {
        guard let data = model.vault?.fileData(at: path) else { return }
        #if os(iOS)
        if let ui = UIImage(data: data) { image = Image(uiImage: ui); imageSize = ui.size }
        #else
        if let ns = NSImage(data: data) {
            image = Image(nsImage: ns)
            if let rep = ns.representations.first, rep.pixelsWide > 0 {
                imageSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            } else { imageSize = ns.size }
        }
        #endif
    }
}

#if os(macOS)
/// The Mac shares through its own list (`NoteSharing.present`); this only keeps the name alive
/// so the note screen has no `#if` in the middle of its chain (build 148's lesson).
struct SharedFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
#endif

/// The iPhone's and iPad's share sheet for a note's copy (round 8, build 315). Nothing on the Mac.
struct SharesNoteFile: ViewModifier {
    @Binding var file: SharedFile?

    func body(content: Content) -> some View {
        #if os(iOS)
        content.sheet(item: $file) { file in
            ShareSheet(url: file.url)
        }
        #else
        content
        #endif
    }
}
