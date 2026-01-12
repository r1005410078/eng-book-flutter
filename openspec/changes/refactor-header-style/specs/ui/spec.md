# UI Spec: Refactor Header Style

## MODIFIED Requirements

### Requirement: Header Layout

The header MUST be updated to display a textual progress indicator instead of segmented pills.

#### Scenario: Display Progress Text

- **Given** The user is on the practice screen
- **Then** The header title should be "Friends S01E01"
- **And** The subtitle should show "第 {currentIndex+1} / {total} 句"
- **And** The right icon should be a generic menu/list icon

### Requirement: Interactivity

The right menu icon MUST be interactive (placeholder).

#### Scenario: Tap Menu

- **Given** The user taps the menu icon
- **Then** (For now) nothing happens or a toast appears (placeholder)
