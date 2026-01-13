# 提案：课程选择页面

## Why

用户希望在首页通过右上角的图标进入“课程选择”页面，以便切换不同的学习课程。这符合及设计稿的需求，允许用户在不同教材（如视频、书籍、播客）之间进行选择。

## What Changes

1.  **新功能**: `CourseSelectionScreen` 组件。
    - **UI**: 全屏模态弹窗风格（深色主题）。
    - **头部**: 标题“选择课程” + 关闭/退出按钮。
    - **筛选栏**: 横向滚动的分类标签（全部、我的、视频、书籍、入门等）。
    - **统计**: 显示“共找到 X 个教程”。
    - **列表**: 课程卡片的网格布局。
2.  **入口**: 更新 `HomeScreen` 的右上角图标 (`Icons.menu_book_rounded`) 点击事件，使其打开此新页面。
    - 使用 `showModalBottomSheet` (isScrollControlled: true) 或 `showGeneralDialog` 来实现全屏弹窗效果。
3.  **数据**: 添加课程的 Mock 数据（包含封面图、标题、章节数、类型等）。

## Impact

- `HomeScreen`: modify `_buildTopBar` 添加 `onTap` 处理。
- 新增文件: `lib/src/features/home/presentation/course_selection_screen.dart`.
