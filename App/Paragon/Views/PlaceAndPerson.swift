import SwiftUI
import MapKit
import Contacts
#if os(iOS)
import ContactsUI
#endif
import ParagonCore

// Round 350: **Remind me at a place…** and **Person…**.
//
// A place on a task is `@place(Name|lat,lon|arrive)` on its line; the sync gives the reminder a
// location alarm and Apple Reminders does the watching, so PARAGON never asks for the phone's
// location for it. A person is `@person(Name)` on a task and `people:` on a note. Neither
// permission (Contacts) is asked at launch: only when a button that needs it is pressed.

// MARK: - Writers

extension AppModel {
    /// Puts a place on a task, or takes it off (nil). The change is made to the line **as the
    /// note holds it now**, as `makeWaiting` does (build 279). Nothing is written when nothing
    /// changes.
    func setPlace(_ place: ReminderPlace?, for ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task), !live.isDone else { return }
        var changed: TaskItem = live
        changed.place = place
        guard changed != live, note.rewrite(task: live, with: changed) else { return }
        guard save(note) else { return }
        if let place {
            flash("\(place.words). It rings once the task has synced with Reminders.")
        } else {
            flash("Place taken off.")
        }
    }

    /// Links a task to a person, or takes the link off (nil).
    func setPerson(_ name: String?, for ref: TaskRef) {
        flushPendingEdits()
        guard var note = note(at: ref.notePath), let live = note.liveTask(for: ref.task) else { return }
        var changed: TaskItem = live
        changed.person = name.flatMap { PersonName.clean($0) }
        guard changed != live, note.rewrite(task: live, with: changed) else { return }
        guard save(note) else { return }
        if let person = changed.person {
            flash("Linked to \(person).")
        } else {
            flash("Person taken off.")
        }
    }

    /// The people on a note's `people:` line.
    func setNotePeople(_ names: [String], on note: Note) {
        flushPendingEdits()
        guard let live = self.note(at: note.relativePath) else { return }
        let updated: Note = live.settingPeople(names)
        guard updated.people != live.people else { return }
        guard save(updated) else { return }
        reload()
    }
}

// MARK: - Place

/// One answer of the place search.
struct PlaceHit: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    init(item: MKMapItem) {
        let coordinate: CLLocationCoordinate2D = item.placemark.coordinate
        let title: String = item.name ?? item.placemark.title ?? "Place"
        self.name = title
        self.address = item.placemark.title ?? ""
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.id = "\(title)|\(coordinate.latitude),\(coordinate.longitude)"
    }
}

