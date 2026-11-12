import Foundation

/// What is in a folder the user has just picked, found **without writing anything** (build 308,
/// hardening-16). Until then picking a folder set it up at once: six folders, templates, an
/// Inbox note and a settings file were written into whatever was chosen — the wrong folder, or
/// a vault iCloud had not finished listing, which then got a second, fresh Inbox.
public struct FolderLook: Equatable, Sendable {
    /// Notes found: `.md` files, counting those iCloud has not sent yet. Templates and anything
    /// in a hidden folder are not notes.
    public var noteCount: Int
    /// The folder carries PARAGON's marks: its settings file, an Inbox note, or one of the
    /// Projects / Areas / Resources / Archive folders.
    public var isVault: Bool
    /// The folder is kept in iCloud.
    public var inCloud: Bool
    /// Nothing at all is in it.
    public var isEmpty: Bool
    /// Folders inside it whose contents iCloud has not listed on this device yet.
    public var foldersNotListed: Int
    /// The folder could not be read at all.
    public var unreadable: Bool

    public init(noteCount: Int = 0, isVault: Bool = false, inCloud: Bool = false, isEmpty: Bool = false,
                foldersNotListed: Int = 0, unreadable: Bool = false) {
        self.noteCount = noteCount
        self.isVault = isVault
        self.inCloud = inCloud
        self.isEmpty = isEmpty
        self.foldersNotListed = foldersNotListed
        self.unreadable = unreadable
    }

    public enum Finding: Equatable, Sendable {
        /// A PARAGON vault with this many notes: open it.
        case vault(notes: Int)
        /// Not a vault (yet), holding this many notes of its own: offer to set it up.
        case notAVault(notes: Int)
        /// iCloud has not finished listing it: wait, and say so.
        case stillListing
        /// It cannot be read.
        case unreadable
    }

    /// What to tell the user. `settled` is false for the first looks at a folder: an iCloud
    /// folder that looks empty, or looks like a vault without a single note, may only be a
    /// listing that has not arrived, so it reads as "still listing" until a few looks agree.
    public func finding(settled: Bool) -> Finding {
        if !settled, foldersNotListed > 0 { return .stillListing }
        if inCloud, !settled, unreadable || isEmpty || (isVault && noteCount == 0) { return .stillListing }
        if unreadable { return .unreadable }
        return isVault ? .vault(notes: noteCount) : .notAVault(notes: noteCount)
    }

    /// Looks at the folder. Reads names and iCloud's marks only: no file is opened, nothing is
    /// created, nothing is written.
    public static func look(at folder: URL, config: VaultConfig = VaultConfig()) -> FolderLook {
        let fm = FileManager.default
        var look = FolderLook()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        look.inCloud = (try? folder.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
        guard let top = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else {
            look.unreadable = true
            return look
        }
        let names = top.map(\.lastPathComponent).filter { $0 != ".DS_Store" }
        look.isEmpty = names.isEmpty
        func has(_ name: String) -> Bool {
            names.contains(name) || names.contains(".\(name).icloud")
        }
        let state = folder.appendingPathComponent(Vault.stateFolderName, isDirectory: true)
        let paraFolders = [ParaKind.project, .area, .resource, .archive].compactMap { config.folder(for: $0) }
        look.isVault = CloudFiles.exists(state.appendingPathComponent("config.json"))
            || has(config.inboxFile) || paraFolders.contains(where: has)

        func count(in directory: URL, entries: [URL]?) {
            guard let entries = entries ?? (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) else {
                look.foldersNotListed += 1
                return
            }
            for entry in entries {
                let name = entry.lastPathComponent
                let values = try? entry.resourceValues(forKeys: Set(keys))
                if values?.isDirectory == true {
                    if name.hasPrefix(".") || (directory == folder && name == config.templatesFolder) { continue }
                    if values?.isUbiquitousItem == true, values?.ubiquitousItemDownloadingStatus == .notDownloaded {
                        look.foldersNotListed += 1
                        continue
                    }
                    count(in: entry, entries: nil)
                } else if (CloudFiles.realName(ofPlaceholder: name) ?? name).lowercased().hasSuffix(".md"),
                          CloudFiles.realName(ofPlaceholder: name) != nil || !name.hasPrefix(".") {
                    look.noteCount += 1
                }
            }
        }
        count(in: folder, entries: top)
        return look
    }
}
