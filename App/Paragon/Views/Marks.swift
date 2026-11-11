import SwiftUI
import AMSIcons

// 1.0 (build 280): every icon in the app is a hand-drawn mark from the AMS-Icons package —
// one 1.9 stroke on a 24-point grid, round ends, no fill — never an SF Symbol and never an
// emoji (his rule). The old symbol names stay in the code as the *names* of marks, so a row
// that said `tray` still says `tray`; this file is the one place a name becomes a drawing.

/// A mark by name.
struct MarkRef {
    enum Kind { case app(AppMark), control(ControlMark) }
    let kind: Kind
    /// Degrees clockwise. A chevron that points down is the right-pointing chevron turned.
    var rotation: Double = 0
}

enum Marks {
    /// The old SF Symbol names the app has used since build 1, each with the mark it means.
    static let byName: [String: MarkRef] = [
        // Sidebar and parts
        "tray": .init(kind: .app(.inbox)),
        "tray.full": .init(kind: .app(.trayFull)),
        "sun.max": .init(kind: .app(.today)),
        "calendar": .init(kind: .app(.calendar)),
        "calendar.badge.clock": .init(kind: .app(.timeBlocks)),
        "checklist": .init(kind: .app(.review)),
        "checklist.checked": .init(kind: .app(.review)),
        "point.3.filled.connected.trianglepath.dotted": .init(kind: .app(.map)),
        "clock.arrow.circlepath": .init(kind: .app(.recent)),
        "trash": .init(kind: .app(.bin)),
        "doc.badge.gearshape": .init(kind: .app(.templates)),
        "text.append": .init(kind: .app(.snippets)),
        "number": .init(kind: .app(.tags)),
        "magnifyingglass": .init(kind: .app(.search)),
        "star.fill": .init(kind: .app(.aspiration)),
        "star": .init(kind: .app(.aspiration)),
        "target": .init(kind: .app(.goal)),
        "scope": .init(kind: .app(.goal)),
        "flag": .init(kind: .app(.project)),
        "flag.checkered": .init(kind: .app(.finished)),
        "circle.grid.2x2": .init(kind: .app(.area)),
        "books.vertical": .init(kind: .app(.resource)),
        "archivebox": .init(kind: .app(.archive)),
        "briefcase": .init(kind: .app(.work)),
        "doc.text": .init(kind: .app(.page)),
        // Actions
        "tray.and.arrow.down": .init(kind: .app(.capture)),
        "tray.and.arrow.down.fill": .init(kind: .app(.capture)),
        "arrow.triangle.2.circlepath": .init(kind: .app(.sync)),
        "eye": .init(kind: .app(.read)),
        "eye.slash": .init(kind: .app(.readOff)),
        "chevron.left": .init(kind: .app(.back)),
        "chevron.backward": .init(kind: .app(.back)),
        "chevron.right": .init(kind: .app(.forward)),
        "chevron.forward": .init(kind: .app(.forward)),
        "chevron.down": .init(kind: .app(.forward), rotation: 90),
        "chevron.up": .init(kind: .app(.forward), rotation: -90),
        "moon.fill": .init(kind: .app(.moon)),
        "sunrise": .init(kind: .app(.sunrise)),
        "cup.and.saucer.fill": .init(kind: .app(.cup)),
        "hourglass": .init(kind: .app(.hourglass)),
        "person.crop.circle": .init(kind: .app(.hourglass)),
        "person.crop.circle.badge.questionmark": .init(kind: .app(.hourglass)),
        "link": .init(kind: .app(.link)),
        "icloud": .init(kind: .app(.cloud)),
        "icloud.and.arrow.down": .init(kind: .app(.cloudDown)),
        "exclamationmark.triangle": .init(kind: .app(.warning)),
        "exclamationmark.triangle.fill": .init(kind: .app(.warning)),
        "exclamationmark.circle": .init(kind: .app(.warningCircle)),
        "exclamationmark": .init(kind: .app(.exclamation)),
        "timer": .init(kind: .app(.timer)),
        "clock": .init(kind: .app(.timer)),
        "clock.badge.exclamationmark": .init(kind: .app(.clockAlert)),
        "circle.dashed": .init(kind: .app(.ringDashed)),
        "square.and.pencil": .init(kind: .app(.compose)),
        "bookmark": .init(kind: .app(.bookmark)),
        "list.bullet.indent": .init(kind: .app(.listIndent)),
        "info.circle": .init(kind: .app(.info)),
        "hand.draw": .init(kind: .app(.hand)),
        "paintpalette": .init(kind: .app(.palette)),
        "ruler": .init(kind: .app(.ruler)),
        "repeat": .init(kind: .app(.`repeat`)),
        "questionmark.circle": .init(kind: .app(.question)),
        "arrow.up.right": .init(kind: .app(.openLink)),
        "arrow.up.forward.app": .init(kind: .app(.openApp)),
        "arrow.up.circle.fill": .init(kind: .app(.send)),
        "arrow.down.left": .init(kind: .app(.arrowDownLeft)),
        "arrow.down": .init(kind: .app(.arrowDown)),
        "square.and.arrow.up": .init(kind: .app(.share)),
        "shippingbox": .init(kind: .app(.parcel)),
        "minus": .init(kind: .app(.minus)),
        "plus.magnifyingglass": .init(kind: .app(.zoomIn)),
        "minus.magnifyingglass": .init(kind: .app(.zoomOut)),
        "line.3.horizontal.decrease.circle": .init(kind: .app(.filter)),
        "arrow.turn.left.up": .init(kind: .app(.undo)),
        "circle.fill": .init(kind: .app(.dot)),
        "lock": .init(kind: .app(.lock)),
        "square": .init(kind: .control(.circle)),
        "checkmark.square.fill": .init(kind: .control(.ticked)),
        "minus.circle": .init(kind: .app(.minus)),
        "square.grid.2x2": .init(kind: .app(.area)),
        "questionmark.folder": .init(kind: .app(.question)),
        "pause.circle": .init(kind: .control(.pause)),
        // Control marks the package already had
        "plus": .init(kind: .control(.add)),
        "plus.circle": .init(kind: .control(.addCircle)),
        "plus.circle.fill": .init(kind: .control(.addCircle)),
        "pencil": .init(kind: .control(.edit)),
        "checkmark": .init(kind: .control(.check)),
        "checkmark.circle": .init(kind: .control(.ticked)),
        "checkmark.circle.fill": .init(kind: .control(.ticked)),
        "checkmark.seal": .init(kind: .control(.ticked)),
        "circle": .init(kind: .control(.circle)),
        "xmark": .init(kind: .control(.close)),
        "xmark.circle": .init(kind: .control(.close)),
        "ellipsis.circle": .init(kind: .control(.more)),
        "ellipsis": .init(kind: .control(.more)),
        "gear": .init(kind: .control(.settings)),
        "gearshape": .init(kind: .control(.settings)),
        "list.bullet": .init(kind: .control(.list)),
    ]

