import SwiftUI
import Vision
import ImageIO
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
    /// Build 173. A saved search is being named, or renamed. One `.alert` for each, because a
    /// macOS alert drops everything that is not a TextField (build 93) and these ask for
    /// nothing else.
    @State private var savingName = ""
    @State private var savePrompt = false
    @State private var renaming: SavedSearch?
    @State private var renamingName = ""
    @AppStorage("searchSavedFolded") private var savedFolded = false
    @AppStorage("searchFiltersFolded") private var deskFiltersFolded = false
    @AppStorage("searchFiltersFoldedPhone") private var phoneFiltersFolded = true
    private var filtersFolded: Bool { isPhone ? phoneFiltersFolded : deskFiltersFolded }
    /// The height of the boxes, measured, so the pane can be exactly that tall (1.0).
    @State private var filtersHeight: CGFloat = 0
    /// Build 281: the phone's groups are single rows now (see `group`), so all four fit under
    /// 240 and the pane shows every group; 200 cut the third and the fourth off below its edge.
    private var filtersCap: CGFloat { isPhone ? 240 : 360 }

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
            savedBar
            if filtersFolded {
                foldedLine(query)
            } else {
                // 1.0: the pane is as tall as its boxes and no taller, so it ends at the last
                // row and not through the middle of a group; only a longer list scrolls.
                ScrollView { filters(query).measureHeight($filtersHeight) }
                    // The phone has the keyboard under all of this. 320pt of boxes plus the
                    // field plus the keyboard left the results about two rows tall, which is
                    // what he reported (build 160).
                    .frame(height: filtersHeight > 0 ? min(filtersHeight, filtersCap) : nil)
                    .frame(maxHeight: filtersCap)
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
        .alert("Save this search", isPresented: $savePrompt) {
            TextField("Name", text: $savingName)
            Button("Save") { model.saveCurrentSearch(named: savingName) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("It is saved as the words and boxes you have set, not as the results, so it answers for the vault as it is each time you run it.")
        }
        .alert("Rename saved search", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $renamingName)
            Button("Rename") {
                if let search = renaming { model.renameSavedSearch(search, to: renamingName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
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
                    MarkLabel(filtersFolded ? "Show the boxes" : "Hide the boxes", filtersFolded ? "chevron.down" : "chevron.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(filtersFolded ? "Show the tick boxes" : "Put the tick boxes away")
                .accessibilityIdentifier("search.boxes")
                if !model.queryText.isEmpty {
                    // Build 173. Offered only when there is something to save, and it comes
                    // with a name already filled in — the query in the same plain words the
                    // line under the boxes uses, so the two can never disagree.
                    Button {
                        savingName = SavedSearch.suggestedName(for: model.searchQuery)
                        savePrompt = true
                    } label: {
                        MarkLabel("Save this search", "bookmark")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Give this search a name and keep it")
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

    // MARK: Saved searches

    /// The saved searches as chips, right under the field (build 173).
    ///
    /// **Chips, not a list and not a sidebar row.** A list would take the room the results
    /// need on a phone, and a sidebar row would be a second door into the Search screen — the
    /// argument he accepted in build 166 against giving "All of them" its own row. A chip is
    /// one press to run, and a `WrappingHStack` so a long name moves to the next line whole
    /// rather than being squeezed (build 138).
    ///
    /// Nothing is drawn at all when there are none: an empty grey strip above the results
    /// would be a promise with nothing behind it. The **Save this search** button beside the
    /// field is how the first one is made, and it only appears when there is a search to save.
    @ViewBuilder
    private var savedBar: some View {
        if !model.savedSearches.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    savedFolded.toggle()
                } label: {
                    MarkLabel("Saved searches", savedFolded ? "chevron.right" : "chevron.down")
                        .font(Txt.label.weight(.semibold))
                        .foregroundStyle(.soft)
                }
                .buttonStyle(.plain)
                if !savedFolded {
                    WrappingHStack(spacing: 6, lineSpacing: 5) {
                        ForEach(model.savedSearches) { search in
                            SavedSearchChip(search: search,
                                            isCurrent: search.query == model.queryText) {
                                model.runSavedSearch(search)
                                fieldText = SearchQuery.words(in: search.query)
                                focused = false
                            } rename: {
                                renamingName = search.name
                                renaming = search
                            }
                        }
                    }
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            // His ask, with a screenshot: the saved searches ran straight into the TASKS
            // boxes below with nothing between them, so the row read as part of the filters
            // rather than as its own thing (build 175).
            Divider()
        }
    }

    /// What the boxes say while they are folded away, so the query is never invisible.
    private func foldedLine(_ query: SearchQuery) -> some View {
        Text(query.summary)
            .font(Txt.label)
            .foregroundStyle(.soft)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
    }

    // MARK: The boxes

    @ViewBuilder
    private func filters(_ query: SearchQuery) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            group("Tasks", tint: SidebarSection.allActions.tint,
                  note: "Tick any of these and the results are tasks, not notes.") {
                ForEach(Self.taskStates, id: \.self) { state in
                    FilterBox(title: SearchQuery.label(for: state).capitalizedFirst,
                              isOn: query.taskStates.contains(state),
                              tint: SidebarSection.allActions.tint,
                              token: "is:\(state.rawValue)", chip: true) { toggle("is:\(state.rawValue)") }
                }
                ForEach(Self.dues, id: \.self) { due in
                    FilterBox(title: SearchQuery.label(for: due).capitalizedFirst,
                              isOn: query.dues.contains(due),
                              tint: SidebarSection.calendar.tint,
                              token: "due:\(due.rawValue)", chip: true) { toggle("due:\(due.rawValue)") }
                }
            }
            group("Kind of note", tint: ParaKind.project.tint, note: nil) {
                ForEach(Self.kinds, id: \.self) { kind in
                    FilterBox(title: kind.displayName,
                              isOn: query.kinds.contains(kind),
                              tint: kind.tint,
                              token: "type:\(kind.rawValue)", chip: true) { toggle("type:\(kind.rawValue)") }
                }
            }
            group("How the note stands", tint: SidebarSection.review.tint, note: nil) {
                let asked = Set(query.statuses.map { NoteStatus(reading: $0) })
                ForEach(Self.statuses, id: \.self) { status in
                    FilterBox(title: status.label,
                              isOn: asked.contains(status),
                              tint: SidebarSection.review.tint,
                              token: "status:\(status.rawValue)", chip: true) { toggle("status:\(status.rawValue)") }
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
        group("Tags", tint: SidebarSection.tags.tint, note: tags.isEmpty ? "No tags in the vault yet" : nil) {
            ForEach(tags, id: \.self) { tag in
                FilterBox(title: "#\(tag)",
                          isOn: query.tags.contains(tag.lowercased()),
                          tint: SidebarSection.tags.tint,
                          token: "#\(tag)", chip: true) { toggle("#\(tag)") }
            }
        }
    }

    /// Build 302: the same chips as All actions on every device, so one spacing.
    private let boxSpacing: CGFloat = 5

    /// One titled row of boxes. `WrappingHStack` so a narrow column moves whole boxes to the
    /// next line rather than squeezing every one of them thinner (build 138).
    /// Build 302: the group's name in small grey capitals, as on All actions — the chips
    /// carry the colour.
    private func groupName(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Txt.pill.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.soft)
    }

    private func group<Content: View>(_ title: String, tint: Color, note: String?,
                                      @ViewBuilder boxes: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isPhone {
                // Build 281: on the phone a group is one row — its name at the left, the boxes
                // sliding sideways after it. Wrapped, the seven kinds alone took three rows and
                // the pane's 200 points ended in the middle of the second group (his 9 November
                // test: the last groups were cut). The Mac keeps the wrapping boxes.
                HStack(alignment: .center, spacing: 8) {
                    groupName(title)
                        .fixedSize()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: boxSpacing) {
                            boxes()
                        }
                        .lineLimit(1)
                        .padding(.trailing, 10)
                    }
                }
            } else {
                groupName(title)
            }
            if let note {
                Text(note)
                    .font(Txt.listSecond)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isPhone {
                WrappingHStack(spacing: boxSpacing, lineSpacing: 6) {
                    boxes()
                }
                .lineLimit(1)
            }
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
                           markName: SidebarSection.search.markName,
                           message: emptyMessage(query),
                           tint: SidebarSection.search.tint)
        } else if query.wantsTasks {
            let refs = hits.flatMap { hit in
                hit.tasks.map { TaskRef(notePath: hit.note.relativePath, noteTitle: hit.note.displayTitle, task: $0) }
            }
            List(selection: model.noteSelection) {
                Group {
                Section {
                    ForEach(refs) { ref in
                        TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
                            .tag(ref.notePath)
                    }
                } header: {
                    resultsHeading("\(refs.count) task\(refs.count == 1 ? "" : "s")")
                }
                }
                // Review round 4: on the iPhone each row is a card in the part's colour.
                .phoneCard(SidebarSection.search.tint)
            }
        } else {
            List(selection: model.noteSelection) {
                Group {
                Section {
                    ForEach(hits) { hit in
                        SearchHitRow(hit: hit)
                            .tag(hit.note.relativePath)
                    }
                } header: {
                    resultsHeading("\(hits.count) note\(hits.count == 1 ? "" : "s")")
                }
                }
                // Review round 4: on the iPhone each row is a card in the part's colour.
                .phoneCard(SidebarSection.search.tint)
            }
        }
    }

    /// The results' heading, "3 tasks" or "1 note", named for the screen tests.
    private func resultsHeading(_ text: String) -> some View {
        Text(text)
            .accessibilityIdentifier("search.results")
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
        // Build 295: words read in pictures count here too, as they do in the results.
        let count = model.index.search(wordsOnly, pictureText: model.pictureText).count
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

/// One tick box. **On the Mac it is the Mac's own tick box** (1.0, the reviewer's point): a
/// `Toggle` in the checkbox style, in the row's colour. On the iPhone it stays a chip, in the
/// same two states as `StateToggle` (build 142) in words rather than a symbol: on is the tint
/// filled with a solid border, off is grey with a dashed one. Both carry the name
/// `search.box.<token>`, the token the box writes into the query.
struct FilterBox: View {
    let title: String
    let isOn: Bool
    var tint: Color = .accentColor
    /// What the box writes into the query ("is:open", "type:project", "#travel"); the box is
    /// named `search.box.<token>` by it. All actions' boxes name themselves and pass none.
    var token: String? = nil
    /// Build 301 (his ask, All actions): a smaller, calmer chip on every device — off is a
    /// soft grey fill, ticked is filled in the row's colour with white words and a small tick.
    var chip: Bool = false
    let action: () -> Void

    var body: some View {
        if chip { chipBody } else { boxBody }
    }

    private var chipBody: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    MarkImage("checkmark", size: 9)
                        .fontWeight(.bold)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(title)
                    .font(Txt.pill)
            }
            .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.75))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isOn ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.06)))
            )
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: isOn ? tint.opacity(0.28) : .clear, radius: 3, y: 1)
            .contentShape(Capsule())
            .animation(.snappy(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "\(title), ticked" : "\(title), not ticked")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(token.map { "search.box.\($0)" } ?? "")
    }

    @ViewBuilder
    private var boxBody: some View {
        #if os(macOS)
        Toggle(isOn: Binding(get: { isOn }, set: { _ in action() })) {
            Text(title)
                .font(Txt.list)
        }
        .toggleStyle(.checkbox)
        .tint(tint)
        .accessibilityIdentifier(token.map { "search.box.\($0)" } ?? "")
        #else
        Button(action: action) {
            HStack(spacing: 5) {
                MarkImage(isOn ? "checkmark.square.fill" : "square")
                    .font(Txt.label)
                    .foregroundStyle(isOn ? tint : Color.secondary)
                Text(title)
                    .font(Txt.label)
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
        .accessibilityIdentifier(token.map { "search.box.\($0)" } ?? "")
        #endif
    }
}

struct SearchHitRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                KindBadge(kind: hit.note.declaredKind, size: 20)
                Text(hit.note.displayTitle)
                    .font(Txt.listTitle)
                Spacer()
                if let status = hit.note.status, status != "active" {
                    Text(status.capitalized)
                        .font(Txt.listSecond)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(hit.note.tint.opacity(0.18), in: Capsule())
                        .rowTint(hit.note.tint)
                }
            }
            ForEach(hit.snippets.prefix(2), id: \.self) { snippet in
                Text(snippet)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .lineLimit(1)
            }
            if !hit.tasks.isEmpty && hit.snippets.isEmpty {
                Text("\(hit.tasks.count) matching task\(hit.tasks.count == 1 ? "" : "s")")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
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
            Group {
            Section {
                Text("Write a word above, or tick any of the boxes. Ticking two boxes in the same row means either of them; boxes in different rows are added together.")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
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
                            Text(example.1).font(Txt.list)
                            Text(example.0).font(Txt.listSecond).foregroundStyle(.soft)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Examples")
            } footer: {
                Text("The small grey line is the same search, typed. Every box has a word you can type instead: type:, status:, tag: or #tag, area:, in:, due:, is:. A \"quoted phrase\" matches as a whole.")
                    .font(Txt.listSecond)
                    .fixedSize(horizontal: false, vertical: true)
            }
            }
            // Review round 4: on the iPhone each row is a card in the part's colour.
            .phoneCard(SidebarSection.search.tint)
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

/// One saved search (build 173).
///
/// It uses the two-state language the rest of the app has used since build 142: the one you
/// are looking at right now is filled with a solid border, the others are grey with a dashed
/// one. So the screen says which saved search you are in without a word of explanation.
struct SavedSearchChip: View {
    @EnvironmentObject private var model: AppModel
    let search: SavedSearch
    let isCurrent: Bool
    let run: () -> Void
    let rename: () -> Void

    private var tint: Color { isCurrent ? SidebarSection.search.tint : Color.primary.opacity(0.62) }

    var body: some View {
        Button(action: run) {
            MarkLabel(search.name, "bookmark")
                .font(Txt.label)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isCurrent ? tint.opacity(0.24) : Color.clear, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(tint, style: StrokeStyle(lineWidth: 1.2,
                                                                    dash: isCurrent ? [] : [3, 3]))
                )
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .help(search.query)
        .contextMenu {
            Button("Rename\u{2026}", action: rename)
            Button("Delete", role: .destructive) { model.deleteSavedSearch(search) }
        }
    }
}

// MARK: - Build 294: words inside pictures

extension AppModel {
    /// Reads the words in every picture the notes show, a few seconds after the notes
    /// change, in the background. What was read is kept, so a picture is read again only
    /// when its file changes.
    func readPicturesSoon() {
        guard pictureReading == nil else { picturesChangedWhileReading = true; return }
        guard let root = vault?.rootURL else { return }
        let paths = Set(notes.flatMap { note in
            Pictures.matches(in: note.body, notePath: note.relativePath).map(\.path)
        })
        guard !paths.isEmpty else { return }
        pictureReading = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            let words = await Task.detached(priority: .utility) {
                PictureReader.read(paths: paths, root: root)
            }.value
            guard let self else { return }
            if words != self.pictureText { self.pictureText = words }
            self.pictureReading = nil
            if self.picturesChangedWhileReading {
                self.picturesChangedWhileReading = false
                self.readPicturesSoon()
            }
        }
    }
}

