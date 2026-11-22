import Foundation
import ParagonCore
#if os(iOS)
import ActivityKit
import AVFoundation
import FoundationModels
import Speech
import UIKit

/// Build 348: **Record a thought** — the iPhone as a voice note-taker.
///
/// One recorder for the whole app. The Action Button (through **Record a Thought**, an
/// `AudioRecordingIntent`) starts it, a second press or **Stop** on the Lock Screen ends it.
/// While it listens, Apple's own speech-to-text (`SpeechAnalyzer`, on the phone) writes the
/// words and the Lock Screen shows the last of them. When it stops, Apple's on-device model
/// (`FoundationModels`) adds a title, a short summary and the tasks it heard, and Core files it
/// all (`Vault.fileVoiceThought`): a note in Resources, the tasks and one line in the Inbox.
///
/// **Nothing said is ever lost for a missing model or vault:** without Apple Intelligence the
/// words are filed with the first words as title; without an open vault they go to the capture
/// outbox as one Inbox note line, filed the next time the vault is open.
@available(iOS 26.0, *)
@MainActor
final class VoiceRecorder {
    static let shared = VoiceRecorder()

    /// The language chosen in Settings › Voice; "" is the phone's own.
    static let languageKey = "voiceLanguage"

    enum Problem: LocalizedError {
        case microphoneRefused
        case noSpeechModel
        case busy
        // Build 353: a press from the Action Button cannot show iOS's questions or wait minutes
        // for a download (the action is stopped after a short time: "timeout"). Say so at once.
        case microphoneNotAskedYet
        case modelDownloading
        case noMicrophone
        // Build 354: iOS records in the background only while the Lock Screen card shows.
        case noLiveActivity(String)

        var errorDescription: String? {
            switch self {
            case .microphoneRefused:
                return "PARAGON may not use the microphone. Turn it on in the Settings app › PARAGON › Microphone."
            case .noSpeechModel:
                return "This phone cannot turn speech into text in the chosen language."
            case .busy:
                return "PARAGON is still writing up the last thought."
            case .microphoneNotAskedYet:
                return "PARAGON has not been allowed to use the microphone yet. Open PARAGON › Settings › Voice and press Get ready."
            case .noMicrophone:
                return "No microphone is free right now. Is a call or another recording on?"
            case .modelDownloading:
                return "The iPhone is getting Apple's speech model. Open PARAGON › Settings › Voice and press Get ready, or try again in a few minutes."
            case .noLiveActivity(let why):
                return "\(why) iOS only lets PARAGON record in the background while the recording shows on the Lock Screen. Turn on Live Activities in the Settings app › Apps › PARAGON, then press again."
            }
        }
    }

    /// What a stop led to, in words for Siri and the Lock Screen.
    enum Outcome {
        case saved(title: String, tasks: Int)
        case kept
        case nothingHeard
        case notRecording
    }

    private(set) var isRecording = false
    /// Build 349: where this recording is meant to go — the Inbox, or today's daily note
    /// (**Record into Today's Note**). The Lock Screen's second button files it in the other.
    private(set) var place: CaptureTarget = .inbox
    private var intoToday: Bool { place == .today }
    fileprivate(set) var isWriting = false
    /// Build 353: late summaries being written in; never stops a new recording.
    fileprivate var catchingUp = false
    private var startedAt = Date()
    private var engine: AVAudioEngine?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    /// Build 353: what the microphone hears, kept until the speech-to-text is ready for it.
    private var raw: AsyncStream<AVAudioPCMBuffer>.Continuation?
    /// Build 353: the second half of a start (`attachSpeechToText`), and the audio pump.
    private var preparing: Task<Void, Never>?
    private var pump: Task<Void, Never>?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var finished = ""
    private var volatile = ""
    private var activity: Activity<VoiceActivityAttributes>?
    /// Build 354: why the last Lock Screen card could not be shown, in words.
    private var activityProblem = ""
    /// Build 354: the first words of a recording are written to `VoiceLog` once.
    private var loggedFirstWords = false
    private var lastShown = Date.distantPast
    private var limit: Task<Void, Never>?
    private var locale = Locale(identifier: "en-US")
    // Round 350 (voice-words): "stop recording" said out loud stops once.
    private var stopHeardAlready = false
    // Round 350 (voice-controls): Pause / Go on and Mark on the Lock Screen.
    private(set) var isPaused = false
    private var pausedAt: Date?
    /// Seconds spent paused in earlier pauses of this recording.
    private var pausedTotal: TimeInterval = 0
    /// Where each **Mark** came: the length of the cleaned transcript at that moment.
    private var markOffsets: [Int] = []

