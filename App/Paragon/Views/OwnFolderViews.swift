import SwiftUI
import ParagonCore

// MARK: - The page (build 319)

/// One page for everything about PARAGON's own folder: the offer to move, the move at work,
/// how it ended, "your notes have moved", changes waiting in the old folder, and going back.
/// Every page that asks something has Cancel (Escape on the Mac) and one full-colour button.
struct OwnFolderPageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var askingAnyway = false

    private struct Words {
        var title: String
        var lines: [String] = []
        var list: [String] = []
        var cancel: String? = "Cancel"
        var action: String?
        var second: String?
    }

    private static func count(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }

    private var words: Words {
        switch model.ownFolder.page {
        case nil:
            return Words(title: "")
        case .offer(let offer):
            var w = Words(title: "Move your notes to PARAGON\u{2019}s own folder")
            guard offer.reachable else {
                w.lines = ["PARAGON cannot reach iCloud Drive on \(AppModel.thisDevice). Check that you are signed in to iCloud and that iCloud Drive is on for PARAGON, then check again.",
                           "Nothing has changed."]
                w.action = "Check again"
                return w
            }
            w.lines = [
                "PARAGON gets a folder of its own, \(VaultMove.ownFolderWords), and opens it by itself on your iPhone, iPad and Mac. No folder to choose, nothing to remember.",
                "What happens: a backup copy is made and checked. Then your \(Self.count(offer.notes, "note", "notes")), pictures and settings are copied, and every file is compared with its original. Only then does PARAGON switch.",
                "Your old folder \u{201C}\(offer.oldName)\u{201D} stays as it is. PARAGON adds one small text file to it that says where the notes went. You decide later when it can go.",
                "Reminders sync rests during the move and goes on afterwards.",
            ]
            if let other = offer.otherMove {
                w.lines.append(other)
                w.action = "Check again"
                return w
            }
            w.list = offer.devices.map(\.words)
            if VaultDevices.allReady(offer.devices) {
                w.lines.append("Move on one device only. The others follow by themselves.")
                w.action = "Move my notes"
            } else {
                w.lines.append("Open PARAGON \(VaultMove.firstBuild) or newer once on every device first. A device with an older PARAGON would go on writing into the old folder.")
                w.action = "Check again"
                w.second = "Move anyway\u{2026}"
            }
            return w
        case .working(let title):
            var w = Words(title: title)
            w.lines = [model.ownFolder.progress?.words ?? "Getting ready\u{2026}",
                       "You can stop until the last step. If you stop, nothing has changed."]
            let step = model.ownFolder.progress?.step
            w.cancel = (title.hasPrefix("Moving") || title.hasPrefix("Going")) && step != .finishing ? "Stop" : nil
            return w
        case .failed(let title, let why):
            return Words(title: title, lines: [why], cancel: nil, action: "OK")
        case .done(let title, let lines):
            return Words(title: title, lines: lines, cancel: nil, action: "Done")
        case .moved(let moved):
            let stamp = moved.stamp
            let place = stamp.toOwnFolder ? VaultMove.ownFolderWords : "the folder \u{201C}\(stamp.placeName)\u{201D}"
            var w = Words(title: "Your notes have moved")
            w.lines = ["On \(VaultMove.day(stamp.at)) \(stamp.deviceName) moved them to \(place).",
                       "Reminders sync rests on \(AppModel.thisDevice) until it uses the new place too."]
            w.cancel = "Not now"
            if !moved.reachable {
                w.lines.append(stamp.toOwnFolder
                    ? "PARAGON cannot reach iCloud Drive on \(AppModel.thisDevice). Check that iCloud Drive is on for PARAGON."
                    : "PARAGON cannot find that folder on \(AppModel.thisDevice). Choose it in Settings \u{203A} Vault \u{203A} Choose folder\u{2026}")
            } else if moved.ready {
                w.lines.append("Everything is here: \(Self.count(moved.here, "file", "files")). What you changed on \(AppModel.thisDevice) since the move comes along.")
                if !moved.missing.isEmpty {
                    w.lines.append("\(Self.count(moved.missing.count, "file", "files")) from the list made at the move \(moved.missing.count == 1 ? "is" : "are") not there; deleted or renamed since, it seems:")
                    w.list = Array(moved.missing.prefix(8))
                }
                w.action = "Open the new folder"
            } else {
                w.lines.append("Waiting for iCloud: \(moved.here) of \(moved.expected) files are here. You can go on working; your changes come along.")
            }
            return w
        case .oldChanges(let changes):
            var w = Words(title: "\(Self.count(changes.notes.count, "file was", "files were")) changed in the old folder after the move")
            w.lines = ["A device with an older PARAGON still writes into \u{201C}\(changes.oldName)\u{201D}.",
                       "Bring them over: a new note is copied; a note changed only there replaces the one here; a note changed in both places is kept twice. Nothing is deleted."]
            w.list = Array(changes.notes.prefix(12)) + (changes.notes.count > 12 ? ["and \(changes.notes.count - 12) more"] : [])
            if !changes.deleted.isEmpty {
                w.lines.append("\(Self.count(changes.deleted.count, "file was", "files were")) deleted there. \(changes.deleted.count == 1 ? "It stays" : "They stay") here.")
            }
            w.cancel = "Not now"
            w.action = "Bring them over"
            return w
        case .goBack(let back):
            var w = Words(title: "Go back to the old folder")
            w.lines = ["PARAGON will use \u{201C}\(back.oldName)\u{201D} again and stop using \(VaultMove.ownFolderWords).",
                       "What happens: changes waiting in the old folder are brought over, a backup copy is made and checked, then everything you have now is copied to the old folder and every file is compared.",
                       "A file in the old folder that is replaced, or that you have deleted since, is set aside there, not deleted.",
                       "Your other devices follow by themselves. \(VaultMove.ownFolderWords) stays as it is."]
            w.action = "Go back"
            return w
        }
    }

    private func act() {
        switch model.ownFolder.page {
        case .offer(let offer):
            if offer.reachable, offer.otherMove == nil, VaultDevices.allReady(offer.devices) {
                model.startMove(toOwn: true)
            } else {
                model.showMoveOffer(fromSettings: model.ownFolder.pageFromSettings)
            }
        case .moved: model.followMove()
        case .oldChanges: model.bringOldChangesOver()
        case .goBack: model.startMove(toOwn: false)
        case .failed, .done, .working, nil: model.closeOwnFolderPage()
        }
    }

    private func cancel() {
        switch model.ownFolder.page {
        case .working: model.cancelMove()
        case .oldChanges: model.notNowForOldChanges()
        default: model.closeOwnFolderPage()
        }
    }

    private var isWorking: Bool {
        if case .working = model.ownFolder.page { return true }
        return false
    }

    var body: some View {
        let words = words
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if isWorking { ProgressView().controlSize(.small) }
                Text(words.title)
                    .font(Txt.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ownFolder.title")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(words.lines, id: \.self) { line in
                        Text(line)
                            .font(Txt.list)
                            .foregroundStyle(.soft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !words.list.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(words.list, id: \.self) { line in
                                Text(line)
                                    .font(Txt.label)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    if let progress = model.ownFolder.progress, isWorking, progress.total > 0 {
                        ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                            .tint(Theme.fallbackTint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if let second = words.second {
                    Button(second) { askingAnyway = true }
                        .accessibilityIdentifier("ownFolder.anyway")
                }
                Spacer()
                if let cancel = words.cancel {
                    Button(cancel, role: .cancel) { self.cancel() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("ownFolder.cancel")
                }
                if let action = words.action {
                    Button(action) { act() }
                        .buttonStyle(.filled(Theme.fallbackTint))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("ownFolder.confirm")
                }
            }
            .padding(.top, 6)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 460)
        .frame(minHeight: 220, maxHeight: 520)
        #else
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.canvas)
        #endif
        .interactiveDismissDisabled(isWorking)
        .confirmationDialog("Move although a device has not opened PARAGON \(VaultMove.firstBuild) yet?",
                            isPresented: $askingAnyway, titleVisibility: .visible) {
            Button("Move my notes") { model.startMove(toOwn: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("That device goes on writing into the old folder until it is updated. PARAGON will find such changes later and offer to bring them over.")
        }
        .accessibilityIdentifier("ownFolder.page")
    }
}

/// Settings shows the page itself: on the Mac it is a window of its own.
struct OwnFolderSheet: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { model.ownFolder.pageFromSettings && model.ownFolder.page != nil },
            set: { shown in if !shown { model.afterUpdate { model.closeOwnFolderPage() } } }
        )) {
            OwnFolderPageView()
                .environmentObject(model)
        }
    }
}

