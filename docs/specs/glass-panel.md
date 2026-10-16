# Spec: Glass panel

**Status:** ready-for-agent

## Problem Statement

The subtitle panel is a flat slab of 82% black. Over a shared slide or a video grid it reads as a hole cut in the meeting rather than part of the Mac. Every row in the history pane is drawn at the same weight, so after a few minutes my eye has to search for the newest settled row. The live pane is a faint tinted band that barely separates from history. The header doesn't say which backend is translating, so when the English looks off I can't tell at a glance whether it's Gemini Live, Claude or on-device NMT.

## Solution

Restyle the subtitle panel as a macOS HUD, following design A in `docs/design/floating-panel/a-glass.html`:

- **Dark frosted-glass background.** The meeting shows faintly through the panel, which is tinted dark enough that white text stays readable over a white slide.
- **Recency fade.** The newest settled row is drawn at full strength and older rows step down. Hovering the history pane, or scrolling back to read, brings every row to full strength.
- **Live card.** The live pane becomes an inset card with a blue bar on its leading edge, so "happening now" is unmistakable.
- **Backend chip.** The header names the backend that wrote the latest English in a small chip, including on-device translation while a cloud backend is unavailable.
- **Soft top edge.** When there are rows above the visible ones, history fades out at its top edge instead of being cut off hard.

The layout, behaviour and every existing state stay as they are: history and live panes, the hearing line, corrected rows and their original English, failed rows, notices, Click-Through, Text Size, Show Japanese and the "N new" pill.

## User Stories

1. As a meeting attendee, I want the subtitle panel to look like part of macOS, so that it doesn't feel like a foreign object over my meeting.
2. As a meeting attendee, I want to see a hint of the meeting through the panel, so that I keep a sense of what's behind it.
3. As a meeting attendee watching a white slide, I want subtitles to stay clearly readable, so that the glass never costs me legibility.
4. As a meeting attendee, I want the newest settled row to stand out from older ones, so that my eye lands on it without searching.
5. As a meeting attendee, I want older rows to recede gradually, not vanish, so that I can still pick up context from the last few rows.
6. As a meeting attendee reading back, I want every row at full strength while I hover the history pane, so that older rows aren't hard to read when I go looking for them.
7. As a meeting attendee who has scrolled up, I want rows to stay at full strength until I return to the newest row, so that reading back is never dimmed.
8. As a meeting attendee, I want the live rows in a distinct card with an accent bar, so that I can tell what is still being translated from what has settled.
9. As a meeting attendee, I want the live rows always at full strength, so that the recency fade never dims what's happening now.
10. As a meeting attendee, I want the live English slightly larger than history, so that the current sentence is the easiest thing to read.
11. As a meeting attendee, I want "translating…" and the hearing line quieter than translated text, so that placeholders don't compete with real subtitles.
12. As a meeting attendee, I want the header to name the backend that wrote the latest English, so that when a cloud backend is unavailable and Apple NMT takes over, I can tell why the English got worse.
13. As a meeting attendee, I want the backend chip hidden when subtitles are stopped, so that the header doesn't name a backend that isn't running.
14. As a meeting attendee, I want a notice to still take over the header in orange, so that device changes and fallbacks still get my attention.
15. As a meeting attendee, I want the recording dot to look like the macOS microphone indicator, so that I recognise "capturing" at a glance.
16. As a meeting attendee using glossary correction, I want corrected words tinted in a cyan that reads well on glass, so that the fixed term still stands out.
17. As a meeting attendee using glossary correction, I want the reveal chevron to turn when I open a row's original English, so that I can see which rows are expanded.
18. As a meeting attendee, I want failed rows in orange, so that I can spot them as before.
19. As a meeting attendee reading back, I want the "N new" pill as a blue capsule that floats above history, so that it's easy to find and click.
20. As a meeting attendee, I want history to fade softly at its top edge when there is more above, so that the cut-off row doesn't look like a rendering glitch, and a short history isn't faded for nothing.
21. As a meeting attendee with Show Japanese off, I want the glass look to work the same with English only, so that the setting keeps its meaning.
22. As a meeting attendee using a larger Text Size, I want every subtitle size to scale as before, so that the new look doesn't break my preference.
23. As a meeting attendee using Click-Through, I want the panel to look the same and keep ignoring the mouse, so that it stays out of the meeting app's way.
24. As a meeting attendee, I want the glass to stay frosted while another app is active, so that the panel doesn't turn flat grey because it isn't the key window.
25. As a meeting attendee, I want the panel's rounded corners, shadow and hairline border to match other macOS HUDs, so that it looks deliberate on any background.
26. As a meeting attendee, I want resizing, dragging and the resize grip to work exactly as before, so that the restyle costs no behaviour.
27. As someone sharing their screen, I want the Translate My Voice caption panel unchanged, so that what colleagues see doesn't move under me.

