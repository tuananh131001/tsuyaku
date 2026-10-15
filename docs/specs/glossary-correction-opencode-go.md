# Spec: Glossary correction on OpenCode Go

**Status:** ready-for-agent

Builds on [Glossary correction for Gemini Live](glossary-correction.md) and [Glossary correction on every row](glossary-correction-every-row.md). Those specs still hold, except that this one replaces the model that does the correcting, and everything that existed only because that model was Apple Intelligence.

## Problem Statement

Glossary correction on Gemini Live runs on Apple Intelligence, and with my real glossary it doesn't work well enough.

- **Too slow.** With 322 terms, each correction takes 3–4 seconds on my Mac. Rows reach the transcript late and pile up in the live pane when people speak fast.
- **Too small.** The on-device model's context holds about 4,000 tokens. My glossary already uses about 3,000 of them, and at 575 terms correction switched itself off with "Glossary too large for Apple Intelligence".
- **Too weak.** It often leaves a row unchanged even when the right term is in the glossary. For example, 楽すると会社統合して… kept "the companies merged" when it should have become Raksul.

I tested cloud models side by side with Compare Correctors. Gemini direct corrected rows that Apple Intelligence left alone, in 1–2 seconds. I already pay for OpenCode Go and want to use it as the one corrector. OpenCode Go offers many models, and which one corrects best and fastest is something I want to try out, so I want to choose the model myself, starting from `deepseek-v4.1-flash`.

## Solution

On Gemini Live, glossary correction is done by OpenCode Go instead of Apple Intelligence. A new **Correction Model** submenu in the menu bar, shown while Gemini Live is selected, lets me pick which OpenCode Go model does it. It starts on `deepseek-v4.1-flash`, and my choice is remembered. Everything I see stays the same:
- Every Japanese row is checked.
- A corrected row tints only the rewritten words light blue.
- The chevron reveals the original English.
- The transcript gets the corrected English.

The difference is that corrections arrive faster and fix more terms, and a long glossary no longer turns correction off.

Correction needs my OpenCode Go key, the one the OpenCode Go translation backend already uses. Without it, the panel says "Glossary needs an OpenCode Go key on this backend" and rows show Gemini's English, as they do today without Apple Intelligence. If OpenCode Go starts failing, for example because the key is rejected, the panel tells me once per session and subtitles carry on with Gemini's English.

## User Stories

