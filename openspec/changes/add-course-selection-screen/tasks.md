# Tasks

- [ ] Create `lib/src/features/home/presentation/course_selection_screen.dart` with `CourseSelectionScreen` widget. <!-- id: 0 -->
  - Implement Header (Title + Close).
  - Implement Category Filter (Mock state).
  - Implement Course Grid with `CourseCard` widget.
  - Create Mock Data for at least 4 courses matching the design.
- [ ] Update `lib/src/features/home/presentation/home_screen.dart`: <!-- id: 1 -->
  - Add `onTap` to the top-right icon to `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const CourseSelectionScreen())`.
