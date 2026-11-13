import SwiftUI
import AppIntents
import CoreSpotlight
import ParagonCore
#if os(macOS)
import AppKit
#endif

// MARK: A press on a result

/// Opens the note a result in the system search stands for (build 317).
@MainActor
enum SystemSearchOpening {
    private static var last: (identifier: String, at: Date)?

    static func open(_ activity: NSUserActivity, in model: AppModel) {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              identifier.hasPrefix(SystemSearchIndexer.identifierPrefix) else { return }
        // The Mac may hand one press over twice (the window and the app each hear it).
        if let last, last.identifier == identifier, Date().timeIntervalSince(last.at) < 1.5 { return }
        last = (identifier, Date())
        let path = String(identifier.dropFirst(SystemSearchIndexer.identifierPrefix.count))
        // `afterUpdate`: the press may arrive while the window it opened is still being drawn.
        model.afterUpdate {
            guard model.vault != nil else { return }
            #if os(macOS)
            model.showMainWindowForShortcut()
            #endif
            if let note = model.index.note(path: path) {
                // The link path: the section first, the note on the next turn.
                model.show(note)
            } else {
                model.flash("PARAGON could not find that note. It may have been moved or deleted.")
            }
        }
    }
}

/// On the main window: hears a press on a result, and starts the indexer once a window is up.
struct SystemSearchLink: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                SystemSearchOpening.open(activity, in: model)
            }
            .task { SystemSearchIndexer.shared.start(model: model) }
    }
}

#if os(macOS)
extension ReminderAppDelegate {
    /// The Mac hands a press on a Spotlight result to the app as well as to a window; with no
    /// main window open only the app hears it.
    @objc(application:continueUserActivity:restorationHandler:)
    func application(_ application: NSApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType else { return false }
        MainActor.assumeIsolated {
            SystemSearchOpening.open(userActivity, in: AppModel.shared)
        }
        return true
    }
}
#endif

// MARK: Settings

/// **Settings › System search** (build 317): the switch, how many notes are in it, and the
/// button that builds the list again.
struct SystemSearchSection: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(SystemSearchRule.settingKey) private var isOn = true
    @ObservedObject private var indexer = SystemSearchIndexer.shared

    private var countText: String {
        if !isOn { return "None" }
        if model.vault == nil { return "No vault open" }
        guard let count = indexer.count else { return indexer.isWorking ? "Building\u{2026}" : "Not built yet" }
        return indexer.isWorking ? "\(count), updating\u{2026}" : "\(count)"
    }

    private var explanation: String {
        #if os(macOS)
        let place = "Spotlight (\u{2318}Space) on this Mac"
        #else
        let place = "the search on this device (swipe down on the Home Screen)"
        #endif
        return "With this on, \(place) finds your notes by title, first words and tags, and a press on a result opens the note in PARAGON. The list stays on this device. Work notes are never in it."
    }

    var body: some View {
        Section("System search") {
            Toggle("Show notes in system search", isOn: $isOn)
                .accessibilityIdentifier("settings.systemSearch.switch")
                .onChange(of: isOn) { _, _ in indexer.settingChanged() }
            LabeledContent("Notes in it") {
                Text(countText)
                    .foregroundStyle(Theme.soft)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("settings.systemSearch.count")
            Button("Build the list again") { indexer.rebuild() }
                .disabled(!isOn || model.vault == nil || indexer.isWorking)
                .accessibilityIdentifier("settings.systemSearch.rebuild")
            Text(explanation)
                .font(Txt.label)
                .foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// **Settings › Siri and Shortcuts** (build 317): what can be said, and the way into Apple's
/// Shortcuts app, where the same six actions are ready without setting anything up.
struct SiriShortcutsSection: View {
    struct Phrase: Identifiable {
        let action: String
        let say: String
        var id: String { action }
    }

    /// What to say, in the order of `ParagonShortcuts`. The first phrase of each. Each action
    /// is spelled as its tile in the Shortcuts app spells it ("Start the Day"), so the name
    /// here is the name he looks for there (designer, build 317; before: "Start the day").
    static let phrases: [Phrase] = [
        Phrase(action: "Add to Inbox", say: "Add to PARAGON"),
        Phrase(action: "Due Today", say: "What is due today in PARAGON"),
        Phrase(action: "Open Today", say: "Open Today in PARAGON"),
        Phrase(action: "Start the Day", say: "Start the day in PARAGON"),
        Phrase(action: "Close the Day", say: "Close the day in PARAGON"),
        Phrase(action: "Start Focus", say: "Start focus in PARAGON"),
    ]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var widthClass
    #endif

    /// On the iPhone every row is the action with its phrase under it. Side by side, the
    /// longest phrase ("What is due today in PARAGON") did not fit and that one row alone
    /// broke into two lines (designer's list, build 317). The iPad and the Mac have the width.
    private var stacked: Bool {
        #if os(iOS)
        return widthClass == .compact
        #else
        return false
        #endif
    }

    @ViewBuilder
    private func phraseRow(_ row: Phrase) -> some View {
        let say = "\u{201C}\(row.say)\u{201D}"
        if stacked {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.action)
                Text(say)
                    .font(Txt.label)
                    .foregroundStyle(Theme.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent(row.action) {
                Text(say)
                    .foregroundStyle(Theme.soft)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    var body: some View {
        Section("Siri and Shortcuts") {
            ForEach(Self.phrases) { row in
                phraseRow(row)
            }
            #if os(iOS)
            // Apple's own button: opens the Shortcuts app on PARAGON's actions.
            ShortcutsLink()
                .shortcutsLinkStyle(.automaticOutline)
                .accessibilityIdentifier("settings.shortcuts.open")
            #else
            // Apple gives the Mac no such button; this opens the Shortcuts app.
            Button("Open Shortcuts") {
                if let url = URL(string: "shortcuts://") { NSWorkspace.shared.open(url) }
            }
            .accessibilityIdentifier("settings.shortcuts.open")
            #endif
            Text("Say one of these to Siri, or find the same six actions in the Shortcuts app and in the system search. Add to Inbox and What is due today answer without opening PARAGON.")
                .font(Txt.label)
                .foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
