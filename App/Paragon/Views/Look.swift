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

// MARK: - The steps of a part's colour (build 310)

/// A part's colour has a deep day shade and a bright night shade. These are the few steps of
/// it the app draws; which step goes where is decided once, in Core's `ShadeRule`, and read
/// here. No screen mixes its own.
extension Color {
    private static let stepLock = NSLock()
    private static var stepCache: [Color: (day: Shade, night: Shade, solid: Bool)] = [:]
    private static var derivedCache: [Color: [Int: Color]] = [:]

    private var measured: (day: Shade, night: Shade, solid: Bool) {
        Color.stepLock.lock()
        defer { Color.stepLock.unlock() }
        if let known = Color.stepCache[self] { return known }
        var solid = true
        func shade(_ scheme: ColorScheme) -> Shade {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            let c = resolve(in: environment)
            if c.opacity < 0.99 { solid = false }
            return Shade(red: Double(c.red), green: Double(c.green), blue: Double(c.blue))
        }
        let day = shade(.light), night = shade(.dark)
        let all = (day: day, night: night, solid: solid)
        Color.stepCache[self] = all
        return all
    }

    /// The colour's two shades as numbers, read from its colour set (or whatever it is made of).
    var shades: (day: Shade, night: Shade) {
        let m = measured
        return (m.day, m.night)
    }

    /// One step of this colour, made once and kept: SwiftUI then sees the same colour on
    /// every pass. A see-through colour (Apple's greys) has no steps and is returned as it is.
    private func step(_ which: Int, _ make: ((day: Shade, night: Shade)) -> Color) -> Color {
        let m = measured
        guard m.solid else { return self }
        Color.stepLock.lock()
        defer { Color.stepLock.unlock() }
        if let known = Color.derivedCache[self]?[which] { return known }
        let made = make((m.day, m.night))
        Color.derivedCache[self, default: [:]][which] = made
        return made
    }

    init(_ shade: Shade) {
        self.init(.sRGB, red: shade.red, green: shade.green, blue: shade.blue, opacity: 1)
    }

    init(day: Shade, night: Shade) {
        self.init(day: day.hex, night: night.hex)
    }

    /// **The ground for white words**: a full-colour button, the chosen sidebar row, the band
    /// at night, an icon on a white circle. The deep day shade, the same by day and by night.
    var deep: Color { step(0) { Color(ShadeRule.ground(day: $0.day)) } }

    /// **The colour as words on the page**: a heading, a link, the word Done on a sheet. By
    /// day one step deeper where the day shade is weak on white; the night shade at night.
    var ink: Color { step(1) { Color(day: ShadeRule.ink(day: $0.day), night: $0.night) } }

    /// **Small words in a capsule**: a quarter deeper by day, the night shade at night.
    var capsuleWords: Color { step(2) { Color(day: ShadeRule.capsuleWords(day: $0.day), night: $0.night) } }

    /// **The word on a main button that cannot act yet.**
    var waitingWords: Color { step(3) { Color(day: ShadeRule.waitingWords(day: $0.day), night: $0.night) } }

    /// **The far end of the night band.**
    var bandEnd: Color { step(4) { Color(ShadeRule.bandEnd(ground: ShadeRule.ground(day: $0.day))) } }

    /// **The day band, start and far end** (round 9, build 316): white words read 4.5 to 1 or
    /// better along the whole band.
    var bandDayStart: Color { step(5) { Color(ShadeRule.bandDayStart(day: $0.day)) } }
    var bandDayEnd: Color { step(6) { Color(ShadeRule.bandDayEnd(day: $0.day)) } }
}

/// **Quiet words** (build 310): helper sentences, a row's second line, small labels. The
/// app's own soft grey — #5C6470 by day, #A9B1BC at night — instead of Apple's, which is too
/// pale by day. On a row drawn as the chosen one it steps aside for the row's own ink, as
/// Apple's grey did, so the words stay readable on the selection's fill.
struct SoftInk: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.backgroundProminence == .increased
            ? AnyShapeStyle(HierarchicalShapeStyle.secondary)
            : AnyShapeStyle(Theme.soft)
    }
}

/// **The quietest words that still carry information**: the hours down the side of Plan, the
/// project's name in a task chip, "Nothing planned". #737A86 by day, #8B93A0 at night.
struct FaintInk: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.backgroundProminence == .increased
            ? AnyShapeStyle(HierarchicalShapeStyle.tertiary)
            : AnyShapeStyle(Theme.faint)
    }
}