    var transcript: String {
        [finished, volatile].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Start

    func start(into target: CaptureTarget = .inbox) async throws {
        VoiceLog.note("Press to start. PARAGON was \(VoiceLog.appState()).")
        guard !isRecording else { VoiceLog.note("Already recording."); return }
        guard !isWriting else { VoiceLog.note("Refused: still writing up the last thought."); throw Problem.busy }
        do {
            try await askForMicrophoneIfItCanBeAsked()
        } catch {
            VoiceLog.note("Microphone: \(error.localizedDescription)")
            throw error
        }
        loggedFirstWords = false

        place = target == .today ? .today : .inbox
        stopHeardAlready = false
        startedAt = Date()
        isPaused = false
        pausedAt = nil
        pausedTotal = 0
        markOffsets = []
        finished = ""
        volatile = ""
        isRecording = true
        // The Live Activity first: an `AudioRecordingIntent` must show one while it records.
        await showActivity(.init(stage: .preparing, words: "Getting ready…", title: "", tasksFound: 0, length: "", intoToday: intoToday))
        if activity == nil {
            VoiceLog.note("Lock Screen card: not shown. \(activityProblem)")
            // Build 354: without the card iOS stops a recording in the background at once, and
            // the press used to end in silence. On screen PARAGON can record without it.
            if UIApplication.shared.applicationState != .active {
                isRecording = false
                throw Problem.noLiveActivity(activityProblem)
            }
        } else {
            VoiceLog.note("Lock Screen card: shown.")
        }

        // Build 355: the speech-to-text is set up **first** and the microphone second — the order
        // of build 352, which recorded. Build 353 swapped it to beat a time limit in the
        // background, and with PARAGON on screen the microphone then failed with "OSStatus error
        // -50". Since build 355 a press always opens PARAGON (iOS refuses the Lock Screen card to
        // an app in the background: "Target is not foreground"), so the swap bought nothing.
        let (raw, rawBuilder) = AsyncStream<AVAudioPCMBuffer>.makeStream(bufferingPolicy: .unbounded)
        self.raw = rawBuilder
        do {
            try await prepareSpeech(raw: raw)

            let session = AVAudioSession.sharedInstance()
            // Build 356: `.spokenAudio` is a mode for playing speech, and iOS refused it with
            // `.record` on his iPhone ("OSStatus error -50", seen in Last presses on 22 November).
            // `.measurement` is the mode Dictate uses (CaptureDictation), which records on his
            // phone, and the mode Apple names for speech recognition. The plain mode is the
            // fall-back, so a refused mode never again stops the recording.
            do {
                try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            } catch {
                VoiceLog.note("Sound: measurement mode refused (\(error.localizedDescription)). Trying the plain mode.")
                try Self.step("Sound: set to recording") { try session.setCategory(.record, mode: .default, options: []) }
            }
            try Self.step("Sound: switched on") { try session.setActive(true) }

            let engine = AVAudioEngine()
            let node = engine.inputNode
            let heard = node.outputFormat(forBus: 0)
            guard heard.sampleRate > 0, heard.channelCount > 0 else {
                VoiceLog.note("Microphone: no sound format (\(heard.sampleRate) Hz, \(heard.channelCount) channels).")
                throw Problem.noMicrophone
            }
            node.installTap(onBus: 0, bufferSize: 4096, format: heard) { buffer, _ in
                rawBuilder.yield(buffer)
            }
            engine.prepare()
            try Self.step("Microphone: start") { try engine.start() }
            self.engine = engine
            startedAt = Date()
            VoiceLog.note("Microphone: listening.")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if !isPaused { await showActivity(listeningState("Listening…")) }

            limit = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(VoiceThought.longest))
                guard let self, !Task.isCancelled, self.isRecording else { return }
                // Not cancelled by the stop it starts: the write-up must not be cut short.
                self.limit = nil
                Task { @MainActor in _ = await self.stopAndFile() }
            }
        } catch {
            VoiceLog.note("Could not start: \(error.localizedDescription)")
            await tearDown()
            isRecording = false
            await showActivity(.init(stage: .nothing, words: error.localizedDescription, title: "", tasksFound: 0, length: "", intoToday: intoToday),
                               endAfter: 60)
            throw error
        }
    }

    /// Build 355: one step of the start that can fail, named in `VoiceLog` when it does, so the
    /// last presses say which step it was and not only Apple's number.
    private static func step(_ name: String, _ work: () throws -> Void) throws {
        do {
            try work()
        } catch {
            VoiceLog.note("\(name) failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Sets up Apple's speech-to-text and the pump that feeds it everything the microphone
    /// hears. The converter is made from the first sound that arrives, so this needs nothing
    /// from the microphone and can run before it starts.
    private func prepareSpeech(raw: AsyncStream<AVAudioPCMBuffer>) async throws {
        guard let chosen = await chosenTranscriberAndLocale() else {
            VoiceLog.note("Speech model: none for the chosen language.")
            throw Problem.noSpeechModel
        }
        let transcriber = chosen.transcriber
        locale = chosen.locale
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            // In the background a download takes too long: it is started, and this recording ends.
            guard UIApplication.shared.applicationState == .active else {
                VoiceLog.note("Speech model: not on the iPhone. The download was started.")
                Task { @MainActor in try? await install.downloadAndInstall() }
                throw Problem.modelDownloading
            }
            VoiceLog.note("Speech model: downloading.")
            await showActivity(.init(stage: .preparing, words: "Getting the speech model ready…", title: "", tasksFound: 0, length: "", intoToday: intoToday))
            try await install.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        // Round 350 (voice-words): the odd words from Settings › Voice, for it to listen for.
        let hints = VoiceWords.contextualWords(Self.savedWords())
        if !hints.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = hints
            try? await analyzer.setContext(context)
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            VoiceLog.note("Speech model: no sound format it can take.")
            throw Problem.noSpeechModel
        }
        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
        input = builder
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            VoiceLog.note("Speech model: start failed: \(error.localizedDescription)")
            throw error
        }
        VoiceLog.note("Speech model: ready (\(chosen.locale.identifier)).")

        results = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    if !self.loggedFirstWords, !text.isEmpty {
                        self.loggedFirstWords = true
                        VoiceLog.note("First words heard.")
                    }
                    if result.isFinal {
                        self.finished = [self.finished, text].joined(separator: " ")
                            .trimmingCharacters(in: .whitespaces)
                        self.volatile = ""
                        // Round 350 (voice-words): "stop recording" said out loud.
                        if VoiceWords.removingStopPhrase(from: self.finished) != nil, self.isRecording, !self.stopHeardAlready {
                            self.stopHeardAlready = true
                            Task { @MainActor in _ = await self.stopAndFile() }
                        }
                    } else {
                        self.volatile = text
                    }
                    self.showWords()
                }
            } catch {}
        }

        // Everything the microphone hears, converted for the model. The converter is made from
        // the first sound, since the microphone has not started yet.
        pump = Task.detached {
            var converter: AVAudioConverter?
            var madeConverter = false
            for await buffer in raw {
                let heard = buffer.format
                if !madeConverter {
                    madeConverter = true
                    converter = heard == format ? nil : AVAudioConverter(from: heard, to: format)
                }
                guard let converter else {
                    builder.yield(AnalyzerInput(buffer: buffer))
                    continue
                }
                let ratio = format.sampleRate / heard.sampleRate
                let room = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
                guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: room) else { continue }
                var given = false
                var problem: NSError?
                converter.convert(to: out, error: &problem) { _, status in
                    if given {
                        status.pointee = .noDataNow
                        return nil
                    }
                    given = true
                    status.pointee = .haveData
                    return buffer
                }
                if problem == nil, out.frameLength > 0 { builder.yield(AnalyzerInput(buffer: out)) }
            }
        }
    }

    // MARK: Stop

    /// Stops, writes it up and files it. Comes back when it is in the Inbox (or kept).
    /// Build 349: `into` (the Lock Screen's second button) files it there instead of where the
    /// recording was meant to go.
    func stopAndFile(into chosen: CaptureTarget? = nil) async -> Outcome {
        VoiceLog.note("Stop asked for. PARAGON was \(VoiceLog.appState()).")
        guard isRecording else {
            // A Stop left on the Lock Screen by an app that was closed meanwhile.
            for old in Activity<VoiceActivityAttributes>.activities { await old.end(nil, dismissalPolicy: .immediate) }
            return .notRecording
        }
        isRecording = false
        isWriting = true
        if let chosen { place = chosen == .today ? .today : .inbox }
        let intoToday = self.intoToday
        let day = DateOnly.today()
        // Once the microphone is off iOS may put PARAGON to sleep: this asks for the minute
        // the write-up and the filing need (the 30-minute stop has no action keeping it awake).
        let awake = UIApplication.shared.beginBackgroundTask(withName: "Record a thought")
        defer {
            isWriting = false
            if awake != .invalid { UIApplication.shared.endBackgroundTask(awake) }
        }
        limit?.cancel()
        limit = nil
        // Round 350: the time spent paused is not part of the length.
        let duration = elapsed
        isPaused = false
        pausedAt = nil
        let length = VoiceThought.clock(duration)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        await tearDown()

        var thought = VoiceThought(transcript: transcript, recordedAt: startedAt, duration: duration)
        // Round 352: the language it was spoken in, so a German "am 25." is read as the 25th.
        thought.language = locale.identifier
        // Round 350 (voice-words): the odd words put right, then the title, tags and ideas he said.
        thought.readWords(replacements: Self.savedWords(), linkTitles: AppModel.shared.voiceLinkTitles())
        let english = Self.wantsEnglish()
        thought.marks = markOffsets
        guard !thought.isEmpty else {
            await showActivity(.init(stage: .nothing, words: "Nothing heard — nothing saved", title: "", tasksFound: 0, length: length, intoToday: intoToday),
                               endAfter: 60)
            return .nothingHeard
        }
        await showActivity(.init(stage: .writing, words: VoiceThought.liveTail(thought.transcript), title: "", tasksFound: 0, length: length, intoToday: intoToday))

        // The words are never kept waiting for the model: after 20 seconds (the phone may be
        // locked, and iOS slows the model down then) they are filed with the first words as
        // title, and the summary is added the next time PARAGON opens.
        var within: Double = 20
        #if DEBUG
        // Test runs only: `-paragon-voice-late` makes the summary always come late.
        if ProcessInfo.processInfo.arguments.contains("-paragon-voice-late") { within = 0.01 }
        #endif
        switch await Self.writeUp(thought.transcript, locale: locale, within: within, english: english) {
        case .done(let title, let summary, let tasks):
            thought.title = title
            thought.summary = summary
            thought.tasks = tasks
            if VoiceChapters.isLong(duration: duration, transcript: thought.transcript) {
                thought.chapters = await Self.writeChapters(thought.transcript, locale: locale, english: english, within: 12)
            }
        case .late:
            thought.summaryPending = true
        case .none:
            break
        }

        let model = AppModel.shared
        await model.vaultOnceOpen()
        if let filed = model.fileVoiceThought(thought, into: place, today: day) {
            let title = filed.title
            if thought.summaryPending {
                Self.remember(LateSummary(path: filed.path, transcript: thought.transcript, locale: locale.identifier,
                                          day: intoToday ? day.description : nil, english: english))
            }
            let tasks = thought.finalTasks.count
            afterFiling(path: filed.path, title: title, thought: thought, day: day, locale: locale.identifier)
            await showActivity(.init(stage: .saved, words: "", title: title, tasksFound: tasks, length: length, intoToday: intoToday), endAfter: 180)
            return .saved(title: title, tasks: tasks)
        }
        // No vault now: the words wait in the outbox, as one note line in the Inbox (or today's note).
        model.capture(text: "Voice note (\(length)): " + VoiceThought.clean(thought.transcript), target: place, asTask: false)
        await showActivity(.init(stage: .saved, words: "", title: thought.finalTitle, tasksFound: 0, length: length, intoToday: intoToday), endAfter: 180)
        return .kept
    }

    private func tearDown() async {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        // Build 353: no more sound; let the set-up and the pump hand over what they have.
        raw?.finish()
        raw = nil
        if let waiting = preparing {
            _ = await VoiceRace.first(within: 8, otherwise: false) { @MainActor () async -> Bool in
                await waiting.value
                return true
            }
        }
        preparing = nil
        if let feeding = pump {
            _ = await VoiceRace.first(within: 4, otherwise: false) { @MainActor () async -> Bool in
                await feeding.value
                return true
            }
            feeding.cancel()
        }
        pump = nil
        input?.finish()
        input = nil
        // Build 353: each wait here has a limit, so a stop can never hang the recorder.
        if let analyzer {
            _ = await VoiceRace.first(within: 6, otherwise: false) { @MainActor () async -> Bool in
                try? await analyzer.finalizeAndFinishThroughEndOfInput()
                return true
            }
        }
        analyzer = nil
        if let pending = results {
            _ = await VoiceRace.first(within: 3, otherwise: false) { @MainActor () async -> Bool in
                await pending.value
                return true
            }
            pending.cancel()
        }
        results = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Lock Screen

    private func showWords() {
        guard isRecording, !isPaused, Date().timeIntervalSince(lastShown) >= 1 else { return }
        lastShown = Date()
        let words = VoiceThought.liveTail(transcript)
        Task { await showActivity(listeningState(words.isEmpty ? "Listening…" : words)) }
    }

    /// Round 350: the Lock Screen card while recording, with the pause and the marks it holds.
    private func listeningState(_ words: String) -> VoiceActivityAttributes.ContentState {
        .listening(words, intoToday: intoToday, heard: VoiceThought.spokenTasks(in: transcript).count,
                   length: isPaused ? VoiceThought.clock(elapsed) : "", paused: isPaused,
                   pausedSeconds: pausedTotal, marks: markOffsets.count)
    }

    /// How long it has been recording, without the pauses.
    private var elapsed: TimeInterval {
        (pausedAt ?? Date()).timeIntervalSince(startedAt) - pausedTotal
    }

    /// **Pause** and **Go on** are one button on the Lock Screen.
    func togglePause() async {
        if isPaused { await resume() } else { await pause() }
    }

    /// Round 350: **Pause**. The microphone rests and the clock stops; the speech session stays
    /// open, so **Go on** continues into the same note.
    func pause() async {
        guard isRecording, !isPaused, let engine else { return }
        engine.pause()
        pausedAt = Date()
        isPaused = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let words = VoiceThought.liveTail(transcript)
        await showActivity(listeningState(words.isEmpty ? "Paused" : words))
    }

    /// Round 350: **Go on**. The time spent paused is not counted.
    func resume() async {
        guard isRecording, isPaused, let engine else { return }
        do {
            try engine.start()
        } catch {
            // The microphone would not start again: stay paused, and say so.
            await showActivity(listeningState("Could not go on. Stop keeps what you said."))
            return
        }
        if let pausedAt { pausedTotal += Date().timeIntervalSince(pausedAt) }
        pausedAt = nil
        isPaused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let words = VoiceThought.liveTail(transcript)
        await showActivity(listeningState(words.isEmpty ? "Listening…" : words))
    }

    /// Round 350: **Mark**. The sentence being said now is kept in bold in the note.
    func mark() async {
        guard isRecording else { return }
        markOffsets.append(VoiceThought.clean(transcript).count)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let words = VoiceThought.liveTail(transcript)
        await showActivity(listeningState(words.isEmpty ? "Listening…" : words))
    }

    // MARK: Getting ready (build 353)

    /// The microphone question can only be shown while PARAGON is on screen. From the Action
    /// Button (PARAGON in the background) the question never appears and the press waited until
    /// iOS stopped it ("timeout"), so there it fails at once with words that say what to do.
    private func askForMicrophoneIfItCanBeAsked() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return
        case .denied:
            throw Problem.microphoneRefused
        default:
            guard UIApplication.shared.applicationState == .active else { throw Problem.microphoneNotAskedYet }
            guard await AVAudioApplication.requestRecordPermission() else { throw Problem.microphoneRefused }
        }
    }

    /// The speech model for the chosen language, or nil when the phone has none for it.
    private func chosenTranscriber() async -> SpeechTranscriber? {
        await chosenTranscriberAndLocale()?.transcriber
    }

    private func chosenTranscriberAndLocale() async -> (transcriber: SpeechTranscriber, locale: Locale)? {
        let chosen = UserDefaults.standard.string(forKey: Self.languageKey) ?? ""
        let wanted = chosen.isEmpty ? Locale.current : Locale(identifier: chosen)
        var match = await SpeechTranscriber.supportedLocale(equivalentTo: wanted)
        if match == nil { match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) }
        guard let found = match else { return nil }
        let transcriber = SpeechTranscriber(locale: found, transcriptionOptions: [],
                                            reportingOptions: [.volatileResults], attributeOptions: [])
        return (transcriber, found)
    }

    /// What Settings › Voice shows: is the microphone allowed, and is the speech model here.
    /// Changes nothing.
    func readiness() async -> VoiceReadiness {
        var found = VoiceReadiness()
        switch AVAudioApplication.shared.recordPermission {
        case .granted: found.microphone = "Allowed"; found.microphoneOK = true
        case .denied: found.microphone = "Not allowed. Turn it on in the Settings app › Apps › PARAGON › Microphone."
        default: found.microphone = "Not asked yet"
        }
        // Build 354: without Live Activities iOS stops a recording that PARAGON is not on screen for.
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            found.liveActivities = "On"
            found.liveActivitiesOK = true
        } else {
            found.liveActivities = "Off. Turn them on in the Settings app › Apps › PARAGON › Live Activities."
        }
        guard let transcriber = await chosenTranscriber() else {
            found.model = "This iPhone cannot turn speech into text in the chosen language."
            return found
        }
        do {
            if try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) == nil {
                found.model = "Ready"
                found.modelOK = true
            } else {
                found.model = "Not on this iPhone yet"
            }
        } catch {
            found.model = "Could not be checked: \(error.localizedDescription)"
        }
        return found
    }

    /// **Get ready** in Settings › Voice, pressed while PARAGON is on screen: asks for the
    /// microphone (the question can show here) and downloads the speech model. Returns words
    /// for the line under the button.
    func prepare() async -> String {
        do {
            try await askForMicrophoneIfItCanBeAsked()
        } catch {
            return error.localizedDescription
        }
        guard let transcriber = await chosenTranscriber() else { return Problem.noSpeechModel.localizedDescription }
        do {
            if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await install.downloadAndInstall()
            }
            return "Ready. Press the Action Button to record a thought."
        } catch {
            return "The speech model could not be downloaded: \(error.localizedDescription) Try again with Wi-Fi."
        }
    }

    private func showActivity(_ state: VoiceActivityAttributes.ContentState, endAfter: TimeInterval? = nil) async {
        let content = ActivityContent(state: state, staleDate: nil)
        if activity == nil || activity?.attributes.startedAt != startedAt {
            for old in Activity<VoiceActivityAttributes>.activities { await old.end(nil, dismissalPolicy: .immediate) }
            activity = nil
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    activity = try Activity.request(attributes: VoiceActivityAttributes(startedAt: startedAt), content: content, pushType: nil)
                    activityProblem = ""
                } catch {
                    activityProblem = "iOS refused it: \(error.localizedDescription)."
                }
            } else {
                activityProblem = "Live Activities are turned off for PARAGON."
            }
        } else {
            await activity?.update(content)
        }
        if let endAfter {
            await activity?.end(content, dismissalPolicy: .after(Date().addingTimeInterval(endAfter)))
            activity = nil
        }
    }

    #if DEBUG
    /// Test runs only (`-paragon-voice-demo`): the Lock Screen card listening to sample words for
    /// 20 seconds, then the real write-up and filing into the test vault.
    func demo() async {
        let words = "The drawer in the hall needs new screws, so I should order them tonight. And I must call Anna about Saturday, whether we go to the lake or stay home. Task: water the plants."
        let awake = UIApplication.shared.beginBackgroundTask(withName: "Voice demo")
        defer { UIApplication.shared.endBackgroundTask(awake) }
        startedAt = Date()
        isRecording = true
        // `-paragon-voice-today`: the recording meant for today's note (Inbox as second button).
        place = ProcessInfo.processInfo.arguments.contains("-paragon-voice-today") ? .today : .inbox
        await showActivity(.listening(VoiceThought.liveTail(words), intoToday: intoToday,
                                      heard: VoiceThought.spokenTasks(in: words).count))
        try? await Task.sleep(for: .seconds(20))
        finished = words
        _ = await stopAndFile()
    }
    #endif

    // MARK: Title, summary and tasks

    @Generable
    struct WrittenUp {
        @Guide(description: "A short title for the spoken note, 2 to 6 words, in the language the note was spoken in.")
        var title: String
        @Guide(description: "Two or three short, plain sentences that sum up the note, in the language it was spoken in.")
        var summary: String
        @Guide(description: "The things the speaker said they need to do, each a short task that starts with a verb, in the language of the note. Empty when nothing needs doing.",
               .maximumCount(10))
        var tasks: [String]
    }

    enum WriteUp {
        case done(title: String, summary: String, tasks: [String])
        /// Not done within the time given.
        case late
        /// No model here (no Apple Intelligence, an older phone, a language it does not know),
        /// or it did not answer.
        case none
    }

    /// Asks Apple's on-device model, giving it `seconds`.
    static func writeUp(_ transcript: String, locale: Locale, within seconds: Double, english: Bool = false) async -> WriteUp {
        let model = SystemLanguageModel.default
        guard model.availability == .available, model.supportsLocale(locale) else { return .none }
        if english, !model.supportsLocale(Locale(identifier: "en-US")) { return .none }
        // Build 353: a task group waits for every child before it returns, so the old limit was
        // no limit: with the phone locked the model could take minutes and the recorder stayed
        // "still writing up the last thought". The race now returns at the limit and lets the
        // model's answer fall away.
        return await VoiceRace.first(within: seconds, otherwise: WriteUp.late) { @MainActor () async -> WriteUp in
            guard let r = await ask(transcript, english: english) else { return WriteUp.none }
            return WriteUp.done(title: r.title, summary: r.summary, tasks: r.tasks)
        }
    }

    private static func ask(_ transcript: String, english: Bool = false) async -> (title: String, summary: String, tasks: [String])? {
        // Round 350 (voice-words): Summary in English writes the three in English.
        let language = english ? "Answer in English, whatever language the note is in." : "Answer in the language of the note."
        let session = LanguageModelSession(instructions: """
            You turn a spoken note into a title, a short summary and a list of tasks. \
            Use only what was said. Never add tasks that were not said. \(language)
            """)
        // The model reads about 4,000 tokens: a very long recording is written up from its start.
        let text = String(transcript.prefix(6000))
        do {
            let answer = try await session.respond(to: "The spoken note:\n\(text)", generating: WrittenUp.self)
            return (answer.content.title, answer.content.summary, answer.content.tasks)
        } catch {
            return nil
        }
    }
}

