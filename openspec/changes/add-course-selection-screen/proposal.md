# Proposal: Course Selection Screen

## Why

User wants to add a "Course Selection" screen accessible from the Home Screen's top-right corner to allow switching between different learning courses. This aligns with the "100LS" methodology where users might have multiple materials.

## What Changes

1.  **New Feature**: `CourseSelectionScreen` widget.
    - **UI**: Full-screen modal style (dark theme).
    - **Header**: Title "选择课程" + Close Button.
    - **Filter**: Horizontal scrollable categories (All, My, Video, Book, Intro).
    - **Count**: "Found X courses".
    - **List**: Grid view of course cards.
2.  **Entry Point**: Update `HomeScreen`'s top-right icon (`Icons.menu_book_rounded`) to open this new screen using structured navigation (or `showModalBottomSheet` as requested "popup dialog mode").
    - _Decision_: Use `showModalBottomSheet` with `isScrollControlled: true` and `useRootNavigator: true` to ensure it covers the bottom nav if needed, or simply `showGeneralDialog` for a custom full-screen dialog. Given the design looks like a full screen overlay with a close button, `showModalBottomSheet` full height is a standard Flutter pattern for "popup dialogs" that feel like pages.
3.  **Data**: Add mock data for courses.

## Impact

- `HomeScreen`: Modify `_buildTopBar` to add `onTap` handler.
- New file: `lib/src/features/home/presentation/course_selection_screen.dart`.
