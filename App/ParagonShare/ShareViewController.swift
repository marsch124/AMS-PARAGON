import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import ParagonCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Share › PARAGON, on the iPhone, the iPad and (build 318) the Mac: text, links, pictures and
/// PDFs from any app's share sheet.
///
/// **It never writes into the vault** — only the app holds the permission for that folder. It
/// leaves one line in the App Group's outbox, and copies shared pictures and PDFs beside it
/// (`SharedFiles`: by file, never through memory, since an extension is given little of it).
/// The app files everything the next time it is in front.
#if os(iOS)
final class ShareViewController: UIViewController {
    private var model: ShareModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let model = ShareModel(context: extensionContext)
        self.model = model
        let host = UIHostingController(rootView: ShareCaptureView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        model.load()
    }
}
#else
final class ShareViewController: NSViewController {
    private var model: ShareModel?

    override func loadView() {
        let model = ShareModel(context: extensionContext)
        self.model = model
        let host = NSHostingView(rootView: ShareCaptureView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 360)
        view = host
        preferredContentSize = host.frame.size
        model.load()
    }
}
#endif

/// One picture or PDF, copied and waiting for the app.
struct StagedFile: Identifiable {
    let id: Int
    /// Its path from the `capture-files` folder: what the outbox item names.
    let relative: String
    let name: String
    let bytes: Int64
    let thumb: CGImage?
    var isPDF: Bool { SharedFiles.isPDF(name) }
}

@MainActor
final class ShareModel: ObservableObject {
    @Published var text = ""
    @Published var url: URL?
    @Published var files: [StagedFile] = []
    /// What could not be kept, in plain words, one line each.
    @Published var problems: [String] = []
    @Published var loading = true
    @Published var target: CaptureTarget = .inbox
    @Published var asNote = false

    private weak var context: NSExtensionContext?
    private let itemID = UUID()

    init(context: NSExtensionContext?) {
        self.context = context
        if container == nil {
            problems.append("PARAGON\u{2019}s shared folder is not available. Open PARAGON once and try again.")
        }
    }

    /// The App Group folder the app reads. The Mac spells the same group with the Team ID in
    /// front (a sandboxed Mac app cannot join it otherwise).
    private nonisolated static var groupID: String {
        #if os(macOS)
        return "D24ENP83QQ.group.com.schabbauer.amspara"
        #else
        return "group.com.schabbauer.amspara"
        #endif
    }

