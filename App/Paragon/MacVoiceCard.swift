#if os(macOS)
import AppKit
import ParagonCore
import SwiftUI

// Build 365: **Record a Thought on the Mac.**
//
// The recorder is the iPhone's (`VoiceRecorder`, one code path). What differs is where it shows:
// the iPhone has the Lock Screen card (a Live Activity), the Mac has none, so here a small dark
// card floats at the top right of the screen, above every window, and shows the same state
// (`VoiceCardState`) with the same words (`VoiceCardWords` in Core).
//
// - `VoiceCardCenter` holds the state and owns the panel.
// - `MacVoiceCardView` draws it: the red dot and "Listening · Inbox", the clock, the last
//   words, up to three key points, and the buttons Mark, Pause, Stop to Today and Stop.
// - `MacVoice` is what the File menu, the menu bar window and the card's buttons call.
// - `RecordThoughtCommands` are the two File menu items; `MacRecordRow` is the button in the
//   menu bar window; `MacVoiceSection` is Settings › Voice on the Mac.

/// What the Mac's recording card shows now, and the panel it is shown in.
@MainActor
final class VoiceCardCenter: ObservableObject {
    static let shared = VoiceCardCenter()

    @Published private(set) var state: VoiceCardState?
    /// When the recording began: the card's clock counts from here.
    @Published private(set) var startedAt = Date()

    private var panel: NSPanel?
    private var closing: Task<Void, Never>?

    var stage: VoiceCardWords.Stage? {
        state.flatMap { VoiceCardWords.Stage(rawValue: $0.stage.rawValue) }
    }

    /// Recording, or about to: the menu item reads **Stop Recording**.
    var isRecording: Bool { stage.map(VoiceCardWords.isRunning) ?? false }
    /// Stopped and being written up: nothing can be started or stopped for these seconds.
    var isWriting: Bool { stage == .writing }

    /// Called by the recorder with every change. `closes` is true for the last state of a
    /// recording (saved, or nothing): the card then goes by itself after `VoiceCardWords.stays`.
    func show(_ state: VoiceCardState, startedAt: Date, closes: Bool) {
        closing?.cancel()
        closing = nil
        self.startedAt = startedAt
        self.state = state
        present()
        guard closes, let stage, let stay = VoiceCardWords.stays(stage) else { return }
        closing = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(stay))
            guard !Task.isCancelled else { return }
            self?.close()
        }
    }

    func close() {
        closing?.cancel()
        closing = nil
        panel?.orderOut(nil)
        state = nil
    }

    private func present() {
        if panel == nil {
            let made = VoiceCardPanel(contentRect: NSRect(x: 0, y: 0, width: MacVoiceCardView.width, height: 120),
                                      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            made.isFloatingPanel = true
            made.level = .floating
            made.hidesOnDeactivate = false
            made.isOpaque = false
            made.backgroundColor = .clear
            made.hasShadow = true
            made.isMovableByWindowBackground = true
            made.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            made.isReleasedWhenClosed = false
            made.setAccessibilityLabel("PARAGON recording")
            made.contentView = FirstClickHostingView(rootView: MacVoiceCardView(center: self))
            panel = made
        }
        guard let panel, !panel.isVisible else { return }
        // A new card starts at the top right, under the menu bar. A card that is already up
        // stays where he dragged it.
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        var frame = panel.frame
        frame.origin = CGPoint(x: screen.maxX - frame.width - 16, y: screen.maxY - frame.height - 12)
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        VoiceLog.note("Card: shown at the top right of the Mac's screen.")
    }

    /// The card's own height changed (more key points, the summary): the panel follows, and
    /// its top edge stays where it is.
    func heightChanged(_ height: CGFloat) {
        guard let panel, height > 1 else { return }
        var frame = panel.frame
        guard abs(frame.height - height) > 0.5 else { return }
        let top = frame.maxY
        frame.size = CGSize(width: MacVoiceCardView.width, height: height)
        frame.origin.y = top - height
        panel.setFrame(frame, display: true)
    }
}

