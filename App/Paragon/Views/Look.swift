import SwiftUI
import ParagonCore
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// The look of 1.0 (build 280): one type scale, one colour system, the pieces every screen
// shares. Martin's choice on 6 November 2026 was look B — "coloured panels with meaning" —
// from a picture of three; the standard copied is his Subscriptions app after its 1.0
// redesign. The written specification is Docs/Look.md. Nothing here changes what a screen
// does; it decides how a screen looks.

extension Color {
    /// One colour for day, another for night, decided in one place.
    init(day: UInt32, night: UInt32) {
        func rgb(_ v: UInt32) -> (Double, Double, Double) {
            (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        }
        let d = rgb(day), n = rgb(night)
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: n.0, green: n.1, blue: n.2, alpha: 1)
            : UIColor(red: d.0, green: d.1, blue: d.2, alpha: 1) })
        #else
        self.init(nsColor: NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(red: n.0, green: n.1, blue: n.2, alpha: 1)
                : NSColor(red: d.0, green: d.1, blue: d.2, alpha: 1) })
        #endif
    }
}

/// **The one type scale.** Every `.font(…)` in the app reads one of these; no screen chooses
/// its own size (a test in Core reads the sources and fails on one that does).
///
/// On the Mac the sizes are fixed points — Apple's text styles are small there (body is 13)
/// and his brief names the numbers: page title 26 bold, a section heading 17 semibold in its
/// part's colour, text and values 15, small labels 12, and Apple's own 13 / 11 for lists, the
/// sidebar and menus. On the iPhone each name is one of Apple's text styles, so everything
/// grows with the text size he sets in Settings.
/// Each device shows only its own words (round 3): "Tap" and "Hold" on the iPhone and the
/// iPad, "Click" and "Right-click" on the Mac. Never both in one sentence.
enum DeviceWords {
    #if os(macOS)
    static let click = "Click"
    static let clickSmall = "click"
    static let holdARow = "Right-click a row"
    static let holdSmall = "right-click"
    /// True where a row is held (iPhone and iPad), false where it is right-clicked (Mac).
    static let holds = false
    static let systemSettings = "System Settings"
    #else
    static let holds = true
    static let systemSettings = "Settings"
    static let click = "Tap"
    static let clickSmall = "tap"
    static let holdARow = "Hold a row"
    static let holdSmall = "hold"
    #endif
}

enum Txt {
    #if os(macOS)
    /// The open note's title, or the title of a whole-column screen.
    static let pageTitle = Font.system(size: 26, weight: .bold)
    /// The one big number on a screen's band (build 282).
    static let bandNumber = Font.system(size: 34, weight: .bold)
    /// A panel's or section's heading, always in the part's colour.
    static let sectionTitle = Font.system(size: 17, weight: .semibold)
    /// Note text, task titles in a note, facts, fields, the words inside a panel.
    static let value = Font.system(size: 15)
    /// The small word beside or above a value, in `Theme.soft`.
    static let label = Font.system(size: 12)
    /// Apple's own list size: sidebar rows, the middle column, menus, pop-ups.
    static let list = Font.system(size: 13)
    /// A row's title: Apple's list size, a step heavier.
    static let listTitle = Font.system(size: 13, weight: .semibold)
    /// The row's one quiet second line, and badges.
    static let listSecond = Font.system(size: 11)
    /// The words on a main button.
    static let button = Font.system(size: 13, weight: .semibold)
    /// Code and the settings block.
    static let mono = Font.system(size: 14, design: .monospaced)
    /// A small coloured capsule: a status, a count, a fact.
    static let pill = Font.system(size: 11, weight: .medium)
    /// The sizes the note editor draws with (NSAttributedString wants numbers, not Fonts).
    enum Editor {
        static let text: CGFloat = 15
        static let h1: CGFloat = 22
        static let h2: CGFloat = 18
        static let h3: CGFloat = 15
        static let code: CGFloat = 14
        static let lineSpacing: CGFloat = 6
        static let paragraphSpacing: CGFloat = 8
    }
    #else
    static let pageTitle = Font.largeTitle.weight(.bold)
    static let bandNumber = Font.largeTitle.weight(.bold)
    static let sectionTitle = Font.headline
    static let value = Font.body
    static let label = Font.footnote
    static let list = Font.body
    static let listTitle = Font.body.weight(.semibold)
    static let listSecond = Font.footnote
    static let button = Font.body.weight(.semibold)
    static let mono = Font.system(.body, design: .monospaced)
    static let pill = Font.caption.weight(.medium)
    enum Editor {
        static var text: CGFloat { UIFont.preferredFont(forTextStyle: .body).pointSize }
        static var h1: CGFloat { UIFont.preferredFont(forTextStyle: .title2).pointSize }
        static var h2: CGFloat { UIFont.preferredFont(forTextStyle: .title3).pointSize }
        static var h3: CGFloat { UIFont.preferredFont(forTextStyle: .headline).pointSize }
        static var code: CGFloat { UIFont.preferredFont(forTextStyle: .callout).pointSize }
        static let lineSpacing: CGFloat = 5
        static let paragraphSpacing: CGFloat = 8
    }
    #endif

