import SwiftUI
import UniformTypeIdentifiers
import ParagonCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var showingImporter = false
    @State private var askedAboutFolder = false

    /// How far above the bottom the short messages sit: clear of the focus timer's bar while a
    /// clock runs — on the phone that bar sits above the tab bar.
    private var flashBottom: CGFloat {
        // Round 9 (build 316): on the iPhone the message sits above the tab bar (49 points
        // and a gap). At 16 points it lay on top of the tabs.
        guard model.focus != nil else { return isCompact && model.vault != nil ? 66 : 16 }
        return isCompact ? 128 : 72
    }

    /// What a wait at the foot of the window is for: the same words with a different offer are a
    /// different wait. A plain value, so `.task(id:)` can compare two of them.
    private struct FlashWait: Equatable {
        let message: String
        let offerID: Int?
    }

    /// How long the message stays. A message with an **Undo** stays eight seconds and every
    /// other message two and a half, as before (`UndoWording.secondsOnScreen`).
    ///
    /// **A screen test on a slow runner may need longer than eight seconds between seeing the
    /// button and pressing it**, and a test that fails for its own reasons is worse than none
    /// (build 190). In a debug build started with `-paragon-test-vault` the offer stays a minute.
    private func flashSeconds() -> Double {
        let offered = model.undoOffer != nil
        #if DEBUG
        if offered && TestVault.isWanted { return 60 }
        #endif
        return model.flashLinger ?? UndoWording.secondsOnScreen(offersUndo: offered)
    }

    /// iPhone (and a narrow iPad window): tabs instead of three columns.
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    /// The window's columns. **On the Mac two since round 7 (build 314)**: the sidebar, and one
    /// side that is the list alone until a note is open (`MacMainColumns`). The iPad keeps the
    /// three columns it had.
    @ViewBuilder
    private var columns: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            MacMainColumns()
        }
        #else
        NavigationSplitView {
            SidebarView()
        } content: {
            NoteListView()
        } detail: {
            DetailView()
        }
        #endif
    }

    var body: some View {
        Group {
            if model.vault == nil {
                WelcomeView(showingImporter: $showingImporter)
                    // The folder picker lives on the welcome screen only, so it never
                    // competes with the sheet below for the same presentation slot.
                    .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
                        if case .success(let url) = result {
                            // Looked at first, opened only on his yes (build 308).
                            askedAboutFolder = true
                            model.lookAtFolder(url)
                        }
                    }
                    .modifier(FolderChoiceSheet(asked: $askedAboutFolder))
            } else if isCompact {
                #if os(iOS)
                PhoneRootView()
                #endif
            } else {
                columns
                .modifier(ColumnsFitTheScreen())
                // The focus timer's bar at the foot of the window (build 256). Nothing at all
                // while no timer runs, so the window is exactly as before.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FocusBar()
                }
                .toolbar {
                    ToolbarItemGroup {
                        // Build 299, his ask: no Quick capture button here any more. The coloured
                        // + New note button over the list does it (Capture is one of its six
                        // choices); ⇧⌘N still opens Quick capture straight away.
                        // Build 292: no sync button here. He asked for it to go; the sync
                        // runs by itself, the pill at the foot of the sidebar shows how it
                        // stands and syncs on a press, and File › Sync with Reminders keeps ⇧⌘R.
                        #if !os(macOS)
                        Button {
                            model.activeSheet = .settings
                        } label: {
                            MarkLabel("Settings", "gear", size: 16)
                        }
                        #endif
                    }
                }
            }
        }
        // One sheet modifier for the whole window: stacking several of them makes
        // SwiftUI present an empty sheet and leave the window modal.
        .sheet(item: model.sheetSelection) { sheet in
            switch sheet {
            case .newNote:
                NewNoteSheet()
                    .environmentObject(model)
            case .quickCapture:
                QuickCaptureView()
                    .environmentObject(model)
            case .syncReport:
                SyncReportView()
                    .environmentObject(model)
            case .noteFromLink:
                NoteFromLinkSheet()
                    .environmentObject(model)
            case .closeDay:
                CloseDayView()
                    .environmentObject(model)
                    // No timer bar inside a sheet, so no Focus on this either (build 256).
                    .environment(\.focusBarShown, false)
            case .startDay:
                StartDayView()
                    .environmentObject(model)
                    .environment(\.focusBarShown, false)
            case .focusStop:
                FocusStopView()
                    .environmentObject(model)
            case .settings:
                NavigationStack {
                    SettingsView()
                        .environmentObject(model)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { model.activeSheet = nil }
                            }
                        }
                }
            }
        }
        // Review round 4: the iPhone layout, and every sheet over it, knows it is one — its
        // lists draw the app's page and cards (`phonePage`, `phoneCard`). After `.sheet`, so
        // the sheets read it too.
        .environment(\.phoneLook, isCompact && model.vault != nil)
        .onOpenURL { url in
            model.handle(url: url)
            #if os(macOS)
            // The main window takes a link itself now (`TakesLinksInOpenWindow`, build 276), so
            // a minimized window or one behind **Plan the day** is brought to the front.
            FocusStatusItem.bringMainWindowForward()
            #endif
        }
        .modifier(MainWindowMarking())
        // A press on a daily reminder opens its screen: **Close the day** in the evening (build
        // 234), **Start the day** in the morning (build 267). `onReceive` also hands over the
        // current count when it starts listening, which is what catches a press that started the
        // app from cold, before this view existed. The answered counts live in `EveningReminder`,
        // so a window opened later does not replay a press an earlier window already answered
        // (build 238), and the count is the one handed in, never read back (build 242).
        .onReceive(EveningReminder.shared.$openRequests) { count in
            guard EveningReminder.shared.takeOpenRequest(.evening, upTo: count) else { return }
            answerReminder(opening: .closeDay)
        }
        .onReceive(EveningReminder.shared.$morningRequests) { count in
            guard EveningReminder.shared.takeOpenRequest(.morning, upTo: count) else { return }
            answerReminder(opening: .startDay)
        }
        // The weekly review's reminder (round 8, build 315) opens the review itself: a place,
        // not a sheet, so nothing typed in an open sheet is lost by going there.
        .onReceive(EveningReminder.shared.$reviewRequests) { count in
            guard EveningReminder.shared.takeOpenRequest(.weeklyReview, upTo: count) else { return }
            model.afterUpdate {
                guard model.vault != nil else { return }
                model.openSection(.review)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.afterUpdate {
                    model.checkForExternalChanges()
                    model.drainOutbox()
                }
            case .inactive, .background:
                // Going to the background (or being quit on iOS): write what is being typed.
                model.flushPendingEdits()
                // And let the widgets have the latest at once, not in two seconds (build 271).
                model.flushWidgetSnapshot()
            @unknown default:
                break
            }
        }
        #if os(macOS)
        // Build 285: on the Mac the Map lives in its own window. Choosing it in the sidebar
        // opens (or fronts) that window and leaves this one where it was.
        .onChange(of: model.section) { old, new in
            guard new == .map else { return }
            openWindow(id: ParagonApp.mapWindowID)
            model.section = (old == nil || old == .map) ? .today : old
        }
        #endif
        .onAppear {
            model.afterUpdate { model.drainOutbox() }
            #if os(macOS)
            // For the menu bar clock's Show PARAGON when every main window is closed (build 257).
            // An `OpenWindowAction` acts on the app's scenes, so it still works after this window
            // has gone.
            model.openMainWindow = { [openWindow] in openWindow(id: ParagonApp.mainWindowID) }
            #endif
            #if DEBUG
            // Lets a test open a note without hands: the phone layouts can only be checked
            // on a screen, and every route to one is a tap. Debug builds only.
            if let title = ProcessInfo.processInfo.environment["PARAGON_OPEN_NOTE"],
               let url = URL(string: "amspara://" + (title.addingPercentEncoding(
                   withAllowedCharacters: .urlHostAllowed) ?? title)) {
                model.afterUpdate { model.handle(url: url) }
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            if let message = model.lastCaptureMessage {
                // The message and, when it carries one, its **Undo** (build 277). Without an
                // offer this draws exactly what it always drew.
                FlashCapsule(message: message, offersUndo: model.undoOffer != nil) { model.undo() }
                    // Above the focus timer's bar while a clock runs, never over its buttons
                    // (build 256): on the phone the bar sits on top of the tab bar, so higher.
                    .padding(.bottom, flashBottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // Keyed to the words **and the offer's number**, so a message that replaces
                    // or extends another gets its own full time on screen (build 257's review),
                    // and so does a second Undo offered under the same words. A new message
                    // cancels the old wait, and a cancelled wait must not clear the new message.
                    .task(id: FlashWait(message: message, offerID: model.undoOffer?.id)) {
                        do { try await Task.sleep(for: .seconds(flashSeconds())) } catch { return }
                        model.clearCaptureMessage()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.lastCaptureMessage)
        .alert("Something went wrong", isPresented: model.errorPresented) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        // "What is next for this goal?" (build 271), asked when a project ends and its goal is
        // left with nothing working on it. A modifier of its own, so this chain gets one line.
        .modifier(WhatNextDialog())
        // Build 307: the brake for mass changes, and "remove its reminders too?".
        .modifier(SyncSafetyDialogs())
    }

    /// The one way a reminder's press is answered (build 267), for the morning and the evening
    /// alike, so the two can never answer a press in different ways. In this order:
    ///
    /// 1. No vault: nothing to open. The press is dropped, never kept for hours.
    /// 2. Everything else happens **a turn later**, never in the update that brought the press
    ///    (build 246): a sheet changed mid-update is what iOS has crashed on before (build 232).
    /// 3. **The same screen is already open: it stays as it is**, with what was typed in it.
    ///    Before build 267 **Close the day** was closed and opened again, empty.
    /// 4. **The focus clock's question is open or waiting, or another screen is open: the press
    ///    waits** (**Wait**, on the plan page he read), and the screen opens a turn after that
    ///    one closes.
    ///    Swapping it would throw away what was typed there, or the stopped clock's time
    ///    (build 257). A message would sit under the open sheet on the phone (build 238).
    ///    **The question "What is next for this goal?" is up** (build 271): the press waits for
    ///    that too. It is a dialog and not a sheet, so `activeSheet` does not say it is there.
    /// 5. Nothing is open: the screen opens.
    private func answerReminder(opening sheet: AppSheet) {
        guard model.vault != nil else { return }
        model.afterUpdate {
            guard model.vault != nil else { return }
            if model.activeSheet == sheet { return }
            if model.activeSheet != nil || model.focusQuestionPending || model.whatNext != nil {
                model.openWhenFree(sheet)
                return
            }
            model.activeSheet = sheet
        }
    }
}

/// The Mac's mark on the main window, for the menu bar clock's **Show PARAGON** (build 257).
/// A modifier, so no `#if` sits in the middle of `ContentView`'s chain (build 148).
///
/// **An overlay, never a background.** A background's platform view is put in front of the
/// content's in `contentView.subviews`, and `tameSplitViewColumns` and `repairOverflow` take
/// `contentView.subviews.first` to be the split view's host: as a background the marker
/// switched off build 34's fix and silenced the OVERFLOW line the screen tests read, with
/// every test still green (build 257's third review). Zero-sized and click-through, so an
/// overlay takes nothing from the window.
private struct MainWindowMarking: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.overlay(MainWindowMarker().frame(width: 0, height: 0))
        #else
        content
        #endif
    }
}

