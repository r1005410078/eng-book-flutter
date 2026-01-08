# ui Specification

## Purpose
TBD - created by archiving change impl-playback-settings. Update Purpose after archive.
## Requirements
### Requirement: The Playback Settings screen allows configuring playback speed

The application MUST provide controls to adjust the audio playback speed. Available options should include 0.5x, 0.75x, and 1.0x (normal speed).

#### Scenario: User changes playback speed

Given the user is on the Playback Settings screen
When they tap "0.5x"
Then the playback speed is set to 0.5
And the "0.5x" button becomes active

### Requirement: The Playback Settings screen allows toggling subtitles

The application MUST allow users to toggle the visibility of English text, Chinese translation, and a "Blur Default" option for active recall practice.

#### Scenario: User toggles English subtitle

Given the English subtitle is ON
When the user taps the toggle
Then the English subtitle turns OFF

### Requirement: The Playback Settings screen allows configuring playback behavior

The application MUST allow configuration of playback behaviors such as loop count per sentence, auto-pause at the end of sentences, and auto-recording.

#### Scenario: User changes loop count

Given the loop count is 3
When the user taps "+"
Then the loop count becomes 4

### Requirement: The Playback Settings screen allows configuring font size

The application MUST provide a slider to adjust the text size of the subtitles, ranging from small to large.

#### Scenario: User changes font size

Given the font size slider is at standard position
When the user drags it to the right
Then the font size increases

