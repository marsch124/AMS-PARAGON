import SwiftUI
import QuickLook
import ImageIO
import ParagonCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Build 318: pictures and PDFs kept beside the notes (`SharedFiles` in ParagonCore) — how a
/// PDF is drawn as a row, how a picture is shown in the Read look and in the Inbox, and how
/// either opens large in Quick Look.
@MainActor
enum AttachmentFiles {
    /// How a file stands on this device.
    enum Presence { case here, coming, missing }

    static func presence(of url: URL) -> Presence {
        if CloudFiles.isMissing(url) { return .coming }
        return FileManager.default.fileExists(atPath: url.path) ? .here : .missing
    }

    /// The PDF's page count; nil when it cannot be read (not here yet, locked, not a PDF).
    nonisolated static func pageCount(of url: URL) -> Int? {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else { return nil }
        return document.numberOfPages
    }

    /// The row's two lines: the words he gave it (or the file's name), then `PDF · 3 pages`,
    /// with the file's name when the words are something else.
    static func words(for path: String, label: String, url: URL) -> (title: String, detail: String) {
        let fileName = (path as NSString).lastPathComponent
        let plainName = (fileName as NSString).deletingPathExtension
        let label = label.trimmingCharacters(in: .whitespaces)
        let named = !label.isEmpty && label != fileName && label != plainName
        switch presence(of: url) {
        case .coming: return (named ? label : plainName, "On its way from iCloud")
        case .missing: return (named ? label : plainName, "This file is not in the vault")
        case .here:
            let pages = SharedFiles.pagesWords(pageCount(of: url))
            return (named ? label : plainName, named ? pages + " · " + fileName : pages)
        }
    }

    /// The PDF's first page, small, on white. Nil when it cannot be read.
    nonisolated static func pageThumb(of url: URL, side: CGFloat, scale: CGFloat = 2) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let fit = min(side / box.width, side / box.height)
        let width = Int((box.width * fit * scale).rounded()), height = Int((box.height * fit * scale).rounded())
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // The page's own transform: it also turns a page that is stored on its side.
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height),
                                                     rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// A picture file made small without reading all of it into memory at full size.
    nonisolated static func smallPicture(at url: URL, maxSide: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxSide]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// A copy of the file to show in Quick Look. Quick Look gets the copy, not the vault's
    /// file: it can always read it, and nothing done there can change the original.
    nonisolated static func previewCopy(of url: URL) -> URL? {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("AttachmentPreview", isDirectory: true)
        try? fm.removeItem(at: folder)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent(url.lastPathComponent)
            try fm.copyItem(at: url, to: copy)
            return copy
        } catch {
            return nil
        }
    }

    // MARK: The PDF row inside the editor's text

    static let rowHeight: CGFloat = 52

    /// A PDF in the text, drawn as a row: its first page small, its name, `PDF · 3 pages`.
    /// `real` is false while the file is not on this device, so it is drawn again later.
    static func rowImage(path: String, label: String, root: URL, width: CGFloat) -> (image: PlatformImage, real: Bool) {
        let url = root.appendingPathComponent(path)
        let state = presence(of: url)
        if state == .coming { CloudFiles.startDownload(url) }
        let words = words(for: path, label: label, url: url)
        let thumb = state == .here ? pageThumb(of: url, side: 40) : nil
        let size = CGSize(width: max(min(width, 340), 200), height: rowHeight)
        #if os(iOS)
        func render(_ style: UIUserInterfaceStyle) -> UIImage {
            var made = UIImage()
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                made = UIGraphicsImageRenderer(size: size).image { _ in drawRow(size: size, words: words, thumb: thumb) }
            }
            return made
        }
        // Drawn for day and for night, so the row follows the appearance without being remade.
        let asset = UIImageAsset()
        asset.register(render(.light), with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(render(.dark), with: UITraitCollection(userInterfaceStyle: .dark))
        return (asset.image(with: .current), state == .here)
        #else
        let image = NSImage(size: size, flipped: true) { _ in
            drawRow(size: size, words: words, thumb: thumb)
            return true
        }
        return (image, state == .here)
        #endif
    }

    /// Draws the row into the current context, origin at the top left.
    private static func drawRow(size: CGSize, words: (title: String, detail: String), thumb: CGImage?) {
        #if os(iOS)
        let fill = UIColor.secondarySystemFill, line = UIColor.separator
        let ink = UIColor.label, soft = UIColor.secondaryLabel
        let box = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), cornerRadius: 8)
        let context = UIGraphicsGetCurrentContext()
        #else
        let fill = NSColor.quaternaryLabelColor.withAlphaComponent(0.08), line = NSColor.separatorColor
        let ink = NSColor.labelColor, soft = NSColor.secondaryLabelColor
        let box = NSBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        let context = NSGraphicsContext.current?.cgContext
        #endif
        fill.setFill()
        box.fill()
        line.setStroke()
        box.lineWidth = 1
        box.stroke()

        // The page: the PDF's own first page, or a drawn sheet with a folded corner.
        let slot = CGRect(x: 10, y: 6, width: 30, height: 40)
        if let thumb, let context {
            let fit = min(slot.width / CGFloat(thumb.width), slot.height / CGFloat(thumb.height))
            let w = CGFloat(thumb.width) * fit, h = CGFloat(thumb.height) * fit
            let rect = CGRect(x: slot.midX - w / 2, y: slot.midY - h / 2, width: w, height: h)
            context.saveGState()
            // Images are drawn bottom-up: turn this one the right way in a top-down context.
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(thumb, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
            context.setStrokeColor(line.cgColor)
            context.setLineWidth(1)
            context.stroke(rect.insetBy(dx: -0.5, dy: -0.5))
        } else if let context {
            let sheet = CGRect(x: slot.midX - 11, y: slot.midY - 14, width: 22, height: 28)
            let fold: CGFloat = 7
            context.setStrokeColor(soft.cgColor)
            context.setLineWidth(1.9)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
            context.addLine(to: CGPoint(x: sheet.minX, y: sheet.minY))
            context.addLine(to: CGPoint(x: sheet.minX, y: sheet.maxY))
            context.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY))
            context.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
            context.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY))
            context.addLine(to: CGPoint(x: sheet.maxX - fold, y: sheet.minY + fold))
            context.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY + fold))
            context.strokePath()
        }

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingMiddle
        let textWidth = size.width - 50 - 10
        (words.title as NSString).draw(in: CGRect(x: 50, y: 9, width: textWidth, height: 18), withAttributes: [
            .font: PlatformFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: ink, .paragraphStyle: style])
        (words.detail as NSString).draw(in: CGRect(x: 50, y: 28, width: textWidth, height: 16), withAttributes: [
            .font: PlatformFont.systemFont(ofSize: 11), .foregroundColor: soft, .paragraphStyle: style])
    }
}