/// On the iPad, every column fits on the screen (build 278).
///
/// With no style of its own the split view left the arrangement to iPadOS, and on the iPad mini
/// in landscape (1133 points) iPadOS **pushed** the note column to the right when the sidebar
/// came out instead of making it narrower: about 440 of its 760 points were on screen, and the
/// rest — the end of the title, the toolbar buttons, the end of **Add a task…** — was off the
/// right edge (the CI pictures of build 276). `.balanced` asks for the other arrangement: the
/// note column gets narrower so all three sit side by side, as on the Mac. **He always holds
/// the iPad in landscape** (3 November 2026), so that is the one shape this is for; portrait is
/// whatever iPadOS makes of it, and the CI pictures show both.
/// The Mac is untouched: it has always tiled its columns.
private struct ColumnsFitTheScreen: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationSplitViewStyle(.balanced)
        #else
        content
        #endif
    }
}

/// The screen shown when no vault is open.
///
/// **Build 179 gave it a way back.** Until then it was the first-run screen and nothing else, so
/// three different situations looked identical: a genuine first run, a vault closed by mistake,
/// and a folder the app knew about but could not open. His iPhone was the third, and the screen
/// said nothing at all about it — build 100's rule ("never let a read failure look like an
/// absence") broken in the one place where it is the whole screen.
///
/// His words for what was missing: *"a way out back into the app"*. That is `reopenLastVault`.
#if os(macOS)
/// The Mac window's right side (review round 7, build 314, his pick A): **the list takes the
/// whole width until a note is open.** Before, every list sat in a 280-point column beside an
/// empty panel with a grey "New…" button, and the weekly review's headings were cut.
///
/// One `HStack`, and the list is always its first child, so it keeps its state (what is
/// folded, where it is scrolled) when the note's side comes and goes. Which sections keep both
/// parts at all times is Core's `WindowColumns`.
struct MacMainColumns: View {
    @EnvironmentObject private var model: AppModel
    /// The list's width beside an open note. His to drag.
    @AppStorage("macListWidth") private var listWidth = WindowColumns.listWidthAtFirst
    @State private var widthAtDragStart: Double?

    private var noteOpen: Bool {
        guard let path = model.selectedNotePath else { return false }
        return model.note(at: path) != nil
    }
    private var wide: Bool { WindowColumns.listTakesAll(section: model.section?.key, noteOpen: noteOpen) }
    private var canClose: Bool { WindowColumns.canCloseNote(section: model.section?.key, noteOpen: noteOpen) }

    var body: some View {
        HStack(spacing: 0) {
            NoteListView()
                .frame(width: wide ? nil : WindowColumns.listWidth(listWidth))
                .frame(maxWidth: wide ? .infinity : nil)
            if !wide {
                divider
                DetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            if canClose {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.closeNote()
                    } label: {
                        MarkLabel("Close note", "xmark", size: 16)
                    }
                    .help("Close this note and give the list the whole window again (⌃⌘↑)")
                    .accessibilityIdentifier("note.close")
                }
            }
        }
        .modifier(MacToolbarSearch())
    }

    /// The line between the list and the note, with a wider strip over it to drag.
    private var divider: some View {
        Divider()
            .overlay {
                Color.clear
                    .frame(width: 9)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { drag in
                            let start = widthAtDragStart ?? WindowColumns.listWidth(listWidth)
                            widthAtDragStart = start
                            listWidth = WindowColumns.listWidth(start + drag.translation.width)
                        }
                        .onEnded { _ in widthAtDragStart = nil })
            }
    }
}

