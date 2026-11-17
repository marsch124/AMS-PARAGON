import SwiftUI
import ParagonCore

/// Build 332: **File it** with a search field. With many projects and areas a menu is a long
/// scroll, and a menu cannot hold a field to type in, so a long list opens this small page
/// instead: the field on top (always shown, cursor in it at once), the same three groups
/// under it as `FilingPlaces` draws — Suggested, Recent, All projects and areas — filtered
/// by what he types with `FilingOrder.matching`, the one rule the Core tests cover.
///
/// Pressing Return files to the first place shown. A tap on a row is the action, so there is
/// no Save button; Cancel (Escape on the Mac) closes it and files nothing.
struct FilingSearchPage: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let ref: TaskRef
    let places: [Note]
    var focusAtOnce = true

    @State private var query = ""
    @FocusState private var focused: Bool

    private var tint: Color { SidebarSection.inbox.tint }
    private var allPlaces: [FilingOrder.Place] {
        places.map { FilingOrder.Place(path: $0.relativePath, title: $0.displayTitle) }
    }
    private var offer: FilingOrder.Offer {
        model.filingOffer(for: ref, among: places).matching(query)
    }
    private var whole: [FilingOrder.Place] { FilingOrder.matching(allPlaces, query) }
    /// Whether the groups have headings: not when there is nothing to group (the menu's rule).
    private var grouped: Bool {
        !model.filingOffer(for: ref, among: places).isEmpty
    }
    private var firstPlace: FilingOrder.Place? {
        offer.suggested.first ?? offer.recent.first ?? whole.first
    }
    private var taskTitle: String { Note.removingTag(Note.nextActionTag, from: ref.task.title) }

    var body: some View {
        content
            .tint(tint)
            .onAppear { if focusAtOnce { focused = true } }
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("File it")
                    .font(Txt.sectionTitle)
                    .foregroundStyle(tint.ink)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .quietSheetButton()
                    .controlSize(.large)
                    .accessibilityIdentifier("file.search.cancel")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
            page
        }
        #else
        NavigationStack {
            page
                .navigationTitle("File it")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("file.search.cancel")
                    }
                }
        }
        #endif
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(taskTitle)
                .font(Txt.listSecond)
                .foregroundStyle(.soft)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("file.search.task")
            field
            list
        }
        .padding(.top, 10)
    }

    private var field: some View {
        HStack(spacing: 8) {
            MarkImage("magnifyingglass")
                .foregroundStyle(.soft)
            TextField("Search projects and areas", text: $query)
                .textFieldStyle(.plain)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { if let first = firstPlace { file(first) } }
                .accessibilityIdentifier("file.search.field")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var list: some View {
        List {
            if offer.suggested.isEmpty && offer.recent.isEmpty && whole.isEmpty {
                Text("No project or area with these words.")
                    .font(Txt.list)
                    .foregroundStyle(.soft)
                    .accessibilityIdentifier("file.search.none")
            }
            if !offer.suggested.isEmpty {
                Section("Suggested") {
                    ForEach(offer.suggested, id: \.path) { row($0, "file.search.suggested.") }
                }
            }
            if !offer.recent.isEmpty {
                Section("Recent") {
                    ForEach(offer.recent, id: \.path) { row($0, "file.search.recent.") }
                }
            }
            if !whole.isEmpty {
                if grouped {
                    Section("All projects and areas") {
                        ForEach(whole, id: \.path) { row($0, "file.search.row.") }
                    }
                } else {
                    ForEach(whole, id: \.path) { row($0, "file.search.row.") }
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    private func row(_ place: FilingOrder.Place, _ idPrefix: String) -> some View {
        Button { file(place) } label: {
            Text(place.title)
                .font(Txt.list)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Rows as tall as their words: the list's own 11 points above and below are too many.
        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        .accessibilityIdentifier(idPrefix + place.title)
    }

    private func file(_ place: FilingOrder.Place) {
        model.moveTask(ref, to: place.path)
        dismiss()
    }
}
