import Foundation
import OSLog

/// Glossary correction for the live path, between `LiveRowSegmenter` and the
/// store.
///
/// Gemini's translate model takes no instructions, so it cannot be handed the
/// glossary; ラクスル comes out "Lacsul". Every row op passes through to the
/// store untouched, so subtitles appear exactly as fast as before. What this
/// adds happens when a Japanese row closes. Every one is checked, not only
/// those whose Japanese has a glossary term: Gemini's transcript often
/// mishears the term itself (ラクスール, ラクス), and then nothing would match.
///
///   - **Hold.** The row is marked provisional before it finishes, so it
///     stays in the live pane and out of the transcript.
///   - **Queue.** One correction at a time, in order. There is no time
///     limit: every row waits for its correction, however long it takes.
///   - **Release.** The row settles when its correction lands, so the
///     transcript always gets the corrected English. Stop settles the rest.
///
/// A rewrite is accepted only if it differs, adds the English of a glossary
/// term that Gemini's line lacked, and keeps roughly the original length. So
/// a corrected row always means a term was fixed, never a restyled sentence.
///
/// A rewrite that fails leaves the row with Gemini's English and settles it.
/// The first failure of a session says why in the header; later ones are
/// only logged, so a bad stretch doesn't flood it.
@MainActor
final class GlossaryCorrector {

    /// (terms, previous row's Japanese, row's Japanese, row's English) ->
    /// the corrector's English.
    typealias Rewriter = CloudRewriter.Call

    private let log = Logger(subsystem: "com.loind.tsuyaku", category: "glossary-correction")

    private struct Held {
        let id: UUID
        let previous: String
        let source: String
        let english: String
    }

    private let store: SubtitleStore
    private let glossary: Glossary
    private let rewrite: Rewriter

    /// Rows waiting for a correction, in the order they closed.
    private var queue: [Held] = []
    /// Rows kept out of the transcript, in the order they closed, so they
    /// are released into it in the conversation's order.
    private var held: [UUID] = []
    private var worker: Task<Void, Never>?
    /// Bumped by `flush`, so an abandoned worker cannot clear its successor.
    private var generation = 0
    /// The Japanese of the last row to close; empty after an English one.
    private var previousSource = ""
    /// One corrector per session, so this is "told once per session".
    private var failureShown = false

    init(store: SubtitleStore,
         glossary: Glossary,
         rewrite: @escaping Rewriter) {
        self.store = store
        self.glossary = glossary
        self.rewrite = rewrite
    }

    func apply(_ ops: [LiveRowSegmenter.Op]) {
        for op in ops {
            if case .finish(let id) = op { closing(id) }
            store.apply([op])
        }
    }

    /// Settles every held row, for Stop: the transcript closes right after.
    /// A correction still running is abandoned.
    func flush() {
        worker?.cancel()
        worker = nil
        generation &+= 1
        queue.removeAll()
        for id in held { release(id) }
        previousSource = ""
    }

    /// Resolves once the queue is empty. For the self-test.
    func idle() async {
        while let worker { await worker.value }
    }

    // MARK: -

    private func closing(_ id: UUID) {
        guard let row = store.live.last(where: { $0.utterance == id }) else { return }
        let previous = previousSource
        guard row.language != .en else {
            // The echo is what was actually said; it is never rewritten.
            previousSource = ""
            return
        }
        previousSource = row.source
        guard !glossary.isEmpty, !row.failed, !row.target.isEmpty else { return }

        store.hold(utterance: id)
        held.append(id)
        queue.append(Held(id: id, previous: previous, source: row.source, english: row.target))
        if worker == nil {
            let generation = generation
            worker = Task { [weak self] in await self?.drain(generation) }
        }
    }

    private func drain(_ generation: Int) async {
        defer { if self.generation == generation { worker = nil } }
        while !Task.isCancelled, !queue.isEmpty {
            let next = queue.removeFirst()
            guard isHeld(next.id) else { continue }
            let result: String?
            do {
                result = try await rewrite(glossary, next.previous, next.source, next.english)
            } catch {
                result = nil
                if !Task.isCancelled { failed(error) }
            }
            guard !Task.isCancelled, isHeld(next.id) else { continue }
            if let english = Self.accept(result, original: next.english, glossary: glossary) {
                store.correct(utterance: next.id, english: english)
            }
            release(next.id)
        }
    }

    private func failed(_ error: Error) {
        log.error("correction failed: \(error.localizedDescription, privacy: .public)")
        guard !failureShown else { return }
        failureShown = true
        store.flashNotice("Glossary correction failed: \(error.localizedDescription)", for: 10)
    }

    private func isHeld(_ id: UUID) -> Bool {
        held.contains(id)
    }

    private func release(_ id: UUID) {
        guard let i = held.firstIndex(of: id) else { return }
        held.remove(at: i)
        store.settle(utterance: id)
    }

    /// The rewrite to show, or nil to keep `original`.
    nonisolated static func accept(_ result: String?, original: String, glossary: Glossary) -> String? {
        guard let english = result?.trimmingCharacters(in: .whitespacesAndNewlines),
              !english.isEmpty, english != original,
              glossary.entries.values.contains(where: {
                  contains(english, $0) && !contains(original, $0)
              })
        else { return nil }
        // About 30%, with a few characters of slack so a short line can
        // still swap "estimate" for "quote".
        let length = original.count
        let slack = max(Double(length) * 0.3, 6)
        guard Double(abs(english.count - length)) <= slack else { return nil }
        return english
    }

    nonisolated private static func contains(_ text: String, _ term: String) -> Bool {
        text.range(of: term, options: .caseInsensitive) != nil
    }
}
