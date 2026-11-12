import SwiftUI
import ParagonCore

#if os(iOS)
/// The iPhone layout: five tabs — Today, Plan, Actions, Inbox and Browse — each tab a stack
/// that pushes the note editor. Used when the window is compact; iPad and Mac keep the columns.
///
/// **Build 183** made Plan the day and All actions tabs of their own and turned Quick capture
/// into a button on Today. It also made the tabs swipeable, with a page-style `TabView` and a
/// bar of our own.
///
/// **Build 232 went back to the system's own tab bar, his choice.** The swipe crashed the app:
/// both crash reports Apple sent (builds 227 and 228) end in an assertion inside
/// `-[UINavigationBar layoutSubviews]`. A page view keeps all five pages alive side by side,
/// each with its own `NavigationStack` and so its own navigation bar, and iOS 27 lost track of
/// which bar owned which title while a page slid or a sheet closed. The system `TabView` gives
/// each tab its own navigation controller the way UIKit expects, so that cannot happen. The
/// price is the swipe; tapping a tab does the same thing, and the Inbox badge is the system's.
struct PhoneRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .today

    enum Tab: Int, Hashable, CaseIterable, Identifiable {
        case today, plan, actions, inbox, browse

        var id: Int { rawValue }

        /// Also what the screen tests press (`app.tabBars.buttons[title]`): the system's tab bar
        /// carries no identifier of our own, so these words are the one place a test has to
        /// match what he sees (build 232). Rename a tab and `ScreenTests.tabTitles` with it.
        var title: String {
            switch self {
            case .today: return "Today"
            case .plan: return "Plan"
            case .actions: return "Actions"
            case .inbox: return "Inbox"
            case .browse: return "Browse"
            }
        }

        var symbol: String {
            switch self {
            case .today: return "sun.max"
            case .plan: return SidebarSection.timeBlocks.markName
            case .actions: return SidebarSection.allActions.markName
            case .inbox: return "tray"
            case .browse: return "square.grid.2x2"
            }
        }

        /// The section this tab stands on, or nil for Browse, which has none of its own.
        /// Read back from `SidebarSection` rather than spelled again, so the tab and the row
        /// it replaces cannot drift (build 168).
        var section: SidebarSection? {
            switch self {
            case .today: return .today
            case .plan: return .timeBlocks
            case .actions: return .allActions
            case .inbox: return .inbox
            case .browse: return nil
            }
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases) { item in
                page(for: item)
                    // 1.0: colour with meaning — the bar items and buttons of a tab wear the
                    // tab's colour, not the system blue.
                    .tint(item.section?.tint ?? Color.accentColor)
                    // The focus timer's bar, above the tabs on every page (build 256). Nothing
                    // while no timer runs.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        FocusBar()
                    }
                    .tabItem { Label { Text(item.title) } icon: { Marks.image(item.symbol) } }
                    // Zero draws no badge, so only the Inbox ever shows a number.
                    .badge(item == .inbox ? model.count(for: .inbox) : 0)
                    .tag(item)
            }
        }
        // A section asked for from another tab — the **Week** button on **Plan** is the first
        // (build 225). Browse is the tab that can hold any section, so the request chooses it
        // here and `PhoneStack` pushes the screen in the same turn.
        .onChange(of: model.sectionRequest) { _, request in
            guard request.count > 0, tab != .browse else { return }
            tab = .browse
        }
    }

    /// One page. A `switch` inside a `@ViewBuilder` is fine; a `var` would not be (build 58).
    @ViewBuilder
    private func page(for item: Tab) -> some View {
        switch item {
        case .today:
            PhoneStack(section: item.section, isActive: tab == item) {
                TodayView()
                    .navigationTitle("Today")
                    .toolbar {
                        // The same **+** as Plan, Actions and Inbox (build 230, his ask), so
                        // every tab has one button in one place. It opens the New note screen
                        // with **Capture** already chosen (`NewThing.forSection(.today)`), so a
                        // quick line is still one press away. Leading, because Today is the
                        // root of its stack and has no back button: the phone's bar fits a
                        // title and one control per side (build 88).
                        //
                        // Still named `capture.open` for the screen tests: pressing it still
                        // opens the capture screen, which is what that name has always meant.
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                model.activeSheet = .newNote
                            } label: {
                                MarkImage("plus.circle.fill", size: 22)
                                    .accessibilityLabel("New")
                            }
                            .accessibilityIdentifier("capture.open")
                        }
                        PhoneSyncItem()
                    }
            }
        case .plan:
            PhoneStack(section: item.section, isActive: tab == item) {
                // Its own section, never "whatever is current" (build 229): the pager keeps
                // every page alive, so a list that followed `model.section` became a copy of
                // whichever page was in front.
                NoteListView(fixed: item.section)
                    .toolbar { PhoneSyncItem() }
            }
        case .actions:
            PhoneStack(section: item.section, isActive: tab == item) {
                // Its own section, never "whatever is current" (build 229): the pager keeps
                // every page alive, so a list that followed `model.section` became a copy of
                // whichever page was in front.
                NoteListView(fixed: item.section)
                    .toolbar { PhoneSyncItem() }
            }
        case .inbox:
            PhoneStack(section: item.section, isActive: tab == item) {
                // Its own section, never "whatever is current" (build 229): the pager keeps
                // every page alive, so a list that followed `model.section` became a copy of
                // whichever page was in front.
                NoteListView(fixed: item.section)
                    .toolbar { PhoneSyncItem() }
            }
        case .browse:
            PhoneStack(section: item.section, isActive: tab == item) {
                PhoneBrowseView()
            }
        }
    }
}

