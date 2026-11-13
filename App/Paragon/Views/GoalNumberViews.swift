import SwiftUI
import ParagonCore

// A goal with a number to track (build 318). The rules — what is stored, the per cent for
// targets that go up or down, the history line — are `GoalNumber` in Core, with tests. This
// file is only how it looks and the two small windows that change it:
//
// - `GoalNumberLine`   the calm bar with "86.5 of 82 kg · 44 %": rows, the review, the page.
// - `GoalNumberCurve`  the small hand-drawn curve of the history, with the target as a dashed line.
// - `GoalNumberPanel`  the goal's own page: line, curve and the **Update…** button.
// - `GoalNumberChip`   the goal's header: **Set a number…**, or **Edit number…** once it has one.
// - `GoalNumberEditor` what both open: one field to update, or the four fields to set it up.

// MARK: - The bar

/// A calm bar: a soft track in the goal's gold and the part that is done, in full gold. Drawn
/// here rather than with `ProgressView` so it is the same 5 points high on the Mac and the
/// phone, and so a goal that is reached can fill to the very end.
struct GoalNumberBar: View {
    let fraction: Double
    var tint: Color = ParaKind.goal.tint
    var width: CGFloat? = nil
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.2))
                Capsule().fill(tint)
                    // Never a sliver thinner than the bar is high: a round end needs that much.
                    .frame(width: fraction <= 0 ? 0 : max(height, geo.size.width * fraction))
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

/// The bar and its words on one line: "86.5 of 82 kg · 44 %". `compact` is the bar alone with
/// the per cent, for a list row.
struct GoalNumberLine: View {
    let number: GoalNumber
    var tint: Color = ParaKind.goal.tint
    var barWidth: CGFloat? = 54
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            GoalNumberBar(fraction: number.barFraction, tint: tint, width: barWidth)
            if compact {
                Text(Self.compactWords(number))
                    .foregroundStyle(.soft)
            } else {
                Text(number.words())
                    .foregroundStyle(.soft)
                if let percent = number.percent {
                    Text("\(percent) %")
                        .foregroundStyle(tint.ink)
                }
            }
        }
        .font(Txt.label)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(number.wordsWithPercent()))
        .accessibilityIdentifier("goal.number.line")
    }

    /// "86.5 kg": the row already says the target in its measure, and has little room.
    private static func compactWords(_ number: GoalNumber) -> String {
        number.valueWords(number.current)
    }
}

// MARK: - The curve

/// The history as one hand-drawn line: round ends, one stroke, a soft fill under it, the
/// target as a dashed line and a dot where he stands now. The points are spaced evenly, one
/// per update. Nothing is drawn for fewer than two points.
struct GoalNumberCurve: View {
    let number: GoalNumber
    var tint: Color = ParaKind.goal.tint
    var height: CGFloat = 44

