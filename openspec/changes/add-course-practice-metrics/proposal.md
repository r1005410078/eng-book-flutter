# Change: Add Course Practice Metrics In Picker

## Why
当前课程/单元选择面板只能切换课程与单元，缺少学习状态反馈。用户无法快速判断每门课的练习次数、当前进度和熟练度，影响继续学习决策与复习优先级判断。

## What Changes
- 为课程与单元增加可计算、可持久化的学习指标：练习次数、练习进度、熟练度。
- 在课程/单元选择面板中展示上述指标，并区分“未开始 / 学习中 / 已完成”状态。
- 定义练习行为到指标更新的触发时机（进入练习、切句、切单元、跨课程切换）。
- 在恢复学习场景中保持指标一致性，避免切换后统计回退。
- 增加指标计算与面板展示的自动化测试。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/presentation/widgets/short_video_header.dart`
  - `lib/src/features/practice/application/local_course_provider.dart`
  - `lib/src/features/practice/data/learning_resume_store.dart`
  - `lib/src/features/practice/data/local_course_package_loader_io.dart`
  - `test/features/practice/*`
