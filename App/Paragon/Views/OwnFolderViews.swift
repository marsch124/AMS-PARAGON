import SwiftUI
import ParagonCore

// MARK: - The page (build 319)

/// One page for everything about PARAGON's own folder: the offer to move, the move at work,
/// how it ended, "your notes have moved", changes waiting in the old folder, and going back.
/// Every page that asks something has Cancel (Escape on the Mac) and one full-colour button.
struct OwnFolderPageView: View {
    @EnvironmentObject private var model: AppModel

    /// One block of a page: a small heading in the app's colour and what belongs under it.
    private struct Part {
        var head: String?
        var text: [String] = []
        /// Numbered: what happens, in order.
        var steps: [String] = []
        var devices: [VaultDevices.Line] = []
        var files: [String] = []
        var after: [String] = []
    }

    private struct Words {
        var title: String
        /// What stands in the way, first on the page: its heading, then what to do.
        var notice: [String] = []
        var lead: [String] = []
        var parts: [Part] = []
        /// The steps of a move with the one at work, or empty.
        var moveSteps: [String] = []
        var stepAtWork = 0
        /// Done: the first line carries a tick.
        var good = false
        var cancel: String? = "Cancel"
        var action: String?
    }

    private static func count(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }

    /// "iCloud Drive › PARAGON" is one name: it never breaks over two lines.
    private static let place = VaultMove.ownFolderWords.replacingOccurrences(of: " ", with: "\u{00A0}")
    private static func whole(_ words: String) -> String {
        words.replacingOccurrences(of: VaultMove.ownFolderWords, with: place)
    }

    private static let moveOrder: [MoveProgress.Step] = [.reading, .copying, .checking, .sending, .finishing]