// MARK: Summaries that came late

@available(iOS 26.0, *)
extension VoiceRecorder {
    struct LateSummary: Codable, Equatable {
        var path: String
        var transcript: String
        var locale: String
        /// Build 349: the day whose daily note took the thought ("2026-11-20"); nil = the Inbox.
        var day: String? = nil
        /// Round 350: the summary is to be written in English (Settings › Voice).
        var english: Bool? = nil
    }

    private static let lateKey = "voiceLateSummaries"

    static var waiting: [LateSummary] {
        get {
            guard let data = UserDefaults.standard.data(forKey: lateKey) else { return [] }
            return (try? JSONDecoder().decode([LateSummary].self, from: data)) ?? []
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: lateKey) }
    }

    static func remember(_ late: LateSummary) { waiting.append(late) }

    /// When PARAGON comes to the front: writes the summaries that did not finish while the
    /// phone was locked into their notes, and their tasks into the Inbox.
    func finishLateSummaries() async {
        // Build 353: this has its own flag. It used `isWriting`, so a catch-up of several late
        // summaries kept a new recording out with "still writing up the last thought".
        guard !Self.waiting.isEmpty, !isRecording, !isWriting, !catchingUp else { return }
        catchingUp = true
        defer { catchingUp = false }
        let model = AppModel.shared
        await model.vaultOnceOpen()
        guard let vault = model.vault else { return }
        for late in Self.waiting {
            let answer = await Self.writeUp(late.transcript, locale: Locale(identifier: late.locale), within: 60,
                                            english: late.english ?? false)
            var summary = "No summary: Apple Intelligence was not available on this phone."
            var tasks: [String] = []
            switch answer {
            case .late: continue
            case .none: break
            case .done(_, let s, let t):
                summary = s
                // Build 349: the tasks he said were filed at once; only the model's others now.
                tasks = VoiceThought.lateTasks(transcript: late.transcript, modelTasks: t)
            }
            model.flushPendingEdits()
            _ = try? vault.addLateVoiceSummary(path: late.path, summary: summary, tasks: tasks,
                                               intoDay: late.day.flatMap { DateOnly($0) })
            Self.waiting.removeAll { $0 == late }
            model.reload()
        }
    }
}

