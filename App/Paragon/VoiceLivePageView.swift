#if os(iOS)
import SwiftUI
import UIKit
import ParagonCore

// Build 366: **the live page** — the large recording page inside PARAGON, iPhone and iPad.
//
// His words, 24 November 2026: "I want the panel to be larger and I want it to be persistent.
// And when I press stop, I still want it to be persistent and show the analytics, what is
// defined as, or what is suggested as an action and so on."
//
// The Lock Screen card cannot be that: iOS caps it at 160 points and turns a locked screen dark
// after some seconds, whatever the app wants. A page inside the app can: it fills the screen,
// keeps the screen lit while it records, and after **Stop** it stays until **Done**, with the
// title, the summary, the key points and the tasks found (each with a switch).
//
// - `VoiceLiveCenter` holds what the page shows. The one recorder hands it every state it also
//   hands the Lock Screen card (`VoiceRecorder.showActivity`), the longer run of words
//   (`showWords`) and the filed thought (`afterFiling`).
// - `VoiceLivePageView` draws it. Always dark, like the card.
// - `VoiceLivePageLayer` is the overlay `ContentView` carries. An overlay, not a sheet: the
//   window has one sheet (build 44), and a page that came up over an open sheet would be two
//   presentations at once (build 246). Under an open sheet the page simply waits.
//
// The rules (when it comes up, how long the screen stays lit, the words) are in Core,
// `VoiceLivePage`, with tests.

/// What the live page shows now.
@MainActor
final class VoiceLiveCenter: ObservableObject {
    static let shared = VoiceLiveCenter()

    /// The page is on screen (or will be the moment PARAGON is in front).
    @Published private(set) var isUp = false
    @Published private(set) var state: VoiceCardState?
    /// When the recording began: the page's clock counts from here.
    @Published private(set) var startedAt = Date.distantPast
    /// The last `VoiceLivePage.lettersShown` letters of what was said.
    @Published private(set) var heard = ""
    /// The thought once it is filed: its note, its title and its tasks.
    @Published private(set) var result: VoiceFiled?
    /// The summary did not come within its 20 seconds and is written into the note later.
    @Published private(set) var summaryLate = false
    /// **Stop** was pressed and the recorder has not answered yet: a second press must not
    /// reach it (a stop that finds nothing recording takes the Lock Screen card away).
    @Published private(set) var stopping = false
    /// The result's title field and the tasks he switched off.
    @Published var title = ""
    @Published var removed: Set<String> = []

    /// He pressed **Hide** for this recording.
    private var hidden = false
    /// PARAGON was really away (in the background), not only covered for a moment.
    private var wasAway = false
    private var endedAt: Date?
    private var dimming: Task<Void, Never>?

    var stage: VoiceCardWords.Stage? {
        state.flatMap { VoiceCardWords.Stage(rawValue: $0.stage.rawValue) }
    }

    /// Called by the recorder with every state it gives the Lock Screen card.
    func show(_ state: VoiceCardState, startedAt: Date) {
        if startedAt != self.startedAt {
            // A new recording: nothing of the one before stays on the page. A thought that was
            // not looked at yet is still filed, and the check card takes it later.
            self.startedAt = startedAt
            result = nil
            summaryLate = false
            heard = ""
            title = ""
            removed = []
            hidden = false
            stopping = false
            endedAt = nil
        }
        self.state = state
        guard let stage else { return }
        if VoiceLivePage.comesUp(stage, hidden: hidden) { isUp = true }
        switch stage {
        case .preparing, .listening:
            endedAt = nil
        case .writing:
            endedAt = nil
            stopping = false
        case .saved:
            if endedAt == nil { endedAt = Date() }
            stopping = false
        case .nothing:
            if endedAt == nil { endedAt = Date() }
            stopping = false
            // Nothing was saved and nobody is looking: the Lock Screen card has said so, and a
            // page about it hours later would talk about a press long past.
            if UIApplication.shared.applicationState != .active {
                close()
                return
            }
        }
        refreshScreen()
    }

    /// The recorder's longer run of words, about once a second.
    func hear(_ words: String) {
        if words != heard { heard = words }
    }

    /// The recorder filed the thought. True when the page shows it (the check card then stays
    /// away: the page is the check).
    func took(_ filed: VoiceFiled, summaryLate late: Bool) -> Bool {
        guard isUp else { return false }
        result = filed
        summaryLate = late
        title = filed.title
        removed = []
        return true
    }

    /// The recording could not start after all (no Lock Screen card): no page either.
    func clear() {
        close()
    }

    /// **Hide**: the page goes, the recording goes on. The Lock Screen card and the red dot at
    /// the top of the screen still show it.
    func hide() {
        hidden = true
        isUp = false
        refreshScreen()
    }