/// The window behind **Remind me at a place…**: a search field, the answers, Arriving or
/// Leaving, and **Cancel** / **Save** along the top (builds 160 and 231: not under the keyboard).
struct PlaceSearchView: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [PlaceHit] = []
    @State private var chosen: PlaceHit?
    @State private var arriving = true
    @State private var searching = false
    @State private var message: String?
    @FocusState private var focused: Bool

    private var tint: Color { SidebarSection.allActions.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Remind me at a place")
                    .font(Txt.listTitle)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("place.cancel")
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(chosen == nil)
                    .accessibilityIdentifier("place.save")
            }
            if let current = ref.task.place {
                HStack(spacing: 8) {
                    Text("Now: \(current.words)")
                        .font(Txt.label)
                        .foregroundStyle(.soft)
                        .accessibilityIdentifier("place.current")
                    Spacer(minLength: 0)
                    Button("Take place off") {
                        model.setPlace(nil, for: ref)
                        isPresented = false
                    }
                    .accessibilityIdentifier("place.remove")
                }
            }
            HStack(spacing: 6) {
                PickChip(title: "Arriving", isOn: arriving, tint: tint) { arriving = true }
                    .accessibilityIdentifier("place.arriving")
                PickChip(title: "Leaving", isOn: !arriving, tint: tint) { arriving = false }
                    .accessibilityIdentifier("place.leaving")
            }
            HStack(spacing: 6) {
                TextField("Search a place", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(search)
                    .accessibilityIdentifier("place.field")
                Button("Search", action: search)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                    .accessibilityIdentifier("place.search")
            }
            if let message {
                Text(message)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("place.message")
            }
            ForEach(results) { hit in
                Button {
                    chosen = hit
                } label: {
                    HStack(spacing: 8) {
                        MarkImage(chosen == hit ? "checkmark" : "mappin", text: .footnote)
                            .foregroundStyle(chosen == hit ? tint.ink : Color.secondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(hit.name)
                                .font(Txt.listTitle)
                                .lineLimit(1)
                            if !hit.address.isEmpty {
                                Text(hit.address)
                                    .font(Txt.label)
                                    .foregroundStyle(.soft)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("place.result.\(hit.name)")
            }
            Text("Apple Reminders watches the place and rings when you \(arriving ? "arrive" : "leave"). The task needs to be in a note that syncs with Reminders.")
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
        .onAppear {
            if let current = ref.task.place { arriving = current.arriving }
            DispatchQueue.main.async { focused = true }
        }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        searching = true
        message = nil
        Task { @MainActor in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            do {
                let response = try await MKLocalSearch(request: request).start()
                let hits: [PlaceHit] = response.mapItems.prefix(8).map { PlaceHit(item: $0) }
                results = hits
                if hits.isEmpty { message = "No place found. Try other words." }
            } catch {
                results = []
                message = "PARAGON could not search for places now. Check the connection and try again."
            }
            searching = false
        }
    }

    private func save() {
        guard let chosen else { return }
        let place = ReminderPlace(name: chosen.name, latitude: chosen.latitude,
                                  longitude: chosen.longitude, arriving: arriving)
        model.setPlace(place, for: ref)
        isPresented = false
    }
}

// MARK: - Person

/// Names from Contacts. Asked for only when a button here is pressed.
enum ContactNames {
    /// Names matching the words, and whether Contacts said no.
    @MainActor
    static func search(_ text: String) async -> (names: [String], denied: Bool) {
        let words = text.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return ([], false) }
        let store = CNContactStore()
        do {
            let granted: Bool = try await store.requestAccess(for: .contacts)
            guard granted else { return ([], true) }
            let keys: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor,
                                           CNContactFamilyNameKey as CNKeyDescriptor,
                                           CNContactOrganizationNameKey as CNKeyDescriptor]
            let contacts: [CNContact] = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: words),
                                                                  keysToFetch: keys)
            let names: [String] = contacts.prefix(8).map { ContactNames.name(of: $0) }.filter { !$0.isEmpty }
            return (names, false)
        } catch {
            return ([], true)
        }
    }

    static func name(of contact: CNContact) -> String {
        let person: String = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        return person.isEmpty ? contact.organizationName : person
    }
}

#if os(iOS)
/// Apple's own contact picker. It runs outside PARAGON and needs no permission.
struct ContactPickerSheet: UIViewControllerRepresentable {
    let onPick: (String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String) -> Void
        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(ContactNames.name(of: contact))
        }
    }
}
#endif

/// Apple's contact picker as a sheet on the iPhone and iPad. Nothing on the Mac, which searches
/// Contacts with a button instead. A modifier of its own so no `#if` sits in a modifier chain.
struct ContactSheet: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: (String) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.sheet(isPresented: $isPresented) {
            ContactPickerSheet { name in
                isPresented = false
                onPick(name)
            }
        }
        #else
        content
        #endif
    }
}

/// Choosing people: for a task one person, for a note any number. **Cancel** and **Save** are
/// along the top. Saving with nobody chosen takes the link away.
struct PersonChooserView: View {
    @EnvironmentObject private var model: AppModel
    let heading: String
    let allowsSeveral: Bool
    let initial: [String]
    let idPrefix: String
    let onSave: ([String]) -> Void
    @Binding var isPresented: Bool
    @State private var picked: [String] = []
    @State private var typed = ""
    @State private var known: [String] = []
    @State private var found: [String] = []
    @State private var contactsMessage: String?
    @State private var showContacts = false
    @FocusState private var focused: Bool

