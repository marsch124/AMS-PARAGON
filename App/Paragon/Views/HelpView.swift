import SwiftUI
import ParagonCore

/// The built-in manual: "How it works" and the version history, both markdown files in the
/// app bundle (`Docs/`). Rendered with a small renderer that knows headings, bullets,
/// paragraphs and fenced code, which is all the documents use.
struct HelpView: View {
    enum Page: String, CaseIterable, Identifiable, Codable, Hashable {
        case howItWorks = "How it works"
        /// The app's own words, one or two sentences each (build 228). His idea: *"It's getting
        /// rather complicated, right?"* It lives in Help, not Settings, because Settings is for
        /// choices and this is something you read — Settings only carries a row that opens it.
        case words = "Words"
        case versionHistory = "Version history"

        var id: String { rawValue }

        /// The word on the switch. The list of versions is called "What's new" everywhere
        /// (round 8, build 315); the raw value stays, because an open Help window is remembered by it.
        var title: String { self == .versionHistory ? "What\u{2019}s new" : rawValue }

        var fileName: String {
            switch self {
            case .howItWorks: return "HowItWorks"
            case .versionHistory: return "VersionHistory"
            case .words: return "Words"
            }
        }
    }

    @State var page: Page = .howItWorks

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            HelpDocument(fileName: page.fileName, title: page == .versionHistory ? page.title : nil)
                .id(page)
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}

/// One markdown document from the bundle, as a title and a list of sections you can open
/// one at a time. A manual you scroll is a manual you do not read; this one is a contents
/// page you drill into, with a search box that filters it.
struct HelpDocument: View {
    let fileName: String
    /// A title that stands in place of the document's own first line ("What's new").
    var title: String? = nil
    /// False where a navigation bar above the page already says its name (the iPhone).
    var showsTitle = true
    @State private var open: Set<String> = []
    @State private var search = ""

    private var document: HelpParts {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return HelpParts(title: fileName,
                             intro: [.paragraph("The document \(fileName).md is missing from this build.")],
                             sections: [])
        }
        return HelpParts(text: text)
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var sections: [HelpSection] {
        guard !query.isEmpty else { return document.sections }
        return document.sections.filter { $0.matches(query) }
    }

    /// While searching, everything that matched is open: the answer should be on screen,
    /// not behind another click.
    private func isOpen(_ section: HelpSection) -> Bool {
        !query.isEmpty || open.contains(section.id)
    }

    private func binding(for section: HelpSection) -> Binding<Bool> {
        Binding(get: { isOpen(section) },
                set: { wanted in
                    if wanted { open.insert(section.id) } else { open.remove(section.id) }
                })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if showsTitle {
                    Text(title ?? document.title)
                        .font(Txt.pageTitle.bold())
                }
                ForEach(Array(document.intro.enumerated()), id: \.offset) { _, block in
                    render(block)
                }
                if sections.isEmpty {
                    Text("Nothing in this page matches \u{201C}\(query)\u{201D}.")
                        .foregroundStyle(.soft)
                        .padding(.top, 8)
                }
                ForEach(sections) { section in
                    DisclosureGroup(isExpanded: binding(for: section)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                                render(block)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.leading, 2)
                    } label: {
                        Text(section.title)
                            .font(Txt.sectionTitle.weight(.semibold))
                    }
                    Divider()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(20)
            .textSelection(.enabled)
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                MarkImage("magnifyingglass")
                    .foregroundStyle(.soft)
                TextField("Search this page", text: $search)
                    .textFieldStyle(.roundedBorder)
                if !query.isEmpty {
                    Button("Clear") { search = "" }
                        .buttonStyle(.borderless)
                }
                Button(open.isEmpty ? "Open all" : "Close all") {
                    open = open.isEmpty ? Set(document.sections.map(\.id)) : []
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
        #if os(iOS)
        // Round 9 (build 316): a small title in the bar. Pushed from Settings the page took
        // Settings' large title, which left an empty band of about 100 points above the
        // search field; the page writes its own title under the field anyway.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func render(_ block: HelpBlock) -> some View {
        switch block {
        case .title(let text):
            Text(text).font(Txt.pageTitle.bold()).padding(.bottom, 4)
        case .heading(let text):
            Text(text).font(Txt.sectionTitle.weight(.semibold)).padding(.top, 10)
        case .subheading(let text):
            Text(text).font(Txt.listTitle).padding(.top, 8)
        case .paragraph(let text):
            Text(Self.inline(text))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.soft)
                        Text(Self.inline(item))
                    }
                }
            }
            .padding(.leading, 4)
        case .code(let text):
            Text(text)
                .font(Txt.mono)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Bold, italics and `code` inside a line.
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

// `HelpBlock` and `HelpBlock.parse` live in Core (`Markdown/HelpBlock.swift`) since build 272,
// where a hard-wrapped bullet is tested. This file only draws what they return.

/// One `##` section of a help document: its heading and everything under it.
struct HelpSection: Identifiable {
    let title: String
    let blocks: [HelpBlock]

    var id: String { title }

    /// True when the heading or any line inside mentions what was typed.
    func matches(_ query: String) -> Bool {
        if title.localizedCaseInsensitiveContains(query) { return true }
        return blocks.contains { $0.text.localizedCaseInsensitiveContains(query) }
    }
}

/// A help document split into its title, whatever comes before the first heading, and
/// the sections themselves.
struct HelpParts {
    let title: String
    let intro: [HelpBlock]
    let sections: [HelpSection]

    init(title: String, intro: [HelpBlock], sections: [HelpSection]) {
        self.title = title
        self.intro = intro
        self.sections = sections
    }

    init(text: String) {
        var title = ""
        var intro: [HelpBlock] = []
        var sections: [HelpSection] = []
        var heading: String?
        var blocks: [HelpBlock] = []

        func close() {
            if let heading {
                sections.append(HelpSection(title: heading, blocks: blocks))
            } else {
                intro = blocks
            }
            blocks = []
        }

        for block in HelpBlock.parse(text) {
            switch block {
            case .title(let text):
                if title.isEmpty { title = text } else { blocks.append(block) }
            case .heading(let text):
                close()
                // Round 9 (build 316): "13 November 2026" in a heading reads 2026-11-13.
                heading = HelpDates.plain(text)
            default:
                blocks.append(block)
            }
        }
        close()

        self.title = title
        self.intro = intro
        self.sections = sections
    }
}
