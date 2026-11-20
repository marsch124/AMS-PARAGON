import SwiftUI
import ParagonCore
#if os(iOS)
import UIKit
import VisionKit
import Vision
#endif

// Round 350 (capture-inbox): the extra buttons of Quick capture — dictate (pick 26) and scan a
// paper list (pick 27) — and the question asked when many lines are pasted (pick 28).

/// A small button in the row under the field. The same shape as `AddChip`, with a mark, and the
/// Inbox's colour filled while it is on (build 142's two states: on is filled, off is plain).
struct CaptureToolFace: View {
    let title: String
    let mark: String
    var isOn = false

    var body: some View {
        let tint: Color = SidebarSection.inbox.tint
        MarkLabel(title, mark, text: .footnote)
            .font(Txt.label)
            .foregroundStyle(isOn ? tint.capsuleWords : Theme.soft)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isOn ? tint.opacity(0.16) : Color.secondary.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? tint.opacity(0.7) : Color.clear, lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - Dictate

/// **Dictate** (pick 26): press, speak, and the words appear in the field as you say them; press
/// **Stop** to finish. What was in the field stays; the spoken words come after it.
struct DictateChip: View {
    @Binding var text: String
    /// Counts up when the capture is saved: dictation stops, or it would put its words back
    /// into the field just emptied.
    let stopWhen: Int
    @StateObject private var dictation = CaptureDictation()

    /// Written out: the private state would make the generated initializer private.
    init(text: Binding<String>, stopWhen: Int) {
        self._text = text
        self.stopWhen = stopWhen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: press) {
                CaptureToolFace(title: dictation.isListening ? "Stop" : "Dictate",
                                mark: dictation.isListening ? "stop.fill" : "mic",
                                isOn: dictation.isListening)
            }
            .buttonStyle(.plain)
            .help("Speak, and PARAGON writes it in the field")
            .accessibilityIdentifier("capture.dictate")
            if let problem = dictation.problem {
                Text(problem)
                    .font(Txt.label)
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: 260, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("capture.dictate.problem")
            }
        }
        .onChange(of: stopWhen) { _, _ in dictation.stop() }
        .onDisappear { dictation.stop() }
    }

    private func press() {
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let start: String = base.isEmpty ? "" : base + " "
        dictation.toggle { words in
            text = start + words
        }
    }
}

// MARK: - Many lines pasted

/// **Make 5 tasks?** (pick 28). Asked when a paste added two lines or more. A dialog on the
/// field's own column, not on the screen's body, which already carries a popover and a sheet.
struct ManyLinesDialog: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let each: () -> Void
    let one: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
                Button("One task each", action: each)
                    .accessibilityIdentifier("capture.many.each")
                Button("Keep as one", role: .cancel, action: one)
                    .accessibilityIdentifier("capture.many.one")
            }
    }
}

// MARK: - Scan a paper list

#if os(iOS)
/// One line read from paper, kept apart so a repeated line can be taken away by itself.
struct ScannedLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

/// **Scan a list** (pick 27): the camera's document scanner, then the writing read off the
/// pages with Apple's text recognition on the phone. Every line read is shown first, with
/// **Cancel** and **Add N tasks**; nothing is written before that. Hidden where the phone has
/// no document camera (the simulator).
struct ScanListChip: View {
    let onAdd: ([String]) -> Void
    @State private var scanning = false
    @State private var reading = false
    @State private var showingResult = false
    @State private var found: [ScannedLine] = []

    init(onAdd: @escaping ([String]) -> Void) {
        self.onAdd = onAdd
    }

    var body: some View {
        if VNDocumentCameraViewController.isSupported {
            Button { scanning = true } label: {
                CaptureToolFace(title: reading ? "Reading\u{2026}" : "Scan a list", mark: "scan.list", isOn: reading)
            }
            .buttonStyle(.plain)
            .disabled(reading)
            .accessibilityIdentifier("capture.scan")
            .fullScreenCover(isPresented: $scanning) {
                DocumentScanner(onScanned: { images in
                    scanning = false
                    read(images)
                }, onCancel: { scanning = false })
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingResult) {
                ScannedLinesSheet(lines: $found, add: { lines in
                    showingResult = false
                    onAdd(lines)
                }, cancel: { showingResult = false })
            }
        }
    }

    private func read(_ images: [UIImage]) {
        reading = true
        Task { @MainActor in
            let lines = await ListReader.lines(in: images)
            // Let the camera finish closing before the list opens over the same screen.
            try? await Task.sleep(for: .milliseconds(350))
            found = lines.map { ScannedLine(text: $0) }
            reading = false
            showingResult = true
        }
    }
}

/// The lines read from the paper, to look over, with a way to drop a wrong one.
struct ScannedLinesSheet: View {
    @Binding var lines: [ScannedLine]
    let add: ([String]) -> Void
    let cancel: () -> Void

    var body: some View {
        content
            .sheetChrome(title: "Scanned list", tint: SidebarSection.inbox.tint,
                         actionTitle: CaptureLines.addTitle(count: lines.count),
                         canAct: !lines.isEmpty, actionIdentifier: "scan.add",
                         cancel: cancel, act: { add(lines.map(\.text)) })
    }

    @ViewBuilder
    private var content: some View {
        if lines.isEmpty {
            Text("No writing was found. Try again with more light, and the page flat.")
                .font(Txt.value)
                .foregroundStyle(.soft)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier("scan.none")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Each line becomes a task in the Inbox. Take away the ones that are wrong.")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                    ForEach(lines) { line in
                        HStack(spacing: 8) {
                            Text(line.text)
                                .font(Txt.value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                lines.removeAll { $0.id == line.id }
                            } label: {
                                MarkImage("xmark", size: 14)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Take this line away")
                            .accessibilityIdentifier("scan.remove")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
            .accessibilityIdentifier("scan.lines")
        }
    }
}

/// The document camera of VisionKit as a screen: scan a page or several, then **Save**.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScanned: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanned: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScanned: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            var page = 0
            while page < scan.pageCount {
                images.append(scan.imageOfPage(at: page))
                page += 1
            }
            onScanned(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onCancel()
        }
    }
}

/// Apple's text recognition on the pages, off the main thread. What comes out goes through
/// `CaptureLines.scanned`, the tested rule that drops marks and smudges.
enum ListReader {
    static func lines(in images: [UIImage]) async -> [String] {
        var pieces: [String] = []
        for image in images {
            guard let cg = image.cgImage else { continue }
            let found: [String] = await Task.detached(priority: .userInitiated) { () -> [String] in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do { try handler.perform([request]) } catch { return [] }
                let raw: [Any] = request.results ?? []
                return raw.compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
            }.value
            pieces.append(contentsOf: found)
        }
        return CaptureLines.scanned(pieces)
    }
}
#else
/// There is no document camera on the Mac.
struct ScanListChip: View {
    let onAdd: ([String]) -> Void
    var body: some View { EmptyView() }
}
#endif