    private var words: Words {
        switch model.ownFolder.page {
        case nil:
            return Words(title: "")
        case .offer(let offer):
            var w = Words(title: "Move your notes to PARAGON\u{2019}s own folder")
            guard offer.reachable else {
                w.notice = ["PARAGON cannot reach iCloud Drive on \(AppModel.thisDevice)",
                            "Check that you are signed in to iCloud and that iCloud Drive is on for PARAGON. Then press Check again.",
                            "Nothing has changed."]
                w.action = "Check again"
                return w
            }
            let ready = VaultDevices.allReady(offer.devices)
            if let other = offer.otherMove {
                w.notice = ["Another device is moving the notes", other]
            } else if !ready {
                w.notice = ["One of your devices is not ready yet",
                            "Open PARAGON \(VaultMove.firstBuild) or newer once on every device. Then press Check again.",
                            "A device with an older PARAGON would go on writing into the old folder, and those changes would not reach the new folder. So PARAGON does not move the notes yet."]
            }
            w.parts = [
                Part(head: "Where your notes will be",
                     text: ["In \(VaultMove.ownFolderWords). PARAGON opens that folder by itself on your iPhone, iPad and Mac. You do not need to choose a folder again."]),
                Part(head: "What happens",
                     steps: ["A backup copy is made and checked.",
                             "Your \(Self.count(offer.notes, "note", "notes")), pictures and settings are copied.",
                             "Every file is compared with its original.",
                             "Only then does PARAGON switch to the new folder."],
                     after: ["Reminders sync is paused during the move and goes on afterwards."]),
                Part(head: "Nothing is deleted",
                     text: ["Your old folder \u{201C}\(offer.oldName)\u{201D} stays as it is. PARAGON only adds one small text file to it that says where the notes went. You decide later when to delete it.",
                            "You can go back: Settings \u{203A} Vault \u{203A} Go back to the old folder\u{2026}"]),
            ]
            if offer.otherMove != nil {
                w.action = "Check again"
                return w
            }
            w.parts.append(Part(head: "Your devices", devices: offer.devices,
                                after: ready ? ["Move on one device only. On your other devices PARAGON then shows \u{201C}Your notes have moved\u{201D}: press Open\u{2026} there."] : []))
            w.action = ready ? "Move my notes" : "Check again"
            return w
        case .working(let title):
            var w = Words(title: title)
            let step = model.ownFolder.progress?.step
            let isMove = title.hasPrefix("Moving"), isBack = title.hasPrefix("Going")
            if isMove || isBack {
                w.moveSteps = ["Reading your notes and making a backup copy",
                               "Copying every file",
                               "Comparing every copy with its original",
                               "Sending to iCloud",
                               isMove ? "Switching to the new folder" : "Switching to the old folder"]
                w.stepAtWork = step.flatMap { Self.moveOrder.firstIndex(of: $0) } ?? 0
                w.lead = [step == .finishing ? "Almost done. Please wait."
                                             : "You can press Stop until the last step. Your notes then stay where they are."]
                w.cancel = step != .finishing ? "Stop" : nil
            } else {
                w.lead = ["Please wait. This takes a moment."]
                w.cancel = nil
            }
            return w
        case .failed(let title, let why):
            return Words(title: title, notice: [why], cancel: nil, action: "OK")
        case .done(let title, let lines):
            return Words(title: title, lead: lines, good: true, cancel: nil, action: "Done")
        case .moved(let moved):
            let stamp = moved.stamp
            let place = stamp.toOwnFolder ? VaultMove.ownFolderWords : "the folder \u{201C}\(stamp.placeName)\u{201D}"
            var w = Words(title: "Your notes have moved")
            w.lead = ["They are now in \(place). The move was made on \(VaultMove.day(stamp.at)), on the device \u{201C}\(stamp.deviceName)\u{201D}.",
                      "Reminders sync is paused on \(AppModel.thisDevice) until it uses the new place too."]
            w.cancel = "Not now"
            if !moved.reachable {
                w.notice = [stamp.toOwnFolder
                    ? "PARAGON cannot reach iCloud Drive on \(AppModel.thisDevice). Check that you are signed in to iCloud and that iCloud Drive is on for PARAGON."
                    : "PARAGON cannot find that folder on \(AppModel.thisDevice). Choose it in Settings \u{203A} Vault \u{203A} Choose folder\u{2026}"]
                w.cancel = "Close"
            } else if moved.ready {
                w.lead.append("Everything has arrived: \(Self.count(moved.here, "file", "files")). What you changed on \(AppModel.thisDevice) since the move comes along.")
                if !moved.missing.isEmpty {
                    w.parts = [Part(text: ["\(Self.count(moved.missing.count, "file", "files")) from the list made at the move \(moved.missing.count == 1 ? "is" : "are") not there. You have probably deleted or renamed \(moved.missing.count == 1 ? "it" : "them") after the move:"],
                                    files: Array(moved.missing.prefix(8)))]
                }
                w.action = "Open the new folder"
            } else {
                w.lead.append("Waiting for iCloud: \(moved.here) of \(moved.expected) files are here. You can go on working; your changes come along.")
                w.cancel = "Close"
            }
            return w
        case .oldChanges(let changes):
            var w = Words(title: "\(Self.count(changes.notes.count, "file was", "files were")) changed in the old folder after the move")
            w.lead = ["Another device still writes into \u{201C}\(changes.oldName)\u{201D}. It has an older PARAGON, or it has not opened the new folder yet."]
            w.parts = [
                Part(head: changes.notes.count == 1 ? "The file" : "The files",
                     files: Array(changes.notes.prefix(12)),
                     after: changes.notes.count > 12 ? ["and \(changes.notes.count - 12) more"] : []),
                Part(head: "What Bring them over does",
                     text: ["A new note is copied. A note changed only in the old folder replaces the one here. A note changed in both places is kept twice.",
                            "Nothing is deleted."]),
            ]
            if !changes.deleted.isEmpty {
                w.parts[1].text.append("\(Self.count(changes.deleted.count, "file was", "files were")) deleted in the old folder. \(changes.deleted.count == 1 ? "It stays" : "They stay") here.")
            }
            w.cancel = "Not now"
            w.action = "Bring them over"
            return w
        case .goBack(let back):
            var w = Words(title: "Go back to the old folder")
            w.lead = ["PARAGON will use \u{201C}\(back.oldName)\u{201D} again and stop using \(VaultMove.ownFolderWords)."]
            w.parts = [
                Part(head: "What happens",
                     steps: ["Changes waiting in the old folder are brought over.",
                             "A backup copy is made and checked.",
                             "Everything you have now is copied to the old folder.",
                             "Every file is compared with its original."]),
                Part(head: "Nothing is deleted",
                     text: ["A file in the old folder that is replaced, or that you have deleted since the move, is set aside there, not deleted.",
                            "\(VaultMove.ownFolderWords) stays as it is."]),
                Part(head: "Your other devices",
                     text: ["They follow: PARAGON shows \u{201C}Your notes have moved\u{201D} there. Press Open\u{2026} on each."]),
            ]
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

    /// The pages he decides on are read in full: they open at full height on the iPhone.
    private var isLong: Bool {
        switch model.ownFolder.page {
        case .offer, .goBack, .oldChanges: return true
        default: return false
        }
    }

    /// A page that opened at full height stays there while it works and when it has finished:
    /// the sheet never jumps under his finger.
    @State private var staysTall = false

    private var tint: Color { Theme.fallbackTint }

    // MARK: Pieces

    private func line(_ words: String, soft: Bool = false) -> some View {
        Text(Self.whole(words))
            .font(Txt.list)
            .foregroundStyle(soft ? Theme.soft : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What stands in the way, in the app's warning look, before everything else.
    private func notice(_ lines: [String]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MarkImage("exclamationmark.triangle", size: 15)
                .foregroundStyle(Theme.attention.ink)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, words in
                    Text(Self.whole(words))
                        .font(index == 0 && lines.count > 1 ? Txt.listTitle : Txt.list)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ownFolder.notice")
    }

    private func deviceRow(_ device: VaultDevices.Line) -> some View {
        let day = device.lastSeen.map { VaultMove.day($0) }
        let second: String
        if let build = device.build {
            second = "PARAGON \(build)" + (device.isThisDevice ? " \u{00B7} this device" : (day.map { " \u{00B7} seen \($0)" } ?? ""))
        } else {
            second = "Has not opened PARAGON \(VaultMove.firstBuild) or newer yet" + (day.map { " \u{00B7} last synced \($0)" } ?? "")
        }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            MarkImage(device.isReady ? "checkmark" : "exclamationmark.triangle", size: 13)
                .foregroundStyle(device.isReady ? tint : Theme.attention.ink)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(device.name).font(Txt.list)
                Text(second).font(Txt.label).foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Resources/Bread recipe.md" reads as the note's name and where it is.
    private func fileRow(_ path: String) -> some View {
        let parts = path.split(separator: "/").map(String.init)
        var name = parts.last ?? path
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        let folder = parts.dropLast().joined(separator: " \u{203A} ")
        return (Text(name) + Text(folder.isEmpty ? "" : "  \u{00B7}  \(folder)").foregroundColor(Theme.soft))
            .font(Txt.list)
            .lineLimit(2)
            .truncationMode(.middle)
    }

    private func part(_ part: Part) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let head = part.head {
                Text(head)
                    .font(Txt.label.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(part.text, id: \.self) { line($0) }
            ForEach(Array(part.steps.enumerated()), id: \.offset) { index, words in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(index + 1).").font(Txt.list).foregroundStyle(.soft).monospacedDigit()
                    line(words)
                }
            }
            ForEach(part.devices) { deviceRow($0) }
            ForEach(part.files, id: \.self) { fileRow($0) }
            ForEach(part.after, id: \.self) { line($0, soft: true) }
        }
    }

    /// The steps of a move: done ones ticked, the one at work with its count, the rest waiting.
    private func stepRows(_ words: Words) -> some View {
        let progress = model.ownFolder.progress
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(words.moveSteps.enumerated()), id: \.offset) { index, name in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Group {
                        if index < words.stepAtWork {
                            MarkImage("checkmark", size: 13).foregroundStyle(tint)
                        } else if index == words.stepAtWork {
                            ProgressView().controlSize(.small)
                        } else {
                            Circle().strokeBorder(Theme.soft.opacity(0.5), lineWidth: 1).frame(width: 9, height: 9)
                        }
                    }
                    .frame(width: 18)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(index == words.stepAtWork ? (progress?.words ?? "Getting ready\u{2026}") : name)
                            .font(index == words.stepAtWork ? Txt.listTitle : Txt.list)
                            .foregroundStyle(index > words.stepAtWork ? Theme.soft : Color.primary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        if index == words.stepAtWork, let progress, progress.total > 0 {
                            ProgressView(value: Double(min(progress.done, progress.total)), total: Double(max(progress.total, 1)))
                                .tint(tint)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("ownFolder.steps")
    }

    var body: some View {
        let words = words
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isWorking, words.moveSteps.isEmpty { ProgressView().controlSize(.small) }
                Text(words.title)
                    .font(Txt.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ownFolder.title")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !words.notice.isEmpty { notice(words.notice) }
                    if !words.moveSteps.isEmpty { stepRows(words) }
                    if !words.lead.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(words.lead.enumerated()), id: \.offset) { index, words in
                                if self.words.good, index == 0 {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        MarkImage("checkmark", size: 14).foregroundStyle(tint)
                                        line(words)
                                    }
                                } else {
                                    line(words, soft: isWorking)
                                }
                            }
                        }
                    }
                    ForEach(Array(words.parts.enumerated()), id: \.offset) { _, one in part(one) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }
            HStack {
                Spacer()
                if let cancel = words.cancel {
                    Button(cancel, role: .cancel) { self.cancel() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("ownFolder.cancel")
                }
                if let action = words.action {
                    Button(action) { act() }
                        .buttonStyle(.filled(tint))
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("ownFolder.confirm")
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        #if os(macOS)
        .frame(width: 460)
        .frame(minHeight: 220, maxHeight: 560)
        #else
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents(isLong || staysTall ? [.large] : [.medium, .large])
        .onAppear { if isLong { staysTall = true } }
        .onChange(of: isLong) { _, long in if long { staysTall = true } }
        .presentationBackground(Theme.canvas)
        #endif
        .interactiveDismissDisabled(isWorking)
        // The page's parts keep their own names for the screen tests.
        .accessibilityElement(children: .contain)
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
            return ("\(stamp.deviceName) is moving your notes back into this folder. Reminders sync is paused until that is done.", nil)
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

    /// Only "cannot reach" is a warning; the rest is news and wears the app's colour.
    private var isWarning: Bool {
        if case .moved(let moved)? = model.ownFolder.banner { return !moved.reachable }
        return false
    }

    var body: some View {
        if let words {
            HStack(spacing: 8) {
                MarkImage(isWarning ? "exclamationmark.triangle" : "folder", size: 14)
                    .foregroundStyle(isWarning ? Theme.attention.ink : Theme.fallbackTint)
                Text(words.text.replacingOccurrences(of: VaultMove.ownFolderWords,
                                                     with: VaultMove.ownFolderWords.replacingOccurrences(of: " ", with: "\u{00A0}")))
                    .font(Txt.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ownFolder.banner.text")
                Spacer(minLength: 4)
                if let button = words.button {
                    Button(button) { open() }
                        .buttonStyle(.filled(Theme.fallbackTint))
                        .controlSize(.small)
                        .accessibilityIdentifier("ownFolder.banner.button")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isWarning ? Color.orange : Theme.fallbackTint).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Theme.radius))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.canvas)
            .accessibilityElement(children: .contain)
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
                } else if model.ownFolder.reachable {
                    // Review of build 319: offered only where PARAGON's folder can be reached.
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
        var parts = [found.notes == 1 ? "1 note" : "\(found.notes.formatted()) notes"]
        if let changed = found.lastChanged { parts.append("last changed \(VaultMove.day(changed))") }
        return parts.joined(separator: " \u{00B7} ")
    }

    var body: some View {
        if let found = model.ownFolder.found {
            VStack(spacing: 6) {
                Text("I found your notes here \u{2014} use them?")
                    .font(Txt.sectionTitle)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("ownFolder.found")
                HStack(spacing: 6) {
                    MarkImage("folder", size: 14).foregroundStyle(Theme.fallbackTint)
                    Text(VaultMove.ownFolderWords).font(Txt.list)
                }
                Text(Self.details(found))
                    .font(Txt.label)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.soft)
                if let caution = found.caution {
                    Text(caution)
                        .font(Txt.label)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.attention.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Use them") { model.useFoundNotes() }
                    .buttonStyle(.filled(Theme.fallbackTint))
                    .padding(.top, 4)
                    .accessibilityIdentifier("ownFolder.found.use")
            }
            .padding(12)
            .frame(maxWidth: 420)
            .background(Theme.fallbackTint.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.panelRadius))
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
