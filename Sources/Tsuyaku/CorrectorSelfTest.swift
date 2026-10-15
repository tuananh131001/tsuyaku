import Foundation

/// Checks glossary correction on the live path with scripted rows, a scripted
/// rewriter and a fake clock, against a real store: each row's English and
/// colour flag, what reaches the transcript and when. No Apple Intelligence,
/// no network, no waiting.
///
/// Run with `Tsuyaku --store-selftest` (via `make test`).
@MainActor
enum CorrectorSelfTest {

    private static var failures = 0

    static func run() async -> Int {
        failures = 0
        print("\n=== glossary correction self-test ===")
        await rowWithoutATermPassesThrough()
        await rowWithATermIsCorrected()
        await termInThePreviousRowTriggers()
        await unchangedEnglishIsNotCorrected()
        await confusedRewritesAreRejected()
        await slowCorrectionReleasesAtTheLimit()
        await fastSpeechSkipsStaleRows()
        await englishEchoIsNeverRewritten()
        await stopSettlesHeldRowsOnce()
        await emptyGlossaryDoesNoWork()
        return failures
    }

    private static let glossary = Glossary(entries: ["ラクスル": "Raksul", "見積": "quote"])

    private static func rowWithoutATermPassesThrough() async {
        let h = Harness(glossary)
        h.row("本日はよろしくお願いします。", "Thank you for today.")
        await h.corrector.idle()
        expect("a row without a term settles at once, untouched",
               h.settled.map(\.english) == ["Thank you for today."]
               && h.settled.first?.at == .zero && h.calls.isEmpty)
    }

    private static func rowWithATermIsCorrected() async {
        let h = Harness(glossary)
        h.replies = [.text("This is Raksul's quote.")]
        h.row("ラクスルの見積です。", "This is Lacsul's estimate.")
        expect("the row shows Gemini's English straight away",
               h.store.live.first?.target == "This is Lacsul's estimate." && h.settled.isEmpty)
        await h.corrector.idle()
        expect("its English is replaced and marked corrected",
               h.store.history.first?.target == "This is Raksul's quote."
               && h.store.history.first?.corrected == true)
        expect("the transcript gets the corrected English",
               h.settled.map(\.english) == ["This is Raksul's quote."])
        expect("Copy Transcript too, with no marker",
               h.store.transcriptMarkdown.contains("> ラクスルの見積です。\n\nThis is Raksul's quote.\n\n")
               && !h.store.transcriptMarkdown.contains("Lacsul"))
    }

    /// Row boundaries come from the English, so the Japanese for a term can
    /// land in the row before the one whose English carries it.
    private static func termInThePreviousRowTriggers() async {
        let h = Harness(glossary)
        h.replies = [.unchanged, .text("This is Raksul's new service.")]
        h.row("始めましょう。ラクスル", "Let's begin.")
        h.row("の新サービスです。", "This is Lacsul's new service.")
        await h.corrector.idle()
        expect("the next row is sent with the previous row's Japanese",
               h.calls.count == 2 && h.calls[1].previous == "始めましょう。ラクスル")
        expect("and corrected",
               h.settled.map(\.english) == ["Let's begin.", "This is Raksul's new service."]
               && h.settled.map(\.corrected) == [false, true])
    }

    private static func unchangedEnglishIsNotCorrected() async {
        let h = Harness(glossary)
        h.replies = [.unchanged]
        h.row("見積をお願いします。", "Please send an estimate.")
        await h.corrector.idle()
        expect("English returned as it was is not marked corrected",
               h.calls.count == 1 && h.settled.first?.corrected == false
               && h.settled.first?.english == "Please send an estimate.")
    }

    private static func confusedRewritesAreRejected() async {
        let h = Harness(glossary)
        h.replies = [
            .text("Please send an offer."),
            .text("Please send a quote for the new printing service we discussed last week."),
            .text(""),
        ]
        h.row("見積をお願いします。", "Please send an estimate.")
        h.row("見積を送ります。", "I'll send the estimate.")
        h.row("見積は以上です。", "That's the estimate.")
        await h.corrector.idle()
        expect("a rewrite without the glossary's English, a long one, or none is rejected",
               h.calls.count == 3
               && h.settled.map(\.english) == ["Please send an estimate.",
                                               "I'll send the estimate.",
                                               "That's the estimate."]
               && h.settled.allSatisfy { !$0.corrected })
    }

    private static func slowCorrectionReleasesAtTheLimit() async {
        let h = Harness(glossary)
        h.replies = [.hang]
        h.row("ラクスルです。", "This is Lacsul.")
        await h.untilHanging()
        h.advance(2.5)
        h.corrector.tick()
        expect("a held row stays out of the transcript inside the limit", h.settled.isEmpty)
        h.advance(0.5)
        h.corrector.tick()
        expect("it settles with Gemini's English at 3 s",
               h.settled.map(\.english) == ["This is Lacsul."]
               && h.settled.first?.at == .seconds(3))
        h.resume("This is Raksul.")
        await h.corrector.idle()
        expect("and a late correction is ignored",
               h.settled.count == 1 && h.store.history.first?.target == "This is Lacsul."
               && h.store.history.first?.corrected == false)
    }

