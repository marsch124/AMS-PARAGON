import SwiftUI
import ParagonCore

#if os(iOS)
/// The iPhone layout: five tabs you can **swipe** between — Today, Plan, Actions, Inbox and
/// Browse — each tab a stack that pushes the note editor. Used when the window is compact;
/// iPad and Mac keep the columns.
///
/// **Build 183, and he chose the shape.** He asked for the swipe of build 181 to work "on every
/// screen, not only the time block". Two screens he reaches for all day — **Plan the day** and
/// **All actions** — were buried inside Browse, so they became tabs of their own, and Quick
/// capture became a button on Today rather than a fifth row in the bar.
///
/// **The bar is ours, not the system's, and that is the whole trick.** SwiftUI's ordinary
/// `TabView` does not swipe; the page style swipes but draws dots instead of a bar. So the
/// pages are a page-style `TabView` with the dots turned off, and `PhoneTabBar` below it writes
/// to the same selection. What we give up with the system bar — the badge, the tap-to-scroll-to-
/// top — is drawn or done here instead.
///
/// The drag from the **left edge** still belongs to iOS: it is *go back*, and a page view leaves
/// it alone. That is why this is a pager and not a gesture of our own (builds 71–74).
struct PhoneRootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .today

    enum Tab: Int, Hashable, CaseIterable, Identifiable {
        case today, plan, actions, inbox, browse

        var id: Int { rawValue }

        /// What the screen tests press. A name of its own, never the title: a tab renamed for
        /// him must not quietly stop a test from finding it (build 190).
        var identifier: String {
            switch self {
            case .today: return "tab.today"
            case .plan: return "tab.plan"
            case .actions: return "tab.actions"
            case .inbox: return "tab.inbox"
            case .browse: return "tab.browse"
            }
        }

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
            case .plan: return SidebarSection.timeBlocks.systemImage
            case .actions: return SidebarSection.allActions.systemImage
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

    /// The gap between two screens while one slides past the other (build 184).
    ///
    /// His ask: make the swipe read as a carousel — *"you see a piece of the next screen at the
    /// edge while you swipe, so it looks like cards passing by."* A page view draws its pages
    /// edge to edge, so the two screens moved as one sheet and nothing said where one ended.
    /// Six points of padding on each page is a twelve-point gap in the middle of a swipe, and
    /// the two edges become two cards.
    ///
    /// **Deliberately not the full carousel.** Showing a slice of the next screen while nothing
    /// is moving means replacing the page view with a horizontal `ScrollView`, and then every
    /// screen's navigation bar lives inside a scroll view instead of its own stack — the top
    /// bar is exactly where this app has paid for mistakes before (builds 88, 117, 155). Told
    /// him the trade and left it to him.
    private static let pageGap: CGFloat = 6

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases) { item in
                page(for: item)
                    .padding(.horizontal, Self.pageGap)
                    .tag(item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PhoneTabBar(tab: $tab)
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
                        // Quick capture lost its tab to Plan and Actions, so it sits here.
                        // Leading, because Today is the root of its stack and has no back
                        // button: the phone's bar fits a title and one control per side
                        // (build 88).
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                model.activeSheet = .quickCapture
                            } label: {
                                Label("Quick capture", systemImage: "tray.and.arrow.down")
                            }
                            .accessibilityIdentifier("capture.open")
                        }
                        ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() }
                    }
            }
        case .plan:
            PhoneStack(section: item.section, isActive: tab == item) {
                NoteListView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() } }
            }
        case .actions:
            PhoneStack(section: item.section, isActive: tab == item) {
                NoteListView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() } }
            }
        case .inbox:
            PhoneStack(section: item.section, isActive: tab == item) {
                NoteListView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { PhoneSyncButton() } }
            }
        case .browse:
            PhoneStack(section: item.section, isActive: tab == item) {
                PhoneBrowseView()
            }
        }
    }
}

/// The five tabs, drawn by us because the system's bar cannot be swiped between.
///
/// It keeps the system bar's habits: the tint says which tab you are on, the whole width of a
/// tab is pressable, and the Inbox still carries its count — the badge the system bar drew for
/// us until build 183.
struct PhoneTabBar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var tab: PhoneRootView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PhoneRootView.Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 2) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 19))
                                .frame(height: 22)
                            if item == .inbox, model.count(for: .inbox) > 0 {
                                Text("\(model.count(for: .inbox))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red, in: Capsule())
                                    .offset(x: 12, y: -6)
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(item == tab ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityIdentifier(item.identifier)
                // Says out loud which tab you are on. VoiceOver should have been told this
                // all along, and it is what lets a screen test check the swipe (build 211):
                // the tint alone is invisible to a test.
                .accessibilityAddTraits(item == tab ? [.isSelected] : [])
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 3)
        // The bar has to reach down past the home indicator, which a plain background does not.
        .background(
            Rectangle()
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) { Divider() }
    }
}

/// Sync with Reminders from the phone. The Mac has this in the window toolbar; without it
/// here the phone could only wait for auto sync, and iOS never asked for Reminders access.
struct PhoneSyncButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            Task { await model.syncNow() }
        } label: {
            if model.isSyncing {
                ProgressView()
            } else {
                Label("Sync with Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(model.isSyncing || model.vault == nil)
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
                                Image(systemName: section.systemImage)
                                    .foregroundStyle(section.tint)
                            }
                        }
                        .accessibilityIdentifier("browse.\(section.title)")
                    }
                }
            }
            Section {
                NavigationLink(value: PhoneRoute.settings) {
                    Label("Settings and Help", systemImage: "gear")
                }
            }
            Section {
                // The other way in, and the one that can actually be found: a long press here.
                // The title in the navigation bar is small and easy to miss (build 117).
                Text("Build \(BuildStamp.number)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
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
                            Image(systemName: SidebarSection.work.systemImage)
                                .foregroundStyle(SidebarSection.work.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("Browse")
        // Inline, or iOS draws its own large title below the bar and the principal item is
        // never the thing being pressed — which is why build 112's long press did nothing.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The way in: a long press on the title. A plain navigation title cannot take a
            // gesture, so the title is drawn here instead (build 112).
            ToolbarItem(placement: .principal) {
                Text("Browse")
                    .font(.headline)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { model.revealWork() }
            }
        }
    }
}

/// A section opened from Browse: the same list as the middle column on the Mac.
struct PhoneSectionScreen: View {
    @EnvironmentObject private var model: AppModel
    let section: SidebarSection

    var body: some View {
        NoteListView()
            .onAppear { if model.section != section { model.section = section } }
    }
}
#endif