/// The Mac's one search (round 7, build 314): a field in the toolbar on every screen. Typing
/// in it opens the Search page with those words; the page's own word field is gone on the
/// Mac, so there is one place to type. ⇧⌘F puts the cursor here.
private struct MacToolbarSearch: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @State private var text = ""
    @State private var shown = false
    /// What this field last wrote into the model, so its own writes are not read back into
    /// it under the cursor (a token half typed, `#tra`, would be taken out of the field).
    @State private var written: String?

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, isPresented: $shown, placement: .toolbar, prompt: "Search")
            .onChange(of: text) { _, value in
                let words = value.trimmingCharacters(in: .whitespaces)
                if model.section != .search {
                    // Arriving by typing: a fresh search for these words, no old boxes.
                    guard !words.isEmpty else { return }
                    let query = SearchQuery.replacing(wordsIn: "", with: value)
                    written = query
                    model.queryText = query
                    model.section = .search
                } else {
                    let query = SearchQuery.replacing(wordsIn: model.queryText, with: value)
                    guard query != model.queryText else { return }
                    written = query
                    model.queryText = query
                }
            }
            .onChange(of: model.queryText) { _, value in
                // Set from elsewhere: a tag pressed, a saved search, Clear, a link.
                guard value != written else { return }
                written = nil
                let words = model.section == .search ? SearchQuery.words(in: value) : ""
                if text != words { text = words }
            }
            .onChange(of: model.section) { _, section in
                if section == .search {
                    let words = SearchQuery.words(in: model.queryText)
                    if text.isEmpty, !words.isEmpty { text = words }
                    shown = true
                } else if !text.isEmpty {
                    written = nil
                    text = ""
                }
            }
    }
}
#endif

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingImporter: Bool

    /// The subtitle depends on why there is no vault, so it is assembled here rather than in
    /// the body (the `@ViewBuilder` rule, build 58).
    private var explanation: String {
        if let problem = model.vaultProblem { return problem }
        return "Projects, Areas, Resources and Archive as plain markdown files, with tasks that stay in sync with Apple Reminders."
    }

    private var backTitle: String {
        if let name = model.lastVaultName { return "Open \(name) again" }
        return "Open my last folder again"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ForEach([ParaKind.project, .area, .resource, .archive], id: \.self) { kind in
                    RoundedRectangle(cornerRadius: 9)
                        .fill(kind.tint)
                        .frame(width: 38, height: 38)
                }
            }
            Text("PARAGON")
                .font(Txt.pageTitle.bold())
            Text(explanation)
                .multilineTextAlignment(.center)
                .foregroundStyle(model.vaultProblem == nil ? Theme.soft : Theme.attention.ink)
                .frame(maxWidth: 420)
            // The way back comes first when there is one: it is the answer nine times out of
            // ten, and choosing a folder by hand is the fallback, not the first offer.
            if model.canReopenLastVault {
                Button(backTitle) { model.reopenLastVault() }
                    .buttonStyle(.filled(Theme.fallbackTint))
                Button("Choose a different folder…") { showingImporter = true }
            } else {
                Button("Choose a vault folder…") { showingImporter = true }
                    .buttonStyle(.filled(Theme.fallbackTint))
            }
            Text("Pick your vault folder, an empty folder or an existing NotePlan style folder. PARAGON shows what it found first and writes nothing until you say so.")
                .font(Txt.label)
                .foregroundStyle(.faint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    /// Review round 7 (build 314): the folded groups, by name ("Look back|Tools"). Empty until
    /// a heading is first pressed, and then `SidebarGroups` says Tools is the folded one.
    @AppStorage("sidebarFoldedGroups") private var foldedStore = "-"

    private var folded: Set<String> { SidebarGroups.folded(in: foldedStore == "-" ? nil : foldedStore) }

    var body: some View {
        List(selection: model.sectionSelection) {
            // Round 7, his pick A: four short groups in the iPhone's order — Do, Goals and
            // PARA, Look back, Tools — and each folds. His tick moved All actions up to Do,
            // away from Recent and Done (his order of build 153).
            ForEach(SidebarGroups.all, id: \.name) { group in
                Section {
                    // A fold in the header, not a DisclosureGroup: those drew their rows over
                    // each other inside a List (build 93). A Section header is not a selectable
                    // row, so the press takes no click away from the list.
                    if !folded.contains(group.name) {
                        ForEach(group.rows, id: \.self) { key in
                            if let section = SidebarSection.all.first(where: { $0.key == key }) {
                                if section == .inbox {
                                    row(section)
                                        .acceptsTaskDrop { ref in model.moveTask(ref, to: model.vault?.config.inboxFile ?? "Inbox.md") }
                                } else {
                                    row(section)
                                }
                            }
                        }
                        #if os(macOS)
                        // The Mac's search is the field in its toolbar (round 7, his pick),
                        // so the sidebar has no Search row. Round 9 (build 316): only while
                        // the Search page is open the row is there, as the chosen one —
                        // before, the sidebar then showed no chosen row at all. It goes
                        // again when another row is chosen.
                        if group.name == "Look back", model.section == .search { row(.search) }
                        #else
                        // The iPad has no such field, so its row stays.
                        if group.name == "Look back" { row(.search) }
                        #endif
                    }
                } header: {
                    groupHeader(group)
                }
            }
            if model.workRevealed {
                Section {
                    row(.work)
                }
            }
            // 1.0: the version as he reads it, "1.0 (280)", as the last line of the list — it
            // scrolls with the rows, so it never lies over one. A bar at the foot did, and on a
            // small iPad in portrait the Areas row sat exactly under it (the iPad screen test of
            // build 280). The long press that reveals Work lives on the Goals and PARA heading above.
            Section {
                Text("PARAGON \(AppVersion.text)")
                    .font(Txt.listSecond)
                    .foregroundStyle(.faint)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .selectionDisabled()
                    .accessibilityIdentifier("sidebar.version")
            }
        }
        .navigationTitle("PARAGON")
        .safeAreaInset(edge: .bottom) {
            // Only the iCloud warning stays at the foot: it is deliberately hard to miss.
            // Build 285: the sync line is always here, under it.
            VStack(spacing: 2) {
                if let warning = model.vaultWarning {
                    VaultWarningBar(text: warning) { model.fetchMissingNotes() }
                }
                SyncStatusBar()
            }
            .padding(.vertical, 4)
            .background(.bar)
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        #endif
    }

    /// A group's heading: a small arrow and the name; a press folds or opens the group.
    /// **A tap gesture, not a Button**, so the long press on "Goals and PARA" — the way in to
    /// Work on the Mac — does not also fold the group when the finger comes up.
    private func groupHeader(_ group: SidebarGroups.Group) -> some View {
        let isFolded = folded.contains(group.name)
        return HStack(spacing: 6) {
            MarkImage(isFolded ? "chevron.right" : "chevron.down", text: .footnote)
            Text(group.name)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.2) {
            if group.name == "Goals and PARA" { model.revealWork() }
        }
        .onTapGesture {
            foldedStore = SidebarGroups.toggling(group.name, in: foldedStore == "-" ? nil : foldedStore)
        }
        .help(isFolded ? "Show \(group.name)" : "Hide \(group.name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sidebar.fold.\(group.name)")
    }

    private func row(_ section: SidebarSection) -> some View {
        // Build 282: the chosen row is filled in its part's colour, with white words.
        let chosen = model.section == section
        let count = model.count(for: section)
        return Label {
            Text(section.title)
                .foregroundStyle(chosen ? Color.white : Color.primary)
        } icon: {
            MarkImage(section.markName)
                .rowTint(chosen ? Color.white : section.tint)
        }
        // Build 310: on the chosen row the count is white, like the words beside it.
        .badge(count > 0 ? Text("\(count)").foregroundStyle(chosen ? Color.white : Theme.soft) : nil)
        .tag(section)
        // Build 310: the fill is the deep day shade by day and by night. At night it was the
        // bright night shade, and the white words on it could not be read (2.2 to 1).
        .listRowBackground(chosen ? RoundedRectangle(cornerRadius: 6).fill(section.tint.deep).padding(.horizontal, 8) : nil)
        // "sidebar.Inbox", "sidebar.Projects" and so on: what the Mac screen tests click
        // (build 195). Accessibility only; nothing here takes the row's click (builds 71-74).
        .accessibilityIdentifier("sidebar.\(section.key)")
    }
}

struct NoteListView: View {
    @EnvironmentObject private var model: AppModel
    /// The section this list always shows, whatever `model.section` says (build 229).
    ///
    /// **Nil on the Mac**, where one middle column follows the sidebar. **Set on the iPhone**,
    /// because there the pager keeps the Plan, Actions and Inbox pages alive side by side — and
    /// until build 229 all three drew `model.section`, so every change of tab rebuilt three
    /// pages into the same screen at once (three planners, three Inbox lists sharing one
    /// selection). That is the prime suspect for the two crashes on 28 and 29 September, which
    /// both came right after Quick capture closed and the tab changed.
    let fixed: SidebarSection?

    init(fixed: SidebarSection? = nil) {
        self.fixed = fixed
    }

    /// What this list is showing: its own section on the phone, the sidebar's on the Mac.
    private var shown: SidebarSection? { fixed ?? model.section }
    /// Kept in the view, not the model: the toolbar search field writes to it while redrawing.
    @State private var searchText = ""
    @State private var noteToTrash: Note?
    @State private var noteToRename: Note?
    @State private var renameDraft = ""
    /// Areas folded shut by their chevron, by relative path. Sub-areas are shown by default.
    @State private var foldedAreas: Set<String> = []
    @State private var makingWorkNote = false
    @State private var workNoteTitle = ""

    private var searching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Build 312: the phone's Actions and Inbox tabs carry the round capture + above the tabs.
    private var hasFloatingCapture: Bool { fixed == .allActions || fixed == .inbox }

    /// Areas are a two-level list: each area followed by its sub-areas unless it is folded.
    /// While searching, and for every other section, the plain flat list.
    private var visibleNotes: [Note] {
        let listed = model.notes(in: shown, matching: searchText)
        guard shown == .kind(.area), !searching else { return listed }
        return model.index.areaTree().flatMap { branch in
            foldedAreas.contains(branch.area.relativePath) ? [branch.area] : branch.all
        }
    }

    /// The areas a given area is arranged among: the top-level areas, or its parent's children.
    private func siblings(of note: Note) -> [Note] {
        guard shown == .kind(.area), !searching else { return visibleNotes }
        guard let parent = model.index.parentArea(of: note) else {
            return model.index.areaTree().map(\.area)
        }
        return model.index.subAreas(of: parent)
    }

    /// Maps a drag in the visible list onto the row's own family, so a sub-area is arranged
    /// among its siblings and a drop that would take it out of the family is left alone.
    private func move(_ listed: [Note], from source: IndexSet, to destination: Int) {
        guard shown == .kind(.area), !searching else {
            guard case .kind(let kind) = shown else { return }
            model.reorder(kind, from: source, to: destination)
            return
        }
        guard let from = source.first, listed.indices.contains(from) else { return }
        let family = siblings(of: listed[from])
        guard let index = family.firstIndex(of: listed[from]) else { return }
        // `toOffset` counts positions in the family before anything is removed, which is what
        // the number of family members above the drop point gives us.
        let to = listed[0..<min(destination, listed.count)].filter { member in
            family.contains { $0.relativePath == member.relativePath }
        }.count
        model.reorder(family, from: IndexSet(integer: index), to: to)
    }

    /// Nil while searching (build 254, from the review of 253). The list then holds only the
    /// matches, and a drag's positions were written onto the whole list: dragging D above B in
    /// a search showing B and D moved B to the top and left D where it was, and rewrote the
    /// `order:` line of notes nobody had touched. Since build 253 a search is the only way the
    /// Projects section shows this list.
    private func mover(for listed: [Note]) -> ((IndexSet, Int) -> Void)? {
        guard !searching else { return nil }
        return { source, destination in
            move(listed, from: source, to: destination)
        }
    }

    private func fold(_ note: Note) {
        if foldedAreas.contains(note.relativePath) {
            foldedAreas.remove(note.relativePath)
        } else {
            foldedAreas.insert(note.relativePath)
        }
    }

    /// True while the Areas list is showing its two levels and this area has sub-areas.
    private func foldable(_ note: Note) -> Bool {
        shown == .kind(.area) && !searching && !model.index.subAreas(of: note).isEmpty
    }

    /// Build 310: true where this list holds notes of more than one part (Recent, and a
    /// search started from a page that is not one part's own list). There a row wears its
    /// part's small icon, not the dot: for red-green colour blindness the dots of Projects,
    /// Areas and Archive are nearly one colour.
    private var mixesParts: Bool {
        switch shown {
        case .kind(_)?, .inbox?, .calendar?, .aspirations?, .work?: return false
        default: return true
        }
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: 4) {
            if foldable(note) {
                Button {
                    fold(note)
                } label: {
                    MarkImage(foldedAreas.contains(note.relativePath) ? "chevron.right" : "chevron.down", text: .footnote)
                        .foregroundStyle(.soft)
                        // The drawing is 12 points; the press area is 14 by 22. The negative
                        // padding keeps the row as tall as it was with the 16-point mark.
                        .frame(width: 14, height: 22)
                        .contentShape(Rectangle())
                        .padding(.vertical, -3)
                }
                .buttonStyle(.plain)
                .help(foldedAreas.contains(note.relativePath) ? "Show the sub-areas" : "Hide the sub-areas")
            } else if shown == .kind(.area), !searching {
                Spacer().frame(width: 14)
            }
            NoteRow(note: note,
                    goalProgress: note.kind == .goal ? model.index.progress(of: note) : nil,
                    goalSymbol: note.goal.map { ChainSymbol.forGoal(named: $0, in: model.index) }
                        ?? ChainSymbol.datedGoal,
                    goalTint: note.goal.map { ChainTint.forGoal(named: $0, in: model.index) }
                        ?? ChainTint.datedGoal,
                    showsPart: mixesParts)
        }
        .padding(.leading, model.index.parentArea(of: note) == nil ? 0 : 18)
        .tag(note.relativePath)
        // Named by its path for the screen tests (build 191); the title alone can appear on
        // other pages of the phone's pager at the same time.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("note.\(note.relativePath)")
        .acceptsTaskDrop { ref in model.moveTask(ref, to: note.relativePath) }
        .contextMenu {
            if note.kind == .area || note.kind == .goal {
                // Build 270: the same press as the button at the top of the note. Goals are
                // here for a search in Aspirations or Goals, which draws this list.
                LookedAtMenuItem(model: model, note: note)
            }
            if note.kind != .inbox, note.kind != .daily {
                Button("Rename…") { startRenaming(note) }
            }
            if note.kind == .area {
                AreaParentMenu(model: model, note: note)
            }
            if note.kind == .area || note.kind == .project {
                NoteGoalMenu(model: model, note: note)
            }
            if note.kind == .project {
                // Build 269: the same choices as **In area…** at the top of the project.
                ProjectAreaMenu(model: model, note: note)
            }
            if model.canArchive(note) {
                Button("Archive") { model.archive(note) }
            }
            if note.kind != .inbox {
                Button("Move to Trash…", role: .destructive) { noteToTrash = note }
            }
        }
    }

    var body: some View {
        Group {
            if shown == .inbox {
                // One inbox note means a list of notes would be a list of one; sort the
                // captured lines here instead.
                InboxTriageView()
            } else if shown == .today {
                TodayView()
            } else if shown == .calendar {
                CalendarView()
            } else if shown == .review {
                ReviewView()
            } else if shown == .map {
                MapView()
            } else if shown == .timeBlocks {
                #if os(iOS)
                // No third column on the phone, so the section is the whole planner. Build 181
                // made it page one of a pair; build 183 gave it a tab of its own instead, and
                // the swipe belongs to the tabs.
                PlannerView()
                #else
                // Build 150, his choice: the planner lives in the ordinary window. The day's
                // actions are the middle column and the two lanes are the detail column.
                PlannerActionsView()
                #endif
            } else if shown == .done {
                DoneView()
            } else if shown == .allActions {
                AllActionsView()
            } else if shown == .deleted {
                DeletedView()
            } else if shown == .templates {
                TemplatesView()
            } else if shown == .snippets {
                SnippetsView()
            } else if shown == .tags {
                TagsView()
            } else if shown == .search {
                SearchView()
            } else if shown == .aspirations, !searching {
                // Build 162's screen, on its own row since build 199: the list is the
                // aspirations, and what serves each one is drawn beside it (the Mac) or
                // folded open under it (the phone). Searching falls through to the ordinary
                // list, which is what a search of the vault should be.
                AspirationsListView()
                    // The field has to exist here, or there would be no way to start a search
                    // in this section and the `!searching` branch above could never be taken.
                    .listSearch($searchText)
            } else if shown == .kind(.goal), !searching {
                // Build 199: every goal with a date, in one list, whether or not an
                // aspiration holds it. His words about the screen before: *"I am not choosing
                // an aspiration, no goals are visible on the Goals page."*
                DatedGoalsListView()
                    .listSearch($searchText)
            } else if shown == .kind(.project), !searching, !model.projectGroups.isEmpty {
                // Build 253, his ask: *"The project list is a bit boring."* Each project is a
                // box under the aspiration it works towards, saying what it needs next. A
                // search falls through to the ordinary list below, as in both goal rooms, and
                // so does an empty vault, to "No projects yet".
                askingToTrash(ProjectsListView(rename: { startRenaming($0) },
                                               trash: { noteToTrash = $0 }))
                    .listSearch($searchText)
            } else {
                let listed = visibleNotes
                if listed.isEmpty {
                    emptyList(searching: !searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .listSearch($searchText)
                } else {
                askingToTrash(
                List(selection: model.noteSelection) {
                    ForEach(listed) { note in
                        noteRow(note)
                    }
                    // Drag a note up or down to arrange the list; the position is written into
                    // the note as `order:` so both devices agree. Not while searching.
                    .onMove(perform: mover(for: listed))
                    // Review round 4: on the iPhone each row is a card in the part's colour.
                    .phoneCard(shown?.tint)
                }
                .listSearch($searchText)
                .onChange(of: shown) { _, _ in searchText = "" }
                )
                }
            }
        }
        #if os(iOS)
        // Review round 4: on the iPhone every section opens with its slim band and sits on
        // the app's page. Nothing on the iPad.
        .modifier(PhoneSectionLook(section: shown))
        #endif
        .navigationTitle(shown?.title ?? "Notes")
        .toolbar {
            if shown == .recent {
                ToolbarItem {
                    Button("Clear") { model.clearRecentNotes() }
                        .help("Empty the Recent list")
                }
            }
            // Over the list it adds to, rather than away at the right by the search field.
            // Build 312: not on the phone's Actions and Inbox tabs (`fixed` is the phone's),
            // where the round + above the tabs has taken its place.
            if !hasFloatingCapture {
            ToolbarItem(placement: .navigation) {
                Button {
                    if shown == .work { makingWorkNote = true } else { model.activeSheet = .newNote }
                } label: {
                    // He chose this from a preview of six
                    // (https://claude.ai/code/artifact/77a48898-bbb1-4e3a-aeff-499b098721c7):
                    // a filled circle, which carries colour in a way no outline in a macOS
                    // toolbar can, and the plainest "add something" there is. The colour is the
                    // section's own — the same tint `ModeAccent` lays over the detail column
                    // (build 107) — so the button says which list it will add to.
                    MarkLabel("New", "plus.circle.fill", size: 16)
                        .foregroundStyle(shown?.tint ?? Color.accentColor)
                }
                .help("Add something new to this section, or to the Inbox (⌘N)")
                // On Today it opens on Capture, so it carries the name the phone's + has and
                // the screen tests press to capture (build 299: the tray button is gone).
                .accessibilityIdentifier(shown == .today ? "capture.open" : "list.newNote")
            }
            }
            if shown == .work {
                ToolbarItem {
                    Button("Hide") { model.hideWork() }
                        .help("Put the Work section away until you ask for it again")
                }
            }
        }
        .alert("New work note", isPresented: $makingWorkNote) {
            TextField("Title", text: $workNoteTitle)
            Button("Cancel", role: .cancel) { workNoteTitle = "" }
            Button("Add") {
                let title = workNoteTitle
                workNoteTitle = ""
                model.createWorkNote(title: title)
            }
        } message: {
            Text("It is kept in the vault's Work folder, out of the rest of the app.")
        }
        .alert("Rename \u{201C}\(noteToRename?.displayTitle ?? "")\u{201D}",
               isPresented: Binding(get: { noteToRename != nil }, set: { if !$0 { noteToRename = nil } })) {
            TextField("Title", text: $renameDraft)
            Button("Cancel", role: .cancel) { noteToRename = nil }
            Button("Rename") { commitRename() }
        } message: {
            Text("The file is renamed too, and every note that links to it is pointed at the new name.")
        }
        #if !os(macOS)
        // The map wants room for its diagram; every other section is a list. (The Mac's list
        // is no column of the split view since round 7: `MacMainColumns` gives it its width.)
        .navigationSplitViewColumnWidth(min: shown == .map ? 420 : 220, ideal: shown == .map ? 720 : 280)
        #endif
    }

    private func startRenaming(_ note: Note) {
        renameDraft = note.displayTitle
        noteToRename = note
    }

    /// The question before a note goes to the Deleted list. One function, because the flat list
    /// and the grouped Projects list (build 253) both ask it and must ask it the same way.
    private func askingToTrash<Content: View>(_ content: Content) -> some View {
        content
            .confirmationDialog("Delete \u{201C}\(noteToTrash?.displayTitle ?? "")\u{201D}?",
                                isPresented: Binding(get: { noteToTrash != nil }, set: { if !$0 { noteToTrash = nil } }),
                                presenting: noteToTrash) { note in
                Button("Delete", role: .destructive) { model.trash(note) }
            } message: { _ in
                Text("It goes to the Deleted list, where you can put it back.")
            }
    }

    private func commitRename() {
        guard let note = noteToRename else { return }
        noteToRename = nil
        model.renameNote(note, to: renameDraft)
    }

    @ViewBuilder
    private func emptyList(searching: Bool) -> some View {
        if !searching, let warning = model.vaultWarning {
            // "No projects yet" in front of a vault the app cannot read is a lie, and a
            // frightening one: it looks exactly like losing everything (build 100).
            EmptyStateView(title: "Not everything is here yet",
                           markName: "icloud.and.arrow.down",
                           message: "\(warning). Your notes are in the vault folder; this Mac has "
                                  + "their names but not their contents yet. They appear as they arrive.",
                           tint: .orange,
                           actionTitle: "Ask iCloud again") { model.fetchMissingNotes() }
        } else if searching {
            EmptyStateView(title: "Nothing found",
                           markName: "magnifyingglass",
                           message: "No note in this section matches what you typed. Search Everywhere (⇧⌘F) looks inside every note and task.")
        } else {
            switch shown {
            case .kind(.project)?:
                EmptyStateView(title: "No projects yet", markName: "flag",
                               message: "A project is something with an end: a race, a move, a report. Give it an outcome and a first task.",
                               tint: ParaKind.project.tint, actionTitle: "New project…") { model.activeSheet = .newNote }
            case .kind(.area)?:
                EmptyStateView(title: "No areas yet", markName: "circle.grid.2x2",
                               message: "An area is something you keep up over time: health, home, a client. It has no finish line.",
                               tint: ParaKind.area.tint, actionTitle: "New area…") { model.activeSheet = .newNote }
            case .kind(.resource)?:
                EmptyStateView(title: "No resources yet", markName: "books.vertical",
                               message: "Resources are reference material: an article, a checklist, an idea you want to keep.",
                               tint: ParaKind.resource.tint, actionTitle: "New resource…") { model.activeSheet = .newNote }
            // Both goal rows fall through to the ordinary note list while a search is
            // running, so both land here (build 199).
            case .kind(.goal)?, .aspirations?:
                EmptyStateView(title: "No goals yet", markName: SidebarSection.kind(.goal).markName,
                               message: "Goals sit above everything else. Write what you want, then point projects and areas at it with a goal: line.",
                               tint: ParaKind.goal.tint, actionTitle: "New goal…") { model.activeSheet = .newNote }
            case .kind(.archive)?:
                EmptyStateView(title: "The archive is empty", markName: "archivebox",
                               message: "Finished projects and closed areas land here. They stay searchable and stop syncing to Reminders.",
                               tint: ParaKind.archive.tint,
                               hint: "A note comes here with Move to Archive")
            case .work?:
                EmptyStateView(title: "No work notes yet", markName: SidebarSection.work.markName,
                               message: "A separate set of notes, kept out of Today, the map, the weekly review, the main search and Reminders. Nothing here is planned or synced.",
                               tint: SidebarSection.work.tint, actionTitle: "New work note…") { makingWorkNote = true }
            case .recent?:
                EmptyStateView(title: "Nothing opened yet", markName: "clock.arrow.circlepath",
                               message: "The notes you open show up here, newest first, so you can get back to what you were on.",
                               hint: "Open any note and it is listed here")
            default:
                EmptyStateView(title: "Nothing here yet", markName: "doc.text",
                               message: "Notes you add to this section show up in this list.",
                               actionTitle: "New\u{2026}",
                               action: { model.activeSheet = .newNote })
            }
        }
    }
}

/// The places an area can sit: nothing, or another area. Shared by the menu on a row
/// and the chip at the top of the note, so both offer exactly the same choices.
struct AreaParentOptions: View {
    /// Passed in rather than read from the environment: these choices are shown inside a
    /// context menu, whose content is built outside the row's own view hierarchy.
    @ObservedObject var model: AppModel
    let note: Note

    private var parent: Note? { model.index.parentArea(of: note) }
    private var children: [Note] { model.index.subAreas(of: note) }

    /// Every other area, its own sub-areas apart: they cannot hold their own parent.
    /// Picking one that is itself a sub-area lifts it out first, which is what asking for
    /// "Yoga under Mobility" means when Mobility sits under Health.
    private var candidates: [Note] {
        model.index.areasInFamilyOrder().filter { area in
            area.relativePath != note.relativePath &&
            !children.contains { $0.relativePath == area.relativePath }
        }
    }

    private func label(for area: Note) -> String {
        let name = model.index.parentArea(of: area).map { "\($0.displayTitle) \u{203A} \(area.displayTitle)" } ?? area.displayTitle
        return parent?.relativePath == area.relativePath ? "\u{2713} \(name)" : name
    }

    var body: some View {
        if let parent {
            Button("Open \(parent.displayTitle)") { model.show(parent) }
            Divider()
        }
        Button(parent == nil ? "\u{2713} Not part of another area" : "Not part of another area") {
            model.setParent(note, to: nil)
        }
        if !candidates.isEmpty {
            Divider()
            ForEach(candidates) { area in
                Button(label(for: area)) { model.setParent(note, to: area) }
            }
        }
    }
}

/// Which aspiration an area serves, written as `goal:`. The app has always read that line —
/// the review's "No project or area serves this" counts areas — but until build 134 the only
/// thing that could write one was dragging the area's box onto a goal on the Map. Build 74's
/// lesson: an action reachable only by an obscure gesture is an action nobody finds.
struct NoteGoalOptions: View {
    /// Passed in rather than read from the environment: context-menu content is built
    /// outside the row's own view hierarchy.
    @ObservedObject var model: AppModel
    let note: Note

    private var current: Note? { note.goal.flatMap { model.index.goal(matching: $0) } }

    /// **`NoteIndex` decides what is in the lists and in what order** (build 272), as it does
    /// for the New note screen's Serves lists (build 204): only live goals, in the order of the
    /// Goals and Aspirations screens, never the note itself (a goal cannot serve itself, and
    /// `setLink` refuses that without a word — build 268), and a goal the note already names
    /// stays even when it has ended, so the tick never disappears (build 175). A project lists
    /// the goals with a date first; an area or a goal lists the aspirations first (build 140).
    private var choices: GoalChoices { model.index.goalChoices(for: note) }
    private var first: [Note] { choices.first }
    private var second: [Note] { choices.second }

    /// A goal that has ended is only here because this note names it, so the line says how it
    /// ended — otherwise it looks like the menu offers finished goals.
    private func label(for goal: Note) -> String {
        let name = goal.isEnded ? "\(goal.displayTitle) (\(goal.noteStatus.label))" : goal.displayTitle
        return current?.relativePath == goal.relativePath ? "\u{2713} \(name)" : name
    }

    var body: some View {
        if let current {
            Button("Open \(current.displayTitle)") { model.show(current) }
            Divider()
        }
        Button(current == nil ? "\u{2713} Serves nothing" : "Serves nothing") {
            model.setGoal(note, to: nil)
        }
        if !first.isEmpty {
            Divider()
            ForEach(first) { goal in
                Button(label(for: goal)) { model.setGoal(note, to: goal) }
            }
        }
        if !second.isEmpty {
            Divider()
            ForEach(second) { goal in
                Button(label(for: goal)) { model.setGoal(note, to: goal) }
            }
        }
    }
}

/// Right-click an area in the list: which aspiration does it serve?
struct NoteGoalMenu: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu("Serves") {
            NoteGoalOptions(model: model, note: note)
        }
    }
}