/// Opens a picture or a PDF of the vault large, in Apple's Quick Look. Hang it on any view
/// with `.attachmentPreview($path)`; the path is from the vault's root.
private struct AttachmentPreview: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @Binding var path: String?
    @State private var shown: URL?

    func body(content: Content) -> some View {
        content
            // On a clear view of its own behind the content: Quick Look is one more thing a
            // screen presents, and the note screen already presents several.
            .background(Color.clear.quickLookPreview($shown))
            .onChange(of: path) { _, wanted in
                guard let wanted else { return }
                path = nil
                open(wanted)
            }
    }

    private func open(_ wanted: String) {
        guard let root = model.vault?.rootURL else { return }
        let url = root.appendingPathComponent(wanted)
        let name = (wanted as NSString).lastPathComponent
        switch AttachmentFiles.presence(of: url) {
        case .coming:
            CloudFiles.startDownload(url)
            model.errorMessage = "\u{201C}\(name)\u{201D} is still on its way from iCloud. Try again in a moment."
        case .missing:
            model.errorMessage = "\u{201C}\(name)\u{201D} is not in the vault any more."
        case .here:
            if let copy = AttachmentFiles.previewCopy(of: url) {
                shown = copy
            } else {
                model.errorMessage = "\u{201C}\(name)\u{201D} could not be opened."
            }
        }
    }
}

extension View {
    func attachmentPreview(_ path: Binding<String?>) -> some View {
        modifier(AttachmentPreview(path: path))
    }
}

/// A picture or a PDF of the vault outside the editor's text: in the Read look (a picture at a
/// calm size, a PDF as a row) and, `compact`, as one line of the Inbox. A press opens it large.
struct AttachmentBlock: View {
    let attachment: SharedFiles.Attachment
    /// The vault's folder. Nil on paper (the printed note): the name stands in words.
    let root: URL?
    var compact = false
    @State private var picture: Image?
    @State private var pdf: (title: String, detail: String, thumb: Image?)?
    @State private var coming = false
    @State private var opened: String?

