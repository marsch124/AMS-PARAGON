import SwiftUI
import ParagonCore

/// Build 332: **One thing** — a calm page with only the one next task.
///
/// Every other screen of the app is a list, and a list asks him to choose. The advisors'
/// round (16 Nov 2026, mindfulness point 2) found that nothing ever shows just the one next
/// thing; the focus bar does, but only after he chose. This page chooses for him
/// (`OneNextThing`: overdue, the one longest ago first; then due today by time; then Today's
/// own next actions) and shows that one task and nothing else.
///
/// His pick from the picture (17 Nov 2026, option 3): a page of its own, opened by a fourth
/// small button **One** on Today's band. Not on the start screen — he said no to that.
///
/// Three answers: **Done** ticks it and the next one comes; **Not now** sets it aside for
/// today (on this device only, nothing is written into a note) and the next one comes;
/// **Start focus** starts the focus timer on it and closes the page. **Close** (Escape on
/// the Mac) leaves everything as it is.
struct OneThingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    static let symbol = "one.thing"
    private var tint: Color { SidebarSection.today.tint }

    var body: some View {
        let queue = model.oneThingQueue
        VStack(spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .quietSheetButton()
                    .accessibilityIdentifier("one.close")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer(minLength: 16)
            Text("One thing")
                .font(Txt.sectionTitle)
                .foregroundStyle(tint.ink)
                .accessibilityIdentifier("one.heading")
            if let pick = queue.first {
                task(pick, more: queue.count - 1)
            } else {
                nothing
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(0.07))
        .tint(tint)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 440, idealHeight: 480)
        #endif
    }

    @ViewBuilder
    private func task(_ pick: OneNextThing.Pick, more: Int) -> some View {
        let ref = pick.ref
        Text(Note.removingTag(Note.nextActionTag, from: ref.task.title))
            .font(Txt.pageTitle)
            .multilineTextAlignment(.center)
            .lineLimit(5)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .accessibilityIdentifier("one.title")
        Text("\(OneNextThing.words(for: pick, today: .today())) · \(ref.noteTitle)")
            .font(Txt.label)
            .foregroundStyle(.soft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .accessibilityIdentifier("one.why")

        VStack(spacing: 8) {
            Button("Done") {
                withAnimation(Motion.settle) { model.toggle(ref) }
            }
            .buttonStyle(.main(tint))
            .accessibilityIdentifier("one.done")
            Button("Not now") {
                withAnimation(Motion.settle) { model.setAsideOneThing(ref) }
            }
            .buttonStyle(OutlineButtonStyle(color: tint))
            .accessibilityIdentifier("one.notNow")
            if model.canFocus(on: ref) {
                Button("Start focus") {
                    model.activeSheet = nil
                    model.startFocus(on: ref)
                }
                .buttonStyle(OutlineButtonStyle(color: tint))
                .accessibilityIdentifier("one.focus")
            }
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 24)
        .padding(.top, 28)

        Text(more == 0 ? "The last one for now" : more == 1 ? "1 more after this" : "\(more) more after this")
            .font(Txt.tiny)
            .foregroundStyle(.soft)
            .padding(.top, 18)
            .accessibilityIdentifier("one.more")
    }

    @ViewBuilder
    private var nothing: some View {
        let aside = model.oneThingAside.count
        Text("Nothing for now.")
            .font(Txt.pageTitle)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .accessibilityIdentifier("one.nothing")
        Text(aside == 0 ? "Nothing is overdue, nothing is due today, and no project has a next action waiting."
                        : aside == 1 ? "You set 1 task aside for today." : "You set \(aside) tasks aside for today.")
            .font(Txt.label)
            .foregroundStyle(.soft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .accessibilityIdentifier("one.nothing.why")
        VStack(spacing: 8) {
            Button("Close") { dismiss() }
                .buttonStyle(.main(tint))
                .accessibilityIdentifier("one.nothing.close")
            if aside > 0 {
                Button(aside == 1 ? "Show it again" : "Show them again") {
                    withAnimation(Motion.settle) { model.clearOneThingAside() }
                }
                .buttonStyle(OutlineButtonStyle(color: tint))
                .accessibilityIdentifier("one.again")
            }
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }
}

/// The second and third button of the page: as wide as the main button above them, drawn as
/// an outline in the part's colour so that the main button stays the only full one.
private struct OutlineButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius)
        configuration.label
            .font(Txt.button)
            .lineLimit(1)
            .foregroundStyle(color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(configuration.isPressed ? 0.14 : 0), in: shape)
            .overlay(shape.strokeBorder(color.opacity(0.45), lineWidth: 1))
            .contentShape(shape)
    }
}