/// Sync with Reminders from the phone. The Mac has this in the window toolbar; without it
/// here the phone could only wait for auto sync, and iOS never asked for Reminders access.
///
/// Build 300, the clock ring: the button itself says where the sync stands, so the
/// "Synced at" pill on Today is gone. A ring round the button is full just after a sync and
/// runs down over two hours — green for the first hour, then yellow; a whole red ring when
/// the last sync had conflicts — with a small word under it (the time, "Yesterday", …).
/// Press = sync now; long press = the old pill's menu, Sync settings included.
/// Build 300: the clock ring and the word under it are wider than the round glass iOS 26
/// draws behind a toolbar button, which cut the word off — so this one item has none.
struct PhoneSyncItem: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() }
        }
    }
}

struct PhoneSyncButton: View {
    @EnvironmentObject private var model: AppModel

    private var finishedAt: Date? { model.lastReport.map { $0.finishedAt ?? $0.startedAt } }
    private var conflicts: Int { model.lastReport?.conflicts.count ?? 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Button {
                Task { await model.syncNow() }
            } label: {
                label(now: context.date)
            }
            .buttonStyle(.plain)
        }
        .disabled(model.vault == nil)
        // Build 301 (his ask): a gentle tap you can feel when a sync finishes — a soft one
        // when all is well, the warning buzz when it ended with conflicts.
        .sensoryFeedback(trigger: model.isSyncing) { was, now in
            guard was, !now else { return nil }
            return conflicts > 0 ? .warning : .impact(flexibility: .soft, intensity: 0.6)
        }
        .contextMenu {
            Button("Sync now") { Task { await model.syncNow() } }
            Button("Show me what would change…") { Task { await model.previewSync() } }
            if model.lastReport != nil {
                Button("Last sync report…") { model.showLastReport() }
            }
            Divider()
            Button("Sync settings…") {
                model.settingsJumpToSync = true
                model.phoneSyncSettingsRequests += 1
            }
        }
        .accessibilityIdentifier("sync.status")
    }

    private func label(now: Date) -> some View {
        SyncRingMark(now: now, axis: .vertical, ring: 26)
    }
}

/// One tab's navigation stack. Selecting a note anywhere in the model pushes the editor
/// on the active tab; going back clears the selection.
struct PhoneStack<Content: View>: View {
    @EnvironmentObject private var model: AppModel
    let section: SidebarSection?
    let isActive: Bool
    @ViewBuilder let content: () -> Content
    @State private var path: [PhoneRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: PhoneRoute.self) { route in
                    switch route {
                    case .note(let notePath):
                        NoteEditorView(path: notePath)
                            .id(notePath)
                            .navigationBarTitleDisplayMode(.inline)
                    case .section(let section):
                        PhoneSectionScreen(section: section)
                    case .template(let name):
                        TemplateEditorView(name: name)
                            .id(name)
                            .navigationBarTitleDisplayMode(.inline)
                    case .settings:
                        SettingsView()
                            .navigationTitle("Settings")
                    }
                }
        }
        .onAppear {
            if isActive, let section, model.section != section { model.section = section }
        }
        .onChange(of: isActive) { _, active in
            if active, let section, model.section != section { model.section = section }
            if active, let selected = model.selectedNotePath, path.last != .note(selected) { path.append(.note(selected)) }
        }
        // A template opens the same way a note does: the middle column picks one, this pushes it.
        .onChange(of: model.templateSelection) { _, selected in
            guard isActive, model.section == .templates else { return }
            if let selected {
                if path.last != .template(selected) { path.append(.template(selected)) }
            } else if case .template = path.last {
                path.removeLast()
            }
        }
        // Revealing Work has to open it here as well: the Mac's columns watch the section,
        // but on the phone a screen exists only once it has been pushed (build 117). The
        // Browse tab is the one with no section of its own.
        //
        // Driven by the *count* of requests, not by `workRevealed`: that flag changes on the
        // first long press and never again, so the second one went nowhere (build 122).
        // Build 300: "Sync settings…" on the sync button's long-press menu opens Settings at
        // the Reminders sync part, on the tab in front.
        .onChange(of: model.phoneSyncSettingsRequests) { _, _ in
            guard isActive else { return }
            if path.last != .settings { path.append(.settings) }
        }
        .onChange(of: model.workRequests) { _, _ in
            guard isActive, section == nil else { return }
            if path.last != .section(.work) { path.append(.section(.work)) }
        }
        // **No `isActive` guard here, unlike every other handler in this stack.** The request
        // arrives from a different tab, so Browse is not on screen yet when it lands; the
        // screen is pushed onto this stack and `PhoneRootView` switches to it in the same
        // turn. A guard would have made the button do nothing at all the first time.
        .onChange(of: model.sectionRequest) { _, request in
            guard self.section == nil, request.count > 0 else { return }
            if path.last != .section(request.section) { path.append(.section(request.section)) }
        }
        // Hiding is still a change of the flag, and only ever in one direction.
        .onChange(of: model.workRevealed) { _, revealed in
            guard isActive, section == nil, !revealed else { return }
            if path.last == .section(.work) { path.removeLast() }
        }
        .onChange(of: model.selectedNotePath) { _, selected in
            guard isActive else { return }
            if let selected {
                if path.last != .note(selected) { path.append(.note(selected)) }
            } else if case .note = path.last {
                path.removeLast()
            }
        }
        .onChange(of: path) { _, newPath in
            guard isActive else { return }
            let showsNote = newPath.contains { if case .note = $0 { return true } else { return false } }
            if !showsNote, model.selectedNotePath != nil { model.selectedNotePath = nil }
            let showsTemplate = newPath.contains { if case .template = $0 { return true } else { return false } }
            if !showsTemplate, model.templateSelection != nil { model.templateSelection = nil }
            if case .section(let section)? = newPath.last, model.section != section { model.section = section }
        }
    }
}

