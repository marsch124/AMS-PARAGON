import Foundation
import AVFoundation
import Speech

/// Round 350 (capture-inbox, pick 26): **dictate into the capture field.** A small microphone
/// button in quick capture; what you say is written into the field while you look at it, and
/// a second press stops. Apple's speech recognition on the device itself — nothing is sent
/// away, and a language that cannot be done on the device is refused, not sent to a server.
///
/// The words are handed to `onText` as one growing string (Apple sends the whole sentence again
/// each time it changes its mind), so the caller sets the field to *what was there + this*.
@MainActor
final class CaptureDictation: ObservableObject {
    @Published private(set) var isListening = false
    /// A sentence for the screen when it could not start. Nil while all is well.
    @Published private(set) var problem: String?

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Numbers each listening, so a late answer from an older one is ignored.
    private var round = 0

    /// Press once to start, again to stop.
    func toggle(onText: @escaping (String) -> Void) {
        if isListening {
            stop()
        } else {
            Task { @MainActor in await self.start(onText: onText) }
        }
    }

    func stop() {
        round += 1
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        engine = nil
        request = nil
        task = nil
        isListening = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func start(onText: @escaping (String) -> Void) async {
        problem = nil
        guard await Self.speechAllowed() else {
            problem = "PARAGON may not turn speech into text. Turn it on in Settings, under PARAGON, Speech Recognition."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            problem = "PARAGON may not use the microphone. Turn it on in Settings, under PARAGON, Microphone."
            return
        }
        let chosen = UserDefaults.standard.string(forKey: "voiceLanguage") ?? ""
        let locale: Locale = chosen.isEmpty ? Locale.current : Locale(identifier: chosen)
        var found: SFSpeechRecognizer? = SFSpeechRecognizer(locale: locale)
        if found == nil { found = SFSpeechRecognizer() }
        guard let recognizer = found, recognizer.isAvailable else {
            problem = "Speech to text is not available right now."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            problem = "This device cannot turn speech into text on the device in this language."
            return
        }
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = true

        // Review of build 350: while a thought is being recorded the microphone is his
        // recording's; dictation would take the audio session away from it. Build 365: the Mac too.
        if #available(iOS 26.0, macOS 26.0, *), VoiceRecorder.shared.isRecording {
            problem = "A thought is being recorded. Stop it first."
            return
        }
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            problem = "The microphone could not be started."
            return
        }
        #endif

        let newEngine = AVAudioEngine()
        let node = newEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        // Review of build 350: no microphone (or one held by a call) gives an empty format, and
        // a tap on it stops the app.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            problem = "No microphone is available right now."
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            return
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            newRequest.append(buffer)
        }
        newEngine.prepare()
        do {
            try newEngine.start()
        } catch {
            node.removeTap(onBus: 0)
            problem = "The microphone could not be started."
            return
        }

        round += 1
        let mine = round
        engine = newEngine
        request = newRequest
        isListening = true
        task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            let words: String? = result?.bestTranscription.formattedString
            let finished = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in
                guard let self, self.round == mine else { return }
                if let words { onText(words) }
                if finished { self.stop() }
            }
        }
    }

    private static func speechAllowed() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status != .notDetermined { return false }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { answer in
                continuation.resume(returning: answer == .authorized)
            }
        }
    }
}
