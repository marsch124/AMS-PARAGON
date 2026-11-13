import SwiftUI
import ParagonCore
#if os(macOS)
import AppKit
#endif

@main
struct ParagonApp: App {
    // The one model (build 317): the actions in Shortcuts and Siri use the same one, also
    // when the system has started the app in the background and no window exists.
    @StateObject private var model = AppModel.shared
    // Only so the reminders' delegate is in place before launch finishes: a press on a
    // notification can start the app from cold (builds 234 and 270).
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ReminderAppDelegate.self) private var reminderDelegate
    #else
    @NSApplicationDelegateAdaptor(ReminderAppDelegate.self) private var reminderDelegate
    #endif
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("showSyncMenuBarItem") private var showSyncMenuBarItem = true
    static let plannerWindowID = "planner"
    /// The main window's name, so the menu bar clock's **Show PARAGON** can open a fresh one when
    /// it was closed (build 257's review).
    static let mainWindowID = "main"
    /// The Map's own window on the Mac (build 285): one only, big, beside the main window.
    static let mapWindowID = "map"

    var body: some Scene {
        WindowGroup(id: ParagonApp.mainWindowID) {
            ContentView()
                .environmentObject(model)
                // A link opened while this window is up (a click on the Today's plan widget)
                // goes to this window and does not make a second one (build 276).
                .modifier(TakesLinksInOpenWindow())
                // Build 317: a press on a note in the system search opens it here.
                .modifier(SystemSearchLink(model: model))
        }
        .commands {
            // `replacing:`, not `after:`. A WindowGroup puts its own "New Window" in this
            // group with ⌘N already on it, and the system item wins: adding a second ⌘N
            // after it meant ⌘N opened an empty second window and never the sheet
            // (build 120). Replacing the group takes New Window out and gives ⌘N back.
            CommandGroup(replacing: .newItem) {
                Button("New…") { model.activeSheet = .newNote }
                    .keyboardShortcut("n", modifiers: [.command])
                    .disabled(model.vault == nil)
                Button("Quick Capture…") { model.activeSheet = .quickCapture }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                // Round 9 (build 316): no dots; it opens no dialog.
                Button("Search Everywhere") { model.section = .search }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(model.vault == nil)
                Button("Sync with Reminders") { Task { await model.syncNow() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.vault == nil || model.isSyncing)
                // The Work section's shortcut. Deliberately not ⌥⌘W, which macOS keeps for
                // closing every window, and deliberately not named in the manual.
                Button(model.workRevealed ? "Hide Work" : "Work") {
                    if model.workRevealed { model.hideWork() } else { model.revealWork() }
                }
                .keyboardShortcut("w", modifiers: [.command, .control])
                .disabled(model.vault == nil)
            }
            // Its own menu, so the shortcuts work wherever the focus happens to be — the
            // toolbar buttons only exist while a note is open.
            CommandMenu("Go") {
                #if os(macOS)
                // The planner is the Time Blocks section itself since build 150. This is the
                // extra he asked to keep: the same three parts in a window of their own, which
                // can stay up while a note is open in the main window.
                PlannerMenuButton()
                    .disabled(model.vault == nil)
                MapMenuButton()
                    .disabled(model.vault == nil)
                Divider()
                #endif
                // Arrows, not the browsers' \u{2318}[ and \u{2318}]: on a Swedish keyboard those
                // brackets are \u{2325}8 and \u{2325}9, so the shortcut would be a three-finger
                // chord and the menu would advertise a key he does not have.
                // Round 7 (build 314): ⌘1 to ⌘5 for the sidebar's first five rows.
                // Round 8 (build 315): ⌘6 Projects and ⌘7 Weekly review follow them.
                ForEach(Array(SidebarGroups.numbered.enumerated()), id: \.offset) { index, key in
                    if let section = SidebarSection.all.first(where: { $0.key == key }) {
                        Button(section.title) { model.section = section }
                            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
                            .disabled(model.vault == nil)
                    }
                }
                Divider()
                #if os(macOS)
                // Not ⌥⌘W (macOS closes every window with it) and not ⌃⌘W (Work).
                Button("Close Note") { model.closeNote() }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .control])
                    .disabled(!WindowColumns.canCloseNote(section: model.section?.key, noteOpen: model.selectedNotePath != nil))
                #endif
                Button("Back") { model.goBack() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
                    .disabled(!model.canGoBack)
                Button("Forward") { model.goForward() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
                    .disabled(!model.canGoForward)
            }
            #if os(macOS)
            // Round 8 (build 315): Edit › Find in Note, with Apple's own find bar over the
            // note's text. ⌘F here; ⇧⌘F stays Search Everywhere (round 7). ⌘G and ⇧⌘G are the
            // Mac's own keys for next and previous.
            CommandGroup(after: .textEditing) {
                Button("Find in Note") { model.findInNote() }
                    .keyboardShortcut("f", modifiers: [.command])
                    .disabled(model.selectedNotePath == nil)
                Button("Find Next") { NoteFind.run(.next) }
                    .keyboardShortcut("g", modifiers: [.command])
                    .disabled(model.selectedNotePath == nil)
                Button("Find Previous") { NoteFind.run(.previous) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(model.selectedNotePath == nil)
            }
            // Build 287/288: Format › Bold, Italic, Strikethrough, Heading, sent to the note's text view.
            CommandGroup(replacing: .textFormatting) {
                Button("Bold") { NSApp.sendAction(#selector(LinkingTextView.paragonBold(_:)), to: nil, from: nil) }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("Italic") { NSApp.sendAction(#selector(LinkingTextView.paragonItalic(_:)), to: nil, from: nil) }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("Strikethrough") { NSApp.sendAction(#selector(LinkingTextView.paragonStrike(_:)), to: nil, from: nil) }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Heading") { NSApp.sendAction(#selector(LinkingTextView.paragonHeading(_:)), to: nil, from: nil) }
                    .keyboardShortcut("h", modifiers: [.command, .option])
            }
            #endif
            CommandGroup(replacing: .help) {
                #if os(macOS)
                HelpMenuButtons()
                #endif
                Button("Copy Diagnostics") { model.copyDiagnostics() }
                    // Not ⌥⌘D: that is macOS's own "hide the Dock" and never reaches the app.
                    .keyboardShortcut("d", modifiers: [.command, .control])
            }
        }
        #if os(macOS)
        // The extra window, opened from Go \u{203a} Plan the Day. The planner itself is the
        // Time Blocks section; this keeps a copy of it up while a note is open. The iPhone has
        // no windows, and no need of one: there the section is the whole planner.
        Window("Plan", id: ParagonApp.plannerWindowID) {
            PlannerView()
                .environmentObject(model)
                // This window has no timer bar, so no Focus on this (build 256).
                .environment(\.focusBarShown, false)
                .frame(minWidth: 720, minHeight: 480)
                .modifier(HandsInMainWindowOpener(model: model))
        }
        .defaultSize(width: 900, height: 620)
        // Build 285, his ask: the Map in a window of its own, so it has the whole width a
        // drawing needs instead of the middle column. `Window`, not `WindowGroup`: there is
        // only ever one, and asking again brings it to the front.
        Window("Map", id: ParagonApp.mapWindowID) {
            MapView(ownWindow: true)
                .environmentObject(model)
                .environment(\.focusBarShown, false)
                .frame(minWidth: 640, minHeight: 420)
                .modifier(HandsInMainWindowOpener(model: model))
        }
        .defaultSize(width: 1200, height: 800)
        MenuBarExtra(isInserted: $showMenuBarItem) {
            QuickCaptureView(compact: true)
                .environmentObject(model)
                .modifier(HandsInMainWindowOpener(model: model))
        } label: {
            // 1.0: the hand-drawn capture tray, as a template image the menu bar can draw.
            Image(nsImage: Marks.nsImage("tray.and.arrow.down"))
            Text("PARAGON quick capture")
        }
        .menuBarExtraStyle(.window)
        // Build 303: the sync clock ring, its own item beside the capture tray.
        MenuBarExtra(isInserted: $showSyncMenuBarItem) {
            MenuBarSyncMenu()
                .environmentObject(model)
        } label: {
            MenuBarSyncLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.menu)
        Settings {
            SettingsView()
                .environmentObject(model)
                .modifier(HandsInMainWindowOpener(model: model))
        }
        WindowGroup("PARAGON Help", id: "help", for: HelpView.Page.self) { page in
            HelpView(page: page.wrappedValue ?? .howItWorks)
                .modifier(HandsInMainWindowOpener(model: model))
        }
        .defaultSize(width: 720, height: 640)
        #endif
    }
}

/// Makes the main window the one that takes a link while it is open (build 276).
///
/// **Without this modifier SwiftUI makes a new window for every link.** Its own rule, from the
/// documentation of `handlesExternalEvents`: it sends an event to the first open scene that
/// prefers to handle it, then to the first that can, and "if it finds neither — including when
/// you don't add this view modifier — SwiftUI creates a new scene for the event". Nobody has
/// seen it, but a click on the **Today's plan** widget (build 273, `amspara:///plan`) would have
/// opened a second PARAGON window beside the one already up.
///
/// - **`"*"` matches any link**, and the Mac's `amspara://` links are all handled in one place
///   (`AppModel.handle(url:)`), so the main window does not need to tell them apart.
/// - **Only this scene carries it.** **Plan the day**, Help and Settings never prefer or allow a
///   link, so they never start receiving the main window's links.
/// - **With no main window open, nothing changes**: the event creates a new scene of the first
///   scene declaration without a `handlesExternalEvents(matching:)`, which is this window group.
/// - **The menu bar clock's Show PARAGON is not an external event** (it uses `openWindow`), so it
///   is not touched.
/// - A modifier, so no `#if` sits in the middle of the scene's chain (build 148). The iPhone has
///   one scene and the documentation says it ignores this modifier there; it is left off so the
///   iPad, where nobody has reported a second window, is not changed in a build about the Mac.
struct TakesLinksInOpenWindow: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        #else
        content
        #endif
    }
}

#if os(macOS)
/// Help menu items that open the help window on the chosen page.
struct HelpMenuButtons: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("How PARAGON Works") { openWindow(id: "help", value: HelpView.Page.howItWorks) }
            .keyboardShortcut("?", modifiers: [.command])
        Button("Words in PARAGON") { openWindow(id: "help", value: HelpView.Page.words) }
        Button("What\u{2019}s New") { openWindow(id: "help", value: HelpView.Page.versionHistory) }
    }
}