/// The same choices at the top of an area note, beside "Part of\u{2026}".
struct NoteGoalChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    private var title: String {
        note.goal.flatMap { model.index.goal(matching: $0) }
            .map { "Serves \($0.displayTitle)" } ?? "Serves\u{2026}"
    }

    /// The star when it serves an aspiration, the target when it serves a dated goal
    /// (build 168). Before that every chip showed the star, whichever it named.
    private var symbol: String {
        note.goal.map { ChainSymbol.forGoal(named: $0, in: model.index) } ?? ChainSymbol.datedGoal
    }

    /// The deeper gold when it names an aspiration (build 189). The symbol and the colour are
    /// decided in the same breath everywhere, or one screen says star and gold while another
    /// says star and bronze.
    private var tint: Color {
        note.goal.map { ChainTint.forGoal(named: $0, in: model.index) } ?? ChainTint.datedGoal
    }

    /// Said per kind: before build 268 a goal's chip would have called the goal "this part of
    /// your life", which is what an area is.
    private var helpText: String {
        switch note.kind {
        case .project: return "Which goal this project delivers"
        case .goal: return "Which aspiration this goal serves"
        default: return "Which aspiration this part of your life serves"
        }
    }

    var body: some View {
        Menu {
            NoteGoalOptions(model: model, note: note)
        } label: {
            MarkLabel(title, symbol)
        }
        .fixedSize()
        .foregroundStyle(note.goal == nil ? Theme.soft : tint.ink)
        .help(helpText)
    }
}

