# Spec: Glossary correction for Gemini Live

**Status:** ready-for-agent

## Problem Statement

When I translate a meeting with the Gemini Live backend, my glossary is ignored. Company names and in-house terms come out wrong: ラクスル becomes "Lacsul" instead of "Raksul", and 見積 becomes "estimate" instead of "quote". Every other backend honours the glossary. Claude, DeepSeek, OpenCode Go, Ollama, Apple Intelligence and Qwen Omni get the terms in their prompt, and the on-device recognizer is biased towards them. Gemini Live's translate model takes no instructions and no text input, so there is no way to hand it the glossary. All the panel tells me is "Glossary not used". The wrong terms then end up in the saved transcript, which I reread and share after the meeting.

## Solution

Gemini Live keeps translating exactly as it does today, and each row appears straight away. When a finished row's Japanese, or the previous row's, contains a glossary term, Apple Intelligence on my Mac gets a short pass at the row's English. This is **glossary correction**. If the English rendered a glossary term wrongly, it is replaced by the glossary's English, changing only the wrong words. The row becomes a **corrected row**, and its English line turns a distinct colour (soft cyan), so I can tell it was changed.

The saved transcript gets the corrected English if the correction finishes within 3 seconds of the row closing. Otherwise it gets Gemini's English. Either way it carries no marker. The feature is always on whenever the glossary has entries and Apple Intelligence is available. On a Mac without Apple Intelligence, the panel says "Glossary needs Apple Intelligence on this backend" instead of "Glossary not used".

## User Stories

1. As a meeting attendee using Gemini Live, I want company names from my glossary rendered with the glossary's English, so that "Raksul" never shows up as "Lacsul".
2. As a meeting attendee using Gemini Live, I want in-house terms rendered with the glossary's English, so that 見積 reads "quote", the word my team uses, not "estimate".
3. As a meeting attendee, I want Gemini's English to appear as fast as it does today, so that the correction never makes the subtitles lag.
4. As a meeting attendee, I want a corrected row's English replaced in place, so that I don't read two versions of the same sentence.
5. As a meeting attendee, I want a corrected row shown in a distinct colour, so that I know its text changed after I first saw it.
6. As a meeting attendee, I want the whole English line of a corrected row coloured, not just the changed words, so that the change is easy to spot at a glance.
7. As a meeting attendee, I want rows without any glossary term left untouched and uncoloured, so that the colour means something.
8. As a meeting attendee, I want a row whose English already uses the right term left unchanged and uncoloured, so that correct rows aren't flagged.
9. As a meeting attendee, I want the correction to change only the wrong words, so that Gemini's phrasing isn't rewritten into something I didn't hear.
10. As a meeting attendee, I want a correction thrown away when it lacks the glossary's English or changes the line's length a lot, so that a confused rewrite never replaces a good translation.
11. As a meeting attendee, I want the previous row's Japanese taken into account, so that a term Gemini's row boundaries split off into the neighbouring row still gets corrected.
12. As someone who rereads transcripts, I want the saved transcript to contain the corrected English, so that the record uses the right names and terms.
13. As someone who rereads transcripts, I want rows saved within a few seconds even when a correction is slow, so that a stuck correction never holds up the transcript.
14. As someone who rereads transcripts, I want no correction markers in the saved file, so that the transcript reads cleanly.
15. As a meeting attendee, I want "Copy Transcript" to include corrected English, so that what I paste matches the panel and the saved file.
16. As a meeting attendee, I want corrections to keep up during fast speech, with a row skipped when its correction can't finish in time, so that corrections never pile up behind the conversation.
17. As a user whose Mac has no Apple Intelligence, I want to be told the glossary needs Apple Intelligence on this backend, so that I know why terms aren't corrected and what would fix it.
18. As a user with an empty glossary, I want no correction work and no glossary notice, so that nothing changes for me.
19. As a user, I want edits to my glossary picked up at the next Start, so that correction works the same way as every other backend's glossary.
20. As a user, I want my glossary's existing format (`Japanese = English`, full-width `＝`, `#` comments) to drive the correction, so that I maintain one file.
21. As a user who has English echo on, I want echoed English rows left alone, so that what English speakers actually said is never rewritten.
22. As a user, I want no extra menu item for this, so that the glossary just works on Gemini Live.
23. As a user, I want the correction to run on my Mac, so that no meeting text goes to another cloud service and nothing costs extra.
24. As a user, I want "Show Japanese" and the other panel settings to work on corrected rows exactly as on any other row.
25. As a user who presses Stop while a correction is running, I want rows still on the panel written to the transcript once, with whatever English they have, so that Stop never loses or duplicates a row.
26. As a user switching to another backend mid-meeting, I want corrections to stop with the Gemini session, so that pending corrections don't land on the wrong session.
27. As a user, I want the Gemini Live reconnects that happen every few minutes not to affect corrections, so that rows on either side of a reconnect are corrected the same way.
28. As a user on Translate My Voice, Qwen Omni or any text backend, I want nothing to change, so that this feature carries no risk for the paths that already honour the glossary.

## Implementation Decisions