    private var tint: Color { SidebarSection.tags.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(heading)
                    .font(Txt.listTitle)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("\(idPrefix).cancel")
                Button("Save") {
                    onSave(picked)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("\(idPrefix).save")
            }
            HStack(spacing: 6) {
                TextField("Name", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(addTyped)
                    .accessibilityIdentifier("\(idPrefix).field")
                Button("Add", action: addTyped)
                    .disabled(PersonName.clean(typed) == nil)
                    .accessibilityIdentifier("\(idPrefix).add")
            }
            contactsRow
            if !picked.isEmpty {
                Text("Chosen")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(picked, id: \.self) { name in
                        PickChip(title: name, isOn: true, tint: tint) { remove(name) }
                            .accessibilityIdentifier("\(idPrefix).chosen.\(name)")
                    }
                }
            }
            if !others.isEmpty {
                Text("People you already use")
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                WrappingHStack(spacing: 6, lineSpacing: 6) {
                    ForEach(others, id: \.self) { name in
                        PickChip(title: name, isOn: false, tint: tint) { choose(name) }
                            .accessibilityIdentifier("\(idPrefix).choice.\(name)")
                    }
                }
            }
            Text("Nobody chosen and Save takes the link away.")
                .font(Txt.label)
                .foregroundStyle(.soft)
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
        .onAppear {
            picked = initial
            known = model.index.peopleNames()
            DispatchQueue.main.async { focused = true }
        }
        .modifier(ContactSheet(isPresented: $showContacts) { name in choose(name) })
    }

    /// The people already used that are not chosen yet. A dozen is plenty; anyone else is typed.
    private var others: [String] {
        let taken = Set(picked.map { PersonName.key($0) })
        return Array(known.filter { !taken.contains(PersonName.key($0)) }.prefix(12))
    }

