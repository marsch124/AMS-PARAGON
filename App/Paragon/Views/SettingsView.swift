import SwiftUI
import ParagonCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false
    @State private var backupToRestore: VaultBackup?
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("hideFinishedTasks") private var hideFinishedTasks = false

    var body: some View {
        Form {
            Section("Vault") {
                LabeledContent("Folder") {
                    Text(model.vaultPath ?? "No vault selected")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Choose folder…") { showingImporter = true }
                    if model.vault != nil {
                        Button("Close vault", role: .destructive) { model.closeVault() }
                    }
                }
            }

            Section("Tasks") {
                Toggle("Hide finished tasks in notes", isOn: $hideFinishedTasks)
                Text("Done and cancelled tasks stay in the file and in the editor; this only hides them from the checklist. A finished task with open subtasks is always shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reminders sync") {
                Button {
                    Task { await model.syncNow() }
                } label: {
                    Label(model.isSyncing ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
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
                Picker("When both sides changed", selection: Binding(
                    get: { model.config.conflictPolicy },
                    set: { var c = model.config; c.conflictPolicy = $0; model.config = c }
                )) {
                    Text("The note wins").tag(ConflictPolicy.noteWins)
                    Text("The reminder wins").tag(ConflictPolicy.reminderWins)
                }
                Toggle("Sync tasks in Area notes", isOn: Binding(
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
                    Text(model.config.inboxListName).foregroundStyle(.secondary)
                }
                LabeledContent("Daily notes list") {
                    Text(model.config.dailyNotesListName).foregroundStyle(.secondary)
                }
            }
            .disabled(model.vault == nil)

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
                    Text("No backups yet. One is saved automatically each day and before each sync, and the last ten are kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    DisclosureGroup("Restore a copy (\(model.backups.count))") {
                        ForEach(model.backups) { backup in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                                    Text("\(backup.noteCount) notes · \(backup.reason)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Restore…") { backupToRestore = backup }
                            }
                        }
                    }
                    Text("Restoring puts those notes back and saves what you have now as another backup first. Notes you made since then are left alone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(model.vault == nil)

            Section("Apple Calendar") {
                Toggle("Show the day's events in Today and in daily notes", isOn: Binding(
                    get: { model.showsCalendarEvents },
                    set: { model.showsCalendarEvents = $0 }
                ))
                if model.calendarAccessGranted == false {
                    Text("Calendar access is off. Allow it in System Settings › Privacy & Security › Calendars.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if model.calendarAccessGranted == true, !model.calendars.isEmpty {
                    DisclosureGroup("Calendars to show") {
                        ForEach(model.calendars) { calendar in
                            Toggle(isOn: Binding(
                                get: { model.isCalendarVisible(calendar.id) },
                                set: { model.setCalendar(calendar.id, visible: $0) }
                            )) {
                                Label {
                                    Text(calendar.title) + Text("  \(calendar.sourceTitle)").foregroundStyle(.secondary)
                                } icon: {
                                    Image(systemName: "circle.fill").foregroundStyle(calendar.color)
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
                Text("Events are only read. The one thing written to your calendar is the time blocks you add in the Time Blocks section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if !os(macOS)
            Section("Help") {
                NavigationLink("How it works") { HelpDocument(fileName: "HowItWorks").navigationTitle("How it works") }
                NavigationLink("Version history") { HelpDocument(fileName: "VersionHistory").navigationTitle("Version history") }
            }
            #endif

            Section("Quick capture") {
                #if os(macOS)
                Toggle("Show capture panel in the menu bar", isOn: $showMenuBarItem)
                #endif
                Text("⇧⌘N opens the capture panel in the app. Other apps can add to the Inbox with a link like amspara://capture?text=Call%20the%20bank&target=inbox (Shortcuts: Open URL). On iOS, use Share › PARAGON.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("How long PARAGON waits before it asks you to look at something again. What is due appears at the top of the Weekly review. Marking a note reviewed writes today's date into it, so both devices agree.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(model.vault == nil)

            Section("Last sync") {
                if let report = model.lastReport {
                    Text(report.summary)
                    ForEach(report.conflicts, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    ForEach(report.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("Not synced yet in this session.").foregroundStyle(.secondary)
                }
            }

            // On both platforms since build 178: the Mac has a widget of its own now, and the
            // Mac's entitlements carry the team-prefixed App Group that goes with it.
            WidgetStatusSection()

            Section("About") {
                LabeledContent("Device id", value: model.deviceID)
                Text("Sync state is stored per device in the vault's .ams-para folder. Task ids (^t…) in your notes and the ams-para marker in reminder notes are what keep both sides linked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(macOS)
        .frame(width: 520, height: 560)
        #endif
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                model.openVault(at: url)
            }
        }
        .confirmationDialog("Restore the backup from \(backupToRestore.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? "")?",
                            isPresented: Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } }),
                            presenting: backupToRestore) { backup in
            Button("Restore", role: .destructive) { model.restore(backup) }
        } message: { backup in
            Text("\(backup.noteCount) notes are written back into the vault, replacing the current versions. What you have now is saved as a backup first.")
        }
        .onAppear { model.refreshBackups() }
    }
}

/// One line of the review rhythm. Its own view because building the `Binding` for a level is
/// a statement, and a `@ViewBuilder` takes views and nothing else (build 58).
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
                .font(.subheadline.weight(.semibold))
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
                .font(.caption)
                .foregroundStyle(.secondary)
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
        return snapshot.written.formatted(date: .abbreviated, time: .shortened)
    }

    private var explanation: String {
        if !folderFound {
            return "The widget reads a small file that the app and the widget share. PARAGON cannot reach that shared folder here, so the widget has nothing to read. That is not something you can mend yourself — tell me and I will fix it in the build."
        }
        if snapshot == nil {
            return "Nothing has been written yet. Open a vault, or press Write it again now."
        }
        return "The widget reads this file. It is written again every time PARAGON reloads the vault."
    }

    var body: some View {
        Section("Widget") {
            LabeledContent("Shared folder") {
                Text(folderFound ? "Found" : "Not found")
                    .foregroundStyle(folderFound ? Color.secondary : Color.orange)
            }
            LabeledContent("Last written") {
                Text(writtenText).foregroundStyle(Color.secondary)
            }
            LabeledContent("Actions in it") {
                Text("\(snapshot?.items.count ?? 0)").foregroundStyle(Color.secondary)
            }
            Button("Write it again now") {
                model.writeWidgetSnapshot()
                refresh()
            }
            .disabled(!folderFound)
            Text(explanation)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        folderFound = model.widgetFolderFound
        snapshot = model.widgetSnapshotOnDisk()
    }
}
