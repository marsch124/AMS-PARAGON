import SwiftUI
import ParagonCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// **Your year in one page** (round 350, pick 38). Reached from a button on the Done page; the
/// page takes the place of the diary until **Close**. Every number comes from Core's
/// `YearReview`, which reads only what the notes can prove (a `@done` stamp, an `ended:` day).
struct YourYearView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void

    @State private var year: Int = DateOnly.today().year
    @State private var review: YearReview = YearReview(year: DateOnly.today().year)
    @State private var range: ClosedRange<Int> = DateOnly.today().year...DateOnly.today().year
    @State private var sharedFile: SharedFile?

    private var tint: Color { SidebarSection.done.tint }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Close", action: close)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("year.close")
                    Spacer()
                    Button(action: share) {
                        Text("Share as PDF")
                    }
                    .buttonStyle(.filled(tint))
                    .accessibilityIdentifier("year.share")
                }
                HStack(spacing: 14) {
                    Button { step(-1) } label: {
                        MarkImage("chevron.left")
                    }
                    .disabled(year <= range.lowerBound)
                    .accessibilityLabel("Earlier year")
                    .accessibilityIdentifier("year.previous")
                    Text(verbatim: String(year))
                        .font(Txt.sectionTitle)
                        .foregroundStyle(tint.ink)
                        .accessibilityIdentifier("year.title")
                    Button { step(1) } label: {
                        MarkImage("chevron.right")
                    }
                    .disabled(year >= range.upperBound)
                    .accessibilityLabel("Later year")
                    .accessibilityIdentifier("year.next")
                    Spacer()
                }
                .buttonStyle(.borderless)
                YearReviewCard(review: review, onPaper: false)
                if !model.notesWaitingForCloud.isEmpty {
                    MarkLabel("Some notes are still coming from iCloud, so the year may be missing some of its days.", "icloud")
                        .font(Txt.label)
                        .foregroundStyle(Theme.attention.ink)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(SharesNoteFile(file: $sharedFile))
        .onAppear { work(model.index) }
        // The value handed in, never `model.index` (build 242).
        .onReceive(model.$index) { index in work(index) }
        .onChange(of: year) { _, _ in work(model.index) }
    }

    private func work(_ index: NoteIndex) {
        range = index.yearRange(today: DateOnly.today())
        review = index.yearReview(for: year)
    }

    private func step(_ by: Int) {
        let next = year + by
        guard range.contains(next) else { return }
        year = next
    }

    private func share() {
        guard let url = YearPDF.file(for: review) else {
            model.errorMessage = "PARAGON could not make the PDF. Nothing was changed."
            return
        }
        #if os(macOS)
        NoteSharing.present(url)
        #else
        sharedFile = SharedFile(url: url)
        #endif
    }
}

/// The year's facts, drawn the same on the screen and on paper. `onPaper` fixes the colours to
/// black on white, as the note's PDF does.
struct YearReviewCard: View {
    let review: YearReview
    var onPaper: Bool

    private var ink: Color { onPaper ? Color.black : Color.primary }
    private var quiet: Color { onPaper ? Color.gray : Color.secondary }
    private var tint: Color { onPaper ? Color(red: 0.0, green: 0.45, blue: 0.45) : SidebarSection.done.tint }

    /// Goals and projects listed at most this many each; the rest are counted.
    private static let listLimit = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: "Your year " + String(review.year))
                .font(Txt.pageTitle)
                .foregroundStyle(ink)
            if review.isEmpty {
                Text(verbatim: "Nothing dated in " + String(review.year) + " yet. A task you tick off, or a goal or project you mark Done, shows up here on the day it happened.")
                    .font(Txt.value)
                    .foregroundStyle(quiet)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                facts
                bars
                names(title: "Goals done", items: review.goals)
                names(title: "Projects finished", items: review.projects)
            }
        }
        // One element with one sentence, for VoiceOver and the screen test.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(review.spoken)
        .accessibilityIdentifier("year.card")
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let text = review.goalsText {
                Text(verbatim: text).font(Txt.value).foregroundStyle(ink)
            }
            if let text = review.projectsText {
                Text(verbatim: text).font(Txt.value).foregroundStyle(ink)
            }
            if let text = review.tasksText {
                Text(verbatim: text).font(Txt.value).foregroundStyle(ink)
            }
            if let text = review.busiestText {
                Text(verbatim: "Busiest month: " + text)
                    .font(Txt.label)
                    .foregroundStyle(quiet)
            }
        }
    }

    /// Twelve bars, one per month, tallest = the busiest month. A month with nothing is a flat
    /// stub, never a number 0 (build 255): the file cannot tell "nothing" from "not written".
    private var bars: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(1...12, id: \.self) { month in
                monthBar(month)
            }
        }
        .frame(height: 130)
    }

    private func monthBar(_ month: Int) -> some View {
        let count: Int = review.tasksByMonth[month - 1]
        let share: Double = Double(count) / Double(review.biggest)
        let isBusiest: Bool = review.busiestMonth == month
        let height: CGFloat = count == 0 ? 3 : max(5, 84 * CGFloat(share))
        let fill: Color = count == 0 ? quiet.opacity(0.35) : (isBusiest ? tint : tint.opacity(0.55))
        return VStack(spacing: 3) {
            Text(verbatim: count == 0 ? " " : String(count))
                .font(Txt.pill)
                .foregroundStyle(quiet)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(height: height)
            Text(verbatim: YearReview.shortMonth(month))
                .font(Txt.pill)
                .foregroundStyle(quiet)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func names(title: String, items: [EndedProject]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(Txt.listTitle)
                    .foregroundStyle(tint)
                ForEach(Array(items.prefix(Self.listLimit))) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: item.title)
                            .font(Txt.value)
                            .foregroundStyle(ink)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text(verbatim: item.ended.description)
                            .font(Txt.label)
                            .foregroundStyle(quiet)
                            .fixedSize()
                    }
                }
                if items.count > Self.listLimit {
                    Text(verbatim: "and " + String(items.count - Self.listLimit) + " more")
                        .font(Txt.label)
                        .foregroundStyle(quiet)
                }
            }
        }
    }
}

/// The year on paper: one page as wide as A4 and as tall as the year needs, always light.
@MainActor
enum YearPDF {
    static func data(for review: YearReview) -> Data? {
        let content = YearReviewCard(review: review, onPaper: true)
            .frame(width: 500, alignment: .leading)
            .padding(48)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        let data = NSMutableData()
        var produced: Data?
        renderer.render { size, draw in
            guard let consumer = CGDataConsumer(data: data) else { return }
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            produced = data as Data
        }
        return produced
    }

    /// A copy in the temporary folder, as the note's PDF is (never inside the notes folder).
    static func file(for review: YearReview) -> URL? {
        guard let data = data(for: review) else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PARAGON share", isDirectory: true)
        let url = folder.appendingPathComponent("PARAGON year " + String(review.year) + ".pdf")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
