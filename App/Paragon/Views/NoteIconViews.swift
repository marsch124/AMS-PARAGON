import SwiftUI
import AMSIcons
import ParagonCore

// A project's and an area's own icon (build 284), drawn with the AMS-Icons package
// (https://github.com/marsch124/AMS-Icons): about 130 hand-drawn icons first made for the
// Packing app, about 300 chosen Apple symbols, fifteen colours and one search.
//
// **This is the only file in the app that imports the package.** Everything else asks these
// views, so a clash between a package name and a SwiftUI name has one place to happen, and
// the rest of the app keeps working from plain strings: Core stores `icon:` and `icon-colour:`
// as text (`NoteIcon.swift` in `ParagonCore`) and decides which of icon, old emoji, colour or
// nothing a note shows (`Note.ownIcon`).
//
// **An icon replaces an emoji.** A note with an old `emoji:` line and no icon keeps showing
// that emoji (the Projects list's tile and the chip below draw it as before), and no file is
// rewritten until an icon is chosen on that note.
//
// **Icons are for projects and areas only.** Goals and aspirations have their own star and
// target (build 168), resources have their blue, and a work note must not gain a new door
// out of the work set (build 112): `AppModel.setIcon` refuses all of those.

/// The note's mark on its colour: the icon when one is chosen, else the first letter of the
/// name when only a colour is. **Not drawn for an old emoji or for nothing** — callers ask
/// `note.ownIcon.isIconOrColour` first, because an emoji tile and the empty dashed tile are
/// the Projects list's own drawings (build 142's two states).
///
/// An `icon:` line this copy of the package cannot draw (a newer icon, an unknown prefix, a
/// bare word) shows the package's dashed circle, never a letter: a letter would say "no icon
/// chosen" about a note that has one written (build 100).
struct NoteIconTile: View {
    let note: Note
    /// What **Automatic** looks like. The Projects list passes its status colour (grey while a
    /// project is on hold or over); everything else passes the kind's own colour.
    let fallbackTint: Color
    let size: CGFloat

    var body: some View {
        IconTile(choice, colour: colour, fallbackTint: fallbackTint, letter: shownLetter, size: size)
    }

    /// The icon written on the note, when the package can read it.
    private var choice: IconChoice? {
        guard let stored = note.iconStored else { return nil }
        return IconChoice(stored: stored)
    }

    private var colour: IconColour? {
        IconColour.of(key: note.iconColourKey)
    }

    /// The name's first letter, only while no icon is written at all.
    private var shownLetter: String? {
        note.iconStored == nil ? note.title : nil
    }

    /// The icon's own name ("Bike"), for what a screen reader says. Nil when no icon is
    /// written, or when the package does not know it.
    static func iconName(of note: Note) -> String? {
        guard let stored = note.iconStored, let choice = IconChoice(stored: stored) else { return nil }
        return IconLibrary.label(for: choice)
    }
}