extension AppModel {
    /// Build 348: files a recorded thought into the open vault and refreshes the lists.
    /// Nil when no vault is open or it could not be written.
    func fileVoiceThought(_ thought: VoiceThought, into place: CaptureTarget = .inbox,
                          today: DateOnly = .today()) -> (title: String, path: String)? {
        guard let vault else { return nil }
        flushPendingEdits()
        do {
            let filed = try vault.fileVoiceThoughtNote(thought, today: today, into: place)
            reload()
            return filed
        } catch {
            return nil
        }
    }
}

/// Build 353: the first of two answers, the work or the limit, without waiting for the other.
/// The work goes on in the background when the limit wins, and its answer is dropped.
enum VoiceRace {
    static func first<T>(within seconds: Double, otherwise late: T,
                         _ work: @escaping @MainActor () async -> T) async -> T {
        await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
            let answer = FirstAnswer(continuation)
            Task { @MainActor in answer.give(await work()) }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                answer.give(late)
            }
        }
    }
}

/// Resumes its continuation once; later answers are dropped.
final class FirstAnswer<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func give(_ value: T) {
        lock.lock()
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(returning: value)
    }
}
/// Build 354: what Settings › Voice shows about the three things a recording needs.
struct VoiceReadiness {
    var microphone = "…"
    var microphoneOK = false
    var liveActivities = "…"
    var liveActivitiesOK = false
    var model = "…"
    var modelOK = false
    var ready: Bool { microphoneOK && liveActivitiesOK && modelOK }
}

