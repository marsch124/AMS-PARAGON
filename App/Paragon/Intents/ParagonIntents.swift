import AppIntents
import SwiftUI
import ParagonCore

// Build 317 (features-07): PARAGON's six actions for Shortcuts, Siri, Spotlight and the Action
// Button. Each is small on purpose: it asks `AppModel` to do what a press in the app does
// (`ShortcutBridge.swift`), and what it says back is decided and tested in Core
// (`ShortcutAnswers.swift`). The phrases Siri knows are in `ParagonShortcuts.swift`.
//
// Names end in `Intent` and live in this folder only, so they cannot be taken for the widget's
// own buttons (`App/ParagonWidgets`).

// MARK: Add to Inbox

/// **Add to Inbox**: one task into the Inbox, without opening PARAGON.
struct AddToInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Inbox"
    static let description = IntentDescription(
        "Adds a task to your PARAGON Inbox without opening the app. You can give it a day; >2026-11-14, !! and #tags in the text work as they do in Quick capture.",
        categoryName: "Capture")
    static let openAppWhenRun = false

    @Parameter(title: "Text", description: "The words of the task.",
               inputOptions: String.IntentInputOptions(capitalizationType: .sentences, multiline: false),
               requestValueDialog: "What do you want to add?")
    var text: String

    @Parameter(title: "Day", description: "The day to do it on. Leave empty for no date.", kind: .date)
    var day: DateComponents?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to the PARAGON Inbox") {
            \.$day
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let chosenDay = day.flatMap { DateOnly(components: $0) }
        guard let item = ShortcutCapture.item(text: text, day: chosenDay) else {
            throw $text.needsValueError("What do you want to add?")
        }
        let filed = AppModel.shared.captureFromShortcut(item)
        return .result(dialog: IntentDialog(stringLiteral: ShortcutCapture.answer(for: item, filed: filed)))
    }
}

// MARK: Open Today, Start the day, Close the day

/// **Open Today**: PARAGON, on Today.
struct OpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today"
    static let description = IntentDescription("Opens PARAGON on Today.", categoryName: "Day")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        guard model.vault != nil else { throw ShortcutProblem.noVault }
        #if os(macOS)
        model.showMainWindowForShortcut()
        #endif
        model.afterUpdate { model.openSection(.today) }
        return .result()
    }
}

/// **Start the day**: the morning screen, where the day's few actions are picked.
struct StartTheDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Start the Day"
    static let description = IntentDescription(
        "Opens Start the day in PARAGON: pick the few actions that matter today and put them in your plan.",
        categoryName: "Day")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        guard model.vault != nil else { throw ShortcutProblem.noVault }
        #if os(macOS)
        model.showMainWindowForShortcut()
        #endif
        model.openDayStep(.startDay)
        return .result()
    }
}

/// **Close the day**: the evening screen.
struct CloseTheDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Close the Day"
    static let description = IntentDescription(
        "Opens Close the day in PARAGON: what you finished, what did not happen, one line about the day.",
        categoryName: "Day")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        guard model.vault != nil else { throw ShortcutProblem.noVault }
        #if os(macOS)
        model.showMainWindowForShortcut()
        #endif
        model.openDayStep(.closeDay)
        return .result()
    }
}

// MARK: Start focus