    /// **Done**, **Open the note**, **Throw it away**: the page is finished with.
    func close() {
        isUp = false
        state = nil
        result = nil
        summaryLate = false
        heard = ""
        stopping = false
        endedAt = nil
        refreshScreen()
    }

    /// PARAGON went to the background.
    func wentAway() {
        wasAway = true
    }

    /// PARAGON came to the front. A recording that runs shows its page again, also after
    /// **Hide**: a press on the Lock Screen card or on the red dot is how he asks for it.
    /// Only when PARAGON was really away: Control Center, a Face ID question or the list of
    /// notifications cover the app for a moment, and a page he hid must not come back for those.
    func cameToFront() {
        if wasAway, let stage, VoiceCardWords.isRunning(stage) {
            hidden = false
            isUp = true
        }
        wasAway = false
        refreshScreen()
    }

    // MARK: The buttons

    /// **Stop**, or **Stop to Today / Stop to Inbox** (`place`: "", "today" or "inbox").
    func stop(into place: String = "") {
        guard !stopping else { return }
        stopping = true
        Task { @MainActor in
            await VoiceActivityBridge.runStop(place)
            self.stopping = false
        }
    }

    func pause() {
        Task { @MainActor in await VoiceActivityBridge.runPause() }
    }

    func mark() {
        Task { @MainActor in await VoiceActivityBridge.runMark() }
    }

    // MARK: The screen stays lit

    /// The screen is kept lit while the page is up and the rule says so, and handed back to
    /// the iPhone's own Auto-Lock the moment it does not.
    private func refreshScreen() {
        dimming?.cancel()
        dimming = nil
        var lit = false
        if isUp, let stage {
            let since = endedAt.map { Date().timeIntervalSince($0) } ?? 0
            lit = VoiceLivePage.keepsScreenLit(stage, secondsSinceEnd: since)
            if lit, endedAt != nil {
                let wait = max(1, VoiceLivePage.litAfterEnd - since + 0.5)
                dimming = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(wait))
                    guard !Task.isCancelled else { return }
                    self?.refreshScreen()
                }
            }
        }
        if UIApplication.shared.isIdleTimerDisabled != lit {
            UIApplication.shared.isIdleTimerDisabled = lit
        }
    }
}

/// The overlay `ContentView` carries: the page while it is up, nothing otherwise.
struct VoiceLivePageLayer: View {
    @ObservedObject private var center = VoiceLiveCenter.shared
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if center.isUp {
            VoiceLivePageView(center: center)
                .environmentObject(model)
                .transition(.opacity)
        }
    }
}

/// The page itself.
struct VoiceLivePageView: View {
    @ObservedObject var center: VoiceLiveCenter
    @EnvironmentObject private var model: AppModel

    /// The recording red, the Inbox green and Today's purple of the Lock Screen card
    /// (`VoiceLook` in the widget extension, which the app cannot see).
    static let red = Color(red: 0.886, green: 0.294, blue: 0.290)
    static let inbox = Color(red: 0.706, green: 0.824, blue: 0.353)
    static let today = Color(red: 0.663, green: 0.561, blue: 0.878)
    /// The card's own dark, so the page reads the same by day and by night.
    static let page = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let quiet = Color.white.opacity(0.65)

