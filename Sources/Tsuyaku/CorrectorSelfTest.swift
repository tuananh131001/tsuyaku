import Foundation

/// Checks glossary correction on the live path with scripted rows, a scripted
/// rewriter and a fake clock, against a real store: each row's English and
/// colour flag, what reaches the transcript and when, and the header notice.
/// No network, no waiting.
///
/// Run with `Tsuyaku --store-selftest` (via `make test`).
@MainActor
enum CorrectorSelfTest {

    private static var failures = 0

    static func run() async -> Int {
        failures = 0
        print("\n=== glossary correction self-test ===")
        await rowWithoutATermIsChecked()
        await misheardTermIsCorrected()
        await rowWithATermIsCorrected()
        await rowAlreadyUsingTheTermIsChecked()
        await termInThePreviousRowTriggers()
        await unchangedEnglishIsNotCorrected()
        await confusedRewritesAreRejected()
        await rewriteAddingNoNewTermIsRejected()
        await slowCorrectionIsWaitedFor()
        await fastSpeechCorrectsEveryRow()
        await englishEchoIsNeverRewritten()
        await stopSettlesHeldRowsOnce()
        await emptyGlossaryDoesNoWork()
        await failedCorrectionSettlesGeminisEnglish()
        await failureIsToldOncePerSession()
        await rowAfterAFailureIsStillCorrected()
        onlyRewrittenWordsAreMarked()
        return failures
    }

    private static let glossary = Glossary(entries: ["ラクスル": "Raksul", "見積": "quote"])

    private static func rowWithoutATermIsChecked() async {
        let h = Harness(glossary)
        h.replies = [.hang]
        h.row("本日はよろしくお願いします。", "Thank you for today.")
        await h.untilHanging()
        expect("a row without an exact term is sent, and held meanwhile",
               h.calls.map(\.source) == ["本日はよろしくお願いします。"] && h.settled.isEmpty)
        h.resume("Thank you for today.")
        await h.corrector.idle()
        expect("an unchanged reply settles it untouched",
               h.settled.map(\.english) == ["Thank you for today."]
               && h.settled.first?.corrected == false && h.settled.first?.at == .zero)
    }

