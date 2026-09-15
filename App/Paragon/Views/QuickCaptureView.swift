import SwiftUI
import ParagonCore

/// The capture panel used by the menu bar item, the in-app sheet (⇧⌘N), the phone's Capture tab
/// and the share extension.
///
/// **Build 158 gave the phone its own layout.** The old one had a fixed `.frame(width: 460)` on
/// a screen about 390 points wide, so **Save** hung off the right edge; the placeholder was a
/// line of syntax cut off at "for a" (the same fault build 142 fixed on the add-a-task bar);
/// the writing area was two lines with a large empty space under it; and the kind was a switch
/// labelled **As note, not task**, which is a double negative.
///
/// He chose the shape from a preview of three
/// (https://claude.ai/code/artifact/8e6a6105-6865-4fcd-a86e-e25c84733e49): **the one that shows
/// what it understood**. The words fill the sheet, and under them dashed chips read the line
/// back — a date, a priority, tags — with buttons that write the syntax for him. The read-back
/// comes from `CaptureReading`, which runs the **task parser itself** over the line the capture
/// will write, so a chip can never say one thing while the vault stores another.
struct QuickCaptureView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPhone: Bool { sizeClass == .compact }
    #else
    private var isPhone: Bool { false }
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var compact = false
    /// Drawn inside another sheet, which already carries the heading and sets the width.
    /// The New note sheet (build 185) passes this so its **Capture** button gives the very
    /// same screen the menu bar item and ⇧⌘N give - never a second capture screen
    /// that could answer differently.
    var embedded = false
    var onSaved: (() -> Void)? = nil

    @State private var text = ""
    @State private var target: CaptureTarget = .inbox
    @State private var asNote = false
    @State private var confirmation: String?
    @State private var showingSyntax = false
    @State private var pickingDate = false
    /// Drives the little flight into the tray. One of his four extras.
    @State private var flying = false
    /// Chosen once when the sheet appears, so the greeting does not change under his hands.
    @State private var greeting = QuickCaptureView.greetings[0]
    @FocusState private var focused: Bool

    private var reading: CaptureReading { CaptureReading(line: text) }
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    /// One of his extras: the empty field says hello. Picked on appear, never mid-typing.
    static let greetings = [
        "What's on your mind?",
        "Anything to write down?",
        "Write it down before it goes.",
        "What needs to be somewhere safe?",
    ]

    var body: some View {
        Group {
            if isPhone { phoneBody } else { deskBody }
        }
        .onAppear {
            focused = true
            greeting = Self.greetings.randomElement() ?? Self.greetings[0]
        }
        .popover(isPresented: $showingSyntax) { CaptureSyntaxHelp() }
        .sheet(isPresented: $pickingDate) {
            DateChoiceView(current: reading.dueDate, cancel: { pickingDate = false }) { picked in
                if let picked { insert(">\(picked)") }
                pickingDate = false
            }
        }
    }

    // MARK: The phone

    private var phoneBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            // The words get the room. Everything that was empty space under the old two-line
            // field is writing space now.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(greeting)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(6)
            .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            readBack
            addRow
            intoRow
            asRow
            Spacer(minLength: 0)
            caughtToday
            saveBar
        }
        .padding(embedded ? 0 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) { flight }
    }

    // MARK: The Mac, unchanged in shape

    private var deskBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            TextField(greeting, text: $text, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
            readBack
            addRow
            HStack {
                Picker("Save to", selection: $target) {
                    ForEach(model.captureTargets, id: \.self) { t in
                        Text(model.captureTargetLabel(t)).tag(t)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                asRow
                Spacer()
                if !compact {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            caughtToday
            if model.vault == nil {
                Text("No vault is open. Captures are kept and filed the next time the app opens a vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(embedded ? 0 : (compact ? 12 : 20))
        .frame(width: deskWidth)
    }

    /// Nil while embedded: the sheet around it sets the width. Written out rather than a
    /// ternary, so there is nothing for inference to settle about a `CGFloat?`.
    private var deskWidth: CGFloat? {
        if embedded { return nil }
        return compact ? 380 : 460
    }

    // MARK: The pieces both share

    private var header: some View {
        HStack(spacing: 8) {
            if !embedded {
                Label("Quick capture", systemImage: "tray.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(SidebarSection.inbox.tint)
            }
            Spacer()
            if let confirmation {
                Text(confirmation)
                    .font(.caption)
                    .foregroundStyle(SidebarSection.inbox.tint)
                    .transition(.opacity)
            }
            Button {
                showingSyntax = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("What you can write in a capture")
        }
    }

    /// The line read back. Dashed, because these are not buttons — they are what the app heard.
    @ViewBuilder
    private var readBack: some View {
        if !reading.isPlain {
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                if let due = dueChipTitle {
                    ReadChip(title: due, systemImage: "calendar", tint: SidebarSection.calendar.tint)
                }
                if let marks = reading.priorityMarks {
                    ReadChip(title: "Priority \(marks)", systemImage: "exclamationmark",
                             tint: ParaKind.area.tint)
                }
                ForEach(reading.tags, id: \.self) { tag in
                    ReadChip(title: "#\(tag)", systemImage: "number", tint: SidebarSection.tags.tint)
                }
            }
            .lineLimit(1)
        }
    }

    /// "Due today", "Due tomorrow", or "Due 15 September". Built outside the ViewBuilder.
    private var dueChipTitle: String? {
        guard let dueDate = reading.dueDate else { return nil }
        switch reading.nearness(to: .today()) {
        case .today?: return "Due today"
        case .tomorrow?: return "Due tomorrow"
        case .yesterday?: return "Was due yesterday"
        default: break
        }
        guard let date = dueDate.date() else { return "Due \(dueDate)" }
        return "Due " + QuickCaptureView.dayAndMonth.string(from: date)
    }

    private static let dayAndMonth: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()

    /// The buttons that write the syntax for him, so it never has to be remembered.
    private var addRow: some View {
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            AddChip(title: "Today") { insert(">\(DateOnly.today())") }
            AddChip(title: "Tomorrow") { insert(">\(DateOnly.today().adding(days: 1, calendar: WeekRef.calendar))") }
            AddChip(title: "Date\u{2026}") { pickingDate = true }
            AddChip(title: "!") { insert("!") }
            AddChip(title: "!!") { insert("!!") }
            CaptureTagsChip(model: model, tags: tagChoice)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var intoRow: some View {
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            ForEach(model.captureTargets.prefix(6), id: \.self) { t in
                PickChip(title: model.captureTargetLabel(t),
                         isOn: t == target,
                         tint: SidebarSection.inbox.tint) { target = t }
            }
        }
        .lineLimit(1)
    }

    /// Two words, never "As note, not task". A double negative on a switch said nothing about
    /// which way was which.
    private var asRow: some View {
        HStack(spacing: 6) {
            PickChip(title: "A task", isOn: !asNote, tint: ParaKind.project.tint) { asNote = false }
            PickChip(title: "A note", isOn: asNote, tint: ParaKind.resource.tint) { asNote = true }
        }
    }

    /// One of his extras, and it earns its place: it is also how you know the Inbox needs sorting.
    @ViewBuilder
    private var caughtToday: some View {
        if model.caughtToday > 0 {
            Text(model.caughtToday == 1 ? "1 saved today." : "\(model.caughtToday) saved today.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            if !compact {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Button(action: save) {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(canSave ? SidebarSection.inbox.tint : Color.secondary.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 11))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    /// The words flying into the tray. Half a second, and Reduce Motion turns it off.
    @ViewBuilder
    private var flight: some View {
        if flying && !reduceMotion {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.title)
                .foregroundStyle(SidebarSection.inbox.tint)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    // MARK: Doing it

    /// The tags on this capture, read out of the line and written back into it. There is no
    /// separate list to keep in step: `CaptureReading` reads the very line the capture will
    /// write, so the chips, the picker and the vault cannot disagree.
    private var tagChoice: Binding<[String]> {
        Binding(get: { reading.tags },
                set: { text = CaptureReading.line(text, settingTags: $0) })
    }

    /// Puts a marker at the end of what he has written, with one space in front of it.
    private func insert(_ marker: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        text = trimmed.isEmpty ? marker : trimmed + " " + marker
        focused = true
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.capture(text: trimmed, target: target, asTask: !asNote)
        text = ""
        withAnimation(.easeOut(duration: 0.2)) {
            confirmation = model.lastCaptureMessage ?? "Saved"
            flying = true
        }
        onSaved?()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeIn(duration: 0.25)) { flying = false }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation { confirmation = nil }
            if !compact { dismiss() }
        }
    }
}

// MARK: The three kinds of chip

/// What the app heard. Dashed on purpose: it is not a button, and dashed already means "loose"
/// everywhere else in PARAGON (the Map, `StateToggle`, `FilterBox`).
struct ReadChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            )
    }
}

/// The tags on a capture, chosen from the tags he already has.
///
/// **Build 188, and he had to ask for it.** Build 187 put this list on the New note screen
/// and left the capture screen with a button that wrote a bare `#`: *"The tags work on
/// everything except Capture."* The reason it was missed is worth writing down — a note's
/// tags are a `tags:` line and a capture's are `#tag` inside the words, so in the code they
/// are two different things, and I was editing one screen rather than asking which screens
/// pick a tag. **When a build changes how something is chosen, every screen that chooses the
/// same thing is part of that build** (build 168's rule, in a new place).
///
/// It is drawn as an `AddChip`, because that is what it is: a button that writes tag syntax
/// into the field. Only the way you pick the word has changed.
struct CaptureTagsChip: View {
    @ObservedObject var model: AppModel
    @Binding var tags: [String]
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Text("#tag\u{2026}")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Put a tag on this, from the ones you already have")
        .popover(isPresented: $showing) {
            TagChoices(model: model,
                       title: "Tags for this capture",
                       hint: "Tags on a capture are written into the words as #tag, which is how a task carries one.",
                       chosen: $tags)
        }
    }
}

/// A button that writes syntax into the field.
struct AddChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// One of a set: where it goes, and what it is.
struct PickChip: View {
    let title: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? tint : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint.opacity(isOn ? 0.16 : 0), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isOn ? tint.opacity(0.7) : Color.secondary.opacity(0.3),
                                           lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// What you can write in a capture. Behind the ⓘ, never in the placeholder: 84 characters of
/// syntax fits nowhere on a phone and disappears the moment you type (build 142).
struct CaptureSyntaxHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you can write")
                .font(.subheadline.weight(.semibold))
            Group {
                line(">2026-09-15", "a date")
                line(">2026-09-15T14:30", "a date and a time")
                line("!  !!  !!!", "how important, most marks first")
                line("#travel", "a tag")
            }
            Text("The chips under the field show what the app read, so you can see it went in right. The buttons write these for you.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 290)
        .presentationCompactAdaptation(.popover)
    }

    private func line(_ code: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
            Text(what)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}
