# Change: 新增课程详情页

## Why

用户需要在开始学习之前查看课程的详细信息（如故事情节、语法重点、学习收获），以便更好地了解课程内容并建立学习预期。这将显著提升用户体验，帮助用户做出学习决定。

## What Changes

- 新增 `CourseDetailScreen` 页面，展示以下内容：
  - 课程封面、标题、作者和难度等级。
  - 统计信息（章节数、时长、词汇量）。
  - “故事情节”描述部分。
  - “语法重点”部分，使用标签展示。
  - “你将掌握”列表部分。
  - 底部固定的“开始学习”按钮。
- 在 `AppRouter` 中注册新路由。
- 实现从“课程选择”页面点击课程卡片跳转到详情页的交互。
- 确保 UI 设计符合深色主题、圆角标签和橙色主按钮的视觉规范。

## Impact

- **受影响的 Specs**: `ui`
- **受影响的代码**:
  - `lib/src/features/home/presentation/course_detail_screen.dart` (新增)
  - `lib/src/features/home/presentation/course_selection_screen.dart` (更新导航)
  - `lib/src/routes/app_router.dart` (新增路由)
