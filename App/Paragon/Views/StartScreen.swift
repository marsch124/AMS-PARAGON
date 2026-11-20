import SwiftUI
import ParagonCore

/// **The start screen** (build 329, his pick on 2026-11-16: look 3, "Only when I tap"). One calm
/// page in the app icon's look at every fresh start: the slate ground, the white drawing, the
/// name, the day and what is waiting. It stays until he taps it, and it never shows when he was
/// sent somewhere by name (`StartScreenRule`, Core, tested).
///
/// The same by day and by night, like the icon itself: the colours here are the icon's own
/// (`Tools/make_icon.py`), not a part's tint.
struct StartScreen: View {
    @EnvironmentObject private var model: AppModel
    #if os(macOS)
    @FocusState private var hasKeys: Bool
    #endif

    /// The icon's flat ground, #262D32.
    static let slate = Color(red: 38 / 255, green: 45 / 255, blue: 50 / 255)
    private static let quiet = Color(red: 190 / 255, green: 198 / 255, blue: 204 / 255)

    /// Only once the notes are open: before that the numbers would be two wrong zeros.
    private var opened: Bool { model.vault != nil }

    var body: some View {
        ZStack {
            Self.slate.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                IconDrawing(size: 132)
                    .padding(.bottom, 22)
                Text("PARAGON")
                    .font(Txt.bandNumber)
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 14)
                // Build 346, his picture: the weekday and the date each on their own line.
                Text(StartScreenRule.weekdayLine(.today()))
                    .font(Txt.sectionTitle)
                    .foregroundStyle(Color.white)
                Text(StartScreenRule.dateLine(.today()))
                    .font(Txt.value.monospacedDigit())
                    .foregroundStyle(Self.quiet)
                    .padding(.bottom, 18)
                // What is waiting, one thing per line with its mark: the calendar for what is
                // due, the Inbox's tray for the Inbox. The two marks stand one above the other
                // and the words start at one place. The lines keep their place while the notes
                // open, so nothing jumps when they fill.
                VStack(alignment: .leading, spacing: 8) {
                    waitingRow("calendar", opened ? StartScreenRule.dueLine(model.sidebarCounts.dueByToday) : " ")
                        .accessibilityIdentifier("start.due")
                    waitingRow("tray", opened ? StartScreenRule.inboxLine(model.count(for: .inbox)) : " ")
                        .accessibilityIdentifier("start.inbox")
                }
                .opacity(opened ? 1 : 0)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("start.waiting")
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                // Build 346, his picture: no "Tap to start" and no version line. A tap or a
                // key anywhere still starts, as before; the version stays in Settings › About.
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.leaveStartScreen() }
        #if os(macOS)
        // Any key, as the hint says. The page takes the keys while it is up.
        .focusable()
        .focusEffectDisabled()
        .focused($hasKeys)
        .onKeyPress { _ in
            model.leaveStartScreen()
            return .handled
        }
        .onAppear { hasKeys = true }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("start.screen")
    }

    private func waitingRow(_ mark: String, _ words: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            MarkImage(mark, size: 18)
                .foregroundStyle(Color.white)
                .centredOnFirstLine()
            Text(words)
                .font(Txt.value)
                .foregroundStyle(Self.quiet)
        }
    }
}

/// The app icon's drawing — a tick and three squares, the four PARA boxes with the first one
/// done — as a line, on the icon library's 24-point grid with its one 1.9 stroke and round
/// ends. The numbers are `Tools/make_icon.py`'s, so this is the icon and not a look-alike.
struct IconDrawing: View {
    var size: CGFloat
    var colour: Color = .white

    var body: some View {
        IconDrawingShape()
            .stroke(colour, style: StrokeStyle(lineWidth: 1.9 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct IconDrawingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        // Lifted 0.4 of a grid point, as in the icon: the ink's middle is 12.4, not 12.
        let ox = rect.midX - 12 * k, oy = rect.midY - 12.4 * k
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * k, y: oy + y * k) }
        var path = Path()
        path.move(to: point(4.8, 8.6))
        path.addLine(to: point(7.0, 10.9))
        path.addLine(to: point(11.0, 6.1))
        for (x, y) in [(13.6, 4.6), (4.2, 14.0), (13.6, 14.0)] as [(CGFloat, CGFloat)] {
            let corner = point(x, y)
            path.addRoundedRect(in: CGRect(x: corner.x, y: corner.y, width: 6.2 * k, height: 6.2 * k),
                                cornerSize: CGSize(width: 1.5 * k, height: 1.5 * k))
        }
        return path
    }
}

/// The icon as a small tile, for the welcome page: the slate ground with the white drawing.
struct AppIconTile: View {
    var side: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
            .fill(StartScreen.slate)
            .frame(width: side, height: side)
            .overlay { IconDrawing(size: side * 0.62) }
            .accessibilityHidden(true)
    }
}