    var body: some View {
        ZStack(alignment: .top) {
            // The strip behind the clock and the battery keeps the app's own page colour, so
            // they stay readable by day; the dark page starts under it.
            // The dark look is set on the page under it only: set on the whole stack it would
            // turn this strip to its night colour too, and the clock would be black on dark.
            Theme.canvas.ignoresSafeArea()
            ZStack(alignment: .top) {
                Self.page.ignoresSafeArea(edges: [.bottom, .horizontal])
                if let state = center.state, let stage = center.stage {
                    content(state, stage)
                        .frame(maxWidth: 640)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                }
            }
            .foregroundStyle(Color.white)
            .environment(\.colorScheme, .dark)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceLive.page")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            // A keyboard left up by the screen underneath would lie over the buttons.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    @ViewBuilder
    private func content(_ state: VoiceCardState, _ stage: VoiceCardWords.Stage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header(state, stage)
            switch stage {
            case .preparing, .listening:
                running(state, stage)
            case .writing:
                writing(state)
            case .saved:
                saved(state)
            case .nothing:
                nothing(state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: The first line

    private func header(_ state: VoiceCardState, _ stage: VoiceCardWords.Stage) -> some View {
        let listening = stage == .listening && !state.paused
        return HStack(alignment: .center, spacing: 10) {
            dot(stage, state: state)
            Text(VoiceCardWords.heading(stage, paused: state.paused, intoToday: state.intoToday))
                .font(Txt.sectionTitle)
                .foregroundStyle(listening ? Self.red : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("voiceLive.heading")
            Spacer(minLength: 8)
            if VoiceCardWords.isRunning(stage) {
                Button {
                    center.hide()
                } label: {
                    Text("Hide")
                        .font(Txt.button)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("voiceLive.hide")
                .accessibilityHint("Hides this page. The recording goes on.")
            }
        }
    }

    /// Red dot while it records, the Inbox tray (or Today's sun) once saved, a pale dot otherwise.
    @ViewBuilder
    private func dot(_ stage: VoiceCardWords.Stage, state: VoiceCardState) -> some View {
        if stage == .saved {
            MarkImage(state.intoToday ? "sun.max" : "tray", size: 18)
                .foregroundStyle(state.intoToday ? Self.today : Self.inbox)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(stage == .listening && !state.paused ? Self.red : Color.white.opacity(0.45))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
        }
    }

    // MARK: While it records

    @ViewBuilder
    private func running(_ state: VoiceCardState, _ stage: VoiceCardWords.Stage) -> some View {
        clock(state)
            .font(Txt.bandNumber.monospacedDigit())
            .accessibilityIdentifier("voiceLive.clock")
        if !state.points.isEmpty {
            part("Key points so far")
            pointList(Array(state.points.prefix(3)))
        }
        wordsBox(state)
        if !VoiceCardWords.heard(tasks: state.tasksFound, marks: state.marks).isEmpty {
            Text(VoiceCardWords.heard(tasks: state.tasksFound, marks: state.marks))
                .font(Txt.label.weight(.semibold))
                .accessibilityIdentifier("voiceLive.heard")
        }
        Text(center.stopping ? "Stopping\u{2026}" : VoiceLivePage.screenNote)
            .font(Txt.label)
            .foregroundStyle(Self.quiet)
        buttons(state)
            .disabled(center.stopping)
            .opacity(center.stopping ? 0.5 : 1)
    }

    /// The running clock. The time spent paused is not counted, so it starts that much later;
    /// while paused it stands still and shows the length so far.
    @ViewBuilder
    private func clock(_ state: VoiceCardState) -> some View {
        if state.paused {
            Text(state.length)
        } else {
            Text(timerInterval: center.startedAt.addingTimeInterval(state.pausedSeconds)...Date.distantFuture, countsDown: false)
        }
    }

    /// What was said, the newest words at the foot and in sight.
    private func wordsBox(_ state: VoiceCardState) -> some View {
        ScrollView {
            Text(center.heard.isEmpty ? state.words : center.heard)
                .font(Txt.reading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("voiceLive.words")
        }
        .defaultScrollAnchor(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buttons(_ state: VoiceCardState) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                LivePageButton(title: "Mark", mark: "bookmark", id: "voiceLive.mark") { center.mark() }
                    .accessibilityHint("Keeps the sentence you are saying now in bold in the note")
                LivePageButton(title: VoiceCardWords.pauseButton(paused: state.paused),
                               mark: state.paused ? "play.fill" : "pause.fill", id: "voiceLive.pause") { center.pause() }
            }
            HStack(spacing: 10) {
                LivePageButton(title: VoiceCardWords.otherPlaceButton(intoToday: state.intoToday), id: "voiceLive.other") {
                    center.stop(into: state.intoToday ? "inbox" : "today")
                }
                LivePageButton(title: "Stop", mark: "stop.fill", fill: Self.red, id: "voiceLive.stop") { center.stop() }
                    .accessibilityHint("Stops and files the thought")
            }
        }
    }

    // MARK: While it is written up

    @ViewBuilder
    private func writing(_ state: VoiceCardState) -> some View {
        Text(state.length)
            .font(Txt.bandNumber.monospacedDigit())
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.white)
            Text("PARAGON is writing the title, the summary and the tasks.")
                .font(Txt.value)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !state.points.isEmpty {
            part("Key points so far")
            pointList(Array(state.points.prefix(3)))
        }
        wordsBox(state)
    }

    // MARK: Once it is filed

    @ViewBuilder
    private func saved(_ state: VoiceCardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(VoiceLivePage.recordedLine(length: state.length, intoToday: state.intoToday))
                    .font(Txt.label)
                    .foregroundStyle(Self.quiet)
                    .accessibilityIdentifier("voiceLive.where")
                if let filed = center.result {
                    TextField("Title", text: $center.title)
                        .font(Txt.reading.weight(.semibold))
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.10)))
                        .accessibilityIdentifier("voiceLive.title")
                    part("Summary")
                    Text(summaryWords(filed, state))
                        .font(Txt.value)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("voiceLive.summary")
                    if !state.points.isEmpty {
                        part("Key points while you spoke")
                        pointList(Array(state.points.prefix(3)))
                    }
                    part(VoiceLivePage.tasksHeading(filed.tasks.count))
                        .accessibilityIdentifier("voiceLive.tasks")
                    ForEach(filed.tasks, id: \.self) { task in
                        Toggle(isOn: keeping(task)) {
                            Text(task)
                                .font(Txt.value)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tint(Self.inbox)
                        .accessibilityIdentifier("voiceLive.task.\(task)")
                    }
                    if !filed.tasks.isEmpty {
                        Text(VoiceLivePage.tasksHint(intoToday: filed.toToday))
                            .font(Txt.label)
                            .foregroundStyle(Self.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    // No notes folder was open: the words wait and are filed later.
                    Text(state.title)
                        .font(Txt.reading.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if !state.summary.isEmpty {
                        Text(state.summary)
                            .font(Txt.value)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("It is filed the next time PARAGON opens your notes.")
                        .font(Txt.label)
                        .foregroundStyle(Self.quiet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        Text(VoiceLivePage.staysNote)
            .font(Txt.label)
            .foregroundStyle(Self.quiet)
        if center.result != nil {
            HStack(spacing: 10) {
                LivePageButton(title: "Open the note", mark: "doc.text", id: "voiceLive.open") { openNote() }
                LivePageButton(title: "Throw it away", mark: "trash", id: "voiceLive.throwAway") { throwAway() }
            }
        }
        LivePageButton(title: "Done", fill: Self.inbox.opacity(0.35), id: "voiceLive.done") { done() }
    }

    @ViewBuilder
    private func nothing(_ state: VoiceCardState) -> some View {
        Text(state.words)
            .font(Txt.reading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("voiceLive.nothing")
        Spacer(minLength: 0)
        LivePageButton(title: "Done", id: "voiceLive.done") { center.close() }
    }

    // MARK: Small parts

    /// A small quiet word over a part of the page.
    private func part(_ words: String) -> some View {
        Text(words)
            .font(Txt.label.weight(.semibold))
            .foregroundStyle(Self.quiet)
            .padding(.top, 2)
    }

    private func pointList(_ points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{2022}")
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text(point)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(Txt.sectionTitle)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key points: " + points.joined(separator: "; "))
        .accessibilityIdentifier("voiceLive.points")
    }

    private func keeping(_ task: String) -> Binding<Bool> {
        Binding(get: { !center.removed.contains(task) },
                set: { keep in
                    if keep { center.removed.remove(task) } else { center.removed.insert(task) }
                })
    }

    /// The summary as the note holds it now (whole, not the card's cut), or the line that
    /// says why there is none yet.
    private func summaryWords(_ filed: VoiceFiled, _ state: VoiceCardState) -> String {
        let text = model.note(at: filed.path)?.text ?? ""
        if center.summaryLate, text.isEmpty || text.contains(VoiceThought.pendingLine) {
            return VoiceLivePage.summaryStandIn(late: true)
        }
        if let words = VoiceNoteText.summary(of: text) { return words }
        if !state.summary.isEmpty { return state.summary }
        return VoiceLivePage.summaryStandIn(late: false)
    }

    // MARK: The result's buttons

    /// Keeps the thought with the changes made here (a new title, tasks switched off), and
    /// counts it as checked, so the check card does not ask again.
    private func keep() {
        guard let filed = center.result else { return }
        model.saveVoiceCheck(filed, title: center.title, remove: filed.tasks.filter { center.removed.contains($0) })
    }

    private func done() {
        keep()
        center.close()
        // An older thought that was never looked at gets its check card now. Not when the save
        // just failed: the message about that is up, and a card over it would be two at once.
        if model.errorMessage == nil { model.presentVoiceCheckIfWaiting() }
    }

    private func openNote() {
        keep()
        // A new title moved the note; the list of filed thoughts knows where it is now.
        let path = VoiceHistoryStore.load().first?.path ?? center.result?.path
        center.close()
        if let path, let note = model.note(at: path) {
            model.show(note)
        } else {
            model.flash("The note is not here yet. Look in Voice notes.", seconds: 5)
        }
    }

    private func throwAway() {
        guard let filed = center.result else { return }
        model.throwAwayVoice(filed)
        // It could not be thrown away (a note changed on another device): the page stays, so
        // he can try again once the message is closed.
        if model.errorMessage == nil { center.close() }
    }
}

/// One large button of the page: a word, with a small drawn mark in front where there is one.
private struct LivePageButton: View {
    let title: String
    var mark: String? = nil
    var fill: Color = Color.white.opacity(0.16)
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let mark { MarkImage(mark, size: 15) }
                Text(title)
                    .font(Txt.button)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
#endif