/// Build 354: what the last presses of **Record a Thought** did, step by step, shown in
/// Settings › Voice. A press from the Action Button happens with PARAGON out of sight, so this
/// list is the only way to see where it stopped. Kept on this iPhone only, the last 40 lines.
enum VoiceLog {
    private static let key = "voiceLog"
    private static let kept = 40

    static func note(_ line: String) {
        let clock = Date().formatted(date: .omitted, time: .standard)
        var lines = UserDefaults.standard.stringArray(forKey: key) ?? []
        lines.append("\(clock)  \(line)")
        if lines.count > kept { lines.removeFirst(lines.count - kept) }
        UserDefaults.standard.set(lines, forKey: key)
    }

    static var lines: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    @available(iOS 26.0, *)
    static func words(for outcome: VoiceRecorder.Outcome) -> String {
        switch outcome {
        case .saved(let title, let tasks): return "saved \"\(title)\", \(tasks) tasks"
        case .kept: return "kept, to be filed when PARAGON next opens the notes"
        case .nothingHeard: return "nothing heard"
        case .notRecording: return "nothing was recording"
        }
    }

    @MainActor
    static func appState() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "on screen"
        case .inactive: return "half on screen"
        case .background: return "in the background"
        @unknown default: return "in an unknown state"
        }
    }
}

#endif