1. As a meeting attendee using Gemini Live, I want glossary correction done by OpenCode Go, so that corrections are faster and catch more glossary terms than Apple Intelligence did.
2. As a meeting attendee, I want to choose which OpenCode Go model does glossary correction, so that I can use the one that corrects best and fastest for my meetings.
3. As a meeting attendee, I want the choice in the menu bar, next to the other Gemini Live options, so that I can switch without a terminal.
4. As a meeting attendee, I want the current correction model ticked in the menu, so that I always know which model is correcting my rows.
5. As a meeting attendee, I want `deepseek-v4.1-flash` chosen until I pick another, so that correction works sensibly out of the box.
6. As a meeting attendee, I want my choice remembered across launches, so that I pick it once.
7. As a meeting attendee, I want a model change mid-meeting to take effect at once, so that I can compare models on the same meeting.
8. As a meeting attendee, I want the correction model kept separate from the model I picked for OpenCode Go translation, so that changing one never changes the other.
9. As a meeting attendee, I want the menu to list every model OpenCode Go currently offers, so that I can try new models as soon as OpenCode adds them, without a Tsuyaku update.
10. As a meeting attendee, I want the model list fetched in the background when the app starts, so that the menu bar comes up as fast as before and the list is ready by the time I open the menu.
11. As a meeting attendee, I want the last fetched list remembered, so that the menu still offers the full list when I'm offline or OpenCode is down.
12. As a meeting attendee on a first launch with no network, I want a short built-in list, so that the submenu is never empty.
13. As a developer, I want to set any OpenCode Go model ID from the command line, so that a model missing from the menu can still be tried.
14. As a meeting attendee who set a model from the command line, I want the menu to show and tick it, so that the menu never claims a different model is in use.
15. As a meeting attendee with a long glossary, I want correction to keep working however many terms I have, so that growing my glossary never switches correction off.
16. As a meeting attendee, I want the "Glossary too large for Apple Intelligence" notice gone, so that I'm not warned about a limit that no longer applies.
17. As a meeting attendee on a Mac without Apple Intelligence, I want glossary correction to work anyway, so that the feature no longer depends on my hardware or system settings.
18. As a meeting attendee without an OpenCode Go key, I want the panel to say "Glossary needs an OpenCode Go key on this backend", so that I know why my glossary isn't applied and what to set up.
19. As a meeting attendee without an OpenCode Go key, I want subtitles to run normally with Gemini's English, so that a missing key never stops the meeting.
20. As a meeting attendee whose OpenCode Go key is rejected or whose quota is used up, I want one notice per session saying correction failed and why, so that I'm not left wondering why nothing is corrected.
21. As a meeting attendee, I want a failed correction to leave the row with Gemini's English and settle it, so that one failed request never holds a row back from the transcript.
22. As a meeting attendee, I want the failure notice shown only once per session, not on every row, so that the header isn't flooded during a bad stretch.
23. As a meeting attendee, I want every Japanese row still checked, with the whole glossary, so that misheard terms (ラクスール, ラックス) are still caught.
24. As a meeting attendee, I want the acceptance rule unchanged, so that a corrected row still always means a glossary term was fixed, never a restyled sentence.
25. As a meeting attendee, I want only the words the corrector wrote tinted light blue, as now, so that my eye goes straight to the fixed term.
26. As a meeting attendee, I want the chevron on a corrected row to keep revealing the original English, so that I can judge a correction that looks odd.
27. As a meeting attendee, I want subtitles to appear as fast as before, so that sending rows to a cloud model never makes the panel lag.
28. As someone who rereads transcripts, I want the saved and copied transcript unchanged, with the corrected English and no original English or marker, so that the record reads the same as before.
29. As a meeting attendee, I want corrections to run one at a time and in order, with no time limit, as now, so that rows reach the transcript in the conversation's order.
30. As a user with English echo on, I want echoed English rows never sent for correction, as before.
31. As a user with an empty glossary, I want no correction requests at all, so that nothing is sent or spent for no reason.
32. As a user of other translation backends, I want nothing to change, so that this stays a Gemini Live feature.
33. As a user who picks Apple on-device LLM as a translation backend, I want that backend unaffected, so that only glossary correction moves off Apple Intelligence.
34. As a user trying Compare Correctors, I want it to keep working, with its OpenCode Go lane using the correction model I chose and making the same request as the real corrector, so that the comparison reflects what I'll get.
35. As a developer, I want a command that sends sample rows to the corrector's model and prints the answer and the time, so that I can check the key and the latency without starting a meeting.

## Implementation Decisions

- **The corrector's model is a user choice.** It's a new defaults-backed setting, the correction model, with `deepseek-v4.1-flash` as the default. It works the same way as the existing OpenCode Go translation model setting (a static, defaults-backed value that the CLI can set without a `Settings` instance), but it is a separate key: changing one never changes the other. The translation model is currently `kimi-k2.7-code`.
- **Choosing it from the menu.**
  - A **Correction Model** submenu sits under Translation. It is shown only when Gemini Live is selected, like Compare Correctors.
  - It lists the OpenCode Go models from the latest fetch (see below), in the order OpenCode returns them, with the current one ticked.
  - If the saved model isn't in the list, for example because it was set from the CLI, it is listed too, so the tick is never wrong.
  - The submenu is enabled only when an OpenCode Go key is stored. Without one, it shows "— no key", as the Translation submenu does.