#if DEBUG
extension VoiceCardCenter {
    /// Test runs only (`-paragonVoiceCardPictures <folder>`): the card in each of its states,
    /// drawn into PNG files by the app itself, so the look can be checked without the screen.
    static func writePictures(to folder: String) {
        let points = ["Hall drawer needs new screws", "Call Anna about Saturday", "Water the plants"]
        let words = "whether we go to the lake or stay home. Task: water the plants."
        let states: [(String, VoiceCardState)] = [
            ("1-listening", .listening(words, heard: 0, length: "0:07")),
            ("2-listening-points", .listening(words, heard: 1, length: "0:21", marks: 1, points: points)),
            ("3-paused-today", .listening(words, intoToday: true, heard: 1, length: "0:21", paused: true, points: points)),
            ("4-writing", VoiceCardState(stage: .writing, words: words, title: "", tasksFound: 0, length: "0:42", points: points)),
            ("5-saved", VoiceCardState(stage: .saved, words: "", title: "Hall Drawer and Saturday Plans", tasksFound: 2, length: "0:42",
                                       points: points, summary: "The hall drawer needs new screws, to be ordered tonight. Anna is to be called about Saturday: the lake or staying home. The plants need water.")),
            ("6-saved-late", VoiceCardState(stage: .saved, words: "", title: "The drawer in the hall needs new", tasksFound: 1, length: "0:42",
                                            intoToday: true, points: points)),
            ("7-nothing", VoiceCardState(stage: .nothing, words: "Nothing heard \u{2014} nothing saved", title: "", tasksFound: 0, length: "0:03")),
            ("8-refused", VoiceCardState(stage: .nothing, words: "PARAGON may not use the microphone. Turn it on in System Settings \u{203A} Privacy & Security \u{203A} Microphone.", title: "", tasksFound: 0, length: "")),
        ]
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        for (name, state) in states {
            let center = VoiceCardCenter()
            center.state = state
            center.startedAt = Date().addingTimeInterval(-21)
            let renderer = ImageRenderer(content: MacVoiceCardView(center: center).padding(14).background(Color(white: 0.55)))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
        }
        let row = ImageRenderer(content: MacRecordRow().frame(width: 320).background(Color(nsColor: .windowBackgroundColor)))
        row.scale = 2
        if let image = row.nsImage, let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("9-menu-bar-row.png"))
        }
    }
}
#endif

/// A panel without a title bar can not take the keyboard by itself; this one can, so its
/// buttons answer the first click while another app stays in front.
private final class VoiceCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The card's buttons work on the first click, also while PARAGON is not the front app.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// What the File menu, the menu bar window and the card's buttons do.
@MainActor
enum MacVoice {
    /// Starts a recording, or stops the one that runs.
    static func toggle(into target: CaptureTarget = .inbox) {
        guard #available(macOS 26.0, *) else {
            AppModel.shared.flash("Record a Thought needs macOS 26 or newer.")
            return
        }
        let recorder = VoiceRecorder.shared
        Task { @MainActor in
            if recorder.isRecording {
                await finish(into: nil)
                return
            }
            do {
                try await recorder.start(into: target)
            } catch {
                // A start that failed before the microphone ran (not allowed, no speech model):
                // the card says why, and goes by itself.
                VoiceCardCenter.shared.show(VoiceCardState(stage: .nothing, words: error.localizedDescription, title: "",
                                                           tasksFound: 0, length: "", intoToday: target == .today),
                                            startedAt: Date(), closes: true)
            }
        }
    }

    /// **Stop**, or **Stop to Today / Stop to Inbox** (`place`).
    static func stop(into place: CaptureTarget? = nil) {
        Task { @MainActor in await finish(into: place) }
    }

    private static func finish(into place: CaptureTarget?) async {
        guard #available(macOS 26.0, *) else { return }
        let outcome = await VoiceRecorder.shared.stopAndFile(into: place)
        VoiceLog.note("Stop finished: \(VoiceLog.words(for: outcome)).")
        // A summary that did not come within its 20 seconds is written into the note a little
        // later. The Mac is not put to sleep, so it need not wait for PARAGON to open again.
        try? await Task.sleep(for: .seconds(30))
        await VoiceRecorder.shared.finishLateSummaries()
    }

    static func pause() {
        guard #available(macOS 26.0, *) else { return }
        Task { @MainActor in await VoiceRecorder.shared.togglePause() }
    }

    static func mark() {
        guard #available(macOS 26.0, *) else { return }
        Task { @MainActor in await VoiceRecorder.shared.mark() }
    }

    /// **Open** on the saved card: the newest recorded thought, in PARAGON's window.
    static func openNewest() {
        let model = AppModel.shared
        guard let path = VoiceHistoryStore.load().first?.path, let note = model.note(at: path) else { return }
        NSApp.activate(ignoringOtherApps: true)
        model.show(note)
        VoiceCardCenter.shared.close()
    }
}

/// The card itself. Always dark, like the iPhone's Lock Screen card, so it reads the same on
/// any desktop picture.
struct MacVoiceCardView: View {
    @ObservedObject var center: VoiceCardCenter
    static let width: CGFloat = 360
    /// The recording red of the iPhone's card (`VoiceLook.red`).
    static let red = Color(red: 0.886, green: 0.294, blue: 0.290)
    static let inbox = Color(red: 0.706, green: 0.824, blue: 0.353)
    static let today = Color(red: 0.663, green: 0.561, blue: 0.878)

