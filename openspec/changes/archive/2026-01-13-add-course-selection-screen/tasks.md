# Tasks

- [x] 创建 `lib/src/features/home/presentation/course_selection_screen.dart` 并实现 `CourseSelectionScreen` 组件。 <!-- id: 0 -->
  - 实现头部（标题 + 关闭按钮）。
  - 实现分类筛选栏（Mock 状态）。
  - 实现课程网格及 `CourseCard` 组件。
  - 创建至少 4 个符合设计稿的 Mock 课程数据。
- [x] 更新 `lib/src/features/home/presentation/home_screen.dart`: <!-- id: 1 -->
  - 为右上角图标添加 `onTap` 事件，调用 `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const CourseSelectionScreen())`。