// MARK: - The bar in the main window

/// A quiet bar at the top of the window while something about the folder waits for him: the
/// notes have moved, or files were changed in the old folder after the move. Nothing otherwise.
struct OwnFolderBanner: View {
    @EnvironmentObject private var model: AppModel

    private var words: (text: String, button: String?)? {
        switch model.ownFolder.banner {
        case nil:
            return nil
        case .moved(let moved):
            if moved.ready { return ("Your notes have moved to \(moved.stamp.toOwnFolder ? VaultMove.ownFolderWords : moved.stamp.placeName).", "Open\u{2026}") }
            if !moved.reachable { return ("Your notes have moved. PARAGON cannot reach the new place on \(AppModel.thisDevice).", "More\u{2026}") }
            return ("Your notes have moved. Waiting for iCloud: \(moved.here) of \(moved.expected) files.", "More\u{2026}")
        case .beingFilled(let stamp):
            return ("\(stamp.deviceName) is moving your notes back into this folder. Reminders sync rests until that is done.", nil)
        case .oldChanges(let changes):
            let n = changes.notes.count
            return ("\(n) file\(n == 1 ? " was" : "s were") changed in the old folder after the move.", "Look\u{2026}")
        }
    }

    private func open() {
        switch model.ownFolder.banner {
        case .moved(let moved): model.showOwnFolderPage(.moved(moved), fromSettings: false)
        case .oldChanges(let changes): model.showOwnFolderPage(.oldChanges(changes), fromSettings: false)
        case .beingFilled, nil: break
        }
    }

