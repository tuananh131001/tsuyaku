# Tsuyaku

Live subtitles for meetings: other people's Japanese speech shown as English in a floating panel, plus Japanese captions of the user's own English.

## Language

**Glossary**:
The user's list of fixed Japanese → English term pairs, such as company names and in-house jargon, that a translation must render exactly.
_Avoid_: Dictionary, vocabulary, term list

**Row**:
One line of the subtitle panel: a stretch of source speech and its English translation.
_Avoid_: Line, subtitle, segment

**Live row**:
A row still being heard or translated. Its source and English can change until it settles.
_Avoid_: Current line, in-progress row, pending row

**Settled row**:
A row that has finished and will not change again. It stays on screen with the earlier rows and goes into the transcript.
_Avoid_: History line, final row, finished line

**Backend**:
The service or model that turns the other speakers' speech into English, such as Gemini Live, Claude or Apple's on-device translation.
_Avoid_: Provider, engine, translator

**Glossary correction**:
A second pass over a finished row that replaces wrong renderings of glossary terms with the glossary's English, used where the translating backend cannot be given the glossary.
_Avoid_: Rewrite, post-edit, fix-up

**Corrected row**:
A row whose English was changed by glossary correction. It is shown in a distinct colour.
_Avoid_: Rewritten row, fixed row

**Flag**:
The user's mark on a row whose translation they judge wrong, kept so they can fix the glossary later. A flag can be removed again.
_Avoid_: Report, mark wrong, bad translation

**Flagged row**:
A row the user has flagged.
_Avoid_: Reported row, wrong row

**Original English**:
The backend's English for a corrected row, from before glossary correction changed it. Hidden by default; the user can reveal it.
_Avoid_: Raw output, Gemini output, uncorrected text
