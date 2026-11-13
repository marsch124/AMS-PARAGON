import SwiftUI
import ParagonCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// **Share…** in a note's menu (review round 8, build 315): the note as a PDF in the Read look,
/// as plain text, or the file itself.
///
/// **Always a copy in the temporary folder, never the file in the vault**: whatever app takes
/// it gets something it may keep, move or change without touching his note.
@MainActor
enum NoteSharing {
    /// Writes the copy and says where it is; nil when it could not be made.
    static func file(_ form: NoteShare.Form, for note: Note) -> URL? {
        let data: Data?
        let name: String
        switch form {
        case .pdf:
            data = NotePDF.data(for: note)
            name = NoteShare.fileName(title: note.displayTitle, ext: "pdf")
        case .text:
            data = Data(NoteShare.plainText(of: note.text).utf8)
            name = NoteShare.fileName(title: note.displayTitle, ext: "txt")
        case .file:
            data = Data(note.text.utf8)
            name = (note.relativePath as NSString).lastPathComponent
        }
        guard let data else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PARAGON share", isDirectory: true)
        let url = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    #if os(macOS)
    /// The Mac's own share list, at the top right of the window the note is in.
    static func present(_ url: URL) {
        guard let view = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentView else { return }
        let corner = NSRect(x: view.bounds.maxX - 60, y: view.isFlipped ? 0 : view.bounds.maxY - 1, width: 1, height: 1)
        NSSharingServicePicker(items: [url]).show(relativeTo: corner, of: view, preferredEdge: .minY)
    }

    static func showInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
}

/// The note on paper: A4 pages, the Read look, always light. A page ends between two blocks
/// (a heading, a paragraph, a task), never through the middle of one unless a single block is
/// taller than a page.
@MainActor
enum NotePDF {
    static let page = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 48

    static func data(for note: Note) -> Data? {
        let width = page.width - 2 * margin
        let bottom = page.height - margin
        let room = page.height - 2 * margin
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        context.beginPDFPage(nil)
        var y = margin
        for view in NotePrint(note: note).pieces {
            let renderer = ImageRenderer(content: view.frame(width: width, alignment: .leading)
                .environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            renderer.render { size, draw in
                let height = size.height
                guard height > 0 else { return }
                // A block that fits on a page is never cut: it starts the next page instead.
                if height <= room, y + height > bottom {
                    context.endPDFPage()
                    context.beginPDFPage(nil)
                    y = margin
                }
                var drawn: CGFloat = 0
                while drawn < height {
                    if bottom - y < 1 {
                        context.endPDFPage()
                        context.beginPDFPage(nil)
                        y = margin
                    }
                    let slice = min(bottom - y, height - drawn)
                    context.saveGState()
                    // PDF pages count from the bottom; `y` counts from the top.
                    context.clip(to: CGRect(x: margin, y: page.height - y - slice, width: width, height: slice))
                    context.translateBy(x: margin, y: page.height - y + drawn - height)
                    draw(context)
                    context.restoreGState()
                    drawn += slice
                    y += slice
                }
            }
            y += 6
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}

/// The pieces of a printed note, top to bottom: its name, then each block of the Read look.
/// Tasks are drawn as a box and their words, since paper has nothing to press.
@MainActor
struct NotePrint {
    let note: Note

    var pieces: [AnyView] {
        let preview = MarkdownPreview(note: note, beforeToggle: {})
        let blocks = preview.blocks
        var result: [AnyView] = []
        // The note's name on top, unless the note already begins with it as a heading.
        if case .heading(_, let text)? = blocks.first(where: { if case .blank = $0 { return false } else { return true } }),
           text == note.displayTitle {
        } else {
            result.append(AnyView(
                Text(note.displayTitle)
                    .font(.system(size: Txt.Editor.h1, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.bottom, 6)
            ))
        }
        for block in blocks {
            if case .task(let task) = block {
                result.append(AnyView(PrintedTask(task: task, words: preview.inline(Self.words(of: task)))))
            } else {
                result.append(AnyView(preview.render(block).foregroundStyle(Color.black)))
            }
        }
        return result
    }

    /// The task's words, with its day when it has one (2026-11-13).
    static func words(of task: TaskItem) -> String {
        guard let due = task.dueDate else { return task.title }
        return "\(task.title)  \u{00B7}  \(due)"
    }
}

private struct PrintedTask: View {
    let task: TaskItem
    let words: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            MarkImage(task.isDone ? "checkmark.square.fill" : "square", size: 13)
            words.strikethrough(task.status == .cancelled)
        }
        .foregroundStyle(task.isDone ? Color.gray : Color.black)
        .padding(.leading, CGFloat(task.indentLevel) * 14)
    }
}
