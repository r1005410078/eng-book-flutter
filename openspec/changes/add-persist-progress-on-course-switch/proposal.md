# Change: Add Progress Persistence On Course Switch

## Why
当前在上下切换课程/单元时，学习位置保存时机不稳定，用户重新进入后可能回到错误句子，造成“视频与字幕上下文不连续”的体验问题。

## What Changes
- 在用户切换课程/单元时立即保存当前学习进度（`packageRoot`、课程名、句子 ID、所属单元）。
- 统一进度保存触发点，避免并发切换导致旧进度覆盖新进度。
- 启动首页学习流时优先恢复最近一次有效进度；若进度无效则回退到本地课程首句。
- 增加回归测试覆盖“切换后重进恢复”的关键路径。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/data/learning_resume_store.dart`
  - `lib/src/features/home/presentation/home_screen.dart`
  - `test/features/practice/*`
