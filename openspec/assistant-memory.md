# Assistant Memory (Project Snapshot)

Last updated: 2026-02-19

## 1) 5分钟上手
- 项目：`engbooks`（Flutter 英语学习 App，移动端优先）。
- 当前核心：本地课程包驱动的句子练习（主流程）+ 阅读模式 + 下载中心。
- 技术栈：Flutter 3.x + Riverpod + go_router + `video_player` + `just_audio` + `record` + `shared_preferences`。
- 架构形态：Feature-first，`presentation`（页面/UI）+ `application`（可测试服务）+ `data`（存储/加载）+ `domain`（模型）。

## 2) 当前真实路由（以代码为准）
文件：`lib/src/routing/routes.dart`
- `/` -> `HomeScreen`
- `/download-center` -> `DownloadCenterScreen`
- `/practice/sentence/:id` -> `SentencePracticeScreen`
- `/practice/reading/:id` -> `ReadingPracticeScreen`

说明：旧的 `/practice/settings` 已不存在；播放设置统一走 bottom sheet。

## 3) 目录与模块地图
- `lib/src/features/home/*`：主页与空态。
- `lib/src/features/download_center/*`：课程下载/目录来源。
- `lib/src/features/practice/*`：练习域（最核心、变更最频繁）。
- `lib/src/routing/*`：路由与导航。

`practice` 内重点：
- `presentation/sentence_practice_screen.dart`
  - 当前业务中枢，依赖多个 application service。
  - 管理音频/视频播放、句子切换、影子跟读（shadowing）、设置同步、课程切换。
- `presentation/reading_practice_screen.dart`
  - 阅读模式页面，已接入播放设置 sheet。
- `presentation/playback_settings_screen.dart` + `playback_settings_sheet.dart`
  - 仅保留 bottom sheet 用法。
- `presentation/course_unit_picker_*`
  - 课程/单元切换弹窗与构建逻辑。

## 4) Practice 关键服务分层
`lib/src/features/practice/application/*`
- `practice_media_playback_service.dart`：音频/视频播放控制抽象。
- `sentence_seek_coordinator.dart`：句子定位与 seek 协调。
- `practice_sentence_end_action_planner.dart`：句尾后续动作策略。
- `practice_lesson_*_service/planner.dart`：lesson 索引、翻页、预览等。
- `shadowing_auto_record_service.dart` + `shadowing_step_controller.dart`：自动录音与跟读步骤控制。
- `practice_playback_settings_provider.dart`：播放设置 Riverpod 状态入口。

设计意图：把 `SentencePracticeScreen` 里“可纯逻辑化”的部分剥离到 service，提升可测性，避免 UI 巨石继续膨胀。

## 5) 数据存储与状态
`lib/src/features/practice/data/*`
- `practice_playback_settings_store.dart`
  - 播放设置持久化（`practice_playback_settings_v1`）。
  - 使用写队列串行化写入。
- `learning_metrics_store.dart`
  - 课程/单元练习次数、进度、熟练度快照（`learning_metrics_v1`）。
  - 写队列串行化，提供 `courseView/unitView`。
- `learning_resume_store.dart`
  - 最近学习位置（`learning_resume_v1`）。
  - 已修复 `save/clear` 并发竞态：`clear` 会使旧 save 失效并进入统一写队列。
- `local_course_package_loader*.dart`
  - 本地课程包解析与句子加载。

## 6) 已完成的关键重构点（近期）
- 播放设置入口统一为 bottom sheet，删除未使用全屏分支。
- 移除未使用 API：`PracticePlaybackSettingsController.reset()`。
- `LearningResumeStore` 增强并发安全（token + queue）。
- 新增回归测试：`clear wins against in-flight stale save writes`。
- `reading_practice_screen.dart` 清理 `withOpacity` 旧用法与部分 lint 噪音。

## 7) 测试与验证抓手
优先跑（快速回归）：
- `flutter test test/features/practice/data/learning_resume_store_test.dart`
- `flutter test test/features/practice/data/practice_playback_settings_store_test.dart`
- `flutter test test/features/practice/presentation/sentence_practice_playback_settings_test.dart`

局部静态检查：
- `flutter analyze lib/src/features/practice/...`

## 8) 下次接手建议顺序
1. 先看 `lib/src/features/practice/presentation/sentence_practice_screen.dart` 当前职责边界。
2. 再看 `application/*` 新增 service 是否已完全接管对应逻辑。
3. 检查 `data/*_store.dart` 的并发写入策略是否一致（是否都需要 clear 与 save 串行化）。
4. 跑上述 3 个关键测试确保基础稳定后再扩展功能。

## 9) 当前技术债（高优先）
- `SentencePracticeScreen` 仍偏大，仍有可继续下沉到 service/controller 的逻辑。
- 播放器链路（audio/video/preview controller）仍在页面层维护较多状态，后续可进一步状态机化。
- 全量 analyze 仍有部分非本轮范围的 info 级提示，后续可分批清理。
