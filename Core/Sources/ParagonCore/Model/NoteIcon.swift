import Foundation

/// The keys of a note's own icon (build 284): `icon:` and `icon-colour:` in the settings block.
///
/// **Core stores strings and never imports the icon package.** The AMS-Icons package (the
/// hand-drawn icons and the Apple symbols every AMS app shares) decides what a stored icon
/// looks like and whether it can be drawn; this file decides only what reaches the file and what
/// is read back. So `icon:` holds the package's own one-word-and-a-name spelling (`hand:bike`,
/// `symbol:figure.run`) exactly as the package writes it, and `icon-colour:` holds the colour's
/// key (`blue`, `slate`). The App turns both into pictures.
public enum NoteIconFields {
    /// The settings key for the icon.
    public static let iconKey = "icon"
    /// The settings key for the colour of its tile. A note that says nothing is **Automatic**:
    /// the tile takes the colour of the kind of note (a project's green, an area's pink).
    public static let colourKey = "icon-colour"
    /// What the package also writes for Automatic. Read as no colour; never written.
    public static let automatic = "auto"
}

/// What a project or an area shows in its tile, worked out in one place so that the Projects
/// list, the area page and the Areas list cannot disagree (build 168).
///
/// **An icon replaces an emoji** (his word, 27 October). A note with both shows the icon; a note
/// with only an old `emoji:` line keeps showing its emoji exactly as before, and no file is
/// rewritten until he chooses an icon on that note.
public enum NoteIcon: Equatable, Sendable {
    /// `icon:` as written, and the colour of its tile (nil is Automatic). The text is **not**
    /// checked here: a line this version of the app cannot draw (a newer icon, an unknown
    /// prefix, a bare word) is still kept as written and still counts as "an icon is set", so
    /// the App can draw a dashed circle instead of pretending there is nothing (build 100).
    case icon(String, colour: String?)
    /// The old `emoji:` line, when no icon is set.
    case emoji(String)
    /// Only a colour was chosen: the tile is that colour with the first letter of the name.
    case colour(String)
    /// Nothing chosen. The App draws its dashed empty tile.
    case unset

    /// An icon or a colour is chosen — the cases the icon package draws. An emoji is not one.
    public var isIconOrColour: Bool {
        switch self {
        case .icon, .colour: return true
        case .emoji, .unset: return false
        }
    }
}

public extension Note {
    /// The icon as written in the settings block, trimmed. Nil when there is no line or the
    /// line is empty (`icon:`), as for `measure:`. Not checked: an unknown prefix is returned as
    /// it stands.
    var iconStored: String? {
        NoteIconText.line(frontmatter.string(NoteIconFields.iconKey))
    }

    /// The colour key of the icon's tile, in small letters. Nil for no line, an empty line and
    /// `auto`, all of which mean Automatic.
    var iconColourKey: String? {
        NoteIconText.colour(frontmatter.string(NoteIconFields.colourKey))
    }

    /// What this note shows in its tile. The icon first, then an old emoji, then a lone colour.
    var ownIcon: NoteIcon {
        if let stored = iconStored { return .icon(stored, colour: iconColourKey) }
        if let old = self.emoji { return .emoji(old) }
        if let colour = iconColourKey { return .colour(colour) }
        return .unset
    }

    /// The note with its icon and the colour of its tile set. Nil removes the line — a note
    /// that says nothing has no icon, and that is what a new note looks like (build 165's rule
    /// for `status:`, never `icon:` with an empty value).
    ///
    /// **Setting or clearing an icon always removes the old `emoji:` line.** That is what
    /// "an icon replaces an emoji" means: pressing **No icon** on a project that has an old
    /// emoji takes the emoji away too, and the tile shows the empty one. A note that is never
    /// given to this function keeps its emoji.
    ///
    /// **Nothing that changes nothing is written.** The same icon and colour again, with no old
    /// emoji to remove, returns the note as it was, so pressing the icon already chosen never
    /// moves the file's date or sends it round iCloud (build 254's rule). Every other line and
    /// the body are untouched.
    func settingIcon(_ icon: String?, colour: String?) -> Note {
        var updated = self
        if let value = NoteIconText.line(icon) {
            updated.frontmatter.set(NoteIconFields.iconKey, value)
        } else {
            updated.frontmatter.remove(NoteIconFields.iconKey)
        }
        if let key = NoteIconText.colour(colour) {
            updated.frontmatter.set(NoteIconFields.colourKey, key)
        } else {
            updated.frontmatter.remove(NoteIconFields.colourKey)
        }
        updated.frontmatter.remove(ProjectEmoji.key)
        return updated.frontmatter == frontmatter ? self : updated
    }
}

/// How the two values are cleaned before they are compared or written.
enum NoteIconText {
    /// One line, trimmed. A line break (never in a stored icon, but a hand-edited file might
    /// hold one) is joined into a space, because a settings line cannot hold two. Nil for
    /// nothing.
    static func line(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned.isEmpty ? nil : cleaned
    }

    /// A colour key: trimmed, small letters, and nil for nothing or for `auto`.
    static func colour(_ text: String?) -> String? {
        guard let text else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty || key == NoteIconFields.automatic { return nil }
        return key
    }
}
