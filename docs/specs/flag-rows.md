# Spec: Flag rows

**Status:** ready-for-agent

## Problem Statement

During a meeting on Gemini Live I sometimes see a row translated wrongly, usually a company name or in-house term that glossary correction didn't fix. In the moment I can't stop to work out the right glossary entry. Afterwards I no longer remember which lines were wrong, and the transcript has only the final English, so I can't tell what Gemini said or what the Japanese was.

## Solution

Every settled Japanese row on Gemini Live gets a small **flag** button, shown when I hover the row with Click-Through off. Clicking it makes the row a **flagged row** and appends a block to `flagged.txt` in Tsuyaku's Application Support folder. The block holds the previous row's Japanese, the row's Japanese and English, and the original English if the row was corrected. Clicking again removes the flag and its block. A new menu item, **Open Flagged Rows…**, opens the file so I can work through it later and fix `glossary.txt`.

## User Stories

1. As a meeting attendee using Gemini Live, I want to flag a wrongly translated row with one click, so that I can deal with it after the meeting.
2. As a meeting attendee, I want the flag button to appear only when I hover a row, so that the panel stays uncluttered.
3. As a meeting attendee using Click-Through, I want the panel to keep ignoring the mouse, so that flags never get in the way of the meeting app.
4. As a meeting attendee, I want a flagged row to show a filled flag, so that I can see what I've already flagged.
5. As a meeting attendee, I want to remove a flag I set by mistake by clicking again, so that `flagged.txt` only holds rows I meant.
6. As a meeting attendee, I want to flag only rows that have settled, so that what's recorded is the English the panel finally shows, not English a correction is about to replace.
7. As someone fixing the glossary later, I want each flagged row's Japanese and English recorded, so that I can see what was said and how it came out.
8. As someone fixing the glossary later, I want the previous row's Japanese recorded too, so that a term split across rows is still visible.
9. As someone fixing the glossary later, I want the original English recorded for a corrected row, so that I can see what Gemini said and what the correction did.
10. As someone fixing the glossary later, I want the time and backend in each entry, so that I can match it to the meeting and its transcript.
11. As a user, I want to open the flag file from the menu, so that I don't have to find the Application Support folder.
12. As a user, I want the flag file kept private like my transcripts, so that meeting text isn't readable by other users of the Mac.
13. As a user on any backend other than Gemini Live, or in the Translate My Voice caption panel, I want no flag button, so that nothing changes there.
14. As someone who rereads transcripts, I want flags kept out of the transcript, so that the record reads cleanly.

## Implementation Decisions

- **Where the button shows.** Subtitle panel only, on Japanese rows produced by the Gemini Live backend, once the row has settled. Not on English echo rows, failed rows, the `hearing` line, or anything in the caption panel.
- **Interaction.**
  - Hidden until the pointer hovers the row. Needs Click-Through off, like any other click on the panel.
  - Unflagged: an outline flag. Flagged: a filled flag, always visible on that row, not only on hover.
  - Clicking toggles the flag. Flag state lives on the row in the store and is lost on Clear or restart.
- **File.**
  - `flagged.txt` in `~/Library/Application Support/Tsuyaku` (`AppPaths`), created `0600`, next to `glossary.txt`.
  - Plain UTF-8 text. Flagging appends one block, separated from the previous block by a blank line:

    ```
    # 2026-10-15 14:32 · Gemini Live · a1b2c3
    Previous: 先週の件ですが
    Japanese: ラクスールの見積は明日送ります
    English:  We'll send Raksul's quote tomorrow.
    Original: We'll send Lacsul's estimate tomorrow.
    ```

  - The header holds the local time, the backend's short name and a short row id (the first six hex digits of the row's id).
  - `Previous` is omitted when the previous row was English or there was none. `Original` is present only for a corrected row.
  - Multi-line values are joined to one line.
- **Unflag.** Removes the block whose header carries the row's short id. If no block has that id (for example, the user edited it away), the file is left alone and the row still goes back to unflagged.
- **Menu.** Add **Open Flagged Rows…** next to **Edit Glossary…**. It creates `flagged.txt` with a one-line `#` header comment if the file is missing, then opens it in the default text editor.
- **Writer.** A small file-writing component owns `flagged.txt`: append a block, remove a block by short id, ensure the file exists. All of its writes happen off the main thread, in the order they were requested.
- **Transcript.** Unchanged: flags never appear in the saved or copied transcript.
- **No new settings or UserDefaults keys.**
- **Architecture doc.** Add the flag writer and `flagged.txt` to §1 and §9, and the new menu action to the `AppDelegate` entry in §6.

## Testing Decisions

- **Seam:** the flag-file writer, tested against a temporary directory. Cases:
  - Appending writes a block in the format above, with and without `Previous` and `Original`.
  - Appending twice gives two blocks separated by one blank line.
  - Removing by short id deletes that block only, and leaves the rest byte-for-byte unchanged.
  - Removing an id that isn't in the file leaves the file unchanged.
  - The file is created `0600`.
  - "Ensure exists" creates the header comment once and never overwrites an existing file.
- **Store:** flag state toggles on a row and is cleared by Clear.
- **By hand:**
  - The hover button and the settled-only rule.
  - The Click-Through behaviour.
  - That other backends and the caption panel show no button.
  - The menu item.
- Prior art: the transcript self-test for file output and permissions, and the store self-test for row state. The new tests join the self-test run, so `make test` covers them.

## Out of Scope

- A global shortcut to flag the last row, which would also work with Click-Through on. Possible later.
- Flagging on backends other than Gemini Live, or in the caption panel.
- Suggesting glossary entries from flagged rows, or editing `glossary.txt` automatically.
- Showing flagged rows in the transcript.
- Remembering flag state across Clear or restart.

## Further Notes

- Domain terms used here (row, flag, flagged row, corrected row, original English, glossary) are defined in the root `GLOSSARY.md`.