extension ShapeStyle where Self == SoftInk {
    static var soft: SoftInk { SoftInk() }
}

extension ShapeStyle where Self == FaintInk {
    static var faint: FaintInk { FaintInk() }
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
    /// The one small word under a symbol: the sync ring's word, the Today band's captions.
    static let tiny = Font.system(size: 10)
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
    static let tiny = Font.caption2
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
    /// The quietest words that still carry information (build 310).
    static let faint = Color(day: 0x737A86, night: 0x8B93A0)
    /// The colour of anything that belongs to no part: Browse, Settings, a plain link. Purple,
    /// Today's colour — the home screen's. Its own colour set, FallbackTint.
    static let fallbackTint = Color("FallbackTint")
    /// Hairlines and the night border round a panel.
    static let line = Color(day: 0xE2E6EB, night: 0x2E333A)
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
                .foregroundStyle(color.ink)
            // Build 291: the count is a small capsule in the heading's own colour, not a
            // loose grey number beside it.
            if let count, count > 0 {
                Text("\(count)")
                    .font(Txt.pill.monospacedDigit())
                    // Build 310: the smallest words, a quarter deeper by day.
                    .foregroundStyle(color.capsuleWords)
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
            .foregroundStyle(color.capsuleWords)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

/// The main button of a screen: always full colour, never grey — also on the Mac when its
/// window is behind another, where Apple's own filled button drains to grey (build 310).
///
/// The fill is the part's deep shade with white words, the same by day and by night. While it
/// cannot act yet the fill is pale (40 % by day, 30 % at night) and the word is written in
/// the part's colour, so it can still be read.
struct MainButtonStyle: ButtonStyle {
    let color: Color
    /// True for the one wide button at the foot of a form; false for a button that is as
    /// wide as its word (Save beside Cancel, Set, Add).
    var wide = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let waiting = scheme == .dark ? ShadeRule.waitingFillNight : ShadeRule.waitingFillDay
        configuration.label
            .font(small ? Txt.label.weight(.semibold) : Txt.button)
            .lineLimit(1)
            .foregroundStyle(isEnabled ? Color.white : color.waitingWords)
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, wide ? 0 : small ? 10 : 14)
            .padding(.vertical, wide ? 9 : small ? 3 : tall ? 6 : MainButtonStyle.regularPad)
            .background(isEnabled ? color.deep.opacity(configuration.isPressed ? 0.8 : 1)
                                  : (scheme == .dark ? color : color.deep).opacity(waiting),
                        in: RoundedRectangle(cornerRadius: wide ? Theme.radius : 7))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var small: Bool { controlSize == .small || controlSize == .mini }
    private var tall: Bool { controlSize == .large || controlSize == .extraLarge }
    /// As tall as Apple's own button beside it: Cancel on the Mac is lower than on the iPhone.
    #if os(macOS)
    private static let regularPad: CGFloat = 4
    #else
    private static let regularPad: CGFloat = 6
    #endif
}

extension ButtonStyle where Self == MainButtonStyle {
    /// A full-colour button as wide as its word: `.buttonStyle(.filled(tint))`.
    static func filled(_ color: Color) -> MainButtonStyle { MainButtonStyle(color: color, wide: false) }
    /// The one wide main button of a form.
    static func main(_ color: Color) -> MainButtonStyle { MainButtonStyle(color: color) }
}

/// A panel that wears its part's colour: the surface with a whisper of tint laid over it,
/// 7 % by day and 13 % by night, a 1 pt line round it at night so it keeps an edge.
struct PanelStyle: ViewModifier {
    let tint: Color?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.phoneLook) private var phoneLook

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.panelRadius)
        content
            .padding(Theme.panelPad)
            .background {
                ZStack {
                    shape.fill(Theme.surface)
                    if let tint {
                        shape.fill(tint.opacity(Theme.tintShare(scheme, phone: phoneLook)))
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
                .foregroundStyle(.soft)
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
                .foregroundStyle(tint.ink)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button("Cancel", action: cancel)
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                .accessibilityIdentifier("sheet.cancel")
            if showsAction {
                Button(actionTitle, action: act)
                    .keyboardShortcut(.defaultAction)
                    // Build 310: the app's own filled button. Apple's turns grey whenever
                    // the window is not the front one.
                    .buttonStyle(.filled(tint))
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
                        // Round 9 (build 316): the app's filled button, as on the capture
                        // sheet. It was a coloured word that went grey while it could not act.
                        SheetActionItem(title: actionTitle, tint: tint, canAct: canAct,
                                        identifier: actionIdentifier, act: act)
                    }
                }
        }
        #endif
    }
}

