# Proposal: Refactor Header Style

## Why

User requested a UI update for the header to match a specific design style (screenshot provided). The expected changes are to replace the segmented progress bar with a textual progress indicator and update the right-side icon.

## What Changes

1.  **Header UI**:
    - Change the central content from a row of progress pills to a Column containing a Title ("Friends S01E01") and a Subtitle ("第 X / Y 句").
    - Change the right-side icon from Streak/Flame to a "Menu" / "List" icon.
2.  **Mock Data Usage**: Use the existing `mockSentences` length for the "Y" value and `_currentIndex + 1` for the "X" value.
3.  **Styling**: Use a clean, centered text style for the title and a smaller, greyed-out style for the progress text.

## Impact

- `SentencePracticeScreen`: `_buildHeader` method will be heavily modified.
- No logic changes expected, purely cosmetic/UI.