    private nonisolated var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID)
    }

    private var outbox: CaptureOutbox? {
        container.map { CaptureOutbox(fileURL: $0.appendingPathComponent("capture-outbox.jsonl")) }
    }

    var canSave: Bool {
        guard !loading, outbox != nil else { return false }
        return !files.isEmpty || url != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Reading what was shared

    func load() {
        let items = (context?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let title = items.first?.attributedContentText?.string ?? ""
        let group = DispatchGroup()
        var fileCount = 0
        var tooMany = 0
        for (index, provider) in providers.enumerated() {
            let pdf = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
            let image = provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            let fileURL = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            if pdf || image || fileURL {
                guard fileCount < SharedFiles.maxItems else { tooMany += 1; continue }
                fileCount += 1
                group.enter()
                if pdf || image {
                    let type = pdf ? UTType.pdf : UTType.image
                    let suggested = provider.suggestedName
                    // The file is only there while this block runs: it is copied inside it.
                    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, error in
                        let result = Self.stage(url, suggested: suggested, index: index, itemID: self?.itemID, root: self?.container, error: error)
                        DispatchQueue.main.async { self?.took(result); group.leave() }
                    }
                } else {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                        let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                        let reading = url?.startAccessingSecurityScopedResource() ?? false
                        let result = Self.stage(url, suggested: nil, index: index, itemID: self?.itemID, root: self?.container, error: error)
                        if reading { url?.stopAccessingSecurityScopedResource() }
                        DispatchQueue.main.async { self?.took(result); group.leave() }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    DispatchQueue.main.async { if let url { self?.url = url }; group.leave() }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    let words = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                    DispatchQueue.main.async { if let words { self?.text = words }; group.leave() }
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            // Only a share without files takes the sending app's title as its words: with a
            // picture it is usually a file name, and the words there are his to add.
            if self.text.isEmpty, self.files.isEmpty { self.text = title }
            self.text = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.files.sort { $0.id < $1.id }
            if tooMany > 0 {
                self.problems.append("PARAGON takes \(SharedFiles.maxItems) files at a time. \(tooMany) more \(tooMany == 1 ? "was" : "were") left out.")
            }
            self.loading = false
        }
    }

    private enum Staged {
        case file(StagedFile)
        case problem(String)
    }

    private func took(_ result: Staged) {
        switch result {
        case .file(let file): files.append(file)
        case .problem(let words): problems.append(words)
        }
    }

    /// Copies one shared file into the waiting folder. Runs on the queue the system hands the
    /// file over on, and touches nothing of the model.
    private nonisolated static func stage(_ url: URL?, suggested: String?, index: Int, itemID: UUID?, root: URL?, error: Error?) -> Staged {
        guard let url else {
            return .problem("One item could not be read\(error.map { " (\($0.localizedDescription))" } ?? "").")
        }
        guard let itemID, let root else { return .problem("\u{201C}\(url.lastPathComponent)\u{201D} could not be kept.") }
        // The name the sending app suggests (IMG_0412), with the kind of the file it handed over.
        var name = url.lastPathComponent
        if let suggested, !suggested.trimmingCharacters(in: .whitespaces).isEmpty {
            let hasKind = SharedFiles.accepts(suggested) || (suggested as NSString).pathExtension.lowercased() == url.pathExtension.lowercased()
            name = hasKind || url.pathExtension.isEmpty ? suggested : suggested + "." + url.pathExtension
        }
        var source = url
        var made: URL?
        defer { if let made { try? FileManager.default.removeItem(at: made) } }
        if !SharedFiles.accepts(name) {
            // A picture of a kind the notes do not show (WebP, TIFF …) is kept as a JPEG.
            guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
                  let jpeg = jpegCopy(of: url) else {
                return .problem("\u{201C}\(name)\u{201D} was left out: PARAGON keeps pictures and PDFs.")
            }
            made = jpeg
            source = jpeg
            name = ((name as NSString).deletingPathExtension) + ".jpg"
        }
        do {
            let relative = try SharedFiles.stage(source, named: name, itemID: itemID, index: index,
                                                 root: root.appendingPathComponent(SharedFiles.stagingFolder, isDirectory: true))
            let staged = root.appendingPathComponent(SharedFiles.stagingFolder).appendingPathComponent(relative)
            let bytes = (try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }.map(Int64.init) ?? 0
            return .file(StagedFile(id: index, relative: relative, name: staged.lastPathComponent, bytes: bytes,
                                    thumb: SharedFiles.isPDF(relative) ? nil : small(staged, side: 120)))
        } catch {
            return .problem("\u{201C}\(name)\u{201D} could not be copied: \(error.localizedDescription)")
        }
    }

    /// A small picture read from the file without opening it at full size.
    private nonisolated static func small(_ url: URL, side: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: side]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private nonisolated static let jpegLock = NSLock()

    /// A JPEG of a picture, longest side 3000, in the temporary folder.
    private nonisolated static func jpegCopy(of url: URL) -> URL? {
        // One at a time: each holds the whole picture in memory for a moment (up to 3000 × 3000),
        // and the system hands over several files at once. An extension is given little memory.
        jpegLock.lock()
        defer { jpegLock.unlock() }
        guard let image = small(url, side: 3000) else { return nil }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? target : nil
    }

    // MARK: Save and Cancel

    /// True once the line is in the outbox: a second press on **Save** writes nothing more.
    private var saved = false

    func save() {
        guard !saved, let outbox else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A share with files is written as note lines: a picture is not a task.
        let item = CaptureItem(id: itemID, text: words, url: url, target: target,
                               asTask: files.isEmpty ? !asNote : false,
                               files: files.isEmpty ? nil : files.map(\.relative))
        do {
            try outbox.append(item)
            saved = true
            context?.completeRequest(returningItems: nil)
        } catch {
            problems.append("Could not be saved: \(error.localizedDescription)")
        }
    }

    func cancel() {
        // The copies made for this share are taken away again — never after Save: the line in
        // the outbox names them.
        if !saved, let outbox {
            try? FileManager.default.removeItem(at: outbox.filesURL.appendingPathComponent(itemID.uuidString, isDirectory: true))
        }
        context?.cancelRequest(withError: NSError(domain: "ParagonShare", code: NSUserCancelledError))
    }
}

/// A sheet of paper with a folded corner, drawn: the PDF's mark.
struct PageMark: Shape {
    func path(in rect: CGRect) -> Path {
        let sheet = rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.12)
        let fold = sheet.width * 0.34
        var path = Path()
        path.move(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
        path.addLine(to: CGPoint(x: sheet.minX, y: sheet.minY))
        path.addLine(to: CGPoint(x: sheet.minX, y: sheet.maxY))
        path.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY))
        path.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
        path.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
        path.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY + fold))
        path.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
        return path
    }
}