/// **Icon…** in a project's or an area's header: grey and dashed until something is chosen, then
/// the icon on its colour in a frame of the note's own colour. An old emoji is drawn as it was
/// in build 254 until an icon replaces it. Pressing it opens the package's picker.
///
/// **The picker is used as it is** — colours first, **Find an icon**, the hand-drawn icons and
/// then Apple's symbols, **No icon**, **Cancel**. Every press in it ends it, which is how the
/// Packing app works: one press on a colour, an icon or **No icon** writes the note and closes.
/// It is a `.popover`, so on the Mac it is one and on the iPhone the system shows it as a sheet;
/// it is the screen's only presentation (build 44). **Cancel** writes nothing.
struct NoteIconChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var picking = false

    /// Read back from the model rather than kept: choosing saves and reloads, and the copy
    /// handed to this view a moment ago is then one behind (build 144's `NoteTagsChip`).
    private var live: Note { model.note(at: note.relativePath) ?? note }

    private var kindWord: String { note.kind == .area ? "area" : "project" }

    var body: some View {
        let current = live
        Button { picking = true } label: {
            chipFace(current)
                .helpWhenClosed("Choose an icon and a colour for this \(kindWord). They are shown in its tile.",
                                open: picking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken(current))
        .accessibilityIdentifier("note.icon")
        .popover(isPresented: $picking) {
            picker(for: current)
        }
    }

    // MARK: The chip

    @ViewBuilder
    private func chipFace(_ current: Note) -> some View {
        switch current.ownIcon {
        case .icon, .colour:
            framed(NoteIconTile(note: current, fallbackTint: current.kind.tint, size: 22), isSet: true)
        case .emoji(let emoji):
            framed(Text(emoji), isSet: true)
        case .unset:
            framed(Label("Icon\u{2026}", systemImage: "paintpalette").foregroundStyle(.secondary), isSet: false)
        }
    }

    /// The capsule round the face: solid in the note's colour once something is set, grey and
    /// dashed until then (build 142's two states).
    private func framed<Face: View>(_ face: Face, isSet: Bool) -> some View {
        let edge: Color = isSet ? note.kind.tint : Color.secondary
        return face
            .padding(.horizontal, isSet ? 5 : 7)
            .padding(.vertical, 2)
            .overlay(
                Capsule().strokeBorder(edge.opacity(0.6),
                                       style: StrokeStyle(lineWidth: 1, dash: isSet ? [] : [3, 2]))
            )
            .contentShape(Capsule())
    }

    /// What a screen reader says. The visible chip has no words once an icon is set.
    private func spoken(_ current: Note) -> String {
        switch current.ownIcon {
        case .icon, .colour:
            if let name = NoteIconTile.iconName(of: current) { return "Icon: " + name }
            return "Icon"
        case .emoji(let emoji):
            return "Emoji " + emoji
        case .unset:
            return "Choose an icon"
        }
    }

    // MARK: The picker

    private func picker(for current: Note) -> some View {
        IconPicker(
            title: current.title,
            chosen: chosenIcon(of: current),
            colour: IconColour.of(key: current.iconColourKey),
            fallbackTint: current.kind.tint,
            onPick: { picked in choose(picked) },
            onColour: { picked in chooseColour(picked) },
            onCancel: { picking = false }
        )
        .modifier(IconPickerSize())
    }

    private func chosenIcon(of current: Note) -> IconChoice? {
        guard let stored = current.iconStored else { return nil }
        return IconChoice(stored: stored)
    }

    /// An icon, or **No icon** (nil). The colour is whatever the note holds now.
    private func choose(_ picked: IconChoice?) {
        let now = live
        model.setIcon(picked?.stored, colour: now.iconColourKey, on: now)
        picking = false
    }

    /// A colour, or **Automatic** (nil). The icon is whatever the note holds now, written back
    /// as it stands, so an icon this version cannot draw is kept rather than dropped.
    ///
    /// **Automatic on a note whose colour is already Automatic writes nothing.** The picker
    /// calls this on every press of that swatch, also when it is the one ringed, and
    /// `settingIcon` removes an old `emoji:` line whenever it is called. On a project that has
    /// only an old emoji nothing visible is being chosen, so the emoji must stay.
    private func chooseColour(_ picked: IconColour?) {
        let now = live
        if picked == nil && now.iconColourKey == nil {
            picking = false
            return
        }
        model.setIcon(now.iconStored, colour: picked?.key, on: now)
        picking = false
    }
}

/// How large the picker is in its popover. The package gives the Mac a sheet-sized minimum
/// (520 by 620) and nothing else, so a popover needs an ideal size and a top: without them it
/// would ask the scroll view for the height of every icon in the library. **Only the ideal size
/// is given on the iPhone and iPad** (no minimum, no top): an iPad popover asks for the ideal
/// size, while an iPhone sheet is handed the whole screen and never asks.
private struct IconPickerSize: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(idealWidth: 540, maxWidth: 580, idealHeight: 640, maxHeight: 680)
        #else
        content.frame(idealWidth: 440, idealHeight: 620)
        #endif
    }
}
