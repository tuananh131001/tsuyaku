# Tsuyaku

Live subtitles for meetings: other people's Japanese speech shown as English in a floating panel, plus Japanese captions of the user's own English.

## Language

**Glossary**:
The user's list of fixed Japanese → English term pairs, such as company names and in-house jargon, that a translation must render exactly.
_Avoid_: Dictionary, vocabulary, term list

**Row**:
One line of the subtitle panel: a stretch of source speech and its English translation.
_Avoid_: Line, subtitle, segment

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