enum PhoneRoute: Hashable {
    case note(String)
    case template(String)
    case section(SidebarSection)
    case settings
}

/// The Browse tab: every section as a row, plus Settings.
struct PhoneBrowseView: View {
    @EnvironmentObject private var model: AppModel

    private let groups: [(String, [SidebarSection])] = [
        // Aspirations first, then the goals with a date: that is the order of the chain, and
        // two rows since build 199.
        ("Goals and PARA", [.aspirations, .kind(.goal), .kind(.project), .kind(.area), .kind(.resource), .kind(.archive)]),
        // Time Blocks and All actions are not here: they are tabs of their own since build
        // 183, and a second door into one room is what build 166 argued against.
        ("Plan", [.calendar, .review, .map, .recent, .done, .deleted, .search]),
        ("Tools", SidebarSection.tools),
    ]

    var body: some View {
        List {
            ForEach(groups, id: \.0) { group in
                Section(group.0) {
                    ForEach(group.1) { section in
                        NavigationLink(value: PhoneRoute.section(section)) {
                            Label {
                                HStack {
                                    Text(section.title)
                                    Spacer()
                                    let count = model.count(for: section)
                                    if count > 0 {
                                        Text("\(count)").foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                MarkImage(section.markName)
                                    .foregroundStyle(section.tint)
                            }
                        }
                        .accessibilityIdentifier("browse.\(section.key)")
                    }
                }
            }
            Section {
                NavigationLink(value: PhoneRoute.settings) {
                    MarkLabel("Settings and Help", "gear")
                }
            }
            Section {
                // The other way in, and the one that can actually be found: a long press here.
                // The title in the navigation bar is small and easy to miss (build 117).
                Text("PARAGON \(AppVersion.text)")
                    .font(Txt.label)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
                    .accessibilityIdentifier("browse.version")
            }
            // Only there once it has been asked for; see the long press below.
            if model.workRevealed {
                Section {
                    NavigationLink(value: PhoneRoute.section(.work)) {
                        Label {
                            HStack {
                                Text(SidebarSection.work.title)
                                Spacer()
                                Text("\(model.workNotes.count)").foregroundStyle(.secondary)
                            }
                        } icon: {
                            MarkImage(SidebarSection.work.markName)
                                .foregroundStyle(SidebarSection.work.tint)
                        }
                    }
                }
            }
        }
        // 1.0: Apple's large title, which shrinks as the list scrolls. The long press that
        // reveals Work lives on the version row at the foot of this list (build 117), which is
        // the way in that can actually be found; the title's own long press (build 112) is gone
        // with the inline title it needed.
        .navigationTitle("Browse")
    }
}

/// A section opened from Browse: the same list as the middle column on the Mac.
struct PhoneSectionScreen: View {
    @EnvironmentObject private var model: AppModel
    let section: SidebarSection

    var body: some View {
        NoteListView(fixed: section)
            .onAppear { if model.section != section { model.section = section } }
    }
}
#endif