/// Right-click an area in the list: where does it belong?
struct AreaParentMenu: View {
    @ObservedObject var model: AppModel
    let note: Note

    var body: some View {
        Menu("Part of") {
            AreaParentOptions(model: model, note: note)
        }
    }
}

/// The same choices at the top of an area note, where they can actually be found.
struct AreaParentChip: View {
    @ObservedObject var model: AppModel
    let note: Note

    private var title: String {
        model.index.parentArea(of: note).map { "Part of \($0.displayTitle)" } ?? "Part of\u{2026}"
    }

    var body: some View {
        Menu {
            AreaParentOptions(model: model, note: note)
        } label: {
            MarkLabel(title, "arrow.turn.left.up")
        }
        .fixedSize()
        .foregroundStyle(ParaKind.area.tint.ink)
        .help("Put this area under another area, or take it back out")
    }
}

struct NoteRow: View {
    let note: Note
    /// Filled in for goals only: how far the work under this goal has come. The row cannot
    /// work it out itself — it holds one note, and the roll-up needs the whole index.
    var goalProgress: GoalProgress? = nil
    /// The symbol for the goal this note serves — star for an aspiration, target for a dated
    /// goal (build 168). Handed in for the same reason as `goalProgress`: the row holds one
    /// note and cannot look the named goal up.
    var goalSymbol: String = ChainSymbol.datedGoal
    /// Its colour, handed in for the same reason and always with it (build 189).
    var goalTint: Color = ChainTint.datedGoal
    /// True in a list that mixes parts (build 310): the part's small icon stands where the
    /// dot stood, so the part can be told without its colour.
    var showsPart = false

