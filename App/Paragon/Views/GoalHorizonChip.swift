import SwiftUI
import ParagonCore

/// How far ahead a goal with a date reaches — **This year** or **Long term** — in the note's
/// header (build 276). It replaces the plain grey label that used to say the same words.
///
/// **A field a screen shows needs the control that changes it** (builds 132, 134, 140, 144, 165,
/// 268). `horizon:` was read by the Goals lists and the review, and written only when the goal
/// was made. Pressing the words now opens two choices with a tick on the one the goal has.
///
/// - **A popover with named rows, not a `Menu`** (build 268): the same shape as the target and
///   measure buttons beside it, known to behave on both platforms, and it can carry a heading
///   that says what is being chosen.
/// - **Dated goals only.** An aspiration is a different thing and lives in the other room, so it
///   has no such button; `NoteHeader` draws this chip for a goal with a date and nothing else,
///   and Core refuses anything else anyway (`Note.settingHorizon`, tested).
/// - **The words come from `GoalHorizon.label`**, the one place they are spelled, so the button,
///   the Goals list and the Map cannot say two things.
/// - The gold is the goal's own (`ChainTint.datedGoal`). The grey it replaced looked like a
///   fact; a button should look like one (build 74).
/// - **One view, two looks** (build 268's `GoalTargetChip`, `CalendarEventRow(compact:)`): a
///   label in a note's header, or a capsule on the Goals screen's own page for the goal. On the
///   Mac that page is what a goal opens as, and the note's header is one press of its **Note**
///   button away, so a button only in the header would be a button he does not meet.
struct GoalHorizonChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    var onChainPage: Bool = false
    @State private var picking = false

    /// Read back out of the model: a chip beside this one may have just saved and reloaded the
    /// note, and the copy handed in is then one behind (build 144).
    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let current: GoalHorizon = live.horizon ?? GoalHorizon.year
        Button { picking = true } label: {
            face(current)
                .helpWhenClosed("How far ahead this goal reaches: this year, or a longer time.",
                                open: picking)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(Self.spoken(current)))
        .accessibilityIdentifier("goal.horizon")
        .popover(isPresented: $picking) {
            choices(current: current)
        }
    }

    @ViewBuilder
    private func face(_ horizon: GoalHorizon) -> some View {
        if onChainPage {
            ChainChip(text: Self.words(horizon), tint: ChainTint.datedGoal, filled: false)
        } else {
            Label(Self.words(horizon), systemImage: "scope")
                .foregroundStyle(ChainTint.datedGoal)
        }
    }

    private func choices(current: GoalHorizon) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How far ahead is this goal?")
                .font(Txt.label.weight(.semibold))
            ForEach(GoalFields.datedHorizons, id: \.rawValue) { option in
                row(option, current: current)
            }
        }
        .padding(14)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
        // A plain Button in a popover takes keyboard focus when it opens, and the Mac rings it
        // in the user's accent colour, which reads as a second selection beside the tick
        // (build 202).
        .focusEffectDisabled()
    }

    private func row(_ option: GoalHorizon, current: GoalHorizon) -> some View {
        Button {
            model.setHorizon(option, on: note)
            picking = false
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: option == current ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(option == current ? ChainTint.datedGoal : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                    Text(Self.explanation(option))
                        .font(Txt.label)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.horizon.\(option.rawValue)")
    }

    /// What the button says: the horizon's own word. A function returning `String` rather than a
    /// `map` with a literal inside a `Label`, which also takes a `LocalizedStringKey`
    /// (build 268: there is no compiler here to settle which one is meant).
    static func words(_ horizon: GoalHorizon) -> String {
        horizon.label
    }

    /// What a screen reader says, and what the screen test reads.
    static func spoken(_ horizon: GoalHorizon) -> String {
        "How far ahead: \(horizon.label)"
    }

    /// The line under each choice, in the years the model has always meant by them.
    static func explanation(_ horizon: GoalHorizon) -> String {
        switch horizon {
        case .year: return "Reached within one or two years."
        case .long: return "Takes three to ten years."
        case .life: return "An aspiration has no date. It is not a choice here."
        }
    }
}
