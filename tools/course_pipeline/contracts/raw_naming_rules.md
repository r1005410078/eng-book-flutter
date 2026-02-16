# Raw Folder Naming Rules

## Required
- Lesson media files MUST use a numeric prefix key: `NN_*.mp4` or `NN_*.mp3`.
- `NN` MUST be zero-padded two digits for MVP (`01`, `02`, ...).
- Matching between media and sidecar files MUST use `NN` only.

## Optional Sidecar Files
- `NN.md`
- `NN.en.srt`
- `NN.zh.srt`

## Examples
- `01_greeting.mp4`
- `01.md`
- `01.en.srt`
- `01.zh.srt`

## Rejection Cases
- Missing numeric prefix (`greeting.mp4`)
- Non-numeric prefix (`aa_greeting.mp4`)
- Duplicate media for same key in one lesson (`01_a.mp4` + `01_b.mp4`)