#if os(iOS)
/// The doing button in the bar of an iPhone or iPad edit sheet (round 9, build 316): the
/// app's own filled button in the part's colour, whole, without the round glass iOS 26 draws
/// behind a bar button. The same shape as **Set** on the date sheet (`DateSetItem`).
struct SheetActionItem: ToolbarContent {
    let title: String
    let tint: Color
    let canAct: Bool
    let identifier: String
    let act: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .confirmationAction) { button }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .confirmationAction) { button }
        }
    }

    private var button: some View {
        Button(title, action: act)
            .buttonStyle(.filled(tint))
            .fixedSize()
            .disabled(!canAct)
            .accessibilityIdentifier(identifier)
    }
}
#endif

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
                    if scheme == .dark {
                        // Build 310: at night the band is the deep day shade, running to
                        // 80 % of itself over black — rich, and white words read on it. It
                        // used to be the bright night shade dimmed with black: dusty.
                        LinearGradient(colors: [color.deep, color.bandEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        // Round 9 (build 316): by day the band runs to a darker end. It
                        // used to fade to 80 % over white, too pale for the white words.
                        LinearGradient(colors: [color.bandDayStart, color.bandDayEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
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
                // Round 9 (build 316): full white; at 85 % the small words were under 4.5 to 1.
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - The iPhone's page, cards and band (review round 4)

extension Theme {
    /// How much of a part's colour lies over a panel or a card: 7 % by day, 13 % at night.
    /// On the iPhone 12 % by day since round 9 (build 316): Core's `ShadeRule.tintShare`.
    static func tintShare(_ scheme: ColorScheme, phone: Bool = false) -> Double {
        ShadeRule.tintShare(night: scheme == .dark, phone: phone)
    }
}

private struct PhoneLookKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside the iPhone layout (`PhoneRootView` and the sheets over it), false on the
    /// Mac and in the iPad's columns. Set once, in `ContentView`. Not the size class: a
    /// column of the iPad's split view is "compact" too.
    var phoneLook: Bool {
        get { self[PhoneLookKey.self] }
        set { self[PhoneLookKey.self] = newValue }
    }
}

#if os(iOS)
/// **An iPhone card**: the surface with the part's colour over it, 7 % by day and 13 % at
/// night — a panel's fill, as a list row's background. Outside the iPhone layout it is
/// Apple's own card, so the iPad is as it was.
struct PhoneCardFill: View {
    let tint: Color?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.phoneLook) private var phoneLook

    var body: some View {
        if phoneLook {
            ZStack {
                Theme.surface
                // Only drawn inside the iPhone layout, so the iPhone's share.
                if let tint { tint.opacity(Theme.tintShare(scheme, phone: true)) }
            }
        } else {
            Color(UIColor.secondarySystemGroupedBackground)
        }
    }
}

private struct PhoneCard: ViewModifier {
    let tint: Color?
    @Environment(\.phoneLook) private var phoneLook

    func body(content: Content) -> some View {
        content.listRowBackground(phoneLook ? PhoneCardFill(tint: tint) : nil)
    }
}

private struct PhonePage: ViewModifier {
    @Environment(\.phoneLook) private var phoneLook

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(phoneLook ? .hidden : .automatic)
            .background(phoneLook ? Theme.canvas : Color.clear)
    }
}

/// **The slim band every iPhone list screen opens with**: one row in the part's colour, the
/// screen's one fact — a count or the date — in white. The same band Today draws.
struct PhoneBand: View {
    let tint: Color
    let text: String

    var body: some View {
        Text(text)
            .font(Txt.label)
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .accessibilityIdentifier("phone.band")
            .band(tint, vertical: 6)
    }
}
#endif

extension View {
    /// The iPhone's page: `Theme.canvas` behind a list or a scrolling screen, in place of
    /// Apple's grouped grey. Nothing on the Mac or the iPad.
    func phonePage() -> some View {
        #if os(iOS)
        modifier(PhonePage())
        #else
        self
        #endif
    }

    /// The iPhone's cards: on the content of a `List` (a `Group`, a `Section`, a row), gives
    /// each row the surface with the part's colour over it. Nothing on the Mac or the iPad.
    func phoneCard(_ tint: Color?) -> some View {
        #if os(iOS)
        modifier(PhoneCard(tint: tint))
        #else
        self
        #endif
    }
}
