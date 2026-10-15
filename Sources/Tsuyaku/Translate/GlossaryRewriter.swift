import Foundation

/// What `GlossaryCorrector` asks a model: the instructions, with the whole
/// glossary, and the per-row prompt. The model behind it is OpenCode Go
/// (`CloudRewriter.opencodeGo`).
enum GlossaryRewriter {

    /// The terms go in as the same "Fixed terminology" lines every LLM backend
    /// prompt carries, so they read the same everywhere.
    static func instructions(_ terms: Glossary) -> String {
        """
        You proofread English subtitles translated from Japanese speech.

        Rules:
        - Fix ONLY words that render a fixed term below wrongly: a misspelled \
        name, or a synonym in place of the required English.
        - A fixed term may be misheard or misspelled, in the Japanese (for \
        example ラクスール or ラクス for ラクスル) and in the English (for \
        example "Lacsul" or "Lux" for "Raksul"). A near-match in sound counts \
        as that term.
        - Change nothing else. Keep every other word, the word order and the \
        punctuation exactly as they are.
        - If no fixed term is rendered wrongly, return the English unchanged.
        - Output ONLY the English line. No preamble, no notes, no quotes.

        Example, for the fixed term ラクスル = Raksul:
        Japanese: ラクスールの新しいサービスです。
        English: This is Lux's new service.
        Output: This is Raksul's new service.

        Fixed terminology (use exactly):
        \(terms.promptLines)
        """
    }

    static func prompt(previous: String, source: String, english: String) -> String {
        var p = ""
        if !previous.isEmpty { p += "Previous Japanese:\n\(previous)\n\n" }
        p += "Japanese:\n\(source)\n\nEnglish:\n\(english)"
        return p
    }
}
