import SwiftUI
import AMSIcons
import ParagonCore

/// 1.0: the widgets draw the same hand-drawn marks as the app (never an SF Symbol). The old
/// symbol names stay as the names; this is the widgets' own small map of them.
struct WidgetMark: View {
    let name: String
    var size: CGFloat = 13

    /// Round 5: a mark under 16 points keeps a 1.3-point line on screen (1.9 on the grid at
    /// 13 points was 1.03). The same rule the app draws with.
    private var line: CGFloat { CGFloat(MarkRule.lineWidth(forSize: Double(size))) }

    var body: some View {
        switch name {
        case "target", "scope": AppMarkView(.goal, size: size, lineWidth: line)
        case "circle.grid.2x2": AppMarkView(.area, size: size, lineWidth: line)
        case "books.vertical": AppMarkView(.resource, size: size, lineWidth: line)
        case "tray": AppMarkView(.inbox, size: size, lineWidth: line)
        case "calendar": AppMarkView(.calendar, size: size, lineWidth: line)
        case "calendar.badge.clock": AppMarkView(.timeBlocks, size: size, lineWidth: line)
        case "archivebox": AppMarkView(.archive, size: size, lineWidth: line)
        case "checkmark.circle": ControlMarkView(.ticked, size: size, lineWidth: line)
        case "circle": ControlMarkView(.circle, size: size, lineWidth: line)
        case "exclamationmark.triangle": AppMarkView(.warning, size: size, lineWidth: line)
        case "sun.max": AppMarkView(.today, size: size, lineWidth: line)
        default: AppMarkView(.project, size: size, lineWidth: line)
        }
    }
}
