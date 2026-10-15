import Foundation

/// Glossary correction for the live path, between `LiveRowSegmenter` and the
/// store.
///
/// Gemini's translate model takes no instructions, so it cannot be handed the
/// glossary; ラクスル comes out "Lacsul". Every row op passes through to the
/// store untouched, so subtitles appear exactly as fast as before. What this
/// adds happens when a Japanese row closes with a glossary term in its source,
/// or in the previous row's -- row boundaries come from the English, so a
/// row's Japanese can run a few words into the next sentence:
///
///   - **Hold.** The row is marked provisional before it finishes, so it
///     stays in the live pane and out of the transcript.
///   - **Queue.** One correction at a time, in order. A row whose turn comes
///     more than `limit` after it closed is skipped: fast speech must not
///     build a backlog behind the conversation.
///   - **Release.** The row settles when its correction lands, is skipped, or
///     runs past `limit`, whichever is first. A late correction is dropped.
///
/// A rewrite is accepted only if it differs, carries the English of a term
/// that triggered it, and keeps roughly the original length. Anything else
/// is a confused model, and Gemini's English stands.
///
/// The clock is injected and `tick` is driven from outside, like
/// `LiveRowSegmenter`, so `CorrectorSelfTest` runs without real waiting.
@MainActor
final class GlossaryCorrector {

    /// (terms, previous row's Japanese, row's Japanese, row's English) ->
    /// corrected English, or nil when there is nothing to offer.
    typealias Rewriter = @Sendable (Glossary, String, String, String) async -> String?

    private struct Held {
        let id: UUID
        let closedAt: ContinuousClock.Instant
        let terms: Glossary
        let previous: String
        let source: String
        let english: String
    }

    private let store: SubtitleStore
    private let glossary: Glossary
    private let limit: Duration
    private let now: () -> ContinuousClock.Instant
    private let rewrite: Rewriter

    /// Rows waiting for a correction, in the order they closed.
    private var queue: [Held] = []
    /// Rows kept out of the transcript, in the order they closed, so they
    /// are released into it in the conversation's order.
    private var held: [(id: UUID, closedAt: ContinuousClock.Instant)] = []
    private var worker: Task<Void, Never>?
    /// Bumped by `flush`, so an abandoned worker cannot clear its successor.
    private var generation = 0
    /// The Japanese of the last row to close; empty after an English one.
    private var previousSource = ""

    init(store: SubtitleStore,
         glossary: Glossary,
         limit: Duration = .seconds(3),
         now: @escaping () -> ContinuousClock.Instant = { .now },
         rewrite: @escaping Rewriter) {
        self.store = store
        self.glossary = glossary
        self.limit = limit
        self.now = now
        self.rewrite = rewrite
    }

    func apply(_ ops: [LiveRowSegmenter.Op]) {
        for op in ops {
            if case .finish(let id) = op { closing(id) }
            store.apply([op])
        }
    }

    /// Releases rows whose correction has run out of time.
    func tick() {
        let t = now()
        for row in held where t - row.closedAt >= limit {
            release(row.id)
        }
    }

    /// Settles every held row, for Stop: the transcript closes right after.
    /// A correction still running is abandoned.
    func flush() {
        worker?.cancel()
        worker = nil
        generation &+= 1
        queue.removeAll()
        for row in held { release(row.id) }
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
        guard !row.failed, !row.target.isEmpty else { return }

        let terms = glossary.entries.filter { row.source.contains($0.key) || previous.contains($0.key) }
        guard !terms.isEmpty else { return }
        // Every term already in its glossary form: nothing to correct.
        if terms.values.allSatisfy({ Self.contains(row.target, $0) }) { return }

        let closedAt = now()
        store.hold(utterance: id)
        held.append((id, closedAt))
        queue.append(Held(id: id, closedAt: closedAt, terms: Glossary(entries: terms),
                          previous: previous, source: row.source, english: row.target))
        if worker == nil {
            let generation = generation
            worker = Task { [weak self] in await self?.drain(generation) }
        }
    }

    private func drain(_ generation: Int) async {
        defer { if self.generation == generation { worker = nil } }
        while !Task.isCancelled, !queue.isEmpty {
            let next = queue.removeFirst()
            guard isHeld(next.id), now() - next.closedAt < limit else {
                release(next.id)
                continue
            }
            let result = await rewrite(next.terms, next.previous, next.source, next.english)
            guard !Task.isCancelled, isHeld(next.id) else { continue }
            if now() - next.closedAt <= limit,
               let english = Self.accept(result, for: next) {
                store.correct(utterance: next.id, english: english)
            }
            release(next.id)
        }
    }

    private func isHeld(_ id: UUID) -> Bool {
        held.contains { $0.id == id }
    }

    private func release(_ id: UUID) {
        guard let i = held.firstIndex(where: { $0.id == id }) else { return }
        held.remove(at: i)
        store.settle(utterance: id)
    }

    private static func accept(_ result: String?, for row: Held) -> String? {
        guard let english = result?.trimmingCharacters(in: .whitespacesAndNewlines),
              !english.isEmpty, english != row.english,
              row.terms.entries.values.contains(where: { contains(english, $0) })
        else { return nil }
        // About 30%, with a few characters of slack so a short line can
        // still swap "estimate" for "quote".
        let original = row.english.count
        let slack = max(Double(original) * 0.3, 6)
        guard Double(abs(english.count - original)) <= slack else { return nil }
        return english
    }

    private static func contains(_ text: String, _ term: String) -> Bool {
        text.range(of: term, options: .caseInsensitive) != nil
    }
}