    /// The Map draws at a zoom of its own; its box titles and labels scale with it, from
    /// Apple's list sizes. Nothing on the Map is drawn under 11 points at zoom 1.
    static func mapTitle(_ zoom: CGFloat) -> Font { .system(size: 12.5 * zoom, weight: .semibold) }
    static func mapLabel(_ zoom: CGFloat) -> Font { .system(size: 11 * zoom) }
}

extension Theme {
    /// A panel: white by day, a step lighter than the page by night.
    static let surface = Color(day: 0xFFFFFF, night: 0x1E2228)
    /// The page behind the panels.
    static let canvas = Color(day: 0xF3F5F8, night: 0x15181C)
    /// Text that is quieter than the main text and still easy to read.
    static let soft = Color(day: 0x5C6470, night: 0xA9B1BC)
    /// Hairlines and the night border round a panel.
    static let line = Color(day: 0xE2E6EB, night: 0x2E333A)
    /// Words on a full-colour button: white, except on the bright night golds and oranges.
    static let onDark = Color(day: 0xFFFFFF, night: 0x2B2200)
    /// "Look at this" — orange, never red (build 182's rule).
    static let attention = Color(day: 0xD4640A, night: 0xFFA23A)

    /// Note text stops here and sits centred; the extra space on a wide window is calm margin.
    static let readingWidth: CGFloat = 680
    /// Inside a tinted panel.
    static let panelPad: CGFloat = 12
    /// Between panels.
    static let panelGap: CGFloat = 12
    /// Between the sections of a page.
    static let sectionGap: CGFloat = 20
    /// A heading to its first line.
    static let headGap: CGFloat = 6
    /// A panel's corner.
    static let panelRadius: CGFloat = 10
}

/// A section heading in the part's own colour, with an optional quiet count after it.
struct Heading: View {
    let text: String
    let color: Color
    var count: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text)
                .font(Txt.sectionTitle)
                .foregroundStyle(color)
            // Build 291: the count is a small capsule in the heading's own colour, not a
            // loose grey number beside it.
            if let count, count > 0 {
                Text("\(count)")
                    .font(Txt.pill.monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.14), in: Capsule())
                    .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] + 1 }
            }
        }
        .lineLimit(1)
    }
}

/// A small coloured capsule for a fact that cannot be changed from here: a status, a count,
/// a horizon. One shape for all of them.
struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(Txt.pill)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

/// The main button of a screen: always full colour, never grey. When it cannot act it is the
/// same colour at 40 %.
struct MainButtonStyle: ButtonStyle {
    let color: Color
    var text: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Txt.button)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

/// A panel that wears its part's colour: the surface with a whisper of tint laid over it,
/// 7 % by day and 13 % by night, a 1 pt line round it at night so it keeps an edge.
struct PanelStyle: ViewModifier {
    let tint: Color?
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.panelRadius)
        content
            .padding(Theme.panelPad)
            .background {
                ZStack {
                    shape.fill(Theme.surface)
                    if let tint {
                        shape.fill(tint.opacity(scheme == .dark ? 0.13 : 0.07))
                    }
                    if scheme == .dark {
                        shape.strokeBorder(Theme.line, lineWidth: 1)
                    }
                }
            }
    }
}

/// Keeps a column of text at the reading width, centred.
struct ReadingWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Theme.readingWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Draws this content as a panel in the part's colour (nil: a plain white panel).
    func panel(_ tint: Color?) -> some View { modifier(PanelStyle(tint: tint)) }
    /// Note text and the panels above it stop at `Theme.readingWidth` and sit centred.
    func readingWidth() -> some View { modifier(ReadingWidth()) }
}

/// What a screen shows when there is nothing in it: the part's icon, quiet, and one calm
/// line. No headline, no paragraph, no button — the way in is in the toolbar already.
struct CalmEmptyView: View {
    let text: String
    let tint: Color
    /// The icon above the line; drawn by the caller so this file does not decide icons.
    var icon: AnyView? = nil

