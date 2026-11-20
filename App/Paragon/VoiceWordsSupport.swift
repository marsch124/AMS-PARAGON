#if os(iOS)
import Foundation
import FoundationModels
import ParagonCore

/// Round 350 (voice-words): what the recorder needs for the words he says out loud — the
/// saved list of odd words, the English switch, the note titles for `[[links]]`, and the
/// headings of a long thought. The rules are in Core (`VoiceWords`, `VoiceChapters`).

/// One small heading for a part of a long thought.
@available(iOS 26.0, *)
@Generable
struct VoiceChapterHeading {
    @Guide(description: "A heading of two to five words for this part of a spoken note.")
    var heading: String
}

@available(iOS 26.0, *)
extension VoiceRecorder {
    /// Settings › Voice › Words it mishears (JSON in one setting).
    static let wordsKey = "voiceWords"
    /// Settings › Voice › Summary in English.
    static let englishKey = "voiceSummaryEnglish"

    static func savedWords() -> [VoiceReplacement] {
        VoiceReplacement.decode(UserDefaults.standard.string(forKey: wordsKey) ?? "")
    }

    /// The switch is on, and it is offered (he speaks Swedish).
    static func wantsEnglish() -> Bool {
        let chosen = UserDefaults.standard.string(forKey: languageKey) ?? ""
        guard UserDefaults.standard.bool(forKey: englishKey) else { return false }
        return VoiceWords.offersEnglishSummary(voiceLanguage: chosen,
                                               phoneLanguageCode: Locale.current.language.languageCode?.identifier)
    }

    /// A long thought in parts, each under a small heading. Empty (the plain text stays) when
    /// the model is not there, or is too slow: the pass gives up after `seconds`.
    static func writeChapters(_ transcript: String, locale: Locale, english: Bool, within seconds: Double) async -> [VoiceChapter] {
        let chunks = VoiceChapters.chunks(of: transcript)
        guard !chunks.isEmpty else { return [] }
        let model = SystemLanguageModel.default
        guard model.availability == .available, model.supportsLocale(locale) else { return [] }
        let deadline = Date().addingTimeInterval(seconds)
        var headings: [String?] = []
        for chunk in chunks {
            if Date() >= deadline { return [] }
            let heading: String? = await chapterHeading(for: chunk, english: english)
            headings.append(heading)
        }
        return VoiceChapters.chapters(chunks: chunks, headings: headings)
    }

    private static func chapterHeading(for text: String, english: Bool) async -> String? {
        var instructions = "You give a short heading to a part of a spoken note. Use only what was said."
        if english {
            instructions += " Write the heading in English."
        } else {
            instructions += " Write the heading in the language of the note."
        }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let answer = try await session.respond(to: "The part of the note:\n\(String(text.prefix(3000)))",
                                                   generating: VoiceChapterHeading.self)
            return answer.content.heading
        } catch {
            return nil
        }
    }
}

extension AppModel {
    /// The titles a first mention of can become a `[[link]]`: projects, areas, resources and goals.
    func voiceLinkTitles() -> [String] {
        var out: [String] = []
        for note in notes {
            switch note.kind {
            case .project, .area, .resource, .goal:
                out.append(note.title)
            default:
                break
            }
        }
        return out
    }
}
#endif