- **The model list is fetched in the background at app start.**
  - The request is `GET https://opencode.ai/zen/go/v1/models`, an OpenAI-style list (`{"object":"list","data":[{"id":…}, …]}`). It needs no key; it was checked with and without one on 2026-10-15 and returned 37 models both times.
  - It is sent once per launch, off the main thread, after settings have loaded. It never delays the status item, the menu or Start.
  - When it succeeds, the IDs are saved to UserDefaults and the menu is rebuilt, so the next open shows them.
  - When it fails (offline, timeout, HTTP error, unreadable reply), the failure is logged and nothing is shown to the user. The menu keeps the last saved list.
  - With no saved list at all (a first launch offline), the menu uses a short built-in list: `deepseek-v4.1-flash`, `qwen3.8-flash`, `glm-5.3-flash`, `kimi-k2.7-code`, `minimax-m3`.
  - The list is not filtered: whatever OpenCode Go offers is listed, including slow reasoning models. Choosing a poor model is the user's call, and Compare Correctors and `--compare-correctors` show its time.
  - A model that disappears from the list stays selected and stays listed, as a model set from the CLI does. If OpenCode Go refuses it, the per-session failure notice says so.
  - Parsing the reply is a pure function from the response body to an ordered list of IDs, so it can be self-tested.
- **Choosing it from the CLI.** `--correction-model <id>` stores any model ID, mirroring `--opencode-model`, and works on its own or before `--compare-correctors`.
- **When a change applies.** At once. Choosing a model saves it and cycles a running pipeline, the same way a provider change does (`rebuildController`). Rows held at that moment are settled by Stop's flush, as for any restart. The corrector reads the model once, at Start.
- **Key.** The existing `opencodeGo` keychain account, read off the main thread at Start, once per session. There is no new key, setting or menu item.
- **Wire format.** One non-streaming Anthropic Messages request per row to OpenCode Go's Go endpoint:
  - `thinking` disabled, temperature 0, at most 256 output tokens, a 20-second request timeout.
  - An `x-opencode-session` header that is the same for every request in a session and new at each Start. OpenCode Go rejects requests without it ("MissingSessionID").

  This is the cloud client that Compare Correctors already has; the corrector and that comparison's OpenCode Go lane share it, and both use the chosen correction model. The lane's column header shows the model ID, so it follows the choice.
- **Prompt.** Unchanged: the same rewriter instructions (the misheard-term rule and the worked example), the whole glossary, and the previous row's Japanese, the row's Japanese and the row's English.
- **Unchanged from the earlier specs:** hold, queue (one at a time, in order), no time limit, release, Stop flushing every held row, the acceptance rule, English echo rows never sent, and no corrector with an empty glossary.
- **Failure handling moves into the corrector.** Today the rewriter returns an optional string and failures are swallowed inside it. The rewriter becomes a call that throws, and the corrector decides what a failure means:
  - The row keeps Gemini's English, is not marked corrected, and settles.
  - The error is logged each time.
  - On the first failure of a session, the store shows "Glossary correction failed: \<reason\>" for 10 seconds. Later failures in the same session show nothing.

  This puts the behaviour behind the existing test seam.
- **Starting the corrector.** On Gemini Live with a non-empty glossary:
  - With an OpenCode Go key, the corrector is created.
  - Without one, it isn't, and the store shows "Glossary needs an OpenCode Go key on this backend" for 8 seconds.

  Compare Correctors, when on, still takes the corrector's place, as now.
- **Removed: everything that existed only for Apple Intelligence.** That means the availability check and the "Glossary needs Apple Intelligence on this backend" notice, the on-device model prewarm, the glossary token-count check (`fits`) and the "Glossary too large for Apple Intelligence (N terms) — correction off" notice, and the on-device rewrite itself. The rewriter module keeps only the instructions and the per-row prompt.
- **Apple Intelligence as a translation backend** ("Apple on-device LLM") is untouched.
- **Wording.** Comments and docs that say Apple Intelligence wrote the tinted words say "the corrector" instead. The light-blue colour, the chevron and the word diff are unchanged.
- **Privacy.** Corrections now send each Japanese row, its English and the glossary to OpenCode Go. Gemini Live already sends the meeting audio to Google, so the meeting was never on-device on this backend. The architecture doc's line that correction keeps meeting text on the Mac must go.
- **Diagnostics.** `--compare-correctors` already sends two real rows to every lane and prints each answer and time; its OpenCode Go lane uses the chosen correction model. With `--correction-model <id>` in front, it checks any model. No other new command is needed.
- **Architecture doc.** Update §5 (glossary correction runs on OpenCode Go with the chosen correction model; key needed; failure notice; no size check), §9's UserDefaults diagram (the correction model and the saved model list), §1 (the background model-list fetch at launch), §10 (`--correction-model`), §1 (the rewriter node is OpenCode Go, not Apple Intelligence), §6 (the corrector's and the rewriter's interfaces), and §9 (the glossary drives correction on Gemini Live, which needs an OpenCode Go key, not Apple Intelligence).

