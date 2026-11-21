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

        var errorDescription: String? {
            switch self {
            case .microphoneRefused:
                return "PARAGON may not use the microphone. Turn it on in the Settings app › PARAGON › Microphone."
            case .noSpeechModel:
                return "This phone cannot turn speech into text in the chosen language."
            case .busy:
                return "PARAGON is still writing up the last thought."
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
    private var startedAt = Date()
    private var engine: AVAudioEngine?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var finished = ""
    private var volatile = ""
    private var activity: Activity<VoiceActivityAttributes>?
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
        guard !isRecording else { return }
        guard !isWriting else { throw Problem.busy }
        guard await AVAudioApplication.requestRecordPermission() else { throw Problem.microphoneRefused }

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

        do {
            let chosen = UserDefaults.standard.string(forKey: Self.languageKey) ?? ""
            let wanted = chosen.isEmpty ? Locale.current : Locale(identifier: chosen)
            var match = await SpeechTranscriber.supportedLocale(equivalentTo: wanted)
            if match == nil { match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) }
            guard let found = match else { throw Problem.noSpeechModel }
            locale = found
            let transcriber = SpeechTranscriber(locale: found, transcriptionOptions: [],
                                                reportingOptions: [.volatileResults], attributeOptions: [])
            if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
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
                throw Problem.noSpeechModel
            }
            let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
            input = builder
            try await analyzer.start(inputSequence: stream)

            results = Task { @MainActor [weak self] in
                do {
                    for try await result in transcriber.results {
                        guard let self else { return }
                        let text = String(result.text.characters)
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

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .spokenAudio, options: [])
            try session.setActive(true)

            let engine = AVAudioEngine()
            let node = engine.inputNode
            let heard = node.outputFormat(forBus: 0)
            let converter = heard == format ? nil : AVAudioConverter(from: heard, to: format)
            node.installTap(onBus: 0, bufferSize: 4096, format: heard) { buffer, _ in
                guard let converter else {
                    builder.yield(AnalyzerInput(buffer: buffer))
                    return
                }
                let ratio = format.sampleRate / heard.sampleRate
                let room = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
                guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: room) else { return }
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
            engine.prepare()
            try engine.start()
            self.engine = engine
            startedAt = Date()
            await showActivity(listeningState("Listening…"))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            limit = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(VoiceThought.longest))
                guard let self, !Task.isCancelled, self.isRecording else { return }
                // Not cancelled by the stop it starts: the write-up must not be cut short.
                self.limit = nil
                Task { @MainActor in _ = await self.stopAndFile() }
            }
        } catch {
            await tearDown()
            isRecording = false
            await showActivity(.init(stage: .nothing, words: error.localizedDescription, title: "", tasksFound: 0, length: "", intoToday: intoToday),
                               endAfter: 60)
            throw error
        }
    }

    // MARK: Stop

    /// Stops, writes it up and files it. Comes back when it is in the Inbox (or kept).
    /// Build 349: `into` (the Lock Screen's second button) files it there instead of where the
    /// recording was meant to go.
    func stopAndFile(into chosen: CaptureTarget? = nil) async -> Outcome {
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
        input?.finish()
        input = nil
        if let analyzer { try? await analyzer.finalizeAndFinishThroughEndOfInput() }
        analyzer = nil
        await results?.value
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

    private func showActivity(_ state: VoiceActivityAttributes.ContentState, endAfter: TimeInterval? = nil) async {
        let content = ActivityContent(state: state, staleDate: nil)
        if activity == nil || activity?.attributes.startedAt != startedAt {
            for old in Activity<VoiceActivityAttributes>.activities { await old.end(nil, dismissalPolicy: .immediate) }
            activity = nil
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                activity = try? Activity.request(attributes: VoiceActivityAttributes(startedAt: startedAt), content: content, pushType: nil)
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
        return await withTaskGroup(of: WriteUp.self) { group in
            group.addTask { @MainActor in
                guard let r = await ask(transcript, english: english) else { return .none }
                return .done(title: r.title, summary: r.summary, tasks: r.tasks)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return .late
            }
            let first = await group.next() ?? .none
            group.cancelAll()
            return first
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
        guard !Self.waiting.isEmpty, !isRecording, !isWriting else { return }
        isWriting = true
        defer { isWriting = false }
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
#endif