## Implementation Decisions

- **Scope.** Subtitle panel only: `SubtitleView` and the subtitle `FloatingPanel` layout. The caption panel (`CaptionView`, `Layout.captions`) is unchanged.
- **Background.**
  - An AppKit visual-effect view, wrapped as an `NSViewRepresentable`, is the background of `SubtitleView`: HUD material, behind-window blending, dark appearance forced. The tint, the 16pt clip and the hairline are applied in `SubtitleView` too. `FloatingPanel` is not changed, so the caption panel can't change by accident. If the window shadow doesn't follow the rounded shape, the panel calls `invalidateShadow()` after the first layout.
  - The visual-effect state is pinned to **active**. The panel is non-activating and is almost never key, so the default "follows window" state would grey the glass out.
  - A dark tint over the material, about 74% (`rgb(22,22,26)` in the mockup), keeps white text readable over a white slide. The 58% tint first tried in the mockup was too light.
  - Corner radius 16pt (was 12), a 0.5pt white hairline border at 18%, and the window's own shadow. The panel stays non-opaque with a clear window background.
- **Colours.** These map to macOS system colours on dark:
  - Primary text white.
  - Secondary text: the Japanese line and the original English, at about 58%.
  - Tertiary text: "translating…", the hearing line and the version, at about 32%.
  - Accent: system blue, for the live bar and the "N new" pill.
  - Corrected words: cyan `#64D2FF`, replacing today's light blue.
  - Failed rows and the notice dot: system orange.
  - Recording dot: system red with a soft 3pt halo.