## Testing Decisions

- **One seam: the corrector with an injected rewriter.** This is the existing seam, with the same harness and style as the corrector self-test: scripted row operations, a scripted fake rewriter, and assertions on a real subtitle store only. The only change to the seam is that the fake rewriter can now throw.
- **A good test** checks only what the user can see: each row's English, whether it is marked corrected, the original English, what reaches the transcript and in what order, and the header notice. It does not check queues, generations or call counts beyond "was this row sent".
- **Cases to add:**
  - A throwing rewriter leaves the row with Gemini's English, not corrected, and settles it into the transcript.
  - The first failure in a session shows "Glossary correction failed: …" with the reason.
  - A second failure in the same session shows no new notice.
  - After a failure, the next row is still sent and can still be corrected.
- **Model list parsing,** at a second, pure seam: the response body in, the ordered IDs out, with no network. Prior art is the glossary parser self-test.
  - The 2026-10-15 reply shape gives the IDs in order.
  - An empty `data`, a missing `data`, or a body that isn't JSON gives no list, so the saved or built-in list stays.
  - Duplicate IDs are listed once.
- **Cases kept as they are:** every existing corrector case (every-row trigger, misheard term, acceptance rule rejections, slow correction waited for, fast speech, echo rows, Stop, empty glossary, word diff). They run unchanged against the throwing rewriter type.
- **Compare Correctors self-test:** unchanged, but it must still pass with the shared OpenCode Go client.
- **Not covered by self-tests, and checked by hand:**
  - The missing-key notice at Start. It depends on the keychain, and the controller has no test seam today.
  - The Correction Model submenu: it appears only with Gemini Live, ticks the saved model (including one set from the CLI), switching models restarts a running session onto the new model, and the choice survives a relaunch.
  - The background fetch: on launch the submenu fills with OpenCode Go's list, offline it keeps the last saved list, and a first launch offline shows the built-in list.
  - A few models from the list, through `--correction-model <id> --compare-correctors`.
  - A real request with the user's key and glossary, through `--compare-correctors`.

## Out of Scope

- Refreshing the model list after launch (on a timer, or when the menu opens). It is fetched once per launch.
- Showing model details (price, speed, context size) in the menu. The list endpoint returns IDs only.
- Correction models from providers other than OpenCode Go.
- Per-model settings such as temperature or thinking.
- Falling back to Apple Intelligence, or to any other model, when OpenCode Go fails.
- Retries. A failed correction is skipped for that row.
- Removing Compare Correctors. It stays as a prototype behind its toggle.
- A per-term list of known mishearings (楽天 heard for ラクスル). That's a possible follow-up; see Further Notes.
- Correction on any backend other than Gemini Live.
- A release version bump and changelog entry, unless asked for.

## Further Notes

- **Measured with Compare Correctors** (2026-10-15):
  - Gemini direct corrected both sample rows in 1.2–4.7 s.
  - OpenCode Go returned `401 Invalid credential` for the stored key, from the existing OpenCode Go translator too. The user must store a working key before this feature can be used.
  - OpenCode Go's own latency was not measured, because of that `401`. The user has said its API is slower than calling providers directly.
- **The user's glossary.** It gained `ラクスル = Raksul` on 2026-10-15. Before that, a bare "Raksul" could never pass the acceptance rule, because only longer terms (`ラクスル株式会社 = RAKSUL INC.`) existed.
- **Gemini's transcript mishears ラクスル as 楽天 (Rakuten).** No corrector can fix that from the text alone, because 楽天 is a real company and 楽天銀行支払い is a real payment method. A list of known mishearings per glossary term would let the corrector decide from context. That is left for a later spec.
- Domain terms (glossary, row, glossary correction, corrected row, original English) are defined in the root `GLOSSARY.md`.