/// **Start focus**: the focus clock, on a task you name or on what is next today.
///
/// It does not open the app: the clock is the app's own (`AppModel.startFocus`), so the bar,
/// the Mac's menu bar clock and the notification at the planned end follow as they do after a
/// press on **Focus on this**. A clock already running on something else is stopped and its
/// time written under **Worked** first — the app's rule, unchanged.
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription(
        "Starts PARAGON's focus clock. With no task chosen it takes the block of today's plan that is running now, else the first task due today, else the next block.",
        categoryName: "Focus")
    static let openAppWhenRun = false

    @Parameter(title: "Task", description: "The task to focus on. Leave empty for what is next today.")
    var task: FocusTaskEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start focus on \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        guard model.vault != nil else { throw ShortcutProblem.noVault }
        guard !model.focusQuestionPending else { throw ShortcutProblem.busy }
        let before = model.focus
        let hadProblem = model.errorMessage != nil
        let wanted: String

        if let task {
            guard let ref = FocusTaskEntity.ref(for: task.id, in: model) else { throw ShortcutProblem.taskGone }
            wanted = planBlockTitle(from: ref.task)
            if let running = before, !running.isPaused, running.title == wanted {
                return .result(dialog: IntentDialog(stringLiteral: "The clock is already running on \(Self.spoken(wanted))."))
            }
            model.startFocus(on: ref)
        } else {
            switch model.focusPick() {
            case .block(let block):
                wanted = block.title
                if let running = before, !running.isPaused, NowAndNext.sameName(running.title, wanted) {
                    return .result(dialog: IntentDialog(stringLiteral: "The clock is already running on \(Self.spoken(wanted))."))
                }
                model.startFocus(onBlock: block, on: DateOnly.today())
            case .task(let ref):
                wanted = planBlockTitle(from: ref.task)
                if let running = before, !running.isPaused, running.title == wanted {
                    return .result(dialog: IntentDialog(stringLiteral: "The clock is already running on \(Self.spoken(wanted))."))
                }
                model.startFocus(on: ref)
            case .nothing:
                throw ShortcutProblem.nothingToFocus
            }
        }

        // The app refuses to start a new clock when the old one's time could not be written:
        // the measured time is never thrown away. Its own words say why.
        guard let now = model.focus, now != before, now.title == wanted else {
            if !hadProblem, let why = model.errorMessage {
                model.errorMessage = nil
                throw ShortcutProblem.cannotFocus(why)
            }
            throw ShortcutProblem.taskGone
        }
        let planned = now.plannedMinutes.map { ", \($0) minutes planned" } ?? ""
        return .result(dialog: IntentDialog(stringLiteral: "Focus started on \(Self.spoken(wanted))\(planned)."))
    }

    /// A title as it is read out: without `#tags`.
    private static func spoken(_ title: String) -> String {
        let plain = CaptureReading.line(title, settingTags: [])
        return plain.isEmpty ? title : plain
    }
}

// MARK: What is due today?

/// **What is due today?**: one spoken sentence and a short list. PARAGON is not opened.
struct DueTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "What Is Due Today?"
    static let description = IntentDescription(
        "Says and shows the tasks due today in PARAGON, and how many are overdue, without opening the app. Gives the task names to the next action.",
        categoryName: "Day")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog & ShowsSnippetView {
        let model = AppModel.shared
        guard model.vault != nil else { throw ShortcutProblem.noVault }
        // A fresh look at the files, the app's own: only notes changed since the last look are
        // read again. The open note's unsaved text is written first, as before every re-read.
        if !model.isSyncing {
            model.flushPendingEdits()
            model.reload()
        }
        let answer = DueTodayAnswer(index: model.index, today: DateOnly.today())
        let stillComing = model.notesWaitingForCloud.count
        var spoken = answer.spoken
        if stillComing > 0 {
            spoken += stillComing == 1
                ? " One note is still coming from iCloud, so this may not be everything."
                : " \(stillComing) notes are still coming from iCloud, so this may not be everything."
        }
        return .result(value: answer.due.map(\.title),
                       dialog: IntentDialog(stringLiteral: spoken),
                       view: DueTodaySnippet(answer: answer, stillComing: stillComing))
    }
}

/// The card under the spoken answer: Today's colour, the date, up to five tasks.
///
/// Drawn by the system outside the app's windows, so it takes plain values only and no model.
struct DueTodaySnippet: View {
    let answer: DueTodayAnswer
    let stillComing: Int

    private var tint: Color { SidebarSection.today.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                MarkImage("sun.max", size: 17)
                    .foregroundStyle(tint)
                Text("Due today")
                    .font(.headline)
                    .foregroundStyle(tint)
                Spacer(minLength: 8)
                Text(DayWords.plain(answer.day))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if answer.due.isEmpty {
                Text("Nothing is due today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(answer.shown) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .strokeBorder(tint, lineWidth: 1.6)
                                .frame(width: 13, height: 13)
                                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1.5 }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(line.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(line.noteTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            if let time = line.time {
                                Text(time)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            if let footnote = answer.footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if stillComing > 0 {
                Text(stillComing == 1 ? "1 note is still coming from iCloud." : "\(stillComing) notes are still coming from iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