extension AppModel {
    /// Build 295: the words in one picture, read now if they have not been read yet.
    func pictureWords(_ path: String) async -> String? {
        if let known = pictureText[path] { return Pictures.wordsToCopy(known) }
        guard let root = vault?.rootURL else { return nil }
        let read = await Task.detached(priority: .userInitiated) {
            PictureReader.read(paths: [path], root: root)[path]
        }.value
        if let read, pictureText[path] != read { pictureText[path] = read }
        return Pictures.wordsToCopy(read)
    }

    /// Build 295: Copy words on a picture — its words on the clipboard, and a short note.
    func copyPictureWords(_ path: String) {
        Task {
            if let words = await pictureWords(path) {
                MapExport.copyToPasteboard(words)
                flash("Words copied")
            } else {
                flash("No words found in this picture")
            }
        }
    }
}

/// Apple's on-device text recognition over the vault's pictures, with a cache in the app's
/// own Application Support folder (never in the vault).
enum PictureReader {
    struct Entry: Codable { var modified: Double; var text: String }

    static var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("PictureText.json")
    }

    static func read(paths: Set<String>, root: URL) -> [String: String] {
        var cache: [String: Entry] = [:]
        if let url = cacheURL, let data = try? Data(contentsOf: url) {
            cache = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
        }
        var changed = false
        var result: [String: String] = [:]
        for path in paths {
            let file = root.appendingPathComponent(path)
            // A picture still on its way from iCloud has no file yet: read it next time.
            guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate?.timeIntervalSince1970 else { continue }
            if let entry = cache[path], entry.modified == modified {
                if !entry.text.isEmpty { result[path] = entry.text }
                continue
            }
            guard let text = recognize(file) else { continue }
            cache[path] = Entry(modified: modified, text: text)
            changed = true
            if !text.isEmpty { result[path] = text }
        }
        if changed, let url = cacheURL, let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: url, options: .atomic)
        }
        return result
    }

    /// Build 298: where each search term sits on the picture — 0…1, origin at the bottom left.
    static func boxes(of terms: [String], in file: URL) -> [CGRect] {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { return [] }
        var boxes: [CGRect] = []
        for observation in request.results ?? [] {
            guard let line = observation.topCandidates(1).first else { continue }
            for range in Pictures.termRanges(in: line.string, terms: terms) {
                if let box = try? line.boundingBox(for: range)?.boundingBox { boxes.append(box) }
            }
        }
        return boxes
    }

    /// The words in one picture, line by line; nil when it cannot be read.
    static func recognize(_ file: URL, region: CGRect? = nil) -> String? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        if let region { request.regionOfInterest = region }
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return nil
        }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

