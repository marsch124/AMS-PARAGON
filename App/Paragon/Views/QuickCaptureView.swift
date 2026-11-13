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
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// One of his extras: the empty field says hello. Picked on appear, never mid-typing.
    static let greetings = [
        "What's on your mind?",
        "Anything to write down?",
        "Write it down before it goes.",
        "What needs to be somewhere safe?",
    ]

    var body: some View {
        Group {
            if isPhone { phoneBodyChromed } else { deskBodyChromed }
        }
        .onAppear {
            focused = true
            greeting = Self.greetings.randomElement() ?? Self.greetings[0]
            // Words handed over by an empty screen's button (round 8, build 315). Taken once.
            if text.isEmpty, let preset = model.capturePreset {
                model.capturePreset = nil
                text = preset
            }
        }
        .popover(isPresented: $showingSyntax) { CaptureSyntaxHelp() }
        .sheet(isPresented: $pickingDate) {
            // Round 8 (build 315): the same date window as a task's, with its **At** line, so
            // "Call the bank at 14:00" needs no typing of `>2026-11-14T14:00`.
            DateTimeChoiceView(current: reading.dueDate, time: reading.dueTime,
                               cancel: { pickingDate = false }) { picked, at in
                if let picked {
                    text = CaptureReading.line(text, dated: picked, at: at)
                    focused = true
                }
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
                        .foregroundStyle(.soft)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(Txt.value)
                    .accessibilityIdentifier("capture.text")
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .padding(6)
            .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            // **The chips scroll; the field and Save do not** (build 231, his report: *"the
            // virtual iphone keyboard is in the way for the Save and cancel button"*). With the
            // keyboard up there is about half a screen left, and inside the New note screen
            // the row of kinds sits above all this too — so a column of fixed-height pieces
            // ran out of room and **Save** ended up under the keyboard. The field stays on top
            // because it is what you are typing in; **Save** stays at the foot because it is
            // what you press next; everything between them gives way. The field is kept out
            // of this `ScrollView` on purpose: a text view inside a scroll view is one scroll
            // inside another (build 127). Dragging the chips down puts the keyboard away.
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    readBack
                    addRow
                    intoRow
                    asRow
                    caughtToday
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(embedded ? 0 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) { flight }
        // Build 312 (review round 6): ONE Save, top right in the bar, full colour; the one
        // Cancel is the bar's, top left. The wide Save at the foot and the second Cancel
        // beside it are gone — the foot is where the keyboard is (build 231's trouble).
        .modifier(CaptureSaveInBar(save: saveOrSayWhy))
    }

    /// On its own the phone's capture gets the same bar the New screen gives it: Cancel left,
    /// Save right. Inside the New screen that bar is already there and only Save is added.
    @ViewBuilder
    private var phoneBodyChromed: some View {
        if embedded {
            phoneBody
        } else {
            phoneBody
                .sheetChrome(title: "Quick capture", tint: SidebarSection.inbox.tint,
                             actionTitle: "Save", showsAction: false,
                             cancel: { dismiss() }, act: save)
        }
    }

    /// The phone's Save can always be pressed. With nothing written it says what is missing,
    /// in the line at the top where "Saved to Inbox" also appears.
    private func saveOrSayWhy() {
        if canSave { save(); return }
        focused = true
        withAnimation(.easeOut(duration: 0.2)) { confirmation = Self.nothingWritten }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if confirmation == Self.nothingWritten { withAnimation { confirmation = nil } }
        }
    }

    static let nothingWritten = "Write something first"

    // MARK: The Mac, unchanged in shape

    private var deskBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            TextField(greeting, text: $text, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
                .accessibilityIdentifier("capture.text")
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
                if embedded {
                    // Inside the New note sheet the sheet's own bar has Cancel; this is the
                    // one Save, where it always was.
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.filled(SidebarSection.inbox.tint))
                        .disabled(!canSave)
                        .accessibilityIdentifier("capture.save")
                }
            }
            caughtToday
            if model.vault == nil {
                Text("No vault is open. Captures are kept and filed the next time the app opens a vault.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
            }
        }
        .padding(embedded ? 0 : (compact ? 12 : 20))
        .frame(width: deskWidth)
    }

    /// 1.0: as a sheet of its own the Mac capture gets the bar with Cancel and Save at the top
    /// right (Escape, Return, ⌘S); embedded in the New note sheet it has none, the sheet does.
    @ViewBuilder
    private var deskBodyChromed: some View {
        if embedded {
            deskBody
        } else {
            deskBody
                .sheetChrome(title: "Quick capture", tint: SidebarSection.inbox.tint,
                             actionTitle: "Save", canAct: canSave, actionIdentifier: "capture.save",
                             cancel: { dismiss() }, act: save)
        }
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
            // 1.0: on the Mac the sheet's bar carries the title; the phone's screen keeps it.
            if !embedded && compact {
                MarkLabel("Quick capture", "tray.and.arrow.down", text: .body)
                    .font(Txt.listTitle)
                    .foregroundStyle(SidebarSection.inbox.tint.ink)
            }
            Spacer()
            if let confirmation {
                Text(confirmation)
                    .font(Txt.label)
                    .foregroundStyle(SidebarSection.inbox.tint.ink)
                    .transition(.opacity)
            }
            Button {
                showingSyntax = true
            } label: {
                MarkImage("info.circle")
            }
            .buttonStyle(.borderless)
            .help("What you can write in a capture")
            .accessibilityLabel("What you can write in a capture")
        }
    }

    /// The line read back. Dashed, because these are not buttons — they are what the app heard.
    @ViewBuilder
    private var readBack: some View {
        if !reading.isPlain {
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                if let due = dueChipTitle {
                    ReadChip(title: due, markName: "calendar", tint: SidebarSection.calendar.tint)
                }
                if let marks = reading.priorityMarks {
                    ReadChip(title: "Priority \(marks)", markName: "exclamationmark",
                             tint: ParaKind.area.tint)
                }
                ForEach(reading.tags, id: \.self) { tag in
                    ReadChip(title: "#\(tag)", markName: "number", tint: SidebarSection.tags.tint)
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
        return "Due " + DayWords.withWeekday(dueDate)
    }

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
                .font(Txt.listSecond)
                .foregroundStyle(.soft)
        }
    }

    /// The words flying into the tray. Half a second, and Reduce Motion turns it off.
    @ViewBuilder
    private var flight: some View {
        if flying && !reduceMotion {
            MarkImage("tray.and.arrow.down.fill", text: .largeTitle)
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
    let markName: String
    let tint: Color

    var body: some View {
        MarkLabel(title, markName, text: .footnote)
            .font(Txt.label)
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
                .font(Txt.label)
                .foregroundStyle(.soft)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
                .helpWhenClosed("Put a tag on this, from the ones you already have", open: showing)
        }
        .buttonStyle(.plain)
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
                .font(Txt.label)
                .foregroundStyle(.soft)
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
                .font(Txt.label)
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? tint.capsuleWords : Theme.soft)
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
                .font(Txt.label.weight(.semibold))
            Group {
                line(">2026-09-15", "a date")
                line(">2026-09-15T14:30", "a date and a time")
                line("!  !!  !!!", "how important, most marks first")
                line("#travel", "a tag")
            }
            Text("The chips under the field show what the app read, so you can see it went in right. The buttons write these for you.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 290)
        .presentationCompactAdaptation(.popover)
    }

    private func line(_ code: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(code)
                .font(Txt.mono)
            Text(what)
                .font(Txt.label)
                .foregroundStyle(.soft)
            Spacer(minLength: 0)
        }
    }
}