struct ShareCaptureView: View {
    @ObservedObject var model: ShareModel
    /// The Inbox's own blue-grey would need the app's theme; the share sheet wears PARAGON's
    /// project green, the colour of its main buttons.
    private let tint = Color(red: 0.20, green: 0.60, blue: 0.40)

    private var wordsPrompt: String { model.files.isEmpty ? "Text" : "A few words (optional)" }

    private var footnote: String {
        model.files.isEmpty
            ? "Filed into your vault the next time PARAGON opens. Add >2026-09-10 for a date, !! for priority, #tags as usual."
            : "Filed into your vault the next time PARAGON opens: pictures into the Pictures folder, PDFs into Attachments, with a line in the note. Until then they wait on this device."
    }

    @ViewBuilder private var fileRows: some View {
        ForEach(model.files) { file in
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12))
                    if let thumb = file.thumb {
                        Image(decorative: thumb, scale: 1).resizable().scaledToFill()
                    } else {
                        PageMark().stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.name).font(.subheadline).lineLimit(1).truncationMode(.middle)
                    Text((file.isPDF ? "PDF · " : "Picture · ") + ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("share.file")
        }
    }

    @ViewBuilder private var problemRows: some View {
        ForEach(model.problems, id: \.self) { words in
            Text(words).font(.caption).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var destination: some View {
        Picker("Save to", selection: $model.target) {
            Text("Inbox").tag(CaptureTarget.inbox)
            Text("Today\u{2019}s note").tag(CaptureTarget.today)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("share.target")
    }

    #if os(iOS)
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(wordsPrompt, text: $model.text, axis: .vertical)
                        .lineLimit(2...8)
                        .accessibilityIdentifier("share.words")
                    if let url = model.url {
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if model.loading || !model.files.isEmpty || !model.problems.isEmpty {
                    Section {
                        if model.loading {
                            HStack(spacing: 8) { ProgressView(); Text("Getting what you shared\u{2026}").foregroundStyle(.secondary) }
                        }
                        fileRows
                        problemRows
                    }
                }
                Section("Save to") {
                    destination
                    if model.files.isEmpty {
                        Toggle("As note, not task", isOn: $model.asNote)
                    }
                }
                Section {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("PARAGON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model.save() }
                        .fontWeight(.semibold)
                        .disabled(!model.canSave)
                }
            }
        }
        .tint(tint)
    }
    #else
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PARAGON").font(.headline)
            TextField(wordsPrompt, text: $model.text, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("share.words")
            if let url = model.url {
                Text(url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            if model.loading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Getting what you shared\u{2026}").foregroundStyle(.secondary) }
            }
            if !model.files.isEmpty || !model.problems.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        fileRows
                        problemRows
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 132)
            }
            HStack(spacing: 10) {
                Text("Save to").foregroundStyle(.secondary)
                destination.labelsHidden().fixedSize()
                Spacer(minLength: 0)
            }
            if model.files.isEmpty {
                Toggle("As note, not task", isOn: $model.asNote)
            }
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                // Escape is Cancel, Return is Save.
                Button("Cancel") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { model.save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .disabled(!model.canSave)
            }
        }
        .padding(16)
        .frame(width: 420, height: 360, alignment: .topLeading)
    }
    #endif
}
