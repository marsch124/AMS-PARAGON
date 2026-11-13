import SwiftUI
import ParagonCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false
    @State private var askedAboutFolder = false
    /// One folder picker serves both questions (two pickers on one screen get in each other's
    /// way): which vault to open, and where the second copy goes.
    @State private var pickingBackupFolder = false
    @State private var backupToRestore: VaultBackup?
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("showSyncMenuBarItem") private var showSyncMenuBarItem = true
    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false
    @AppStorage(TaskTimeSetting.key) private var useTaskTimes = true

    @Environment(\.phoneLook) private var phoneLook

    private var helpSection: some View {
        Section("Help") {
            #if os(macOS)
            // The Mac's manual is its own window, reached from the Help menu. Its three pages
            // have a row here too, as in every app of his (round 8, build 315; before, only
            // the list of words did, build 228).
            HelpWindowButton(page: .howItWorks, label: "How it works")
                .accessibilityIdentifier("settings.howItWorks")
            WordsWindowButton()
            HelpWindowButton(page: .versionHistory, label: "What\u{2019}s new")
                .accessibilityIdentifier("settings.whatsNew")
            #else
            NavigationLink("How it works") { HelpDocument(fileName: "HowItWorks").navigationTitle("How it works") }
                .accessibilityIdentifier("settings.howItWorks")
            NavigationLink("Words in PARAGON") { HelpDocument(fileName: "Words").navigationTitle("Words") }
            NavigationLink("What\u{2019}s new") { HelpDocument(fileName: "VersionHistory", title: "What\u{2019}s new").navigationTitle("What\u{2019}s new") }
                .accessibilityIdentifier("settings.whatsNew")
            #endif
        }
    }

    var body: some View {
        // Build 285: a press on the sync line opens Settings here, at Reminders sync.
        ScrollViewReader { proxy in
        Form {
            Group {
            // Round 6 (build 312): help is needed when you are lost, so on the iPhone it is
            // the first thing in Settings. The Mac and the iPad keep it where it was.
            if phoneLook { helpSection }
            Section("Vault") {
                // Round 9 (build 316): the folder's name and where it is, in plain words.
                // Before, the raw path. On the Mac the path is the row's hover tip, and
                // **Show in Finder** opens the place itself.
                LabeledContent("Folder") {
                    Text(model.vaultPath.map { VaultPlaceWords.line(path: $0, device: AppModel.thisDevice) }
                         ?? "No vault selected")
                        .foregroundStyle(.soft)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("settings.vault.folder")
                }
                #if os(macOS)
                .help(model.vaultPath ?? "")
                #endif
                Button("Choose folder…") {
                    pickingBackupFolder = false
                    showingImporter = true
                }
                #if os(macOS)
                if let vault = model.vault {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([vault.rootURL]) }
                        .accessibilityIdentifier("settings.vault.show")
                }
                #endif
                // On a line of its own (round 3): the red word sat right beside Choose folder.
                if model.vault != nil {
                    Button("Close vault", role: .destructive) { model.closeVault() }
                }
            }

            Section("Tasks") {
                Toggle("Use task times", isOn: $useTaskTimes)
                    .accessibilityIdentifier("settings.useTaskTimes")
                Text("Each task can say how long it takes, for example 45 minutes. Off, no task shows a time and nothing asks for one. Times already written in your notes stay there.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                if useTaskTimes {
                    WorkdayEndRow()
                }
                Toggle("Hide finished tasks in notes", isOn: $hideFinishedTasks)
                Text("Done and cancelled tasks stay in the file and in the editor; this only hides them from the checklist. A finished task with open subtasks is always shown.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }

            Section("Reminders sync") {
                #if os(macOS)
                // Build 303: the sync ring in the menu bar.
                Toggle("Show the sync ring in the menu bar", isOn: $showSyncMenuBarItem)
                #endif
                Button {
                    Task { await model.syncNow() }
                } label: {
                    MarkLabel(model.isRestoring ? "Restoring…" : (model.isSyncing ? "Syncing…" : "Sync now"), "arrow.triangle.2.circlepath")
                }
                .disabled(model.isSyncing || model.vault == nil)
                Picker("Sync automatically", selection: Binding(
                    get: { model.autoSyncMinutes },
                    set: { model.autoSyncMinutes = $0 }
                )) {
                    Text("Off").tag(0)
                    Text("Every 5 minutes").tag(5)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                }
                // Round 9 (build 316): shorter words on the iPhone, so the label and its
                // value share one line (the value used to drop to a second line).
                Picker(phoneLook ? "If both changed" : "When both sides changed", selection: Binding(
                    get: { model.config.conflictPolicy },
                    set: { var c = model.config; c.conflictPolicy = $0; model.config = c }
                )) {
                    Text(phoneLook ? "Note wins" : "The note wins").tag(ConflictPolicy.noteWins)
                    Text(phoneLook ? "Reminder wins" : "The reminder wins").tag(ConflictPolicy.reminderWins)
                }
                Toggle("Sync tasks in area notes", isOn: Binding(
                    get: { model.config.syncAreas },
                    set: { var c = model.config; c.syncAreas = $0; model.config = c }
                ))
                Toggle("Create missing Reminders lists", isOn: Binding(
                    get: { model.config.createMissingLists },
                    set: { var c = model.config; c.createMissingLists = $0; model.config = c }
                ))
                Toggle("Import reminders that are already completed", isOn: Binding(
                    get: { model.config.importCompletedReminders },
                    set: { var c = model.config; c.importCompletedReminders = $0; model.config = c }
                ))
                Toggle("Sync tasks in daily notes", isOn: Binding(
                    get: { model.config.syncDailyNotes },
                    set: { var c = model.config; c.syncDailyNotes = $0; model.config = c }
                ))
                LabeledContent("Inbox list") {
                    Text(model.config.inboxListName).foregroundStyle(.soft)
                }
                LabeledContent("Daily notes list") {
                    Text(model.config.dailyNotesListName).foregroundStyle(.soft)
                }
            }
            .id("settings.sync")
            .disabled(model.vault == nil)

            // Build 315: the lists he answered "Keep them apart" for. Hidden while there are none.
            if !model.config.listsKeptApart.isEmpty {
                Section {
                    ForEach(model.config.listsKeptApart) { list in
                        HStack {
                            Text(list.name)
                            Spacer()
                            Button("Connect again") { model.connectAgain(list) }
                                .accessibilityIdentifier("settings.keptApart.connect.\(list.name)")
                        }
                    }
                } header: {
                    Text("Lists kept apart")
                } footer: {
                    Text("These Reminders lists have the same name as a note, and you chose to keep them apart. The sync leaves the list and the note alone. After **Connect again**, the next sync asks you about the list once more.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("settings.keptApart")
            }

            Section("Backups") {
                Toggle("Save a copy of the vault before each sync", isOn: Binding(
                    get: { model.backsUpBeforeSync },
                    set: { model.backsUpBeforeSync = $0 }
                ))
                HStack {
                    Button("Back up now") { model.backUpNow() }
                    #if os(macOS)
                    Button("Show in Finder") { model.showBackupsInFinder() }
                    #endif
                    Spacer()
                }
                if model.backups.isEmpty {
                    Text("No backups yet. One is saved automatically each day and before each sync. Older ones are thinned out: one a day for two weeks, one a week for two months.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                } else {
                    DisclosureGroup("Restore a copy (\(model.backups.count))") {
                        ForEach(model.backups) { backup in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(DayWords.plainWithTime(backup.date))
                                    Text("\(backup.noteCount) notes · \(backup.reason)")
                                        .font(Txt.label)
                                        .foregroundStyle(.soft)
                                }
                                Spacer()
                                Button("Restore…") { backupToRestore = backup }
                            }
                        }
                    }
                    Text("Restoring puts those notes back and saves what you have now as another backup first. Notes you made since then are left alone.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                }
            }
            .disabled(model.vault == nil)

            // Build 308 (hardening-13): the backups above sit inside the vault folder, so they
            // are lost with it. This one is kept somewhere else, and holds the pictures too.
            Section("Second copy, outside the vault") {
                LabeledContent("Kept") {
                    Text(model.outsideBackupFolderName.map { "in the folder \u{201C}\($0)\u{201D}" } ?? "on \(AppModel.thisDevice)")
                        .foregroundStyle(.soft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityIdentifier("settings.outsideBackup.place")
                LabeledContent("Last made") {
                    Text(model.lastOutsideBackup.map { DayWords.plainWithTime($0) }
                         ?? (model.outsideBackupRunning ? "Being made now\u{2026}" : "Not yet"))
                        .foregroundStyle(.soft)
                }
                .accessibilityIdentifier("settings.outsideBackup.last")
                if let problem = model.outsideBackupProblem {
                    Text(problem)
                        .font(Txt.label)
                        .foregroundStyle(Theme.attention.ink)
                        .accessibilityIdentifier("settings.outsideBackup.problem")
                }
                HStack {
                    Button(model.outsideBackupFolderName == nil ? "Choose a folder…" : "Change folder…") {
                        pickingBackupFolder = true
                        showingImporter = true
                    }
                    .accessibilityIdentifier("settings.outsideBackup.choose")
                    if model.outsideBackupFolderName != nil {
                        Button("Keep it on \(AppModel.thisDevice)") { model.keepOutsideBackupOnDevice() }
                            .accessibilityIdentifier("settings.outsideBackup.useDevice")
                    }
                    #if os(macOS)
                    Button("Show in Finder") { model.showOutsideBackupsInFinder() }
                        .accessibilityIdentifier("settings.outsideBackup.show")
                    #endif
                    Spacer()
                }
                // Build 315: until now this copy could only be put back by hand, in Finder.
                Button("Restore from the outside copy\u{2026}") { model.lookAtOutsideCopy() }
                    .accessibilityIdentifier("settings.outsideBackup.restore")
                // Build 316: what the last restore did stays here, not only in a short message.
                if model.isRestoring {
                    Text("Restoring\u{2026}")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                        .accessibilityIdentifier("settings.outsideBackup.restoring")
                } else if let line = model.lastOutsideRestoreLine {
                    Text(line)
                        .font(Txt.label.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.outsideBackup.restored")
                }
                Text("Once a day, and with Back up now, your notes, pictures and sketches are also copied to a place outside the vault, so they are still there if the vault folder is lost. Choose a folder, for example in Dropbox, to keep this copy somewhere other than \(AppModel.thisDevice).")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }
            .disabled(model.vault == nil)

            Section("Apple Calendar") {
                Toggle("Show the day's events in Today and in daily notes", isOn: Binding(
                    get: { model.showsCalendarEvents },
                    set: { model.showsCalendarEvents = $0 }
                ))
                if model.calendarAccessGranted == false {
                    Text("Calendar access is off. Allow it in \(DeviceWords.systemSettings) › Privacy & Security › Calendars.")
                        .font(Txt.label)
                        .foregroundStyle(Theme.attention.ink)
                }
                if model.calendarAccessGranted == true, !model.calendars.isEmpty {
                    DisclosureGroup("Calendars to show") {
                        ForEach(model.calendars) { calendar in
                            Toggle(isOn: Binding(
                                get: { model.isCalendarVisible(calendar.id) },
                                set: { model.setCalendar(calendar.id, visible: $0) }
                            )) {
                                Label {
                                    Text(calendar.title) + Text("  \(calendar.sourceTitle)").foregroundStyle(.soft)
                                } icon: {
                                    MarkImage("circle.fill").foregroundStyle(calendar.color)
                                }
                            }
                        }
                    }
                    Picker("Time blocks go to", selection: Binding(
                        get: { model.timeBlockCalendarID },
                        set: { model.timeBlockCalendarID = $0 }
                    )) {
                        ForEach(model.calendars.filter(\.isWritable)) { calendar in
                            Text(calendar.title).tag(Optional(calendar.id))
                        }
                    }
                } else if model.calendarAccessGranted == nil {
                    Button("Connect Apple Calendar…") {
                        Task { await model.ensureCalendarAccess() }
                    }
                }
                Text("Events are only read. The one thing written to your calendar is the time blocks you add in Plan.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }

            // Round 6 (build 312): on the iPhone Help is the first group, above (see the top).
            if !phoneLook { helpSection }

            // Morning first, the order of the day (build 267).
            DayReminderSection(kind: .morning)
            DayReminderSection(kind: .evening)
            DayReminderSection(kind: .weeklyReview)

            Section("Quick capture") {
                #if os(macOS)
                Toggle("Show capture panel in the menu bar", isOn: $showMenuBarItem)
                // Round 8 (build 315): one key that opens quick capture from any app.
                CaptureKeyRow()
                #endif
                // Each device its own words, and no link in Settings (round 3): the link
                // example is in How it works, under Quick capture.
                #if os(macOS)
                Text("⇧⌘N opens quick capture in PARAGON; the key above opens it from any app. A Shortcut can add to the Inbox too: see How it works.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                #else
                Text("Use Share › PARAGON from any app")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                #endif
            }

            Section("Weekly review") {
                Stepper("Flag projects unchanged for \(model.config.staleProjectDays) days", value: Binding(
                    get: { model.config.staleProjectDays },
                    set: { var c = model.config; c.staleProjectDays = $0; model.config = c }
                ), in: 3...90)
            }
            .disabled(model.vault == nil)

            // **Build 172: a rhythm per level.** The project number was already here under a
            // different name ("Review projects every N days") and is *the same setting* — one
            // number, never two for one thing. The other three are new.
            Section {
                ForEach(ReviewLevel.allCases, id: \.self) { level in
                    ReviewRhythmStepper(model: model, level: level)
                }
            } header: {
                Text("Review rhythm")
            } footer: {
                Text("How long PARAGON waits before it asks you to look at something again. What is due appears at the top of the Weekly review. **I looked at it today** writes today's date into the note, so both devices agree.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(model.vault == nil)

            Section("Last sync") {
                if let report = model.lastReport {
                    Text(report.summary)
                    ForEach(report.conflicts, id: \.self) { Text($0).font(Txt.label).foregroundStyle(Theme.attention.ink) }
                    ForEach(report.warnings, id: \.self) { Text($0).font(Txt.label).foregroundStyle(.soft) }
                } else {
                    Text("Not synced yet in this session").foregroundStyle(.soft)
                }
            }

            // On both platforms since build 178: the Mac has a widget of its own now, and the
            // Mac's entitlements carry the team-prefixed App Group that goes with it.
            WidgetStatusSection()

            Section("About") {
                // Build 315 (features-06): the version is here too, on every device.
                LabeledContent("Version", value: AppVersion.text)
                    .accessibilityIdentifier("settings.about.version")
                // Round 9 (build 316): the technical lines sit behind **Details**, closed to
                // begin with. Nothing was removed; the id is on one line and can be copied.
                DisclosureGroup("Details") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device id")
                        Text(model.deviceID)
                            .font(Txt.label.monospaced())
                            .foregroundStyle(.soft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .textSelection(.enabled)
                    }
                    Text("Sync state is stored per device in the vault's .ams-para folder. Task ids (^t…) in your notes and the ams-para marker in reminder notes are what keep both sides linked.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                }
                .accessibilityIdentifier("settings.about.details")
            }
            }
            // Review round 4: on the iPhone each row is a card in the part's colour.
            .phoneCard(Theme.fallbackTint)
        }
        .formStyle(.grouped)
        .phonePage()
        .navigationTitle("Settings")
        #if os(macOS)
        .frame(width: 520, height: 560)
        #endif
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                if pickingBackupFolder {
                    model.chooseOutsideBackupFolder(url)
                } else {
                    // Looked at first, opened only on his yes (build 308).
                    askedAboutFolder = true
                    model.lookAtFolder(url)
                }
            }
        }
        .modifier(FolderChoiceSheet(asked: $askedAboutFolder))
        .sheet(isPresented: Binding(get: { model.outsideRestoreChoice != nil },
                                    set: { shown in if !shown { model.cancelOutsideRestore() } })) {
            OutsideRestoreView().environmentObject(model)
        }
        .confirmationDialog("Restore the backup from \(backupToRestore.map { DayWords.plainWithTime($0.date) } ?? "")?",
                            isPresented: Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } }),
                            presenting: backupToRestore) { backup in
            Button("Restore", role: .destructive) { model.restore(backup) }
        } message: { backup in
            Text("\(backup.noteCount) notes are written back into the vault, replacing the current versions. What you have now is saved as a backup first.")
        }
        .onAppear {
            model.refreshBackups()
            jumpToSync(proxy)
        }
        .onChange(of: model.settingsJumpToSync) { _, jump in if jump { jumpToSync(proxy) } }
        }
    }

    private func jumpToSync(_ proxy: ScrollViewProxy) {
        guard model.settingsJumpToSync else { return }
        // After the page has laid itself out, or the scroll lands nowhere.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { proxy.scrollTo("settings.sync", anchor: .top) }
            model.settingsJumpToSync = false
        }
    }
}

/// Build 315, **Restore from the outside copy…**: the copies of this vault (newest chosen to
/// begin with), each with its date and how many notes it holds, and what a yes does — with
/// Cancel (Escape on the Mac) and one main button. Nothing has been changed while this is on
/// screen.
struct OutsideRestoreView: View {
    @EnvironmentObject private var model: AppModel

    private var copies: [OutsideCopy] {
        if case .copies(let copies) = model.outsideRestoreChoice?.finding { return copies }
        return []
    }

    /// The headline, the smaller lines under it, and whether the main button is offered.
    private var words: (headline: String, details: [String], canRestore: Bool, busy: Bool) {
        let place = model.outsideRestoreChoice?.placeWords ?? ""
        let vault = "\u{201C}\(model.outsideRestoreChoice?.vaultName ?? "")\u{201D}"
        switch model.outsideRestoreChoice?.finding {
        case nil, .looking:
            return ("Looking for the outside copy\u{2026}", ["Nothing is changed."], false, true)
        case .some(.none):
            return ("There is no outside copy yet.",
                    ["PARAGON looked \(place) and found no copy of the vault \(vault). One is made once a day, and with Back up now. Nothing was changed."], false, false)
        case .copies(let copies):
            guard let copy = model.outsideRestoreChoice?.selectedCopy else { return ("", [], false, false) }
            let which = copies.count == 1 ? "It is the only outside copy of the vault \(vault)"
                : (copy.id == copies.first?.id ? "It is the newest of \(copies.count) outside copies of the vault \(vault)"
                   : "It is one of \(copies.count) outside copies of the vault \(vault)")
            var details = ["\(which), kept \(place). It holds \(FolderChoiceView.notes(copy.backup.noteCount)), with their pictures and sketches."]
            if !copy.isMarked {
                details.append("This copy was made before build 315, so it does not say which vault it is of. Check its folders before you restore it.")
            }
            details += ["Restoring puts those notes, pictures and sketches back into the vault \(vault), over the versions you have now.",
                        "What you have now is saved as a backup first, so you can go back. Notes you made since that copy are left alone. Nothing is deleted."]
            return ("Restore the outside copy from \(DayWords.plainWithTime(copy.backup.date))?", details, true, false)
        case .restoring(let copy):
            return ("Restoring the copy from \(DayWords.plainWithTime(copy.date))\u{2026}",
                    ["Saving what you have now first, then putting the copy back. With many pictures this can take a minute."], false, true)
        }
    }

    private var isRestoring: Bool {
        if case .restoring = model.outsideRestoreChoice?.finding { return true }
        return false
    }

    /// The smaller line of a copy's row: how many notes, and what sets it apart.
    static func rowDetail(_ copy: OutsideCopy) -> String {
        var parts = [FolderChoiceView.notes(copy.backup.noteCount)]
        if copy.isBeforeRestore { parts.append("made just before a restore") }
        if let folders = copy.unmarkedFolders {
            parts.append("made before build 315")
            parts.append(folders.isEmpty ? "no folders" : "folders: " + folders.prefix(6).joined(separator: ", "))
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// The copies, newest first; a press chooses one. Shown as the copies inside the vault are.
    private var copyList: some View {
        let chosen = model.outsideRestoreChoice?.selectedCopy?.id
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(copies.enumerated()), id: \.element.id) { index, copy in
                    Button {
                        model.chooseOutsideCopy(copy)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            MarkImage("checkmark", size: 11)
                                .foregroundStyle(Theme.fallbackTint.ink)
                                .opacity(copy.id == chosen ? 1 : 0)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(DayWords.plainWithTime(copy.backup.date))
                                    .font(Txt.list)
                                Text(Self.rowDetail(copy))
                                    .font(Txt.label)
                                    .foregroundStyle(.soft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.fallbackTint.ink.opacity(copy.id == chosen ? 0.12 : 0)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("outsideRestore.copy.\(index)")
                    .accessibilityAddTraits(copy.id == chosen ? .isSelected : [])
                }
            }
        }
        .frame(maxHeight: 150)
    }

    var body: some View {
        let words = words
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if words.busy { ProgressView().controlSize(.small) }
                Text(words.headline)
                    .font(Txt.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("outsideRestore.headline")
            }
            if copies.count > 1 || copies.contains(where: { !$0.isMarked }) { copyList }
            ForEach(words.details, id: \.self) { line in
                Text(line)
                    .font(Txt.list)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { model.cancelOutsideRestore() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRestoring)
                    .accessibilityIdentifier("outsideRestore.cancel")
                if words.canRestore {
                    Button("Restore") { model.restoreOutsideCopy() }
                        .buttonStyle(.filled(Theme.fallbackTint))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("outsideRestore.confirm")
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 420)
        #else
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents(copies.count > 1 || copies.contains(where: { !$0.isMarked }) ? [.medium, .large] : [.height(340)])
        // Build 315 polish: a low sheet is glass on the iPhone and the Settings rows behind
        // showed through the words. The app's own page colour, by day and at night.
        .presentationBackground(Theme.canvas)
        #endif
        .interactiveDismissDisabled(isRestoring)
        .accessibilityIdentifier("outsideRestore.sheet")
    }
}

/// One line of the review rhythm. Its own view because building the `Binding` for a level is
/// a statement, and a `@ViewBuilder` takes views and nothing else (build 58).
#if os(macOS)
/// Settings › Quick capture: the key that opens quick capture from any app (round 8, build
/// 315). Off until he picks one; the choice is kept on this Mac and takes effect at once.
struct CaptureKeyRow: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(CaptureHotKey.storageKey) private var stored = CaptureHotKey.off.rawValue
    /// Build 316: the key he recorded himself, as `RecordedKey.stored`; empty for none.
    @AppStorage(RecordedKey.storageKey) private var storedOwn = ""
    @State private var refused = false
    @State private var recording = false

    private var own: RecordedKey? { RecordedKey(stored: storedOwn) }

    private func choose(_ choice: CaptureHotKey) {
        stored = choice.rawValue
        CaptureKey.shared.apply(choice, model: model)
        refused = choice != .off && !CaptureKey.shared.isRegistered
    }

    var body: some View {
        Picker("Key from any app", selection: Binding(
            get: { CaptureHotKey.stored(stored) },
            set: { choice in choose(choice) }
        )) {
            ForEach(CaptureHotKey.fixedChoices) { choice in
                Text(choice.label).tag(choice)
            }
            // His own key is in the list once one is recorded.
            if let own {
                Text("My own key: \(own.label)").tag(CaptureHotKey.custom)
            }
        }
        .accessibilityIdentifier("settings.captureKey")
        Button("Record my own key\u{2026}") { recording = true }
            .accessibilityIdentifier("settings.captureKey.record")
            .sheet(isPresented: $recording) {
                RecordKeySheet(current: own) { key in
                    storedOwn = key.stored
                    choose(.custom)
                }
                // Whatever way the window closed, the chosen key is taken again.
                .onDisappear { CaptureKey.shared.apply(CaptureHotKey.stored(stored), model: model) }
            }
        if refused {
            Text("Another app already uses this key. Pick a different one.")
                .font(Txt.label)
                .foregroundStyle(Theme.attention.ink)
                .accessibilityIdentifier("settings.captureKey.refused")
        }
    }
}

/// **Record my own key…** (round 9, build 316): press the keys, see them as symbols, then
/// **Save**. A key without ⌘, ⌃ or ⌥ is refused; a key macOS is known to use gets a warning
/// and may still be saved. Cancel and Escape leave everything as it was.
///
/// Only keys pressed **while this window is open** are looked at, and only inside PARAGON
/// (`addLocalMonitorForEvents`): nothing is read from other apps and no permission is needed.
struct RecordKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: RecordedKey?
    let save: (RecordedKey) -> Void
    @State private var pressed: RecordedKey?
    @State private var triedToSave = false
    @State private var monitor: Any?

    private var refusedLine: String? {
        if let pressed, !pressed.isAllowed { return RecordedKey.refusedLine }
        if pressed == nil, triedToSave { return "Press the keys first." }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Record my own key")
                .font(Txt.sectionTitle)
            Text("Press the keys that should open quick capture from any app, for example \u{2325}\u{2318}K.")
                .font(Txt.list)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
            Text(pressed?.label ?? current.map { "Now: \($0.label)" } ?? "Waiting for keys\u{2026}")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(pressed == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.primary))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.fallbackTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.fallbackTint.opacity(0.45), lineWidth: 1))
                .accessibilityIdentifier("recordKey.keys")
            if let refusedLine {
                Text(refusedLine)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recordKey.refused")
            } else if let warning = pressed?.warningLine {
                Text(warning)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recordKey.warning")
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .accessibilityIdentifier("recordKey.cancel")
                // Always full colour: pressed with nothing usable, it says what is missing.
                Button("Save") { trySave() }
                    .buttonStyle(.filled(Theme.fallbackTint))
                    .accessibilityIdentifier("recordKey.save")
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(width: 380)
        .accessibilityIdentifier("recordKey.sheet")
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    private func trySave() {
        triedToSave = true
        guard let pressed, pressed.isAllowed else { return }
        save(pressed)
        dismiss()
    }

    /// Every key press in this window is the answer, so the buttons' own keys are read here:
    /// Escape by itself is Cancel and Return by itself is Save.
    private func startListening() {
        CaptureKey.shared.letGo()
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let code = UInt32(event.keyCode)
            if flags.isEmpty, code == 53 { dismiss(); return nil }
            if flags.isEmpty, code == 36 || code == 76 { trySave(); return nil }
            var held: UInt32 = 0
            if flags.contains(.command) { held |= RecordedKey.command }
            if flags.contains(.shift) { held |= RecordedKey.shift }
            if flags.contains(.option) { held |= RecordedKey.option }
            if flags.contains(.control) { held |= RecordedKey.control }
            // The letter printed on the key, without what the held keys make of it (⇧3 is "3").
            let typed = (event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? "").uppercased()
            let name = RecordedKey.specialName(forKeyCode: code)
                ?? (typed.unicodeScalars.first.map { $0.value > 32 && $0.value < 0xF700 } == true ? typed : "Key \(code)")
            pressed = RecordedKey(keyCode: code, modifiers: held, keyName: name)
            triedToSave = false
            return nil
        }
    }

    private func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
#endif

struct ReviewRhythmStepper: View {
    @ObservedObject var model: AppModel
    let level: ReviewLevel

    private var days: Binding<Int> {
        Binding(
            get: { ReviewRhythm(config: model.config).days(for: level) },
            set: { value in
                var c = model.config
                switch level {
                case .aspiration: c.aspirationReviewDays = value
                case .goal: c.goalReviewDays = value
                case .project: c.reviewIntervalDays = value
                case .area: c.areaReviewDays = value
                }
                model.config = c
            }
        )
    }

    /// Each level in its own colour, so the four rows read as the four things they set. An
    /// aspiration is the deeper gold since build 189.
    private var levelTint: Color {
        switch level {
        case .aspiration: return ChainTint.aspiration
        case .goal: return ChainTint.datedGoal
        case .project: return ParaKind.project.tint
        case .area: return ParaKind.area.tint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(level.label)
                .font(Txt.label.weight(.semibold))
            // **Build 175: named lengths, not a stepper.** He asked for "every 6 months" and
            // build 174's stepper counted 30 days at a time from 365, so it could not reach
            // 182 at all. Build 136 had already taught this with the date picker: a person
            // thinks in months, not in presses.
            WrappingHStack(spacing: 6, lineSpacing: 5) {
                ForEach(ReviewRhythm.choices(for: level, including: days.wrappedValue), id: \.self) { choice in
                    // `PickChip`, not `FilterBox`: one of a set, not a tick box. Build 158
                    // drew that line and a checkmark square here would say you may have two.
                    PickChip(title: ReviewRhythm.label(forDays: choice),
                             isOn: choice == days.wrappedValue,
                             tint: levelTint) {
                        days.wrappedValue = choice
                    }
                }
            }
            .lineLimit(1)
            Text(level.reason)
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

/// What the widget can see, said inside the app (build 177; on the Mac too since 178).
///
/// **A widget that is not running cannot say anything at all**, which is exactly the state his
/// Mac was in: a blank box, and the only advice available was "open the app once" — which mends
/// nothing when the shared folder is what is missing. So the app answers the same three
/// questions the widget's own foot line answers, and this screen can be looked at even when the
/// widget draws nothing.
///
/// Read fresh every time it appears. The question is what is true now, never what was true at
/// launch.
struct WidgetStatusSection: View {
    @EnvironmentObject private var model: AppModel
    @State private var snapshot: WidgetSnapshot?
    @State private var folderFound = true

    private var writtenText: String {
        guard let snapshot else { return "nothing written yet" }
        return DayWords.plainWithTime(snapshot.written)
    }

    private var explanation: String {
        if !folderFound {
            return "The widget reads a small file that the app and the widget share. PARAGON cannot reach that shared folder here, so the widget has nothing to read. That is not something you can mend yourself — tell me and I will fix it in the build."
        }
        if snapshot == nil {
            return "Nothing has been written yet. Open a vault, or press Write it again now."
        }
        return "The widget reads this file. It is written again a few seconds after a change that the widget would show. Last written is the time of the last such change, so an old time does not mean the widget is not working."
    }

    var body: some View {
        Section("Widget") {
            LabeledContent("Shared folder") {
                Text(folderFound ? "Found" : "Not found")
                    .foregroundStyle(folderFound ? Theme.soft : Theme.attention.ink)
            }
            LabeledContent("Last written") {
                Text(writtenText).foregroundStyle(Theme.soft)
            }
            LabeledContent("Actions in it") {
                Text("\(snapshot?.items.count ?? 0)").foregroundStyle(Theme.soft)
            }
            #if os(macOS)
            // What the Today's plan widget has to draw (build 273): the blocks and the timed
            // events in the file. It is a Mac widget, so the phone has no such line.
            LabeledContent("Today's plan") {
                Text(snapshot?.planSummary ?? "Not written yet").foregroundStyle(Theme.soft)
            }
            #endif
            Button("Write it again now") {
                // `force`: it writes even when nothing has changed, which is what pressing it
                // asks for (build 271).
                model.writeWidgetSnapshot(force: true)
                refresh()
            }
            .disabled(!folderFound)
            if !model.notesWaitingForCloud.isEmpty {
                // Build 261: the widget is not written from part of the vault.
                Text("Not written while \(model.notesWaitingForCloud.count) notes are still coming from iCloud: it would show only part of your vault.")
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(explanation)
                .font(Txt.label)
                .foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        folderFound = model.widgetFolderFound
        snapshot = model.widgetSnapshotOnDisk()
    }
}

/// **Settings › Morning reminder** and **Settings › Evening reminder** (builds 270 and 234): a
/// switch and a time each. Pressing the reminder opens **Start the day** or **Close the day**.
///
/// **One view for both**, so the two parts can never come to say different things about the one
/// permission they share (build 168's rule: one thing drawn in two places is one view). Its own
/// view, because building the time's `Binding` is a statement and a `@ViewBuilder` takes views
/// only (build 58).
///
/// **The `init` is written out**: the keys depend on the kind, so `@AppStorage` cannot be given
/// them where it is declared, and there is no compiler here to settle a generated one.
struct DayReminderSection: View {
    let kind: DayReminder
    @ObservedObject private var reminder = EveningReminder.shared
    @AppStorage private var isOn: Bool
    @AppStorage private var minutes: Int
    /// Only the weekly review's reminder has a day (round 8, build 315).
    @AppStorage(DayReminder.weekdayKey) private var weekday = DayReminder.defaultWeekday

    init(kind: DayReminder) {
        self.kind = kind
        _isOn = AppStorage(wrappedValue: false, kind.onKey)
        _minutes = AppStorage(wrappedValue: kind.defaultMinutes, kind.minutesKey)
    }

    var body: some View {
        Section(kind.sectionTitle) {
            Toggle(kind.switchTitle, isOn: $isOn)
                .accessibilityIdentifier(kind.settingsIdentifier)
                // On the switch, not on the Section (build 246): a modifier on a `Section`
                // is applied to each row, so the system was asked once per row.
                .onAppear { reminder.refreshPermission() }
                .onChange(of: isOn) { _, on in reminder.update(kind, on: on) }
                .onChange(of: minutes) { _, _ in reminder.update(kind, on: isOn) }
                .onChange(of: weekday) { _, _ in
                    if kind == .weeklyReview { reminder.update(kind, on: isOn) }
                }
            if isOn, kind == .weeklyReview {
                Picker("On", selection: $weekday) {
                    ForEach(DayReminder.weekdays, id: \.number) { day in
                        Text(day.name).tag(day.number)
                    }
                }
                .accessibilityIdentifier(kind.settingsIdentifier + ".day")
            }
            if isOn {
                DatePicker("At", selection: time, displayedComponents: .hourAndMinute)
            }
            if isOn, let problem = problemText {
                // Build 100's rule: a switch that is on and does nothing must say why. Since
                // build 243 that includes "never asked", which used to look like "all fine".
                Text(problem)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if reminder.permission == .notAsked {
                    Button("Allow notifications") { reminder.update(kind, on: true) }
                }
            } else if isOn {
                Text(nextText)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }
            Text(kind.explanation)
                .font(Txt.label)
                .foregroundStyle(.soft)
            Button("Try it now") { reminder.sendTest(kind) }
                .disabled(reminder.isTesting(kind))
                .accessibilityIdentifier(kind.testButtonIdentifier)
            if let line = testLine {
                Text(line.text)
                    .font(Txt.label)
                    .foregroundStyle(line.isProblem ? Theme.attention.ink : Theme.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var settingsPlace: String {
        #if os(macOS)
        return "\(DeviceWords.systemSettings) › Notifications › PARAGON"
        #else
        return "the iPhone's Settings › Notifications › PARAGON"
        #endif
    }

    /// Why the switch is on and nothing will appear, or nil when all is well. The permission is
    /// shared, so a problem with it shows in every part whose switch is on.
    private var problemText: String? {
        switch reminder.permission {
        case .refused?:
            return "Notifications for PARAGON are turned off. Turn them on in \(settingsPlace)."
        case .silent?:
            return "Notifications for PARAGON are allowed, but set to None, so nothing appears. Choose Banners in \(settingsPlace)."
        case .notAsked?:
            return "PARAGON has not been allowed to send notifications yet, so no reminder is planned."
        case nil:
            return nil
        case .allowed?:
            return reminder.nextReminders[kind] == nil
                ? "No reminder is planned yet. Turn the switch off and on again."
                : nil
        }
    }

    private var device: String {
        #if os(macOS)
        return "the Mac"
        #else
        return "the iPhone"
        #endif
    }

    /// What this part's test button has done, so a press always gets an answer (build 244).
    private var testLine: (text: String, isProblem: Bool)? {
        guard let test = reminder.tests[kind] else { return nil }
        switch test {
        case .asking:
            return ("Sending…", false)
        case .waiting(let due):
            return ("Sent. It should appear at \(DayWords.time(due, seconds: true)).", false)
        case .delivered(let at):
            return ("Delivered by \(device) at \(DayWords.time(at, seconds: true)). If you did not see it, a Focus mode such as Do Not Disturb may be holding it back.", false)
        case .notDelivered:
            return ("It was sent, but \(device) did not deliver it. Check \(settingsPlace).", true)
        case .notAllowed:
            return ("It could not be sent: PARAGON is not allowed to send notifications. Turn them on in \(settingsPlace).", true)
        case .failed(let message):
            return ("It could not be sent: \(message)", true)
        }
    }

    /// "Next reminder: tomorrow at 07:30", read back from the system's own list.
    private var nextText: String {
        guard let next = reminder.nextReminders[kind] else { return "Checking…" }
        let calendar = Calendar.current
        let day = calendar.isDateInToday(next) ? "today"
            : calendar.isDateInTomorrow(next) ? "tomorrow"
            : DayWords.withWeekday(next)
        return "Next reminder: \(day) at \(DayWords.time(next))"
    }

    /// Minutes since midnight shown as a time of day, today's date standing in for any day.
    /// Clock parts both ways, never seconds since midnight (build 238): on the day the clocks
    /// change those differ by an hour, and 07:30 would have shown as 06:30 or 08:30.
    private var time: Binding<Date> {
        Binding(
            get: {
                let midnight = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                             second: 0, of: midnight) ?? midnight
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                let hour: Int = parts.hour ?? kind.defaultMinutes / 60
                let minute: Int = parts.minute ?? kind.defaultMinutes % 60
                minutes = hour * 60 + minute
            }
        )
    }
}

/// Settings › Tasks › **Working day ends** (build 249). **Start the day** says whether what you
/// picked fits before this time. It is a measure, never a wall: blocks still go into the
/// evening, because he keeps his leisure tasks in PARAGON too.
///
/// Its own view, because building the time's `Binding` is a statement and a `@ViewBuilder`
/// takes only views (build 58) — the shape `DayReminderSection` already has.
struct WorkdayEndRow: View {
    @AppStorage(WorkdaySetting.key) private var minutes = WorkdaySetting.defaultEnd

    var body: some View {
        DatePicker("Working day ends", selection: time, displayedComponents: .hourAndMinute)
            .accessibilityIdentifier("settings.workdayEnds")
        Text("Start the day says whether what you pick fits before this time. Tasks can still be planned after it.")
            .font(Txt.label)
            .foregroundStyle(.soft)
    }

    /// Clock parts both ways, never seconds since midnight (build 238): on the day the clocks
    /// change those differ by an hour.
    private var time: Binding<Date> {
        Binding(
            get: {
                let midnight = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                             second: 0, of: midnight) ?? midnight
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes = (parts.hour ?? 16) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