    @ViewBuilder
    private var contactsRow: some View {
        #if os(iOS)
        Button { showContacts = true } label: { MarkLabel("Choose from Contacts…", "person.linked") }
            .accessibilityIdentifier("\(idPrefix).contacts")
        #else
        Button {
            findInContacts()
        } label: {
            MarkLabel("Search Contacts", "person.linked")
        }
        .disabled(PersonName.clean(typed) == nil)
        .accessibilityIdentifier("\(idPrefix).contacts")
        #endif
        if let contactsMessage {
            Text(contactsMessage)
                .font(Txt.label)
                .foregroundStyle(.soft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(idPrefix).contactsMessage")
        }
        ForEach(found, id: \.self) { name in
            Button { choose(name) } label: {
                Text(name).font(Txt.listTitle)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(idPrefix).found.\(name)")
        }
    }

    private func findInContacts() {
        contactsMessage = nil
        Task { @MainActor in
            let result = await ContactNames.search(typed)
            found = result.names
            if result.denied {
                contactsMessage = "Contacts did not allow it. You can type the name instead, or allow PARAGON in System Settings."
            } else if result.names.isEmpty {
                contactsMessage = "Nobody in Contacts has that name."
            }
        }
    }

    private func addTyped() {
        guard let name = PersonName.clean(typed) else { return }
        choose(name)
        typed = ""
    }

    private func choose(_ raw: String) {
        guard let name = PersonName.clean(raw) else { return }
        if allowsSeveral {
            if !picked.contains(where: { PersonName.key($0) == PersonName.key(name) }) { picked.append(name) }
        } else {
            picked = [name]
        }
    }

    private func remove(_ name: String) {
        picked.removeAll { PersonName.key($0) == PersonName.key(name) }
    }
}

/// **Person…** in a note's header: the people the whole note is about.
struct NotePeopleChip: View {
    @ObservedObject var model: AppModel
    let note: Note
    @State private var showing = false

    /// Read back from the model: a save reloads, and the copy handed in is then one behind.
    private var live: Note { model.note(at: note.relativePath) ?? note }

    private var title: String {
        let names: [String] = live.people
        return names.isEmpty ? "Person…" : names.joined(separator: ", ")
    }

    var body: some View {
        Button {
            showing = true
        } label: {
            MarkLabel(title, "person.linked")
                .lineLimit(1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .foregroundStyle(live.people.isEmpty ? Theme.soft : SidebarSection.tags.tint.ink)
        .frame(maxWidth: 260)
        .accessibilityIdentifier("note.people")
        .popover(isPresented: $showing) {
            PersonChooserView(heading: "People in this note", allowsSeveral: true, initial: live.people,
                              idPrefix: "note.people.choose", onSave: { names in
                model.setNotePeople(names, on: live)
            }, isPresented: $showing)
        }
    }
}

// MARK: - On a task row

/// Which of the two windows a task's menu opens (one binding on the row for both).
enum TaskLinkWindow: String, Identifiable {
    case place
    case person
    var id: String { rawValue }
}

/// The two windows, hung off a view with one `.popover(item:)`.
struct TaskLinkWindows: ViewModifier {
    let ref: TaskRef
    @Binding var window: TaskLinkWindow?

    func body(content: Content) -> some View {
        content.popover(item: $window) { which in
            TaskLinkWindowContent(ref: ref, which: which, window: $window)
        }
    }
}

private struct TaskLinkWindowContent: View {
    @EnvironmentObject private var model: AppModel
    let ref: TaskRef
    let which: TaskLinkWindow
    @Binding var window: TaskLinkWindow?

    private var shown: Binding<Bool> {
        Binding(get: { window != nil }, set: { if !$0 { window = nil } })
    }

    var body: some View {
        switch which {
        case .place:
            PlaceSearchView(ref: ref, isPresented: shown)
        case .person:
            PersonChooserView(heading: "Who is it about?", allowsSeveral: false,
                              initial: ref.task.person.map { [$0] } ?? [],
                              idPrefix: "task.person", onSave: { names in
                model.setPerson(names.first, for: ref)
            }, isPresented: shown)
        }
    }
}

// MARK: - The People page

/// The two parts of the Tags screen, as a switch along its top.
struct TagsPeopleSwitch: View {
    @Binding var showPeople: Bool

    var body: some View {
        Picker("Show", selection: $showPeople) {
            Text("Tags").tag(false)
            Text("People").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("tags.people.switch")
    }
}

/// Every person, with all their tasks and notes. A person opens in place, as a tag does: a
/// plain list, every header a button, nothing tagged for selection (builds 71 to 74 and 143).
struct PeopleView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showPeople: Bool
    @State private var opened: Set<String> = []

    private var people: [PersonEntry] { model.index.people() }

    var body: some View {
        VStack(spacing: 0) {
            TagsPeopleSwitch(showPeople: $showPeople)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            if people.isEmpty {
                EmptyStateView(title: "No people yet",
                               markName: "person.linked",
                               message: "Choose Person… on a task's menu or in a note's header to link it to someone in your Contacts. Everything linked to one person is then here.",
                               tint: SidebarSection.tags.tint,
                               hint: "Choose Person… on a task's menu or in a note's header")
                    .accessibilityIdentifier("people.empty")
            } else {
                List {
                    ForEach(people) { person in
                        Section {
                            if opened.contains(person.id) { contents(of: person) }
                        } header: {
                            header(for: person)
                        }
                    }
                    .phoneCard(SidebarSection.tags.tint)
                }
                .accessibilityIdentifier("people.list")
            }
        }
        .navigationTitle("People")
    }

    private func header(for person: PersonEntry) -> some View {
        let isOpen: Bool = opened.contains(person.id)
        return Button {
            withAnimation(Motion.fold) { toggle(person.id) }
        } label: {
            HStack(spacing: 8) {
                MarkImage(isOpen ? "chevron.down" : "chevron.right", text: .footnote)
                    .foregroundStyle(.soft)
                    .frame(width: 12)
                Text(person.name)
                    .font(Txt.listTitle)
                    .foregroundStyle(SidebarSection.tags.tint.ink)
                Spacer(minLength: 6)
                Text(person.summary)
                    .font(Txt.label)
                    .foregroundStyle(.soft)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityIdentifier("people.person.\(person.name)")
    }

    @ViewBuilder
    private func contents(of person: PersonEntry) -> some View {
        if person.notes.isEmpty && person.open.isEmpty {
            Text("Nothing open is linked to this person")
                .font(Txt.label)
                .foregroundStyle(.soft)
        }
        ForEach(person.notes) { note in
            Button {
                model.show(section: .tags, notePath: note.relativePath)
            } label: {
                HStack(spacing: 8) {
                    KindBadge(kind: note.declaredKind, size: 18)
                    Text(note.displayTitle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        ForEach(person.open) { ref in
            TaskRow(ref: ref, showNote: true) { model.toggle(ref) }
        }
    }

    private func toggle(_ id: String) {
        if opened.contains(id) {
            opened.remove(id)
        } else {
            opened.insert(id)
        }
    }
}
