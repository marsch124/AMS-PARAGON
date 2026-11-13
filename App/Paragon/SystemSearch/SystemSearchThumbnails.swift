import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import AMSIcons
import ParagonCore
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The small picture beside a note in the system search (build 317): a flat tile in the colour
/// of the note's part with that part's hand-drawn mark in white — green with the flag for a
/// project, pink with the four dots for an area. The app's own marks and colours, drawn once.
@MainActor
enum SystemSearchThumbnails {
    private static var drawn: [SystemSearchEntry.Part: Data]?

    static func all() -> [SystemSearchEntry.Part: Data] {
        if let drawn { return drawn }
        var made: [SystemSearchEntry.Part: Data] = [:]
        for part in SystemSearchEntry.Part.allCases {
            made[part] = tile(colourName: colourName(for: part), markName: markName(for: part))
        }
        drawn = made
        return made
    }

    static func colourName(for part: SystemSearchEntry.Part) -> String {
        switch part {
        case .project: return "ProjectTint"
        case .area: return "AreaTint"
        case .resource: return "ResourceTint"
        case .goal: return "GoalTint"
        case .aspiration: return "AspirationTint"
        case .daily: return "CalendarTint"
        case .inbox: return "InboxTint"
        case .archive: return "ArchiveTint"
        }
    }

    /// The names the sidebar uses for the same parts (`SidebarSection.symbol`).
    static func markName(for part: SystemSearchEntry.Part) -> String {
        switch part {
        case .project: return "flag"
        case .area: return "circle.grid.2x2"
        case .resource: return "books.vertical"
        case .goal: return "target"
        case .aspiration: return "star"
        case .daily: return "calendar"
        case .inbox: return "tray"
        case .archive: return "archivebox"
        }
    }

    /// The day colour of an asset colour: one picture serves day and night, like an app icon.
    private static func dayColour(_ name: String) -> CGColor {
        let fallback = CGColor(srgbRed: 0.42, green: 0.31, blue: 0.66, alpha: 1)
        #if canImport(UIKit)
        guard let colour = UIColor(named: name) else { return fallback }
        return colour.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor
        #else
        guard let colour = NSColor(named: name) else { return fallback }
        var resolved = fallback
        (NSAppearance(named: .aqua) ?? NSAppearance.currentDrawing()).performAsCurrentDrawingAppearance {
            resolved = colour.usingColorSpace(.sRGB)?.cgColor ?? colour.cgColor
        }
        return resolved
        #endif
    }

    private static func tile(colourName: String, markName: String) -> Data? {
        let side = 180
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let full = CGRect(x: 0, y: 0, width: side, height: side)
        // The marks are drawn on a grid that counts down from the top.
        context.translateBy(x: 0, y: CGFloat(side))
        context.scaleBy(x: 1, y: -1)
        context.addPath(CGPath(roundedRect: full, cornerWidth: CGFloat(side) * 0.225,
                               cornerHeight: CGFloat(side) * 0.225, transform: nil))
        context.setFillColor(dayColour(colourName))
        context.fillPath()

        // The mark at 58 % of the tile, in the middle, with the app's own 1.9 line on its grid.
        let markSide = CGFloat(side) * 0.58
        let scale = markSide / 24
        let ref = Marks.ref(markName)
        context.translateBy(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
        context.rotate(by: ref.rotation * .pi / 180)
        context.translateBy(x: -markSide / 2, y: -markSide / 2)
        context.scaleBy(x: scale, y: scale)
        context.addPath(GridShape(d: Marks.path(markName)).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).cgPath)
        context.setLineWidth(1.9)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.strokePath()

        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