    private static func fastSpeechSkipsStaleRows() async {
        let h = Harness(glossary)
        h.replies = [.after(2, "Raksul one."), .after(2, "Raksul two."), .text("Raksul three.")]
        h.row("ラクスル一。", "Lacsul one.")
        h.row("ラクスル二。", "Lacsul two.")
        h.row("ラクスル三。", "Lacsul three.")
        await h.corrector.idle()
        expect("corrections run one at a time", h.mostAtOnce == 1)
        expect("a correction past the limit is dropped, and a stale row is skipped",
               h.calls.count == 2
               && h.settled.map(\.english) == ["Raksul one.", "Lacsul two.", "Lacsul three."]
               && h.settled.map(\.corrected) == [true, false, false])
    }

    private static func englishEchoIsNeverRewritten() async {
        let h = Harness(glossary)
        h.row("Lacsul is a printing company.", "", language: .en)
        await h.corrector.idle()
        expect("an English echo row is never sent to the rewriter",
               h.calls.isEmpty && h.settled.map(\.english) == ["Lacsul is a printing company."])
    }

    private static func stopSettlesHeldRowsOnce() async {
        let h = Harness(glossary)
        h.replies = [.hang]
        h.row("ラクスルです。", "This is Lacsul.")
        h.row("見積です。", "It's an estimate.")
        await h.untilHanging()
        h.corrector.flush()
        expect("Stop settles every held row with the English it has",
               h.settled.map(\.english) == ["This is Lacsul.", "It's an estimate."])
        h.resume("This is Raksul.")
        await h.corrector.idle()
        h.corrector.flush()
        expect("and each exactly once", h.settled.count == 2 && h.calls.count == 1)
    }

    private static func emptyGlossaryDoesNoWork() async {
        let h = Harness(.empty)
        h.row("ラクスルの見積です。", "This is Lacsul's estimate.")
        await h.corrector.idle()
        expect("an empty glossary means no rewriter calls",
               h.calls.isEmpty && h.settled.count == 1)
    }

    private static func expect(_ what: String, _ ok: Bool) {
        print("  \(ok ? "ok  " : "FAIL") \(what)")
        if !ok { failures += 1 }
    }
}

/// A real store and corrector, a clock that moves only when told to, and a
/// rewriter that plays one reply per call.
@MainActor
private final class Harness {

    enum Reply {
        case text(String)
        case unchanged
        /// Moves the clock on by this many seconds before answering.
        case after(Double, String)
        /// Answers only when `resume` is called.
        case hang
    }

    struct Settled {
        let english: String
        let corrected: Bool
        let at: Duration
    }

    let store = SubtitleStore()
    var corrector: GlossaryCorrector!
    var replies: [Reply] = []
    private(set) var calls: [(previous: String, source: String, english: String)] = []
    private(set) var settled: [Settled] = []
    private(set) var mostAtOnce = 0
    private var inFlight = 0
    private var hanging: CheckedContinuation<String?, Never>?
    private let t0 = ContinuousClock.now
    private var time: ContinuousClock.Instant

    init(_ glossary: Glossary) {
        time = t0
        store.onSettled = { [unowned self] rows in
            for r in rows {
                settled.append(Settled(english: r.language == .en ? r.source : r.target,
                                       corrected: r.corrected, at: time - t0))
            }
        }
        corrector = GlossaryCorrector(store: store, glossary: glossary,
                                      now: { [unowned self] in time },
                                      rewrite: { @MainActor [unowned self] _, previous, source, english in
                                          await reply(previous: previous, source: source, english: english)
                                      })
    }

    func row(_ source: String, _ english: String, language: SpokenLanguage = .ja) {
        let id = UUID()
        var ops: [LiveRowSegmenter.Op] = [.begin(id, language), .source(id, source)]
        if !english.isEmpty { ops.append(.target(id, english)) }
        ops.append(.finish(id))
        corrector.apply(ops)
    }

    func advance(_ seconds: Double) {
        time = time.advanced(by: .milliseconds(Int(seconds * 1000)))
    }

    func untilHanging() async {
        while hanging == nil { await Task.yield() }
    }

    func resume(_ english: String?) {
        hanging?.resume(returning: english)
        hanging = nil
    }

    private func reply(previous: String, source: String, english: String) async -> String? {
        calls.append((previous, source, english))
        inFlight += 1
        mostAtOnce = max(mostAtOnce, inFlight)
        defer { inFlight -= 1 }
        let next = replies.isEmpty ? .unchanged : replies.removeFirst()
        await Task.yield()
        switch next {
        case .text(let t):
            return t
        case .unchanged:
            return english
        case .after(let seconds, let t):
            advance(seconds)
            return t
        case .hang:
            return await withCheckedContinuation { hanging = $0 }
        }
    }
}