// MARK: The phone's Save and the floating + (build 312)

/// **Save** at the top right of the phone's capture screen, white on the Inbox's full colour.
/// Never grey: pressed early it says what is missing. Nothing on the Mac and the iPad, whose
/// capture keeps its own Save.
struct CaptureSaveInBar: ViewModifier {
    let save: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar { CaptureSaveItem(save: save) }
        #else
        content
        #endif
    }
}

#if os(iOS)
/// Without the round glass iOS 26 draws behind a bar button: the button brings its own colour.
struct CaptureSaveItem: ToolbarContent {
    let save: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .confirmationAction) { button }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .confirmationAction) { button }
        }
    }

    private var button: some View {
        // The bar squeezes a filled button to "S…" unless the word holds its own width.
        Button(action: save) { Text("Save").lineLimit(1).fixedSize() }
            .buttonStyle(.filled(SidebarSection.inbox.tint))
            .accessibilityIdentifier("capture.save")
    }
}

/// **The round + above the tabs** (review round 6, his pick A): bottom right on Today, Actions
/// and Inbox, where a thumb reaches it. It opens the New screen with **Capture** chosen — the
/// same screen Today's top-left + opened — and keeps that button's name, `capture.open`.
///
/// It sits in the bottom safe area, so a list scrolls its last row clear of it, and it steps
/// aside while the keyboard is up (it would ride up on top of the keys otherwise).
struct PhoneCaptureButton: ViewModifier {
    @EnvironmentObject private var model: AppModel
    @State private var keyboardUp = false

    static let size: CGFloat = 54

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                if !keyboardUp { button }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardUp = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardUp = false
            }
            // A second chance, in case the keyboard went without the warning (as `FocusBar`).
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                keyboardUp = false
            }
    }

    private var button: some View {
        Button {
            // Capture, whatever this tab would otherwise start on. Set in the same breath as
            // the sheet is asked for, as `WhatNextDialog` does.
            model.newNotePreset = NewNotePreset(thing: .capture, servesGoal: "")
            model.activeSheet = .newNote
        } label: {
            MarkImage("plus", size: 24)
                .foregroundStyle(Color.white)
                .frame(width: Self.size, height: Self.size)
                .background(SidebarSection.inbox.tint.deep, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                .contentShape(Circle())
                .accessibilityLabel("New")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture.open")
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

extension View {
    /// The floating capture + of the phone's Today, Actions and Inbox tabs.
    func phoneCaptureButton() -> some View { modifier(PhoneCaptureButton()) }
}
#endif
