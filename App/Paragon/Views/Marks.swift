import SwiftUI
import AMSIcons
import ParagonCore

// 1.0 (build 280): every icon in the app is a hand-drawn mark from the AMS-Icons package —
// one 1.9 stroke on a 24-point grid, round ends, no fill — never an SF Symbol and never an
// emoji (his rule). The old symbol names stay in the code as the *names* of marks, so a row
// that said `tray` still says `tray`; this file is the one place a name becomes a drawing.

/// A mark by name.
struct MarkRef {
    /// `drawn` is a mark PARAGON draws itself, in the library's style: an SVG path on the
    /// 24-point grid, stroked with the one 1.9 line and round ends, no fill (round 9).
    enum Kind { case app(AppMark), control(ControlMark), drawn(String) }

    /// The mark's path on the 24-point grid.
    var path: String {
        switch kind {
        case .app(let mark): return mark.path
        case .control(let mark): return mark.path
        case .drawn(let path): return path
        }
    }
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
        // 311: "checklist" is a list of tasks (the ticked list); the weekly review has its own mark.
        "checklist": .init(kind: .control(.list)),
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
        // Round 9 (build 316): a task's deadline has a mark of its own — a pennant on its pole,
        // standing on the finish line. The project keeps the waving flag.
        "deadline": .init(kind: .drawn(Marks.deadlinePath)),
        "circle.grid.2x2": .init(kind: .app(.area)),
        "books.vertical": .init(kind: .app(.resource)),
        "archivebox": .init(kind: .app(.archive)),
        "archivebox.and.arrow.down": .init(kind: .app(.archiveDown)),
        "folder": .init(kind: .app(.folder)),
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
        "person.crop.circle": .init(kind: .app(.person)),
        "person.crop.circle.badge.questionmark": .init(kind: .app(.question)),
        "link": .init(kind: .app(.link)),
        "icloud": .init(kind: .app(.cloud)),
        "icloud.and.arrow.down": .init(kind: .app(.cloudDown)),
        "exclamationmark.triangle": .init(kind: .app(.warning)),
        "exclamationmark.triangle.fill": .init(kind: .app(.warning)),
        "exclamationmark.circle": .init(kind: .app(.warningCircle)),
        "exclamationmark": .init(kind: .app(.exclamation)),
        "timer": .init(kind: .app(.timer)),
        "clock": .init(kind: .app(.clock)),
        "clock.badge.exclamationmark": .init(kind: .app(.clockAlert)),
        "circle.dashed": .init(kind: .app(.ringDashed)),
        "square.and.pencil": .init(kind: .app(.compose)),
        "bookmark": .init(kind: .app(.bookmark)),
        "list.bullet.indent": .init(kind: .app(.listIndent)),
        "info.circle": .init(kind: .app(.info)),
        "hand.draw": .init(kind: .app(.hand)),
        "paintpalette": .init(kind: .app(.palette)),
        "ruler": .init(kind: .app(.ruler)),
        // Build 318: a goal's number has a mark of its own — a rising line on two axes — so
        // **Set a number…** does not wear the measure's ruler beside it.
        "chart.line": .init(kind: .drawn(Marks.chartPath)),
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
        "minus.circle": .init(kind: .control(.minusCircle)),
        "square.grid.2x2": .init(kind: .app(.area)),
        "questionmark.folder": .init(kind: .app(.question)),
        "pause.circle": .init(kind: .control(.pause)),
        // Build 317: the focus bar's Pause, Go on and Stop. Play and pause are the library's
        // drawings; it has no stop mark, so the square is drawn here in the same line.
        "play.fill": .init(kind: .control(.play)),
        "pause.fill": .init(kind: .control(.pause)),
        "stop.fill": .init(kind: .drawn(Marks.stopPath)),
        // Control marks the package already had
        "plus": .init(kind: .control(.add)),
        "plus.circle": .init(kind: .control(.addCircle)),
        "plus.circle.fill": .init(kind: .control(.addCircle)),
        "pencil": .init(kind: .control(.edit)),
        "photo": .init(kind: .control(.photo)),
        "checkmark": .init(kind: .control(.check)),
        "checkmark.circle": .init(kind: .control(.ticked)),
        "checkmark.circle.fill": .init(kind: .control(.ticked)),
        "checkmark.seal": .init(kind: .control(.ticked)),
        "circle": .init(kind: .control(.circle)),
        "xmark": .init(kind: .control(.close)),
        "xmark.circle": .init(kind: .control(.closeCircle)),
        "ellipsis.circle": .init(kind: .control(.more)),
        "ellipsis": .init(kind: .control(.more)),
        "gear": .init(kind: .control(.settings)),
        "gearshape": .init(kind: .control(.settings)),
        "list.bullet": .init(kind: .control(.list)),
    ]

    /// The deadline's mark: a pole, a three-cornered pennant and the finish line under it.
    static let deadlinePath = "M7 20.5V3.5 M7 4.5L18.5 8.75L7 13 M3.5 20.5h13"

    /// A goal's number: two axes and a line that climbs.
    static let chartPath = "M4.5 4.5V19.5H20 M8 15.5L11.5 11.5L14.5 13.5L19.5 7.5"

    /// Stop: a square with round corners, the same drawing as on the Lock Screen banner.
    static let stopPath = "M7 7h10v10h-10Z"

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
        ref(name).path
    }
}

