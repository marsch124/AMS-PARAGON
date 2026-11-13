import Foundation
import ParagonCore
#if os(macOS)
import AppKit
#endif

// Build 317 (features-07): how the actions in Shortcuts and Siri reach PARAGON.
//
// **An action runs inside the app itself**, never in a helper of its own: the system starts
// PARAGON quietly in the background when it is not running, and uses the running app when it
// is. So there is one `AppModel`, one open vault and one writer — an action goes through the
// very functions a press in the app goes through (`capture`, `startFocus`, `openSection`).
// Nothing in this folder opens a file.

extension AppModel {
    /// The one model, for the app's windows and for the actions alike. Made on first use: by
    /// `ParagonApp` when a window is drawn, or by an action when the system has started the
    /// app in the background and no window exists yet.
    static let shared = AppModel()

    /// The **Add to Inbox** action. Through `capture(text:url:target:asTask:)`, the path Quick
    /// capture takes: the open note's unsaved text is written first, the Inbox is read from its
    /// file and saved, and when that cannot be done now (no vault open, the Inbox still coming
    /// from iCloud) the words are kept in the capture outbox — the share extension's file — and
    /// filed the next time the app sees the vault. Answers whether it is in the Inbox now.
    ///
    /// **It never says "Added" for words that are nowhere** (build 317): when the Inbox could
    /// not be written and the outbox could not be written either, it throws
    /// `ShortcutProblem.notSaved`, and Siri says so in plain words.
    func captureFromShortcut(_ item: CaptureItem) throws -> Bool {
        let asked = Date().addingTimeInterval(-1)
        // Set aside for a moment, so a problem with this very capture can be told from an
        // older one that is still on screen.
        let problemBefore = errorMessage
        errorMessage = nil
        capture(text: item.text, url: nil, target: item.target, asTask: item.asTask)
        let waiting = CaptureOutbox(fileURL: Self.outboxURL).peek()
        let kept = waiting.contains { $0.text == item.text && $0.createdAt >= asked }
        // `capture` reports its own failure with these words (and then tries the outbox).
        let failed = errorMessage?.hasPrefix("Could not file the capture now") == true
        // In the Inbox now: a vault is open, the capture did not fail, and the app's own answer
        // is "Saved to Inbox" (every other answer of `capture` means "kept for later").
        let filed = vault != nil && !failed && (lastCaptureMessage ?? "").hasPrefix("Saved to ")
        // The app would otherwise greet him with "Something went wrong" for this capture; the
        // action's own answer already says what happened to it. Another problem is left to show.
        if failed || errorMessage == nil { errorMessage = problemBefore }
        if kept { return false }
        guard filed else { throw ShortcutProblem.notSaved }
        return true
    }

    /// **Start the day** and **Close the day** from an action: the rule of a press on the daily
    /// reminder (`ContentView.answerReminder`). A screen already open is never thrown away for
    /// it — the day's screen then waits until that one is closed.
    func openDayStep(_ sheet: AppSheet) {
        afterUpdate {
            guard self.vault != nil else { return }
            if self.activeSheet == sheet { return }
            if self.activeSheet != nil || self.focusQuestionPending || self.whatNext != nil {
                self.openWhenFree(sheet)
                return
            }
            self.activeSheet = sheet
        }
    }

    /// The tasks **Start focus** offers when asked to choose: due today or overdue first
    /// (Today's order), then each project's next action. Never a task in a work note.
    func focusSuggestions(limit: Int = 30) -> [TaskRef] {
        let today = DateOnly.today()
        let dated = index.openTasks(dueOnOrBefore: today)
        let shown = Set(dated.map(\.id))
        let next = index.nextActions().filter { !shown.contains($0.id) }
        return Array((dated + next).filter { canFocus(on: $0) }.prefix(limit))
    }

    /// The open tasks whose words contain the text, for **Start focus**'s search.
    func focusMatches(_ text: String, limit: Int = 30) -> [TaskRef] {
        let wanted = text.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return focusSuggestions(limit: limit) }
        return Array(index.openTasks()
            .filter { $0.task.title.localizedCaseInsensitiveContains(wanted) && canFocus(on: $0) }
            .prefix(limit))
    }

    /// What **Start focus** starts on when no task was named (`FocusPick`, tested in Core).
    func focusPick(at date: Date = Date()) -> FocusPick {
        let today = DateOnly(date)
        let plan = NowAndNext(blocks: planBlocks(for: today), minute: NowAndNext.minute(of: date))
        let due = index.openTasks(dueOn: today).filter { canFocus(on: $0) }
        return FocusPick.pick(plan: plan, dueToday: due)
    }

    #if os(macOS)
    /// Brings PARAGON's main window to the front for an action that shows something, and opens
    /// one when it was closed. The same search as the menu bar clock's **Show PARAGON**.
    func showMainWindowForShortcut() {
        if NSApp.isHidden { NSApp.unhide(nil) }
        NSApp.activate()
        func holdsMarker(_ view: NSView?) -> Bool {
            guard let view else { return false }
            if view is MainWindowMarker.MarkerView { return true }
            return view.subviews.contains { holdsMarker($0) }
        }
        let shown = NSApp.windows.filter { $0.isVisible || $0.isMiniaturized }
        if let main = shown.first(where: { holdsMarker($0.contentView) }) {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
        } else if let open = openMainWindow {
            open()
        }
        // With neither, the system is opening the app for this action and makes the window.
    }
    #endif
}

/// What an action says when it cannot do its job. Plain words: Siri reads them out.
enum ShortcutProblem: Error, CustomLocalizedStringResourceConvertible {
    case noVault
    case nothingToFocus
    case taskGone
    case cannotFocus(String)
    case busy
    /// Neither the Inbox nor the capture outbox could be written.
    case notSaved

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noVault:
            return "PARAGON has no notes folder open. Open PARAGON and choose your folder first."
        case .nothingToFocus:
            return "Nothing is planned or due today. Choose a task to focus on."
        case .taskGone:
            return "That task is no longer open in PARAGON."
        case .cannotFocus(let why):
            return "\(why)"
        case .busy:
            return "PARAGON is asking about the clock you stopped. Answer that first."
        case .notSaved:
            return "PARAGON could not save this, so it was not added. Nothing was lost from your notes. Please try again."
        }
    }
}