- **New module: glossary corrector.** It sits between the live row segmenter's row operations and the subtitle store on the Gemini Live path only, and is the feature's single test seam. It passes every operation through unchanged and watches for rows closing.
  - **Trigger:** a Japanese row closes, and its source text or the previous row's source text contains a glossary source term.
  - **Hold:** a triggering row is held back from the transcript. The store's existing provisional mechanism does this: the row is marked provisional and settled later. The row still shows in the panel immediately.
  - **Queue:** one correction runs at a time, in order. When a row's turn comes, it is skipped if more than 3 s have passed since it closed.
  - **Release:** the row is settled when its correction finishes, when it is skipped, or when its 3 s limit passes, whichever comes first. A correction that finishes after the limit is dropped and does not change the row.
- **Its inputs** are a rewriter, a clock and the glossary.
  - **Rewriter:** an asynchronous function from (glossary, previous row's Japanese, row's Japanese, row's English) to an optional English string.
  - **Clock:** injected, so tests can run with a fake clock as the existing live self-test does.
- **The rewriter has one real implementation, using Apple Intelligence.**
  - It uses the same on-device model setup as the existing Apple Intelligence translator: general use case, permissive content-transformation guardrails.
  - It starts a fresh session for each correction, so there is no state between rows.
  - Its instructions tell it to fix only wrong renderings of glossary terms, change nothing else, and return the English unchanged when nothing is wrong.
  - The glossary goes in using the same "Fixed terminology (use exactly)" lines that every LLM backend prompt already uses, so the terms look the same everywhere.
- **Acceptance rules** live in the corrector, not the rewriter. A rewrite is accepted only if:
  - it is non-empty and differs from the original;
  - it contains the English of at least one glossary term whose Japanese appears in the row or the previous row;
  - its length is within about 30% of the original.

  Otherwise the row keeps Gemini's English.
- **Subtitle store changes:**
  - A subtitle line gains a "corrected" flag.
  - The store gains an operation that replaces a live row's English and sets that flag. It applies only to rows still in the live pane.
  - Transcript output, both saved and copied, uses whatever English the row has when it settles, with no marker.
- **Panel:** the subtitle view renders a corrected row's English line in a distinct soft-cyan colour. Nothing else about the row's style changes. The caption view (Translate My Voice) is not affected.
- **Pipeline controller, live path:**
  - At Start, it builds a corrector when the glossary has entries and Apple Intelligence is available. If the glossary has entries but Apple Intelligence is unavailable, it shows "Glossary needs Apple Intelligence on this backend" instead of the current "not used" notice. With an empty glossary it shows no notice and builds no corrector.
  - On Stop and on flush, it settles everything the corrector still holds before the transcript closes.
  - English echo rows are never triggers.
- **No new settings**, no menu item and no new UserDefaults key.
- **Architecture doc:** in §5, add the corrector between the row segmenter and the store, and replace the line saying the glossary is not used. In §9, update the glossary paragraph. Add the corrector to the component diagram.

## Testing Decisions

- **What a good test is.** Tests drive the corrector with scripted row operations, a scripted fake rewriter and a fake clock. They assert only observable outcomes on a real subtitle store:
  - each row's English and corrected flag;
  - which rows `onSettled` hands to the transcript, with what English, and at what fake time;
  - the notice text.

  They do not inspect the corrector's queue or internal state.
- **Seam:** the glossary corrector is the only new seam. The pipeline controller and the Apple Intelligence rewriter are not unit-tested. The real rewriter is checked by hand, and through an optional CLI check if one is added.
- **Cases to cover:**
  - A row without glossary terms passes through uncorrected and settles immediately.
  - A row with a term is corrected, coloured, and settled with the corrected English.
  - A term in the previous row's Japanese triggers correction of the current row.
  - The rewriter returns the English unchanged: the row is not marked corrected.
  - A rewrite missing the glossary's English, or changing the length by more than ~30%, is rejected.
  - A slow rewriter: the row settles with Gemini's English at 3 s, and a late result is ignored.
  - Several rows queued during fast speech: corrections run one at a time, and stale rows are skipped.
  - English echo rows are never sent to the rewriter.
  - Flushing on Stop settles held rows exactly once.
  - An empty glossary means no rewriter calls.
- **Prior art:**
  - The live self-test (scripted Gemini fragments, injected clock, assertions on emitted row operations).
  - The store self-test and transcript self-test (assertions on store state and the settled callback).
  - The fallback self-test (a scripted fake translator).

  The new suite joins the store self-test run, so `make test` covers it.

## Out of Scope

- Making Gemini itself aware of the glossary, for example by switching to `gemini-3.1-flash-live-preview` with a system prompt. That is a separate experiment that may later replace this correction.
- Glossary correction on Apple NMT rows, whether NMT is the chosen backend or the fallback. The corrector is designed so it could be reused for them later.
- Translate My Voice, Qwen Omni and every text backend, which already honour the glossary.
- Fixing misheard Japanese. The problem is wrong English for a correctly heard term.
- Fuzzy or rule-based term replacement without Apple Intelligence.
- Remote text LLMs (Claude, DeepSeek, OpenCode Go) as the rewriter. These were ruled out.
- A user-facing toggle, or marking corrections in the transcript.
- Highlighting only the changed words.

## Further Notes

- Gemini Live's row boundaries come from the English text, and source text is attributed to a row by when it arrives. A row's Japanese can therefore run a few words into the next sentence. That is why the previous row's Japanese is included both as a trigger and as context.
- Apple Intelligence latency on short inputs is expected to be well under the 3 s limit. If real meetings show frequent skips, the limit is the setting to revisit.
- Domain terms used here (glossary, row, glossary correction, corrected row) are defined in the root `GLOSSARY.md`.
