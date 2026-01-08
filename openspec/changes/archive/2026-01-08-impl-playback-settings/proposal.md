# Implement Playback Settings Screen

## Summary

Implement a new "Playback Settings" screen (`PlaybackSettingsScreen`) to allow users to configure audio playback preferences, subtitle visibility, and practice behaviors. This screen matches the design provided in `design/31767863254_.pic.jpg`.

## Motivation

Users need granular control over their learning experience, specifically adjusting speed, toggling subtitles for active recall (100LS method), and setting up auto-pause/looping for shadowing practice.

## Goals

- Create a dedicated settings page.
- Implement UI for:
  - Playback Speed (0.5x, 0.75x, 1.0x)
  - Subtitle Toggles (English, Chinese, Blur)
  - Playback Behaviors (Loop count, Auto-pause, Auto-record)
  - Text Size Slider
- Persist these settings (Mock or LocalStorage).