    var body: some View {
        if root == nil {
            Text(attachment.label.isEmpty ? attachment.fileName : attachment.label + " (" + attachment.fileName + ")")
        } else {
            Button { opened = attachment.path } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel(attachment.label.isEmpty ? attachment.fileName : attachment.label)
                .accessibilityHint("Opens it large")
                .accessibilityIdentifier(attachment.isPicture ? "attachment.picture" : "attachment.pdf")
                .attachmentPreview($opened)
                .task(id: attachment.path) { await load() }
        }
    }

    @ViewBuilder private var label: some View {
        if attachment.isPicture {
            if compact { compactPicture } else { fullPicture }
        } else {
            pdfRow
        }
    }

    private var fullPicture: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let picture {
                picture.resizable().scaledToFit()
                    .frame(maxWidth: 420, maxHeight: 260, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            } else {
                waitingBox
            }
            if !attachment.label.isEmpty {
                Text(attachment.label).font(Txt.label).foregroundStyle(.soft)
            }
        }
        .padding(.vertical, 2)
    }

    private var compactPicture: some View {
        HStack(spacing: 8) {
            thumbBox(picture)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.label.isEmpty ? attachment.fileName : attachment.label)
                    .font(Txt.list).lineLimit(2)
                Text(coming ? "On its way from iCloud" : (attachment.label.isEmpty ? "Picture" : "Picture · " + attachment.fileName))
                    .font(Txt.listSecond).foregroundStyle(.soft).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var pdfRow: some View {
        HStack(spacing: 8) {
            thumbBox(pdf?.thumb, page: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(pdf?.title ?? attachment.fileName)
                    .font(compact ? Txt.list : Txt.listTitle).lineLimit(compact ? 2 : 1).truncationMode(.middle)
                Text(pdf?.detail ?? "PDF")
                    .font(Txt.listSecond).foregroundStyle(.soft).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 0 : 6)
        .frame(maxWidth: compact ? .infinity : 340, alignment: .leading)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08))
                RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    /// 40 points: a picture cut square, or a page shown whole on white.
    private func thumbBox(_ image: Image?, page: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: page ? 3 : 6)
            .fill(page && image != nil ? Color.white : Color.secondary.opacity(0.12))
            .frame(width: page ? 30 : 40, height: 40)
            .overlay {
                if let image {
                    if page { image.resizable().scaledToFit() } else { image.resizable().scaledToFill() }
                } else if page {
                    MarkImage("doc.text", size: 18).foregroundStyle(.soft)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: page ? 3 : 6))
            .overlay(RoundedRectangle(cornerRadius: page ? 3 : 6).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
    }

    private var waitingBox: some View {
        Text(coming ? "On its way from iCloud" : "This picture is not in the vault")
            .font(Txt.label).foregroundStyle(.soft)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func load() async {
        guard let root else { return }
        let url = root.appendingPathComponent(attachment.path)
        let state = AttachmentFiles.presence(of: url)
        coming = state == .coming
        if state == .coming { CloudFiles.startDownload(url) }
        if attachment.isPicture {
            guard state == .here else { picture = nil; return }
            let side: CGFloat = compact ? 160 : 1200
            let made = await Task.detached(priority: .userInitiated) {
                AttachmentFiles.smallPicture(at: url, maxSide: side)
            }.value
            picture = made.map { Image(decorative: $0, scale: 1) }
        } else {
            let words = AttachmentFiles.words(for: attachment.path, label: attachment.label, url: url)
            let thumb = state == .here ? AttachmentFiles.pageThumb(of: url, side: 40) : nil
            pdf = (words.title, words.detail, thumb.map { Image(decorative: $0, scale: 1) })
        }
    }
}

/// The words of one Inbox note line: a shared picture or PDF as itself, anything else as text.
struct InboxNoteWords: View {
    @EnvironmentObject private var model: AppModel
    let text: String

    /// True when the line is a picture or a PDF and nothing else.
    static func isAttachment(_ text: String) -> Bool {
        SharedFiles.attachment(inLine: text, notePath: "Inbox.md") != nil
    }

    var body: some View {
        if let vault = model.vault,
           let attachment = SharedFiles.attachment(inLine: text, notePath: vault.config.inboxFile) {
            AttachmentBlock(attachment: attachment, root: vault.rootURL, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .font(Txt.list)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
