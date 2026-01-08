# Design: Playback Settings

## Reference

Image: `design/31767863254_.pic.jpg` - "播放设置"

## UI Architecture

- **Scaffold**: Dark theme (Background: Dark Brown/Black similar to SentencePractice).
- **AppBar**: Title "播放设置", Back button (leading), Reset button (action).
- **Body**: Scrollable list of sections.

## Sections

1.  **Playback Speed (播放语速)**

    - Segmented Control or Row of Buttons.
    - Hint text: "降低语速有助于听清..."

2.  **Subtitle Display (字幕显示)**

    - ListTile based toggle switches.
    - Icons for each setting.
    - "Blur Translation" specific description.

3.  **Playback Behavior (播放行为)**

    - Counter widget for "Loop Count" (`- N +`).
    - Switches for "Auto-pause" and "Auto-record".

4.  **Interface Settings (界面设置)**
    - Slider for font size.
    - Labels "A" -- "A".

## Navigation

- Likely accessed from the `SentencePracticeScreen` (e.g., via a Settings icon in the header or bottom sheet).
- Route path: `/practice/settings` (or similar).