/// The Mac's Settings row for the list of words. Settings is its own window there, so the row
/// opens the Help window on that page rather than pushing a screen (build 228).
struct WordsWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Words in PARAGON") { openWindow(id: "help", value: HelpView.Page.words) }
    }
}

/// A Settings row on the Mac that opens the Help window on one page (round 8, build 315).
struct HelpWindowButton: View {
    let page: HelpView.Page
    let label: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(label) { openWindow(id: "help", value: page) }
    }
}
#endif

#if os(macOS)
/// Every Mac scene hands `openWindow` to the model, not only the main window (build 257's third
/// review): a launch that brings back only **Plan the day** or Help has no main window, and the
/// menu bar clock's **Show PARAGON** must still be able to open one. A Dock click would not:
/// it opens a window only when none is visible.
struct HandsInMainWindowOpener: ViewModifier {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            if model.openMainWindow == nil {
                model.openMainWindow = { [openWindow] in openWindow(id: ParagonApp.mainWindowID) }
            }
        }
    }
}

/// Opens the planner window from the Go menu. Its own view because `openWindow` is read from
/// the environment, which a `View` has and the `App` struct does not — the same shape as
/// `HelpMenuButtons`.
/// Go › Map (build 285): opens the Map's own window, or brings it to the front.
struct MapMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Map") { openWindow(id: ParagonApp.mapWindowID) }
            .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}

struct PlannerMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Round 9 (build 316): no dots; it opens a window, not a dialog (as "Map" beside it).
        Button("Plan") { openWindow(id: ParagonApp.plannerWindowID) }
            .keyboardShortcut("p", modifiers: [.command, .shift])
    }
}
#endif