    /// A note that has its own icon (build 274 for an area; every kind in `ParaKind.takesIcon`
    /// since 276: projects, areas, goals and resources) shows it here, on its colour, in place of
    /// the thin stripe every other row has. Decoration: the title beside it already names the
    /// note, so a screen reader skips it. A shape, so the selection fill leaves its colour alone
    /// (build 200).
    ///
    /// **It asks `declaredKind`, not `kind`**: a note in the Archive has the kind `.archive`, and
    /// the Archive list should keep drawing the icon the note already has (its colour is then
    /// the Archive's grey while it is Automatic, which is what `Note.tint` says for it). Only
    /// the button that *chooses* an icon is refused there.
    @ViewBuilder
    private var leadingMark: some View {
        if note.declaredKind.takesIcon, note.ownIcon.isIconOrColour {
            // A goal with a colour and no icon keeps its star or target (build 281).
            NoteIconTile(note: note, fallbackTint: note.tint, size: 30,
                         defaultMark: note.declaredKind == .goal ? ChainSymbol.forGoal(note) : nil)
                .accessibilityHidden(true)
        } else if showsPart {
            PartMark(note: note)
        } else {
            TintStripe(color: note.tint, height: 34)
        }
    }

    /// 1.0: the row is as tall as its words — a title and at most one quiet second line with
    /// the two facts that matter for this kind of note. Everything else is in the note's own
    /// facts panel. The due date goes red only when it has passed.
    private var secondLine: (text: String, overdue: Bool)? {
        var parts: [String] = []
        var overdue = false
        let progress = note.progress
        switch note.kind {
        case .project:
            if progress.total > 0 { parts.append("\(progress.done) of \(progress.total)") }
            if let due = note.dueDate {
                let days = due.days(since: .today())
                if days < 0 { overdue = true }
                parts.append(days == 0 ? "Due today" : (days > 0 ? "Due in \(days) d" : "\(-days) d overdue"))
            }
        case .goal:
            if let roll = goalProgress, let fraction = roll.fraction {
                parts.append("\(Int((fraction * 100).rounded())) %")
            }
            if let target = note.targetDate { parts.append("by \(DayWords.plain(target))") }
            else if let horizon = note.horizon { parts.append(horizon.label) }
        case .area:
            if note.openTasks.count > 0 { parts.append("\(note.openTasks.count) open") }
        case .resource:
            if !note.related.isEmpty { parts.append("\(note.related.count) linked") }
        case .daily:
            if let due = note.dueDate { parts.append(DayWords.plain(due)) }
        default:
            if note.openTasks.count > 0 { parts.append("\(note.openTasks.count) open") }
            if let due = note.dueDate {
                let days = due.days(since: .today())
                if days < 0 { overdue = true }
                parts.append(days == 0 ? "Due today" : (days > 0 ? "Due in \(days) d" : "\(-days) d overdue"))
            }
        }
        if parts.isEmpty, let goal = note.goal, note.kind != .goal { parts.append(goal) }
        if parts.isEmpty, let area = note.area, note.kind == .project { parts.append(area) }
        guard !parts.isEmpty else { return nil }
        return (parts.joined(separator: " · "), overdue)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            leadingMark
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.displayTitle)
                        .font(Txt.listTitle)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if let status = note.status, status != "active" {
                        Pill(text: status.capitalized, color: note.tint)
                    }
                }
                if let second = secondLine {
                    Text(second.text)
                        .font(Txt.listSecond)
                        .foregroundStyle(second.overdue ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    /// The same key the Goals column's button writes, so the two cannot disagree (build 166).
    @AppStorage(GoalsShowAll.key) private var goalsShowAll = false

    /// Both goal rows show a goal note in this column (build 199). Assembled here rather than
    /// repeated in the chain of `if`s below, where it is read twice.
    private var isGoalSection: Bool {
        model.section == .aspirations || model.section == .kind(.goal)
    }

    var body: some View {
        // The colour follows the section, not the note: it is there to say which mode you are
        // in, and it stays put while you click from note to note.
        detail
    }

    @ViewBuilder
    private var detail: some View {
        if model.section == .calendar {
            // The Calendar section gets the day's schedule here, with the note one click away.
            CalendarDetailView()
        } else if model.section == .templates {
            if let name = model.templateSelection {
                TemplateEditorView(name: name).id(name)
            } else {
                EmptyStateView(title: "Pick a template",
                               markName: SidebarSection.templates.markName,
                               message: "On the left are the files a new note starts from, and the snippets you can drop into one. Choose one to edit it.",
                               tint: SidebarSection.templates.tint)
            }
        } else if model.section == .snippets {
            // No selection to make: the file is the thing you edit, and the list beside it
            // says what is in it.
            TemplateEditorView(name: Snippets.fileName).id(Snippets.fileName)
        } else if model.section == .timeBlocks {
            // The day: the calendar beside your own blocks, on one hour ruler. The same view
            // fills the floating window, where the actions come with it.
            PlannerDayView()
        } else if model.section == .tags, model.selectedNotePath == nil {
            EmptyStateView(title: "Tags",
                           markName: SidebarSection.tags.markName,
                           message: "Every tag in your notes, most used first. Open one to see the notes and tasks that carry it. Write a tag as #travel anywhere in a note or a task.",
                           tint: SidebarSection.tags.tint)
        } else if model.section == .inbox, !model.inboxShowsNote {
            // Sorting happens in the middle column; this is where the lines can go.
            InboxFileItView()
        } else if model.section == .aspirations, goalsShowAll {
            // **All of them** (build 166): the whole chain for every aspiration, in one
            // scroll. Its own header carries the button that turns it off again, in the same
            // place as every other Goals header (build 167).
            AllAspirationsView()
        } else if isGoalSection, let path = model.selectedNotePath,
                  let note = model.note(at: path), note.kind == .goal {
            // The chain under the chosen goal. `GoalDetailView` draws an aspiration and a
            // goal with a date differently, so both rows lead here. The note itself is one
            // button away in its header.
            GoalDetailView(note: note).id(path)
        } else if model.section == .aspirations, model.selectedNotePath == nil {
            EmptyStateView(title: "Pick an aspiration",
                           markName: ChainSymbol.aspiration,
                           message: "An aspiration says what you are becoming. Choose one on the left and everything working towards it appears here: the goals with a date, the projects under them, and the next action on each. The button at the top right shows all of them at once.",
                           tint: ChainTint.aspiration)
        } else if model.section == .kind(.goal), model.selectedNotePath == nil {
            EmptyStateView(title: "Pick a goal",
                           markName: ChainSymbol.datedGoal,
                           message: "A goal with a date says what you will have done, and by when. Choose one on the left to see the projects under it and the next action on each.",
                           tint: ChainTint.datedGoal)
        } else if let path = model.selectedNotePath, model.note(at: path) != nil {
            NoteEditorView(path: path)
                .id(path)
        } else if model.section == .done {
            EmptyStateView(title: "What you finished",
                           markName: "checkmark.circle",
                           message: "Press a task on the left to open the note it came from.",
                           tint: SidebarSection.done.tint)
        } else {
            // Build 291: no words — he asked for the text to go. The icon and the button stay.
            EmptyStateView(title: "",
                           markName: "doc.text",
                           message: "Choose a note in the middle column, or make a new one.",
                           actionTitle: "New…",
                           action: { model.activeSheet = .newNote })
        }
    }
}

extension SyncStatusBar {
    /// Build 291: the tip says what the button does and that nothing is needed from him.
    static func tip(_ report: SyncReport?, every minutes: Int) -> String {
        let auto = minutes > 0 ? " It also runs by itself every \(minutes) minutes." : ""
        // Round 9 (build 316): a press opens the small menu since build 312, so the tip no
        // longer says "Sync … now".
        let head = "The sync with Apple Reminders. Press for Sync now and the other choices; ⇧⌘R syncs at once.\(auto)"
        guard let report else { return head }
        let time = DayWords.time(report.finishedAt ?? report.startedAt)
        if !report.conflicts.isEmpty {
            return "\(head)\nLast sync at \(time): \(report.conflicts.count) to look at — open Last sync report…"
        }
        if !report.warnings.isEmpty {
            return "\(head)\nSynced at \(time) — all fine. \(report.warnings.count) things worth knowing, nothing to do (Last sync report…)."
        }
        return "\(head)\nSynced at \(time) — all fine."
    }
}

// MARK: - Colour

/// One colour per PARA bucket, carried through every screen: Projects green,
/// Areas pink, Resources blue, Archive grey, plus a hue for each action list.
/// Each name resolves to a colour set with a light and a dark variant.
extension ParaKind {
    var tint: Color {
        switch self {
        case .project: return Color("ProjectTint")
        case .area: return Color("AreaTint")
        case .resource: return Color("ResourceTint")
        case .archive: return Color("ArchiveTint")
        case .goal: return Color("GoalTint")
        case .inbox: return Color("InboxTint")
        case .daily: return Color("CalendarTint")
        }
    }
}

extension SidebarSection {
    var tint: Color {
        switch self {
        case .inbox: return Color("InboxTint")
        case .today: return Color("CalendarTint")
        case .calendar: return Color("CalendarTint")
        case .timeBlocks: return Color("CalendarTint")
        case .done: return Color("ReviewTint")
        case .allActions: return Color("ProjectTint")
        case .recent: return Color("ResourceTint")
        case .deleted: return Color("ArchiveTint")
        case .templates: return Color("ResourceTint")
        case .snippets: return Color("InboxTint")
        case .tags: return Color("AreaTint")
        case .review: return Color("ReviewTint")
        case .map: return Color("GoalTint")
        case .search: return Color("ResourceTint")
        // The deeper gold of build 189. `ChainTint.aspiration` is where it is spelled.
        case .aspirations: return ChainTint.aspiration
        // Its own colour, belonging to none of the PARA buckets — it is not one of them.
        case .work: return Color("ArchiveTint")
        case .kind(let kind): return kind.tint
        }
    }
}

extension Note {
    /// A note's colour. **An aspiration is the one note whose colour is not simply its kind's**
    /// (build 189): it is the head of the goal family and wears the deeper gold. `ChainTint` is
    /// the one place that is decided, so this and the chips cannot drift apart.
    var tint: Color { kind == .goal ? ChainTint.forGoal(self) : kind.tint }
}

/// A small filled circle carrying a bucket's colour and symbol.
struct KindBadge: View {
    let kind: ParaKind
    var size: CGFloat = 22
    /// Overrides the kind's own symbol. An aspiration and a goal with a date are both `.goal`
    /// notes and are not the same thing, so the Goals screen hands in its own (build 164).
    var markName: String? = nil
    /// Overrides the kind's own colour, for the same reason and always in the same breath as
    /// `markName`: since build 189 an aspiration is the deeper gold, so a badge that carries
    /// the star must carry that colour too.
    var tint: Color? = nil

    var body: some View {
        // A fixed 16, as before build 311: the disc does not grow with the text size, so
        // the mark in it must not either.
        MarkImage(markName ?? SidebarSection.kind(kind).markName, size: 16)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            // Build 310: white on a part colour always sits on the deep shade.
            .background((tint ?? kind.tint).deep, in: Circle())
            .accessibilityLabel(kind.displayName)
    }
}

/// The coloured stripe down the leading edge of a row.
struct TintStripe: View {
    let color: Color
    /// Ignored since 1.0: the mark is a dot, not a stripe, and a dot has one size.
    var height: CGFloat = 30

    var body: some View {
        // 1.0: an 8-point dot in the part's colour, the one list mark in the app.
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

/// **The part's small icon where a list mixes parts** (build 310): Recent, Deleted, a search
/// across the vault. It stands where the 8-point dot stands in a list of one part, in the
/// same colour — the shape says which part it is to an eye that cannot tell the colours
/// apart. 14 points, lower than a line of words, so no row grows. A list of one part keeps
/// its dot: there the dot says nothing a shape would have to repeat.
/// The "Search notes" field of a list. **Not on the iPhone** since round 6 (build 312): there
/// the one search is the field at the top of Browse, and a second, different one that only
/// showed after a pull down was what the review found. The Mac and the iPad keep theirs.
private struct ListSearch: ViewModifier {
    @Binding var text: String
    @Environment(\.phoneLook) private var phoneLook

    func body(content: Content) -> some View {
        #if os(macOS)
        // Round 7 (build 314): the Mac has one search, the field in the toolbar on every
        // screen (`MacToolbarSearch`). A second one that showed on some lists only is gone.
        content
        #else
        if phoneLook {
            content
        } else {
            content.searchable(text: $text, prompt: "Search notes")
        }
        #endif
    }
}

extension View {
    func listSearch(_ text: Binding<String>) -> some View { modifier(ListSearch(text: text)) }
}

struct PartMark: View {
    let markName: String
    let color: Color

    init(markName: String, color: Color) {
        self.markName = markName
        self.color = color
    }

    /// A note's part: the star or the target for a goal, as everywhere else (build 168).
    init(note: Note) {
        self.init(markName: note.kind == .goal ? ChainSymbol.forGoal(note)
                                               : SidebarSection.kind(note.kind).markName,
                  color: note.tint)
    }

    var body: some View {
        MarkImage(markName, size: 14)
            // A symbol in a row that can be chosen: it steps aside on the selection's fill.
            .rowTint(color)
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            .accessibilityHidden(true)
    }
}


// MARK: - A picked folder, looked at before it is opened (build 308, hardening-16)

/// Presents `FolderChoiceView` for the view that asked. Both places with a folder picker (the
/// welcome screen and Settings) can be on screen at once on the Mac, so each shows the sheet
/// only for its own question.
struct FolderChoiceSheet: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @Binding var asked: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { asked && model.folderChoice != nil },
            set: { shown in
                if !shown {
                    asked = false
                    model.cancelFolderChoice()
                }
            }
        )) {
            FolderChoiceView()
                .environmentObject(model)
        }
    }
}

