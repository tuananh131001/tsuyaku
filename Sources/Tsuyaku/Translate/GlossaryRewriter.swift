import Foundation
import FoundationModels
import OSLog

/// The rewriter behind `GlossaryCorrector`: Apple Intelligence, on the Mac,
/// so no meeting text goes to another service and nothing costs extra.
///
/// Same model setup as `FoundationModelTranslator`, and a fresh session per
/// row so nothing carries over between corrections. Whether the answer is
/// good enough to use is the corrector's call, not this one's.
enum GlossaryRewriter {

    private static let log = Logger(subsystem: "com.loind.tsuyaku", category: "glossary-correction")

    static var isAvailable: Bool { FoundationModelTranslator.isAvailable }

    static let rewrite: GlossaryCorrector.Rewriter = { terms, previous, source, english in
        guard isAvailable else { return nil }
        let session = LanguageModelSession(model: FoundationModelTranslator.model,
                                           instructions: instructions(terms))
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 256)
        do {
            return try await session.respond(to: prompt(previous: previous, source: source, english: english),
                                             options: options).content
        } catch {
            log.error("correction failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The terms go in as the same "Fixed terminology" lines every LLM backend
    /// prompt carries, so they read the same everywhere.
    static func instructions(_ terms: Glossary) -> String {
        """
        You proofread English subtitles translated from Japanese speech.

        Rules:
        - Fix ONLY words that render a fixed term below wrongly: a misspelled \
        name, or a synonym in place of the required English.
        - Change nothing else. Keep every other word, the word order and the \
        punctuation exactly as they are.
        - If no fixed term is rendered wrongly, return the English unchanged.
        - Output ONLY the English line. No preamble, no notes, no quotes.

        Fixed terminology (use exactly):
        \(terms.promptLines)
        """
    }

    private static func prompt(previous: String, source: String, english: String) -> String {
        var p = ""
        if !previous.isEmpty { p += "Previous Japanese:\n\(previous)\n\n" }
        p += "Japanese:\n\(source)\n\nEnglish:\n\(english)"
        return p
    }
}
