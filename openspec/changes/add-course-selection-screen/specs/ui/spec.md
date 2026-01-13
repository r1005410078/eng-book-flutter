# key: add-course-selection-screen

# UI Spec: Course Selection Screen

## ADDED Requirements

### Requirement: Entry Point

The specific icon on the Home Screen MUST open the Course Selection Screen.

#### Scenario: Open Selection

- **Given** The user is on the Home Screen
- **When** The user taps the top-right "Book/Menu" icon
- **Then** The Course Selection Screen appears as a full-screen modal/dialog

### Requirement: Category Filter

The screen MUST display a horizontal list of categories.

#### Scenario: Select Category

- **Given** The filter bar shows "全部", "我的", etc.
- **When** The user taps "视频"
- **Then** The chip becomes active (Orange background)
- **And** The course list filters to show only video courses (Mock logic: just update UI state)

### Requirement: Course Grid

The screen MUST display courses in a grid layout.

#### Scenario: View Courses

- **Given** The user views the grid
- **Then** Each card shows cover image, title, chapter count
- **And** "Continue Learning" tag appears on the active course
- **And** Different icons represent media type (Podcast vs Video) - (Mock data)
