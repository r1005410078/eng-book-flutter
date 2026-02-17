# Change: Integrate Local Course Package Playback

## Why
当前课程包已经能通过 pipeline 产出，但 Flutter 端仍存在关键断点：句子练习页使用 mock 数据、课程详情“开始学习”未打通、本地媒体未接入播放器。这导致“从课程包到学习流程”的闭环尚未成立。

## What Changes
- 新增本地课程包数据入口：统一扫描 `.runtime/tasks/*/package` 的 ready 课程并读取 `course_manifest.json` / `lesson.json`。
- 打通课程入口流程：课程选择页展示本地课程、课程详情页“开始学习”进入真实课程学习。
- 统一阅读页与句子页数据源：两页共用同一课程上下文，不再依赖 `mockSentences`。
- 接入本地媒体播放：根据 `lesson.media.type/path` 选择本地视频或音频播放，并保持句子时间轴同步。
- 增加降级策略：课程包缺失或字段不完整时，给出可见提示并安全回退。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/home/presentation/course_selection_screen.dart`
  - `lib/src/features/home/presentation/course_detail_screen.dart`
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/presentation/reading_practice_screen.dart`
  - `lib/src/features/practice/data/local_course_package_loader*.dart`
  - `lib/src/features/practice/domain/*` (新增课程包/课时上下文模型)