    var body: some View {
        let values = number.curve
        GeometryReader { geo in
            let points = Self.points(values, target: number.target, in: geo.size)
            let targetY = Self.y(number.target, values: values, target: number.target, height: geo.size.height)
            ZStack {
                Self.area(points, height: geo.size.height)
                    .fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: targetY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: targetY))
                }
                .stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 4]))
                Self.line(points)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                if let last = points.last {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .offset(x: last.x - geo.size.width / 2, y: last.y - geo.size.height / 2)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    /// Where a value sits between the top and the bottom, the dot and the stroke kept inside.
    private static func y(_ value: Double, values: [Double], target: Double, height: CGFloat) -> CGFloat {
        let all = values + [target]
        let low = all.min() ?? 0
        let high = all.max() ?? 1
        let inset: CGFloat = 5
        guard high > low else { return height / 2 }
        let share = (value - low) / (high - low)
        return inset + (height - 2 * inset) * CGFloat(1 - share)
    }

    private static func points(_ values: [Double], target: Double, in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let inset: CGFloat = 4
        let step = (size.width - 2 * inset) / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            CGPoint(x: inset + CGFloat(index) * step, y: y(value, values: values, target: target, height: size.height))
        }
    }

    private static func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private static func area(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = line(points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - The goal's page

/// The number on the goal's own page: the bar with its words, the curve, where it started
/// and when it was last updated, and **Update…**. Draws nothing for a goal without a number —
/// the header's **Set a number…** is where one begins.
struct GoalNumberPanel: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var updating = false

    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let current = live
        if let number = current.goalNumber {
            let tint = ChainTint.forGoal(current)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GoalNumberLine(number: number, tint: tint, barWidth: 160)
                    if number.isReached {
                        Pill(text: "Reached", color: tint)
                    }
                    Spacer(minLength: 6)
                    Button("Update\u{2026}") { updating = true }
                        .buttonStyle(.filled(tint))
                        .controlSize(.small)
                        .accessibilityIdentifier("goal.number.update")
                        .popover(isPresented: $updating) {
                            GoalNumberEditor(number: number, setup: false, tint: tint,
                                             cancel: { updating = false }) { draft in
                                model.updateGoalNumber(draft.current, on: current)
                                updating = false
                            } remove: {}
                        }
                }
                if number.curve.count > 1 {
                    GoalNumberCurve(number: number, tint: tint)
                        .frame(maxWidth: 360)
                }
                Text(Self.caption(number))
                    .font(Txt.listSecond)
                    .foregroundStyle(.soft)
                    .lineLimit(1)
            }
            .accessibilityIdentifier("goal.number.panel")
        }
    }

    /// "From 90 kg · last update 2026-11-13 · 3 updates", built outside the ViewBuilder.
    private static func caption(_ number: GoalNumber) -> String {
        var parts = ["From \(number.valueWords(number.start))"]
        if let last = number.history.last {
            parts.append("last update \(DayWords.plain(last.day))")
        }
        if number.history.count > 1 {
            parts.append("\(number.history.count) updates")
        }
        if number.curve.count < 2 {
            parts.append("press Update\u{2026} when the number changes")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

// MARK: - The header's button

/// In the goal's header beside **Set a measure…**: **Set a number…** while the goal has none,
/// **Edit number…** once it has — start, target, unit, and **Remove**. The day-to-day press,
/// **Update…**, is on the panel just under the header, beside the bar it moves.
struct GoalNumberChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var editing = false

    private var live: Note { model.note(at: note.relativePath) ?? note }

    var body: some View {
        let current = live
        let number = current.goalNumber
        let tint = ChainTint.forGoal(current)
        Button { editing = true } label: {
            MarkLabel(number == nil ? "Set a number\u{2026}" : "Edit number\u{2026}", "ruler")
                .lineLimit(1)
                .foregroundStyle(number == nil ? Theme.soft : tint.ink)
                .helpWhenClosed("A number this goal is tracked by: where you started, where you want to be, and where you are now.", open: editing)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(number == nil ? "Set a number" : "Edit number"))
        .accessibilityIdentifier("goal.number")
        .popover(isPresented: $editing) {
            GoalNumberEditor(number: number, setup: true, tint: tint, cancel: { editing = false }) { draft in
                model.setGoalNumber(draft, on: current)
                editing = false
            } remove: {
                model.removeGoalNumber(from: current)
                editing = false
            }
        }
    }
}

// MARK: - The small window

/// What **Update…**, **Set a number…** and **Edit number…** open. A small popover on the phone
/// too, as the measure's is, hanging near the top of the screen so the keyboard never covers
/// **Save**. **Cancel** and **Save**; Return saves and Escape cancels on the Mac.
///
/// `setup` false is the one-field window: the new value, saved with today's date. `setup`
/// true shows start, target, now and unit, and **Remove** when the goal has a number.
struct GoalNumberEditor: View {
    let number: GoalNumber?
    let setup: Bool
    let tint: Color
    let cancel: () -> Void
    let save: (GoalNumber) -> Void
    let remove: () -> Void

    @State private var start = ""
    @State private var target = ""
    @State private var now = ""
    @State private var unit = ""
    @State private var confirmingRemove = false
    @FocusState private var focus: Field?

    private enum Field { case start, target, now, unit }

    /// What **Save** would store, or nil while a field does not read as a number.
    private var draft: GoalNumber? {
        if setup {
            guard let targetValue = GoalNumber.parse(target) else { return nil }
            // An empty start is 0; an empty "now" is the start. A field with words in it that
            // do not read as a number keeps Save off rather than being taken for 0.
            let startValue: Double? = start.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : GoalNumber.parse(start)
            guard let startValue else { return nil }
            let nowValue: Double? = now.trimmingCharacters(in: .whitespaces).isEmpty ? startValue : GoalNumber.parse(now)
            guard let nowValue else { return nil }
            return GoalNumber(start: startValue, target: targetValue, current: nowValue,
                              unit: GoalNumber.cleanedUnit(unit), history: number?.history ?? [])
        }
        guard var updated = number, let value = GoalNumber.parse(now) else { return nil }
        updated.current = value
        return updated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(setup ? "Number" : "Update the number")
                .font(Txt.label.weight(.semibold))
            Text(sentence)
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
            if setup {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    row("Start", $start, .start, prompt: "0", id: "number.start")
                    row("Target", $target, .target, prompt: "82", id: "number.target")
                    row("Now", $now, .now, prompt: "Same as start", id: "number.now")
                    GridRow {
                        Text("Unit").font(Txt.label).foregroundStyle(.soft)
                        TextField("km, kg, kr, pages", text: $unit)
                            .textFieldStyle(.roundedBorder)
                            .focused($focus, equals: .unit)
                            .onSubmit(commit)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                            .accessibilityIdentifier("number.unit")
                    }
                }
            } else {
                HStack(spacing: 6) {
                    numberField($now, .now, prompt: number.map { GoalNumber.shown($0.current) } ?? "")
                        .accessibilityIdentifier("number.field")
                    if let unit = number?.unit, !unit.isEmpty {
                        Text(unit).font(Txt.value).foregroundStyle(.soft)
                    }
                }
            }
            HStack {
                if setup, number != nil {
                    Button("Remove", role: .destructive) { confirmingRemove = true }
                        .accessibilityIdentifier("number.remove")
                        .confirmationDialog("Remove the number from this goal?", isPresented: $confirmingRemove, titleVisibility: .visible) {
                            Button("Remove the number and its history", role: .destructive, action: remove)
                            Button("Cancel", role: .cancel) {}
                        }
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("number.cancel")
                Button("Save", action: commit)
                    .buttonStyle(.filled(tint))
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft == nil)
                    .accessibilityIdentifier("number.save")
            }
        }
        .padding(14)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        .onAppear(perform: fill)
    }

    private func row(_ label: String, _ text: Binding<String>, _ field: Field, prompt: String, id: String) -> some View {
        GridRow {
            Text(label).font(Txt.label).foregroundStyle(.soft)
            numberField(text, field, prompt: prompt)
                .accessibilityIdentifier(id)
        }
    }

    private func numberField(_ text: Binding<String>, _ field: Field, prompt: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: field)
            .onSubmit(commit)
            #if os(iOS)
            .keyboardType(needsMinus ? .numbersAndPunctuation : .decimalPad)
            #endif
    }

    /// The number pad has no minus sign, so a goal that already holds a number below zero
    /// gets the keyboard that has one.
    private var needsMinus: Bool {
        guard let number else { return false }
        return number.start < 0 || number.target < 0 || number.current < 0
    }

    /// The one sentence under the heading, built outside the ViewBuilder.
    private var sentence: String {
        if setup {
            return "Where you started, where you want to be and where you are now. The target may be lower than the start."
        }
        guard let number else { return "" }
        return "Now \(number.valueWords(number.current)), target \(number.valueWords(number.target)). Saved with today's date, \(DayWords.plain(DateOnly.today()))."
    }

    private func fill() {
        if setup, let number {
            start = GoalNumber.shown(number.start)
            target = GoalNumber.shown(number.target)
            now = GoalNumber.shown(number.current)
            unit = number.unit
        }
        // Focus does not always take in the turn the popover appears (build 119).
        DispatchQueue.main.async { focus = setup ? (number == nil ? .start : .target) : .now }
    }

    private func commit() {
        guard let draft else { return }
        save(draft)
    }
}