    var body: some View {
        if let words {
            HStack(spacing: 8) {
                Text(words.text)
                    .font(Txt.label)
                    .foregroundStyle(Theme.attention.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if let button = words.button {
                    Button(button) { open() }
                        .buttonStyle(.filled(Theme.fallbackTint))
                        .accessibilityIdentifier("ownFolder.banner.button")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.canvas)
            .accessibilityIdentifier("ownFolder.banner")
        }
    }
}

// MARK: - Settings › Vault

/// The rows under **Folder** in Settings › Vault: where the notes are, the offer to move, the
/// way to the folder, and the way back.
struct OwnFolderSettingsRows: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.vault != nil {
            if model.ownFolder.isOwn {
                Text("PARAGON keeps your notes in its own folder, \(VaultMove.ownFolderWords), and opens it by itself on every device.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
                #if os(iOS)
                Button("Show in Files") { model.showVaultFolder() }
                    .accessibilityIdentifier("settings.vault.show")
                #endif
                if let old = model.ownFolder.previousName, model.ownFolder.canGoBack {
                    Text("Your old folder \u{201C}\(old)\u{201D} is still there, as it was" + (model.ownFolder.movedOn.map { " on \(VaultMove.day($0))" } ?? "") + ". PARAGON only reads it.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Go back to the old folder\u{2026}") { model.showGoBack(fromSettings: true) }
                        .accessibilityIdentifier("settings.vault.goBack")
                }
            } else {
                #if os(iOS)
                Button("Show in Files") { model.showVaultFolder() }
                    .accessibilityIdentifier("settings.vault.show")
                #endif
                if case .moved(let moved)? = model.ownFolder.banner {
                    Button("Your notes have moved\u{2026}") { model.showOwnFolderPage(.moved(moved), fromSettings: true) }
                        .accessibilityIdentifier("settings.vault.moved")
                } else {
                    Button("Move to PARAGON\u{2019}s own folder\u{2026}") { model.showMoveOffer(fromSettings: true) }
                        .accessibilityIdentifier("settings.vault.move")
                    Text("PARAGON can keep the notes in a folder of its own in iCloud Drive and open it by itself on every device. Nothing happens until you say so.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - The welcome screen

/// "I found your notes here — use them?" on the welcome screen, before anything else.
struct OwnFolderFoundView: View {
    @EnvironmentObject private var model: AppModel

    private static func details(_ found: OwnFolderState.Found) -> String {
        var parts = ["\(VaultMove.ownFolderWords): \(found.notes == 1 ? "1 note" : "\(found.notes.formatted()) notes")"]
        if let changed = found.lastChanged { parts.append("last changed \(VaultMove.day(changed))") }
        return parts.joined(separator: ", ") + "."
    }

    var body: some View {
        if let found = model.ownFolder.found {
            VStack(spacing: 8) {
                Text("I found your notes here \u{2014} use them?")
                    .font(Txt.sectionTitle)
                    .accessibilityIdentifier("ownFolder.found")
                Text(Self.details(found))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.soft)
                if let caution = found.caution {
                    Text(caution)
                        .font(Txt.label)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.attention.ink)
                }
                Button("Use them") { model.useFoundNotes() }
                    .buttonStyle(.filled(Theme.fallbackTint))
                    .accessibilityIdentifier("ownFolder.found.use")
            }
            .frame(maxWidth: 420)
        } else if let note = model.ownFolder.foundNote {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(note)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 420)
        }
    }
}
