import SwiftUI
import AMSIcons

/// 1.0: the widgets draw the same hand-drawn marks as the app (never an SF Symbol). The old
/// symbol names stay as the names; this is the widgets' own small map of them.
struct WidgetMark: View {
    let name: String
    var size: CGFloat = 13

    var body: some View {
        switch name {
        case "target", "scope": AppMarkView(.goal, size: size)
        case "circle.grid.2x2": AppMarkView(.area, size: size)
        case "books.vertical": AppMarkView(.resource, size: size)
        case "tray": AppMarkView(.inbox, size: size)
        case "calendar": AppMarkView(.calendar, size: size)
        case "calendar.badge.clock": AppMarkView(.timeBlocks, size: size)
        case "archivebox": AppMarkView(.archive, size: size)
        case "checkmark.circle": ControlMarkView(.ticked, size: size)
        case "circle": ControlMarkView(.circle, size: size)
        case "exclamationmark.triangle": AppMarkView(.warning, size: size)
        case "sun.max": AppMarkView(.today, size: size)
        default: AppMarkView(.project, size: size)
        }
    }
}