// MARK: - Writing

extension AppModel {
    /// A new current value for a goal's number, dated today in its history (build 318). The
    /// rules are `GoalNumber.updating` in Core. Written to the note as it is on file now, so an
    /// edit still waiting in the editor is saved first and never lost.
    @discardableResult
    func updateGoalNumber(_ value: Double, on note: Note) -> Bool {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else { return false }
        return writeGoalNumber(GoalNumber.updating(value, on: live, day: .today()), over: live)
    }

    /// A goal's number set up or changed: start, target, now and unit. The history is the
    /// note's own, never the window's copy.
    @discardableResult
    func setGoalNumber(_ draft: GoalNumber, on note: Note) -> Bool {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else { return false }
        let updated = GoalNumber.setting(start: draft.start, target: draft.target, current: draft.current,
                                         unit: draft.unit, on: live, day: .today())
        return writeGoalNumber(updated, over: live)
    }

    /// The five number lines taken out of the goal.
    @discardableResult
    func removeGoalNumber(from note: Note) -> Bool {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else { return false }
        return writeGoalNumber(GoalNumber.removing(from: live), over: live)
    }

    private func writeGoalNumber(_ updated: Note, over live: Note) -> Bool {
        guard updated != live else { return true }
        guard save(updated) else { return false }
        reload()
        return true
    }
}