    var body: some View {
        Group {
            if let state = center.state, let stage = center.stage {
                card(state, stage)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { box in
            Color.clear.preference(key: CardHeight.self, value: box.size.height)
        })
        .onPreferenceChange(CardHeight.self) { height in
            Task { @MainActor in center.heightChanged(height) }
        }
    }

    private struct CardHeight: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
    }

    @ViewBuilder
    private func card(_ state: VoiceCardState, _ stage: VoiceCardWords.Stage) -> some View {
        let listening = stage == .listening && !state.paused
        let points = shownPoints(state, stage)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                dot(stage, state: state)
                Text(VoiceCardWords.heading(stage, paused: state.paused, intoToday: state.intoToday))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(listening ? Self.red : Color.white)
                    .lineLimit(1)
                    .accessibilityIdentifier("voiceCard.heading")
                clock(state, listening: listening)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .opacity(0.8)
                Spacer(minLength: 4)
            }
            if stage == .saved {
                Text(VoiceCardWords.savedLine(title: state.title, tasks: state.tasksFound))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .accessibilityIdentifier("voiceCard.saved")
                if !state.summary.isEmpty {
                    Text(state.summary)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !points.isEmpty {
                    pointList(points)
                }
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    CardButton(title: "Open", id: "voiceCard.open") { MacVoice.openNewest() }
                    CardButton(title: "Close", id: "voiceCard.close") { center.close() }
                }
            } else {
                if !points.isEmpty { pointList(points) }
                let heard = stage == .listening ? VoiceCardWords.heard(tasks: state.tasksFound, marks: state.marks) : ""
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if !heard.isEmpty {
                        Text(heard)
                            .fontWeight(.semibold)
                            .fixedSize()
                    }
                    Text(state.words)
                        .lineLimit(points.isEmpty ? 2 : 1)
                        .truncationMode(.head)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(points.isEmpty ? 1 : 0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("voiceCard.words")
                if VoiceCardWords.isRunning(stage) {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        CardButton(title: "Mark", mark: "bookmark", id: "voiceCard.mark") { MacVoice.mark() }
                            .help("Keeps the sentence you are saying now in bold in the note")
                        CardButton(title: VoiceCardWords.pauseButton(paused: state.paused),
                                   mark: state.paused ? "play.fill" : "pause.fill", id: "voiceCard.pause") { MacVoice.pause() }
                        CardButton(title: VoiceCardWords.otherPlaceButton(intoToday: state.intoToday), id: "voiceCard.other") {
                            MacVoice.stop(into: state.intoToday ? .inbox : .today)
                        }
                        .help(state.intoToday ? "Stops and files the thought in the Inbox" : "Stops and files the thought in today's note")
                        CardButton(title: "Stop", mark: "stop.fill", fill: Self.red, id: "voiceCard.stop") { MacVoice.stop() }
                            .help("Stops and files the thought")
                    }
                } else if stage == .nothing {
                    HStack {
                        Spacer(minLength: 0)
                        CardButton(title: "Close", id: "voiceCard.close") { center.close() }
                    }
                }
            }
        }
        .padding(12)
        .foregroundStyle(Color.white)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(red: 0.11, green: 0.12, blue: 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voiceCard")
    }

    /// The key points the card lists: while it records and writes; on the saved card only when
    /// no summary came (the same rule as the iPhone's card).
    private func shownPoints(_ state: VoiceCardState, _ stage: VoiceCardWords.Stage) -> [String] {
        switch stage {
        case .listening, .preparing, .writing: return Array(state.points.prefix(3))
        case .saved: return state.summary.isEmpty ? Array(state.points.prefix(3)) : []
        case .nothing: return []
        }
    }

    private func pointList(_ points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\u{2022}").foregroundStyle(.white.opacity(0.6))
                    Text(point).lineLimit(1)
                }
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key points so far: " + points.joined(separator: "; "))
    }

    /// Red dot while it records, the Inbox tray (or Today's sun) once saved, a pale dot otherwise.
    @ViewBuilder
    private func dot(_ stage: VoiceCardWords.Stage, state: VoiceCardState) -> some View {
        if stage == .saved {
            MarkImage(state.intoToday ? "sun.max" : "tray", size: 14)
                .foregroundStyle(state.intoToday ? Self.today : Self.inbox)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(stage == .listening && !state.paused ? Self.red : Color.white.opacity(0.45))
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func clock(_ state: VoiceCardState, listening: Bool) -> some View {
        if listening {
            // The time spent paused is not counted, so the clock starts that much later.
            Text(timerInterval: center.startedAt.addingTimeInterval(state.pausedSeconds)...Date.distantFuture, countsDown: false)
                .frame(maxWidth: 52, alignment: .leading)
        } else {
            Text(state.length)
        }
    }
}

/// One button of the card: a word, with a small drawn mark in front where there is one.
private struct CardButton: View {
    let title: String
    var mark: String? = nil
    var fill: Color = Color.white.opacity(0.16)
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let mark { MarkImage(mark, size: 10) }
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// File › **Record a Thought** (⌥⌘R; **Stop Recording** while it runs) and **Record into
/// Today's Note**.
struct RecordThoughtCommands: View {
    @ObservedObject private var center = VoiceCardCenter.shared

    var body: some View {
        Button(VoiceCardWords.menuTitle(recording: center.isRecording)) { MacVoice.toggle() }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(center.isWriting)
        Button("Record into Today's Note") { MacVoice.toggle(into: .today) }
            .disabled(center.isRecording || center.isWriting)
    }
}

/// The button under quick capture in PARAGON's menu bar window.
struct MacRecordRow: View {
    @ObservedObject private var center = VoiceCardCenter.shared

    var body: some View {
        HStack(spacing: 8) {
            Button {
                MacVoice.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(MacVoiceCardView.red)
                        .frame(width: 8, height: 8)
                    Text(center.isRecording ? "Stop recording" : "Record a thought")
                }
            }
            .disabled(center.isWriting)
            .accessibilityIdentifier("menubar.recordThought")
            .help("Speak, and PARAGON writes it down: a note with a summary, and the tasks in the Inbox")
            Spacer(minLength: 0)
            Text("\u{2325}\u{2318}R")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Settings › Voice on the Mac: the language, the three switches, and what a recording needs.
@available(macOS 26.0, *)
struct MacVoiceSection: View {
    @AppStorage(VoiceSettings.languageKey) private var language = ""
    @AppStorage(VoiceSettings.checkKey) private var checkFirst = true
    @AppStorage(VoiceSettings.readKey) private var readAloud = false
    @AppStorage(VoiceSettings.keyPointsKey) private var keyPoints = true
    @State private var found = VoiceReadiness()
    @State private var looked = false
    @State private var working = false
    @State private var answer = ""
    @State private var copied = false

    var body: some View {
        Section {
            Picker("Voice language", selection: $language) {
                Text("Mac's language").tag("")
                Text("English").tag("en-US")
                Text("Deutsch").tag("de-DE")
                Text("Svenska").tag("sv-SE")
            }
            .accessibilityIdentifier("settings.voiceLanguage")
            Toggle("Key points while you speak", isOn: $keyPoints)
                .accessibilityIdentifier("settings.voiceKeyPoints")
            Toggle("Check after filing", isOn: $checkFirst)
                .accessibilityIdentifier("settings.voiceCheckFirst")
            Toggle("Read the summary aloud", isOn: $readAloud)
                .accessibilityIdentifier("settings.voiceReadAloud")
            VoiceReadyLine(title: "Microphone", value: found.microphone, ok: found.microphoneOK, looked: looked)
                .accessibilityIdentifier("settings.voiceMicrophone")
                .task(id: language) { await look() }
            VoiceReadyLine(title: "Speech model", value: found.model, ok: found.modelOK, looked: looked)
                .accessibilityIdentifier("settings.voiceModel")
            if found.ready && !working {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    MarkImage("checkmark", text: .footnote)
                        .foregroundStyle(Color.green)
                    Text("Ready to record")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.voiceReady")
            } else {
                Button(working ? "Getting ready\u{2026}" : "Get ready") { press() }
                    .disabled(working || !looked)
                    .accessibilityIdentifier("settings.voiceReady")
            }
            if !answer.isEmpty {
                Text(answer)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.voiceReadyAnswer")
            }
            Button(copied ? "Copied" : "Copy what the last recordings did") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(VoiceLog.lines.joined(separator: "\n"), forType: .string)
                copied = true
            }
            .disabled(VoiceLog.lines.isEmpty)
            .accessibilityIdentifier("settings.voiceLogCopy")
        } header: {
            Text("Voice")
        } footer: {
            Text("Record a Thought is in the File menu (\u{2325}\u{2318}R) and in PARAGON's menu bar window. While you speak, a small card at the top right of the screen shows your words; Stop files a note with a summary in Resources and the tasks in the Inbox. With Key points while you speak, the card lists up to 3 key points of what you have said so far. With Check after filing, the thought is filed first; then a card lets you change the title, take out a task or throw the thought away. With Read the summary aloud, PARAGON says the title, the summary and how many tasks it found. Get ready asks for the microphone once and fetches Apple's speech model. The summary, the tasks and the key points need Apple Intelligence; without it your words are filed as they are.")
        }
    }

    private func look() async {
        found = await VoiceRecorder.shared.readiness()
        looked = true
    }

    private func press() {
        working = true
        answer = ""
        Task { @MainActor in
            answer = await VoiceRecorder.shared.prepare()
            await look()
            working = false
        }
    }
}
#endif