    var body: some View {
        VStack(spacing: 10) {
            if let icon {
                icon
                    .frame(width: 28, height: 28)
                    .foregroundStyle(tint.opacity(0.6))
            }
            Text(text)
                .font(Txt.value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The bar at the top of an edit sheet: the sheet's title in its part's colour, and **Cancel**
/// and the doing button side by side at the right. His brief: Cancel and Save at the top
/// right on the Mac, Save filled in the part's colour; Escape is Cancel, ⌘S is Save.
///
/// The Mac only. On the iPhone a sheet puts Cancel on the left and Save on the right of its
/// navigation bar (`sheetChrome` below does both).
struct SheetBar: View {
    let title: String
    let tint: Color
    let actionTitle: String
    var canAct = true
    /// What the screen tests call the doing button; the Quick capture sheet keeps its old name.
    var actionIdentifier = "sheet.action"
    /// False when the content carries its own doing button (the capture inside New note).
    var showsAction = true
    let cancel: () -> Void
    let act: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Txt.sectionTitle)
                .foregroundStyle(tint)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button("Cancel", action: cancel)
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                .accessibilityIdentifier("sheet.cancel")
            if showsAction {
                Button(actionTitle, action: act)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .controlSize(.large)
                    .disabled(!canAct)
                    .accessibilityIdentifier(actionIdentifier)
                // ⌘S saves too. A button carries one shortcut, so the second lives on a button
                // that takes no space; it is still a button, so the key reaches it.
                Button("Save", action: act)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!canAct)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// One shape for every edit sheet: on the Mac a `SheetBar` above the content and a hairline
/// under it; on the iPhone a navigation bar with Cancel on the left and the doing button on
/// the right, in the part's colour. The content is the caller's form.
struct SheetChrome: ViewModifier {
    let title: String
    let tint: Color
    let actionTitle: String
    var canAct = true
    var actionIdentifier = "sheet.action"
    var showsAction = true
    let cancel: () -> Void
    let act: () -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        VStack(spacing: 0) {
            SheetBar(title: title, tint: tint, actionTitle: actionTitle, canAct: canAct,
                     actionIdentifier: actionIdentifier, showsAction: showsAction, cancel: cancel, act: act)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            Divider()
            content
        }
        #else
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                            .accessibilityIdentifier("sheet.cancel")
                    }
                    if showsAction {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(actionTitle, action: act)
                                .fontWeight(.semibold)
                                .tint(tint)
                                .disabled(!canAct)
                                .accessibilityIdentifier(actionIdentifier)
                        }
                    }
                }
        }
        #endif
    }
}

extension View {
    /// Gives an edit sheet its Cancel and doing button, the keys that drive them, and its title.
    func sheetChrome(title: String, tint: Color, actionTitle: String, canAct: Bool = true,
                     actionIdentifier: String = "sheet.action", showsAction: Bool = true,
                     cancel: @escaping () -> Void, act: @escaping () -> Void) -> some View {
        modifier(SheetChrome(title: title, tint: tint, actionTitle: actionTitle, canAct: canAct,
                             actionIdentifier: actionIdentifier, showsAction: showsAction,
                             cancel: cancel, act: act))
    }
}

/// A view's height, reported upwards so a parent can size a scroll view to its content
/// (the Search boxes, the note column on a short window).
struct MeasuredHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    /// Writes this view's laid-out height into `height` whenever it changes.
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        background(GeometryReader { geo in
            Color.clear.preference(key: MeasuredHeight.self, value: geo.size.height)
        })
        .onPreferenceChange(MeasuredHeight.self) { value in
            if height.wrappedValue != value { height.wrappedValue = value }
        }
    }
}

/// The version as he reads it: "1.0 (280)".
enum AppVersion {
    static var text: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "\(short) (\(BuildStamp.number))"
    }
}

// MARK: - The band (build 282)

/// **Colour at the top** — look A, his pick on 9 November 2026. A screen opens with a band in
/// its part's colour: a soft gradient, the title in white, small white words and one big
/// number. Everything under the band is build 280. Docs/Look.md §15.
struct BandStyle: ViewModifier {
    let color: Color
    /// The space left and right of the words.
    var inset: CGFloat = Theme.gutter + 6
    /// 0 where the band runs edge to edge; a panel's corner where it sits inside a page's gutter.
    var radius: CGFloat = 0
    /// Space above and below the words; Today's one-row band uses less (build 304).
    var vertical: CGFloat = 10
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, inset)
            .padding(.vertical, vertical)
            .background {
                ZStack {
                    // The night shades are bright, and white words need a darker ground.
                    scheme == .dark ? Color.black : Color.white
                    LinearGradient(colors: [color, color.opacity(0.8)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    if scheme == .dark { Color.black.opacity(0.3) }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            }
    }
}

extension View {
    func band(_ color: Color, inset: CGFloat = Theme.gutter + 6, radius: CGFloat = 0,
              vertical: CGFloat = 10) -> some View {
        modifier(BandStyle(color: color, inset: inset, radius: radius, vertical: vertical))
    }
}

/// The band's big number with its few small words: "3 due today", "40 % of the way".
struct BandNumber: View {
    let number: String
    let words: String
    var identifier = "band.number"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number)
                .font(Txt.bandNumber)
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(words)
                .font(Txt.label)
                .foregroundStyle(.white.opacity(0.85))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