    /// Gemini's Japanese misheard the term, so it has no exact match.
    private static func misheardTermIsCorrected() async {
        let h = Harness(glossary)
        h.replies = [.text("This is Raksul's new service.")]
        h.row("ラクスールの新サービスです。", "This is Lacsul's new service.")
        await h.corrector.idle()
        expect("a misheard term is still corrected",
               h.settled.map(\.english) == ["This is Raksul's new service."]
               && h.settled.first?.corrected == true)
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
        expect("the row keeps the original English",
               h.store.history.first?.originalTarget == "This is Lacsul's estimate.")
        expect("the transcript gets the corrected English",
               h.settled.map(\.english) == ["This is Raksul's quote."])
        expect("Copy Transcript too, with no marker",
               h.store.transcriptMarkdown.contains("> ラクスルの見積です。\n\nThis is Raksul's quote.\n\n")
               && !h.store.transcriptMarkdown.contains("Lacsul"))
        expect("the saved transcript has no original English either",
               h.saved.contains("This is Raksul's quote.") && !h.saved.contains("Lacsul"))
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

    /// It may hold a second, misheard term.
    private static func rowAlreadyUsingTheTermIsChecked() async {
        let h = Harness(glossary)
        h.replies = [.text("Raksul will send the quote.")]
        h.row("ラクスルがミツモリを送ります。", "Raksul will send the estimate.")
        await h.corrector.idle()
        expect("a row whose English already has a term is still sent",
               h.calls.count == 1
               && h.settled.map(\.english) == ["Raksul will send the quote."]
               && h.settled.first?.corrected == true)
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

    private static func rewriteAddingNoNewTermIsRejected() async {
        let h = Harness(glossary)
        h.replies = [.text("Thanks for your time today."), .text("Raksul sent over the estimate.")]
        h.row("本日はよろしくお願いします。", "Thank you for today.")
        h.row("ラクスルが見積を送りました。", "Raksul sent the estimate.")
        await h.corrector.idle()
        expect("a restyled line with no glossary English is rejected, and one whose only glossary English was already there",
               h.calls.count == 2
               && h.settled.map(\.english) == ["Thank you for today.", "Raksul sent the estimate."]
               && h.settled.allSatisfy { !$0.corrected }
               && h.store.history.allSatisfy { $0.originalTarget == nil })
    }

    private static func slowCorrectionIsWaitedFor() async {
        let h = Harness(glossary)
        h.replies = [.hang]
        h.row("ラクスルです。", "This is Lacsul.")
        await h.untilHanging()
        h.advance(10)
        expect("a held row stays out of the transcript however long its correction takes",
               h.settled.isEmpty)
        h.resume("This is Raksul.")
        await h.corrector.idle()
        expect("and settles corrected when it lands",
               h.settled.map(\.english) == ["This is Raksul."]
               && h.settled.first?.corrected == true
               && h.settled.first?.at == .seconds(10))
    }

    private static func fastSpeechCorrectsEveryRow() async {
        let h = Harness(glossary)
        h.replies = [.after(4, "Raksul one."), .after(4, "Raksul two."), .text("Raksul three.")]
        h.row("ラクスル一。", "Lacsul one.")
        h.row("ラクスル二。", "Lacsul two.")
        h.row("ラクスル三。", "Lacsul three.")
        await h.corrector.idle()
        expect("corrections run one at a time", h.mostAtOnce == 1)
        expect("every row is corrected, in order, however late",
               h.calls.count == 3
               && h.settled.map(\.english) == ["Raksul one.", "Raksul two.", "Raksul three."]
               && h.settled.allSatisfy(\.corrected))
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

    private static func failedCorrectionSettlesGeminisEnglish() async {
        let h = Harness(glossary)
        h.replies = [.fail("HTTP 401: Invalid credential")]
        h.row("ラクスルです。", "This is Lacsul.")
        await h.corrector.idle()
        expect("a failed correction settles the row with Gemini's English, not corrected",
               h.settled.map(\.english) == ["This is Lacsul."]
               && h.settled.first?.corrected == false
               && h.store.history.first?.originalTarget == nil)
    }

    private static func failureIsToldOncePerSession() async {
        let h = Harness(glossary)
        h.replies = [.fail("HTTP 401: Invalid credential"), .fail("HTTP 429: quota used up")]
        h.row("ラクスルです。", "This is Lacsul.")
        await h.corrector.idle()
        expect("the first failure says correction failed, and why",
               h.store.notice == "Glossary correction failed: HTTP 401: Invalid credential")
        h.store.notice = nil
        h.row("見積です。", "It's an estimate.")
        await h.corrector.idle()
        expect("a second failure in the same session shows nothing new",
               h.calls.count == 2 && h.store.notice == nil && h.settled.count == 2)
    }

    private static func rowAfterAFailureIsStillCorrected() async {
        let h = Harness(glossary)
        h.replies = [.fail("timed out"), .text("This is Raksul.")]
        h.row("見積です。", "It's an estimate.")
        h.row("ラクスルです。", "This is Lacsul.")
        await h.corrector.idle()
        expect("the row after a failure is still sent, and corrected",
               h.calls.count == 2
               && h.settled.map(\.english) == ["It's an estimate.", "This is Raksul."]
               && h.settled.map(\.corrected) == [false, true])
    }

    private static func onlyRewrittenWordsAreMarked() {
        let runs = CorrectionDiff.runs(original: "This is Lacsul's estimate for you.",
                                       corrected: "This is Raksul's quote for you.")
        expect("only the words the corrector wrote are marked",
               runs.filter(\.changed).map(\.text) == ["Raksul's quote"]
               && runs.map(\.text).joined() == "This is Raksul's quote for you.")
        let same = CorrectionDiff.runs(original: "Hello there.", corrected: "Hello there.")
        expect("an unchanged line has nothing marked", same.allSatisfy { !$0.changed })
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
        /// Throws, as a rejected key or a timeout would.
        case fail(String)
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
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
    /// What the transcript file would get, row by row.
    private(set) var saved = ""
    private(set) var mostAtOnce = 0
    private var inFlight = 0
    private var hanging: CheckedContinuation<String, Never>?
    private let t0 = ContinuousClock.now
    private var time: ContinuousClock.Instant

    init(_ glossary: Glossary) {
        time = t0
        store.onSettled = { [unowned self] rows in
            for r in rows {
                saved += r.markdown(time: SubtitleLine.timeFormatter())
                settled.append(Settled(english: r.language == .en ? r.source : r.target,
                                       corrected: r.corrected, at: time - t0))
            }
        }
        corrector = GlossaryCorrector(store: store, glossary: glossary,
                                      rewrite: { @MainActor [unowned self] _, previous, source, english in
                                          try await reply(previous: previous, source: source, english: english)
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

    func resume(_ english: String) {
        hanging?.resume(returning: english)
        hanging = nil
    }

    private func reply(previous: String, source: String, english: String) async throws -> String {
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
        case .fail(let reason):
            throw Failure(errorDescription: reason)
        }
    }
}
