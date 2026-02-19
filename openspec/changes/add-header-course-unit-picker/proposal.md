# Change: Add Header Course And Unit Picker

## Why
当前短视频学习页只能通过上下滑切换当前课程内单元，无法在练习中快速切换到其他课程或直达目标单元。用户需要退出或多次滑动，路径较长，影响连续学习体验。

## What Changes
- 在练习页头部增加可点击标题入口，点击后弹出课程/单元选择面板。
- 面板顶部展示课程列表，支持在已安装课程间切换；下方展示所选课程的单元列表。
- 选择单元后直接切换到该课程对应单元，并关闭面板返回练习页。
- 切换成功后同步更新当前学习上下文与学习进度持久化（课程、单元、句子）。
- 增加交互与状态同步测试，覆盖“跨课程切换”“同课程切单元”“取消面板不变更”。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/practice/presentation/widgets/short_video_header.dart`
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/application/local_course_provider.dart`
  - `lib/src/features/practice/data/local_course_package_loader_io.dart`
  - `lib/src/features/practice/data/learning_resume_store.dart`
  - `test/features/practice/*`