/// A hand-drawn mark in place of `Image(systemName:)`. It takes the colour of the text around
/// it, like the symbol did.
///
/// Round 5 of the premium review: a mark has its size one of two ways. `size:` is a fixed
/// number of points (17 in the toolbar, 14 on a small button) and never changes. `text:` is
/// the text style the mark sits beside: it is sized by `MarkRule.size(for:)` and grows with
/// the text size chosen in the iPhone's settings. With neither it sits beside body text (16).
/// `.font(…)` and `.imageScale(…)` on a mark do nothing — it is a drawing, not a symbol.
struct MarkImage: View {
    let name: String
    /// A fixed size in points, or nil when the mark follows a text style.
    private let fixed: CGFloat?
    @ScaledMetric private var scaled: CGFloat

    init(_ name: String, size: CGFloat) {
        self.name = name
        self.fixed = size
        self._scaled = ScaledMetric(wrappedValue: size)
    }

    init(_ name: String, text: MarkRule.TextStyle = .body) {
        self.name = name
        self.fixed = nil
        self._scaled = ScaledMetric(wrappedValue: CGFloat(MarkRule.size(for: text)), relativeTo: text.fontStyle)
    }

    /// Half points are fine on screen and keep the drawn images few.
    private var size: CGFloat { fixed ?? (scaled * 2).rounded() / 2 }

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

extension MarkRule.TextStyle {
    /// Apple's text style of the same name, for growing with the text size.
    var fontStyle: Font.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }
}

extension Marks {
    /// One image per name and size, drawn once.
    private static var cache: [String: Image] = [:]

    static func templateImage(_ name: String, size: CGFloat) -> Image {
        // The key counts in hundredths of a point, so 9.92 and 9.920000001 are one image.
        let key = "\(name)@\(Int((size * 100).rounded()))"
        if let done = cache[key] { return done }
        #if canImport(UIKit)
        let made = image(name, size: size)
        #else
        let made = Image(nsImage: nsImage(name, size: size))
        #endif
        cache[key] = made
        return made
    }

    /// The line to draw a mark of that size with, on the 24-point grid: 1.9, and heavier for
    /// a mark under 16 points so that it is never thinner than 1.3 points on screen.
    static func gridLine(forSize size: CGFloat) -> CGFloat {
        CGFloat(MarkRule.lineWidth(forSize: Double(size)))
    }
}

/// A `Label` whose icon is a hand-drawn mark, in place of `Label(_:systemImage:)`. The mark
/// has a fixed `size:` or follows a `text:` style, as `MarkImage` does; `.font(…)` on the
/// label sets the words only.
struct MarkLabel: View {
    let title: String
    let name: String
    private let fixed: CGFloat?
    private let style: MarkRule.TextStyle

    init(_ title: String, _ name: String, size: CGFloat) {
        self.title = title
        self.name = name
        self.fixed = size
        self.style = .body
    }

    init(_ title: String, _ name: String, text: MarkRule.TextStyle = .body) {
        self.title = title
        self.name = name
        self.fixed = nil
        self.style = text
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let fixed {
                MarkImage(name, size: fixed)
            } else {
                MarkImage(name, text: style)
            }
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
        let path = ref.path
        let scale: CGFloat = size / 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let drawn = renderer.image { context in
            let cg = context.cgContext
            cg.translateBy(x: size / 2, y: size / 2)
            cg.rotate(by: ref.rotation * .pi / 180)
            cg.translateBy(x: -size / 2, y: -size / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.addPath(GridShape(d: path).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath)
            cg.setLineWidth(gridLine(forSize: size))
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
        let path = ref.path
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            let scale = size / 24
            cg.translateBy(x: size / 2, y: size / 2)
            cg.rotate(by: ref.rotation * .pi / 180)
            cg.translateBy(x: -size / 2, y: -size / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.addPath(GridShape(d: path).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath)
            cg.setLineWidth(gridLine(forSize: size))
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