    /// The mark for a name. A name nobody mapped draws the dot, and says so in a debug build,
    /// so a missing drawing is noticed on the first screen and never ships as a blank.
    static func ref(_ name: String) -> MarkRef {
        if let found = byName[name] { return found }
        #if DEBUG
        print("PARAGON: no mark is drawn for the icon name \(name)")
        #endif
        return MarkRef(kind: .app(.dot))
    }

    /// The SVG path of the mark, for the few places that need to draw it themselves.
    static func path(_ name: String) -> String {
        switch ref(name).kind {
        case .app(let mark): return mark.path
        case .control(let mark): return mark.path
        }
    }
}

/// A hand-drawn mark in place of `Image(systemName:)`. It takes the colour of the text around
/// it, like the symbol did; the size is in points (16 is a sidebar row, 17 the toolbar).
struct MarkImage: View {
    let name: String
    var size: CGFloat = 16

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    var body: some View {
        // A template image rather than a stroked shape: a macOS toolbar, a menu, a context
        // menu and the iPhone's tab bar draw only images, and a shape there came out blank
        // (the first pictures of build 280). The image is drawn by a handler, so it is crisp
        // at any scale, and it takes the colour of the text around it as the symbol did.
        Marks.templateImage(name, size: size)
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
    }
}

extension Marks {
    /// One image per name and size, drawn once.
    private static var cache: [String: Image] = [:]

    static func templateImage(_ name: String, size: CGFloat) -> Image {
        let key = "\(name)@\(size)"
        if let done = cache[key] { return done }
        #if canImport(UIKit)
        let made = image(name, size: size)
        #else
        let made = Image(nsImage: nsImage(name, size: size))
        #endif
        cache[key] = made
        return made
    }
}

/// A `Label` whose icon is a hand-drawn mark, in place of `Label(_:systemImage:)`.
struct MarkLabel: View {
    let title: String
    let name: String
    var size: CGFloat = 16

    init(_ title: String, _ name: String, size: CGFloat = 16) {
        self.title = title
        self.name = name
        self.size = size
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            MarkImage(name, size: size)
        }
    }
}

#if canImport(UIKit)
import UIKit

extension Marks {
    /// The mark as a template image, for the places UIKit draws itself: the tab bar.
    static func image(_ name: String, size: CGFloat = 24) -> Image {
        Image(uiImage: uiImage(name, size: size))
    }

    /// The same drawing as a UIKit image, for the bar above the keyboard (build 286).
    static func uiImage(_ name: String, size: CGFloat = 24) -> UIImage {
        let ref = ref(name)
        let path: String
        switch ref.kind {
        case .app(let mark): path = mark.path
        case .control(let mark): path = mark.path
        }
        let scale: CGFloat = size / 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let drawn = renderer.image { context in
            let cg = context.cgContext
            cg.translateBy(x: size / 2, y: size / 2)
            cg.rotate(by: ref.rotation * .pi / 180)
            cg.translateBy(x: -size / 2, y: -size / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.addPath(GridShape(d: path).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath)
            cg.setLineWidth(1.9)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.strokePath()
        }
        return drawn.withRenderingMode(.alwaysTemplate)
    }
}
#endif

#if os(macOS)
import AppKit

extension Marks {
    /// The mark as a template image, for the places AppKit draws itself: the menu bar items.
    static func nsImage(_ name: String, size: CGFloat = 18) -> NSImage {
        let ref = ref(name)
        let path: String
        switch ref.kind {
        case .app(let mark): path = mark.path
        case .control(let mark): path = mark.path
        }
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            let scale = size / 24
            cg.translateBy(x: size / 2, y: size / 2)
            cg.rotate(by: ref.rotation * .pi / 180)
            cg.translateBy(x: -size / 2, y: -size / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.addPath(GridShape(d: path).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath)
            cg.setLineWidth(1.9)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setStrokeColor(NSColor.black.cgColor)
            cg.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
#endif