/// What a look at the picked folder found, with Cancel and one main button. Nothing has been
/// written when this is on screen; Cancel (Escape on the Mac) leaves the folder untouched.
struct FolderChoiceView: View {
    @EnvironmentObject private var model: AppModel

    private var finding: FolderLook.Finding? { model.folderChoice?.finding }

    static func notes(_ count: Int) -> String {
        count == 1 ? "1 note" : "\(count.formatted()) notes"
    }

    /// The headline, the smaller lines under it, and the main button's words (nil: only Cancel).
    private var words: (headline: String, details: [String], action: String?) {
        let caution = "This folder is in iCloud and may not be fully listed on \(AppModel.thisDevice) yet. If it should hold more, cancel and try again in a minute."
        switch finding {
        case nil:
            return ("Looking at this folder…", ["Nothing is written."], nil)
        case .stillListing:
            return ("iCloud is still listing this folder.", ["PARAGON is waiting and has written nothing. This can take a minute."], nil)
        case .unreadable:
            return ("PARAGON cannot read this folder.", ["Nothing was written. Choose another folder."], nil)
        case .vault(let count):
            var details = ["It is a PARAGON vault."]
            if model.folderChoice?.mayBeIncomplete == true { details.append(caution) }
            return ("This folder has \(Self.notes(count)).", details, "Open it")
        case .notAVault(let count):
            var details: [String] = []
            if count > 0 { details.append("It has \(Self.notes(count)) of its own. They stay as they are.") }
            details.append("Setting it up adds the PARAGON folders, an Inbox note and templates.")
            if model.folderChoice?.mayBeIncomplete == true { details.append(caution) }
            return ("This folder is not a PARAGON vault.", details, "Set it up here")
        }
    }

    var body: some View {
        let words = words
        VStack(alignment: .leading, spacing: 8) {
            Text(model.folderChoice?.name ?? "")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                if words.action == nil, finding != .unreadable { ProgressView().controlSize(.small) }
                Text(words.headline)
                    .font(Txt.sectionTitle)
                    .accessibilityIdentifier("folderChoice.headline")
            }
            ForEach(words.details, id: \.self) { line in
                Text(line)
                    .font(Txt.list)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { model.cancelFolderChoice() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("folderChoice.cancel")
                if let action = words.action {
                    Button(action) { model.confirmFolderChoice() }
                        .buttonStyle(.filled(Theme.fallbackTint))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("folderChoice.confirm")
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 400)
        #else
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.height(260)])
        // The same solid page as the restore sheet (build 315 polish): never see-through.
        .presentationBackground(Theme.canvas)
        #endif
        .accessibilityIdentifier("folderChoice.sheet")
    }
}
