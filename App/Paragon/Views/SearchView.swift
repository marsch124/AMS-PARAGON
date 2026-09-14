import SwiftUI
import ParagonCore

/// The Search section: a field for words, tick boxes for everything else, then the results.
///
/// **Build 157 turned the filters into tick boxes you can see without opening anything.** His
/// words: *"maybe we could perform the search with tick boxes so that you have an overview of
/// what you are actually searching for."* Before this the filters were `Menu`s whose state
/// showed only as a faintly tinted capsule, and the field mixed his words with `key:value`
/// syntax — so searching for the word **done** and ticking the **Done** box looked the same and
/// meant two different things. Now the word goes in the field and the questions are boxes, and
/// a glance at the panel is the whole query.
///
/// **The text is still the one source of truth.** Every box writes or removes a token in
/// `AppModel.queryText`, because other screens set that text — the Tags screen sends `#travel`
/// here, and an `amspara://` link can too — and a second store would have to be kept in step
/// with it. So the syntax he already knows still works, typed by hand or ticked.
struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focused: Bool
    @State private var fieldText = ""
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPhone: Bool { horizontalSizeClass == .compact }
#else
    private var isPhone: Bool { false }
#endif
    /// His to fold. **Open on the Mac** (build 121 is about not hiding the settings he asked to
    /// see) and **folded on the phone**, where the boxes plus the keyboard left about two rows
    /// of results — his screenshot, build 161. Two keys, so the two never overwrite each
    /// other on an iPad, and while folded the line underneath still says what the search is.
    @AppStorage("searchFiltersFolded") private var deskFiltersFolded = false
    @AppStorage("searchFiltersFoldedPhone") private var phoneFiltersFolded = true
    private var filtersFolded: Bool { isPhone ? phoneFiltersFolded : deskFiltersFolded }

    private static let kinds: [ParaKind] = [.goal, .project, .area, .resource, .archive, .daily, .inbox]
    /// Build 165: the boxes are the `NoteStatus` cases, so the list can never miss one the
    /// app can write — and **On hold** is spelled as a person spells it, not as the file does.
    private static let statuses = NoteStatus.allCases
    private static let dues: [SearchQuery.DueFilter] = [.overdue, .today, .week, .month, .none]
    private static let taskStates: [SearchQuery.TaskFilter] = [.open, .done]

    var body: some View {
        let query = model.searchQuery
        VStack(spacing: 0) {
            wordField
            if filtersFolded {
                foldedLine(query)
            } else {
                ScrollView { filters(query) }
                    // The phone has the keyboard under all of this. 320pt of boxes plus the
                    // field plus the keyboard left the results about two rows tall, which is
                    // what he reported (build 160).
                    .frame(maxHeight: isPhone ? 200 : 320)
            }
            Divider()
            results(query)
                // A swipe down the results puts the keyboard away. It reaches every scroll
                // view below, so the two result lists and the help text all have it.
                .scrollDismissesKeyboard(.immediately)
        }
        .onAppear {
            fieldText = SearchQuery.words(in: model.queryText)
            // On the phone the keyboard is what squeezes the results, so it only comes up on
            // its own when there is nothing to look at yet. Arriving with a word already
            // there — from the Tags screen, or an `amspara://` link — you want the results.
            focused = !isPhone || model.queryText.isEmpty
        }
#if os(iOS)
        // Three ways to put the keyboard away, because one is never found: Search on the
        // keyboard itself, a swipe down the result list, and a Done button above the keys.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
#endif
    }

    // MARK: The word

    private var wordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Only words go in here now. Everything else is a box below, so the field can
                // say what it is in two words instead of a line of syntax (build 142's lesson
                // about the add-a-task placeholder).
                // **Words only.** Build 157 promised that and did not keep it: every tick box
                // wrote its token into this very text, so ticking Not done put `is:open` in a
                // field labelled "Search for a word" (his screenshot, build 161). The text is
                // still the one source of truth — the field now shows and edits only its
                // words, and `SearchQuery.replacing(wordsIn:with:)` leaves the boxes alone.
                TextField("Search for a word", text: $fieldText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { focused = false }
                    .onChange(of: fieldText) { _, value in
                        let rebuilt = SearchQuery.replacing(wordsIn: model.queryText, with: value)
                        if model.queryText != rebuilt { model.queryText = rebuilt }
                    }
                    .onChange(of: model.queryText) { _, value in
                        // While he is typing the field is the author, or a token he is halfway
                        // through writing (`#tra` on the way to `#travel`) would be taken out
                        // from under the cursor. It is re-read the moment he leaves the field.
                        guard !focused else { return }
                        let shown = SearchQuery.words(in: value)
                        if fieldText != shown { fieldText = shown }
                    }
                    .onChange(of: focused) { _, isOn in
                        if !isOn { fieldText = SearchQuery.words(in: model.queryText) }
                    }
                Button {
                    if isPhone { phoneFiltersFolded.toggle() } else { deskFiltersFolded.toggle() }
                } label: {
                    Label(filtersFolded ? "Show the boxes" : "Hide the boxes",
                          systemImage: filtersFolded ? "chevron.down" : "chevron.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(filtersFolded ? "Show the tick boxes" : "Put the tick boxes away")
                if !model.queryText.isEmpty {
                    // Both, because the field is not re-read from the model while it has focus.
                    Button("Clear") { model.queryText = ""; fieldText = "" }
                        .buttonStyle(.borderless)
                        .help("Empty the field and untick every box")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    /// What the boxes say while they are folded away, so the query is never invisible.
    private func foldedLine(_ query: SearchQuery) -> some View {
        Text(query.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
    }

    // MARK: The boxes

    @ViewBuilder
    private func filters(_ query: SearchQuery) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            group("Tasks", tint: SidebarSection.allActions.tint,
                  note: "Tick any of these and the results are tasks, not notes.") {
                ForEach(Self.taskStates, id: \.self) { state in
                    FilterBox(title: SearchQuery.label(for: state).capitalizedFirst,
                              isOn: query.taskStates.contains(state),
                              tint: SidebarSection.allActions.tint) { toggle("is:\(state.rawValue)") }
                }
                ForEach(Self.dues, id: \.self) { due in
                    FilterBox(title: SearchQuery.label(for: due).capitalizedFirst,
                              isOn: query.dues.contains(due),
                              tint: SidebarSection.calendar.tint) { toggle("due:\(due.rawValue)") }
                }
            }
            group("Kind of note", tint: ParaKind.project.tint, note: nil) {
                ForEach(Self.kinds, id: \.self) { kind in
                    FilterBox(title: kind.displayName,
                              isOn: query.kinds.contains(kind),
                              tint: kind.tint) { toggle("type:\(kind.rawValue)") }
                }
            }
            group("How the note stands", tint: SidebarSection.review.tint, note: nil) {
                let asked = Set(query.statuses.map { NoteStatus(reading: $0) })
                ForEach(Self.statuses, id: \.self) { status in
                    FilterBox(title: status.label,
                              isOn: asked.contains(status),
                              tint: SidebarSection.review.tint) { toggle("status:\(status.rawValue)") }
                }
            }
            tagGroup(query)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    /// Built as its own function so the empty case is a sentence rather than an empty row.
    @ViewBuilder
    private func tagGroup(_ query: SearchQuery) -> some View {
        let tags = model.allTagNames
        group("Tags", tint: SidebarSection.tags.tint, note: tags.isEmpty ? "No tags in the vault yet." : nil) {
            ForEach(tags, id: \.self) { tag in
                FilterBox(title: "#\(tag)",
                          isOn: query.tags.contains(tag.lowercased()),
                          tint: SidebarSection.tags.tint) { toggle("#\(tag)") }
            }
        }
    }

    /// One titled row of boxes. `WrappingHStack` so a narrow column moves whole boxes to the
    /// next line rather than squeezing every one of them thinner (build 138).
    private func group<Content: View>(_ title: String, tint: Color, note: String?,
                                      @ViewBuilder boxes: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: title, count: nil, tint: tint)
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                boxes()
            }
            .lineLimit(1)
        }
    }

    // MARK: The results

    @ViewBuilder
    private func results(_ query: SearchQuery) -> some View {
        let hits = model.searchHits
        if query.isEmpty {
            SearchHelpView()
        } else if hits.isEmpty {
            // Never a bare "no results": say what was asked for, so a word that found nothing
            // can be told apart from a box that ruled everything out.
            EmptyStateView(title: "Nothing matches",
                           systemImage: SidebarSection.search.systemImage,
                           message: emptyMessage(query),
                           tint: SidebarSection.search.tint)
        } else if query.wantsTasks {
            let refs = hits.flatMap { hit in
                hit.tasks.map { TaskRef(notePath: hit.note.relativePath, noteTitle: hit.note.displayTitle, task: $0) }
            }
            List(selection: model.noteSelection) {
                Section("\(refs.count) task\(refs.count == 1 ? "" : "s")") {
                    ForEach(refs) { ref in
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                }
            }
        } else {
            List(selection: model.noteSelection) {
                Section("\(hits.count) note\(hits.count == 1 ? "" : "s")") {
                    ForEach(hits) { hit in
                        SearchHitRow(hit: hit)
                            .tag(hit.note.relativePath)
                    }
                }
            }
        }
    }

    /// Why there is nothing, not just that there is nothing.
    ///
    /// **This is the fault he reported.** Searching for the word **done** came back empty, and
    /// the reason was almost certainly a box left ticked from before: `is:done done` asks for
    /// *finished tasks whose own title contains the word done*, which nobody has. The old
    /// screen showed that as a blank list. Now it says the boxes ruled the word out, and how
    /// many notes the word alone is in \u2014 build 100's rule, in a new place: an absence has to
    /// say why.
    private func emptyMessage(_ query: SearchQuery) -> String {
        guard query.wantsTasks, !query.terms.isEmpty else { return query.summary }
        var wordsOnly = SearchQuery()
        wordsOnly.terms = query.terms
        let count = model.index.search(wordsOnly).count
        guard count > 0 else { return query.summary }
        let notes = count == 1 ? "1 note" : "\(count) notes"
        return query.summary
            + " The words are in \(notes), but no task in them matches the boxes you ticked."
            + " Untick the boxes under Tasks to search the notes themselves."
    }

    /// Adds a token to the query, or takes it out when it is already there. Two boxes in the
    /// same row can both be on: they mean "either of these" (`SearchQuery.taskMatches`).
    private func toggle(_ token: String) {
        var tokens = model.queryText.split(separator: " ").map(String.init)
        if let i = tokens.firstIndex(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
            tokens.remove(at: i)
        } else {
            tokens.append(token)
        }
        model.queryText = tokens.joined(separator: " ")
    }
}

/// One tick box. The same two states as `StateToggle` (build 142) in words rather than a
/// symbol: on is the tint filled with a solid border, off is grey with a dashed one.
struct FilterBox: View {
    let title: String
    let isOn: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.caption)
                    .foregroundStyle(isOn ? tint : Color.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(isOn ? 0.16 : 0), in: Capsule())
            .overlay(
                Capsule().strokeBorder(isOn ? tint.opacity(0.7) : Color.secondary.opacity(0.35),
                                       style: StrokeStyle(lineWidth: 1, dash: isOn ? [] : [3, 2]))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "\(title), ticked" : "\(title), not ticked")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

struct SearchHitRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                KindBadge(kind: hit.note.declaredKind, size: 20)
                Text(hit.note.displayTitle)
                    .font(.headline)
                Spacer()
                if let status = hit.note.status, status != "active" {
                    Text(status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(hit.note.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(hit.note.tint)
                }
            }
            ForEach(hit.snippets.prefix(2), id: \.self) { snippet in
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !hit.tasks.isEmpty && hit.snippets.isEmpty {
                Text("\(hit.tasks.count) matching task\(hit.tasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// What the results area shows before anything has been asked for.
struct SearchHelpView: View {
    @EnvironmentObject private var model: AppModel

    private let examples: [(String, String)] = [
        ("due:overdue is:open", "Everything overdue"),
        ("due:week is:open", "Due this week"),
        ("type:project status:active", "Active projects"),
        ("is:done due:any", "Finished tasks that had a date"),
    ]

    var body: some View {
        List {
            Section {
                Text("Write a word above, or tick any of the boxes. Ticking two boxes in the same row means either of them; boxes in different rows are added together.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // `Section(_:content:footer:)` does not exist — a title string and a footer cannot
            // be given together. It is the header/footer form or nothing (CI caught this).
            Section {
                ForEach(examples, id: \.0) { example in
                    Button {
                        model.queryText = example.0
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(example.0).font(.system(.caption, design: .monospaced))
                            Text(example.1).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("The same thing, typed")
            } footer: {
                Text("Every box has a word you can type instead: type:, status:, tag: or #tag, area:, in:, due:, is:. A \"quoted phrase\" matches as a whole.")
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension String {
    /// "not done" → "Not done". `capitalized` would give "Not Done".
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