- **Header.**
  - 34pt tall. From leading to trailing: dot, header label, flexible space, backend chip, Click-Through icon (only when it's on), version.
  - The label is drawn in secondary colour, or primary when it is showing a notice.
  - The chip shows the name of the backend that wrote the latest English (`TranslationProvider.shortName`, so Gemini Live reads "Gemini") in a small rounded rectangle at white 8%. It is hidden whenever subtitles aren't running, so a Start that fails never shows a name.
  - English rows shown verbatim (auto-detect, or Gemini's echo) and glossary corrections by OpenCode Go don't change the chip. It keeps naming the session's backend.
- **Backend name in the store.** `SubtitleStore` gains a published, view-only backend name. `PipelineController` sets it, at the same moments as the existing fallback notices:
  - At Start, including a restart through `rebuildController()`: the backend it actually built. That is `settings.provider.shortName`, or "Apple NMT" when `foundation` degraded to `AppleTranslator`.
  - When the "unavailable — translating on-device" notice fires (`onFallback` turns on): "Apple NMT".
  - When the "is back" notice fires (`onFallback` turns off): the provider's name again.
  - At Stop: cleared.

  It is not persisted and never appears in transcripts.
- **Recency fade.**
  - A pure rule maps a history row's distance from the newest settled row, and whether the pane is emphasised, to an opacity:
    - newest (distance 0): 1.0
    - distance 1–2: 0.75
    - distance 3 or more: 0.5
    - emphasised: 1.0 for every row
  - "Emphasised" means the pointer is over the history pane, or the pane is reading back (not pinned to the bottom). Hovering the live card or the header doesn't count. Dragging the panel by its history area does count, and brightens history for the duration of the drag.
  - The rule lives next to `PanelStyle` as a static, so it can be tested without a view. It applies only to the history pane. Live rows, the hearing line and the "N new" pill are never faded.
  - Opacity changes animate over about 0.25s.
  - With Click-Through on there are no hover events, so the fade simply stays in its resting state.
- **History pane.**
  - A 22pt top-edge fade mask, applied only while the content is scrolled past its top (scroll offset above 0). A history that is short, or scrolled all the way up, isn't faded. The offset comes from the existing scroll-geometry callback.
  - Horizontal padding 18pt and row spacing 12pt.
  - The scroll indicator is hidden.
  - The sticky-scroll logic (`HistoryScrollRule`, pin and unpin, the settled-count watcher) is untouched.
- **Live card.**
  - The live pane becomes a card inset 8pt from the panel's sides and bottom: radius 11pt, white 7.5% fill, white 0.5pt hairline at 10%.
  - A 3pt system-blue bar is inset along its leading edge.
  - Live English is 16pt (history stays 15pt), both scaled by Text Size. A row's English shrinks by that 1pt when it settles. This is accepted, because the row moves panes at the same moment.
  - The line limits stay as they are.
  - The card appears and disappears with the existing transition and is hidden under the same conditions as today's live pane.
- **Corrected rows.** The reveal control keeps a single chevron that rotates 90° when the row is open, instead of swapping between two symbols. Its 16pt hit area gets a faint rounded highlight on hover.
- **"N new" pill.** A system-blue capsule with a soft blue shadow, floating 8pt above the bottom of the history pane, with the same appear and disappear behaviour.
- **Unchanged.** Panel sizes and minimums, the drag and resize handling, the resize grip, Show Japanese, the `showsSource` rules, failed-row handling, and transcripts. There are no new settings and no new `UserDefaults` keys.
- **Architecture doc.**
  - §6: add the backend-name property to `SubtitleStore` (set by `PipelineController`), and the recency rule to `PanelStyle`.
  - §9: one sentence noting that the panel draws on a behind-window HUD material pinned active.

## Testing Decisions

- A good test checks behaviour you can observe through a public interface, not how the view is assembled. Here the only logic with observable behaviour is the recency rule. The rest is styling, judged by eye.
- **Seam:** the recency rule, in `PanelStyleSelfTest`, run by `--store-selftest` and therefore `make test`. Cases:
  - Newest row at full opacity, the next two at 0.75, everything older at 0.5.
  - Emphasised gives full opacity at every distance.
  - Opacity never rises as distance from the newest row grows.
- **By hand**, side by side with `docs/design/floating-panel/a-glass.html`:
  - Legibility over a white slide and over a dark video grid.
  - The glass stays frosted while another app is frontmost.
  - Hovering history and scrolling back bring every row to full strength, and returning to the newest row restores the fade.
  - The live card appears and disappears smoothly, and the history pin survives it (the existing container-change rule).
  - The chip shows the right backend, changes after switching backends mid-meeting, and is hidden when stopped.
  - With a cloud backend failing (e.g. a bad key, or blocking the host), the chip switches to "Apple NMT" with the notice, and back to the provider's name with "is back".
  - The top-edge fade is absent with a short history and when scrolled to the very top, and present once scrolled down.
  - A notice, Click-Through, every Text Size, Show Japanese off, a corrected row with its chevron, a failed row, and the "N new" pill.
  - The panel at its minimum size (380×220) still shows the header, one history row and a live card.
- **Prior art:** `PanelStyleSelfTest` (`whichRowsShowJapanese`, `textSizesGrow`) for pure rules beside `PanelStyle`, and `StoreSelfTest` for the store.

## Out of Scope

- The other two directions (B · Cinema, C · Bilingual ledger) and mixing parts of them in.
- The caption panel's look.
- A light-appearance variant, or following the system appearance. The panel stays dark.
- A user setting for the glass tint or the recency fade.
- The blinking caret shown after the streaming English in the mockup.
- The flag button from `docs/specs/flag-rows.md`, though the two must fit together (see below).

## Further Notes

- Domain terms (row, live row, settled row, backend, corrected row, original English, glossary) are defined in the root `GLOSSARY.md`.
- The flag-rows spec puts a flag button on hovered history rows. Under this design, hovering history already brings rows to full strength, so a flag button appears on a row that is fully readable. Whichever ships second should keep both behaviours.
- The mockup files under `docs/design/floating-panel/` are reference material. They are not shipped, and they don't need to change as the Swift implementation evolves.
