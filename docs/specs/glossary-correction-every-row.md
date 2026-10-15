# Spec: Glossary correction on every row

**Status:** ready-for-agent

Builds on [Glossary correction for Gemini Live](glossary-correction.md). That spec still holds except where this one replaces it: the trigger, the "already correct" skip, the acceptance rule, the rewriter's instructions, and the out-of-scope line on misheard Japanese.

## Problem Statement

Glossary correction on Gemini Live only fires when a row's Japanese, or the previous row's, contains a glossary term exactly. Gemini's Japanese transcript often mishears the term itself: ラクスル comes back as ラクスール or ラクス. Then nothing triggers, and "Lacsul" stays in the panel and the transcript. Apple Intelligence is fast enough on my Mac to look at every row, so I want every row checked and no line with a term missed.

When a correction does change a row, I also want to see what Gemini said originally if the correction looks odd.

## Solution

On Gemini Live, when the glossary has entries, every Japanese row goes to Apple Intelligence for glossary correction when it closes. That includes rows whose Japanese has no exact glossary term and rows whose English already uses the glossary's English. The rewriter is told that a fixed term may be misheard or misspelled in the Japanese and the English, and that a near-match in sound counts.

A rewrite is kept only when it adds the English of a glossary term that Gemini's line did not have. So a corrected row in cyan always means "a glossary term was fixed here", never "the model restyled the sentence".

A corrected row gets a small disclosure chevron. Clicking it shows the **original English** (Gemini's line before correction) underneath, dimmed. Clicking again hides it.

## User Stories

1. As a meeting attendee using Gemini Live, I want a row corrected even when Gemini's Japanese misheard the glossary term, so that ラクスール heard for ラクスル still becomes "Raksul".
2. As a meeting attendee, I want every Japanese row checked when I have a glossary, so that no line with a term slips through.
3. As a meeting attendee, I want a row left alone when the rewrite adds no glossary term, so that Gemini's phrasing is never restyled and cyan keeps meaning "term fixed".
4. As a meeting attendee, I want the original English of a corrected row hidden by default, so that the panel shows one version of each sentence.
5. As a meeting attendee, I want to reveal the original English of a corrected row with one click, so that I can judge a correction that looks odd.
6. As a meeting attendee, I want to hide the original English again with another click, so that the panel goes back to normal.
7. As a meeting attendee, I want the reveal to work per row, so that opening one row doesn't expand the whole panel.
8. As a meeting attendee using Click-Through, I want the panel to keep ignoring the mouse, so that the reveal chevron never gets in the way of the meeting app.
9. As a meeting attendee, I want subtitles to appear as fast as before, so that checking every row never makes them lag.
10. As someone who rereads transcripts, I want the saved and copied transcript unchanged: corrected English only, no original English, no marker.
11. As a meeting attendee during fast speech, I want a row skipped when its correction can't finish within 3 s, so that corrections never pile up.
12. As a user with English echo on, I want echoed English rows never rewritten, as before.
13. As a user with an empty glossary, or without Apple Intelligence, I want nothing to change from today.

## Implementation Decisions

- **Trigger (replaces the previous one).** Every Japanese row that closes with non-empty, non-failed English is queued, as long as the corrector exists. The corrector exists, as before, when the glossary has entries and Apple Intelligence is available. English echo rows are never queued.
- **The "already correct" skip is removed.** A row whose English already contains its terms' glossary English is still queued, because it may hold a second, misheard term.
- **Terms passed to the rewriter.** The whole glossary goes in, not only the terms found in the Japanese, since a misheard term won't match.
- **Hold, queue, limit and release are unchanged.** Every queued row is held as provisional, so it stays out of the transcript until it settles: at most 3 s after it closes. Corrections run one at a time, in order, and a row more than 3 s past closing is skipped.
- **Acceptance rule (replaces the previous one).** A rewrite is kept only if all of these hold:
  - it is non-empty and differs from the original;
  - it contains the English of at least one glossary term that the original English does not contain (case-insensitive);
  - its length is within about 30% of the original, with at least 6 characters of slack.

  Otherwise the row keeps Gemini's English and is not marked corrected.
- **Rewriter instructions.** Add a rule that a fixed term may appear misheard or misspelled in the Japanese (for example ラクスール or ラクス for ラクスル) and in the English (for example "Lacsul" or "Lux"), and that a near-match in sound counts as that term. Add one short worked example. The other rules stay: change nothing else, return the English unchanged when nothing is wrong, output only the English line.
- **Subtitle store.** When a correction is applied, the row keeps the original English alongside the corrected English. Transcript output, saved and copied, ignores the original English.
- **Panel.**
  - A corrected row shows a small disclosure chevron next to its cyan English.
  - Clicking it shows the original English underneath, in the same dim secondary style as the Japanese line, and clicking again hides it.
  - It is collapsed by default, the state isn't remembered across launches or Clear, and there is no "expand all".
  - The chevron needs Click-Through off, like any other click on the panel.
  - The caption view (Translate My Voice) is not affected.
- **No new settings, menu items or UserDefaults keys.**
- **Architecture doc.** Update §5: the trigger is every Japanese row, the acceptance rule is the one above, and corrected rows can reveal the original English.

## Testing Decisions

- Same seam and style as the existing corrector tests: scripted row operations, a scripted fake rewriter, a fake clock, and assertions on a real subtitle store only.
- **Cases to change or add:**
  - A row with no exact glossary term is sent to the rewriter (previously passed through).
  - A row whose English already has the term is sent to the rewriter (previously skipped).
  - A rewrite that adds a glossary term's English is accepted, and the row keeps the original English.
  - A rewrite that differs but adds no glossary English the original lacked is rejected, and the row is not corrected.
  - A rewrite whose only glossary English was already in the original is rejected.
  - Every queued row is held, and settles within the 3 s limit.
  - English echo rows are still never sent.
  - An empty glossary means no corrector and no rewriter calls.
  - Transcript output for a corrected row has the corrected English and no original English.
- The chevron and the reveal are checked by hand.

## Out of Scope

- Correction on any backend other than Gemini Live.
- Showing which words changed.
- Putting the original English in the transcript. Flagging a row records it (see [Flag rows](flag-rows.md)).
- Changing the 3 s limit or the one-at-a-time queue. If real meetings show frequent skips, the limit is the thing to revisit.

## Further Notes

- The rewrite's speed is based on what was seen by hand, not measured. Sending every row multiplies the load by however many rows have no exact term.
- Domain terms used here (glossary, row, glossary correction, corrected row, original English) are defined in the root `GLOSSARY.md`.
