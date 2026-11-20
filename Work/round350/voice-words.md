# Round 350 lane voice-words

Nothing was compiled or run (no Swift here). Core rules are in `Core/Sources/ParagonCore/Vault/VoiceWords.swift`, tested in `Core/Tests/ParagonCoreTests/VoiceWordsTests.swift` (5 short tests). `VoiceThought.swift` got the new fields and the note layout.

## Picks
- **1 Dates spoken**: `VoiceThought.spokenTaskItems(in:now:calendar:)` -> `SpokenTask(title,date,time)`. today/tomorrow/day after tomorrow (en, de, sv), a weekday after a word ("on Friday", "next Monday", "am Freitag", "på måndag"; the first such day after today; a bare weekday like "about Saturday" stays words), "the 25th" / "den 25:e" / "am 25ten" (the next such date, today included). Day words are cut from the title. `finalTaskItems()` gives task lines with `>date`; the Inbox/daily tasks use them (`fileVoiceThoughtNote`). The note's Tasks list shows " (due 2026-11-27 15:00)". Not done: German "am 25." (the dot ends a sentence), number words ("three"), "tonight".
- **8 Times spoken**: "at 3", "at 3:30", "at 3 pm", "um 15 Uhr", "klockan 15" / "kl. 15". No am/pm: next 3:00 or 15:00 after now; both passed = tomorrow 03:00; with a spoken future day 1-6 = pm, 7-11 = am. "remind me" / "erinnere mich" / "påminn mig" make a task without the word "task". "Now" = start + length of the recording.
- **4 Tags**: a sentence starting "tag" / "tagga" + one word -> tag (frontmatter `tags: [voice, garden]`); phrase removed from the words. Risk: German "Tag" as a noun at a sentence start also matches.
- **9 Ideas**: sentence starting "idea" / "Idee" / "idé" -> `## Ideas` list between Tasks and Full text (the sentence also stays in the full text). `VoiceThought.enriched` was changed so a late summary's tasks go above Ideas.
- **17 Title**: "title ..." / "Titel ..." at the very start: up to 8 words (or the next sentence if the word stands alone) -> `spokenTitle`, wins over the model's.
- **14 Headings**: recordings >= 4 min or > 600 words. The text is cut in Core at sentence ends into at most 8 parts (`VoiceChapters.chunks`), the model gives one heading per part (`VoiceWordsSupport.swift`, `writeChapters`, 12 s limit); the full text shows `### heading` blocks; the text itself is never rewritten. Model off/slow: plain text.
- **16 Summary in English**: Settings > Voice, switch "Summary in English" (`settings.voiceEnglish`, key `voiceSummaryEnglish`), shown only when the voice language is Svenska, or the phone is Swedish and the voice language is the phone's. The model is told to answer in English; late summaries remember it (`LateSummary.english`).
- **18 Names to links**: `VoiceWords.linking`: first mention of each note title (project, area, resource, goal; >= 4 letters; whole words; case ignored; `[[Title|as said]]` when the case differs) in summary and full text. App passes `AppModel.voiceLinkTitles()`. Not in a late summary.
- **19 Odd words**: Settings > Voice > "Words it mishears" (`settings.voiceWords`) -> page `VoiceWordsPage` (Cancel `voiceWords.cancel`, Save `voiceWords.save`, "Add a word" `voiceWords.add`, fields `voiceWords.word` / `voiceWords.heard`, swipe to remove). JSON in key `voiceWords`. Used as contextual strings for the analyzer and as whole-word replacements in the text.
- **23 Stop recording**: "stop recording" / "stopp inspelning(en)" / "stoppa inspelning(en)" / "Aufnahme beenden/stoppen" at the end of a finalized result calls `stopAndFile()` once; the phrase is removed from the text (`removingStopPhrase`).

## Exact words on screen
Settings > Voice: "Summary in English", "Words it mishears", footer "The language you speak when you record a thought. Summary in English writes the title, summary and tasks in English; the full text stays as you said it." Page: title "Words it mishears"; placeholders "Word as it should be written", "Heard as (optional, separate with commas)"; "Add a word"; header "Words"; footer "Names and odd words you say. PARAGON listens for them, and puts them right when the speech-to-text writes them wrong. Swipe a row to remove it."; "Cancel", "Save". Note headings: "## Ideas", "### <heading>"; "(due YYYY-MM-DD HH:mm)".

## Files
Core: Vault/VoiceWords.swift (new), Vault/VoiceThought.swift (fields, `afterWord`, `taskText` rename of `taskWords(_:)`, noteText, enriched, filing). App: VoiceRecorder.swift (small edits: stop hook, readWords, contextual strings, chapters, english), VoiceWordsSupport.swift (new), Views/VoiceWordsPage.swift (new), Views/SettingsView.swift (VoiceSection). Test: ScreenTests.swift `testWordsItMishearsOpensAndCancels` (iPhone).

## Unsure to compile
- VoiceRecorder.swift (start): `AnalysisContext()`, `context.contextualStrings[.general]`, `analyzer.setContext(_:)` — from memory of the iOS 26 Speech API; if it fails to compile, delete the `hints` block (contextual strings are optional).
- VoiceWordsSupport.swift: top-level `@Generable struct` with `@Guide`; `Locale.current.language.languageCode?.identifier` (iOS 16+).
- VoiceRecorder.swift `writeUp(... english:)`: the model must support both the spoken language and en-US, else the write-up is skipped (as before without a model).
- Existing 349 tests still expect "Call Anna about Saturday" (bare weekday stays words) - written to keep them true.
- Merge: another lane edits VoiceRecorder.swift start/stop; my edits are small blocks marked "Round 350 (voice-words)".
