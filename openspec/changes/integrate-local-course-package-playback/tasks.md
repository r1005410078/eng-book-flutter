## 1. Data Layer
- [x] 1.1 新增本地课程包仓库（扫描 `.runtime/tasks/*/package` 并读取课程清单）。
- [x] 1.2 建立课程/课时/句子统一模型，保留 `lesson_id` 与 `media.path/type` 关联。
- [x] 1.3 提供 Riverpod provider，暴露“课程列表、当前课程、当前句子列表”。

## 2. Entry Flow
- [x] 2.1 课程选择页从本地仓库读取课程，替换纯 mock 列表。
- [x] 2.2 课程详情页“开始学习”跳转到句子练习页，并携带课程上下文。
- [x] 2.3 阅读页与句子页改为读取统一 provider，不再各自加载/拼装数据。

## 3. Local Playback MVP
- [x] 3.1 句子练习页按课程包媒体类型接入本地播放（`video_player.file` / `just_audio`）。
- [x] 3.2 保持句子时间轴同步（seek、上一句/下一句、进度条拖动）。
- [x] 3.3 阅读页与句子页切换时保持同一课程上下文与当前句位置。

## 4. Resilience
- [x] 4.1 当课程包缺失文件或字段异常时，显示可见错误提示并回退默认内容。
- [x] 4.2 统一默认路径策略：优先 `--dart-define COURSE_PACKAGE_DIR`，否则自动发现最新 ready 包。

## 5. Verification
- [x] 5.1 为仓库解析与路径发现补充单元测试。
- [x] 5.2 为“课程进入学习页”补充 widget 测试。
- [x] 5.3 为“句子页本地媒体初始化 + 句子同步”补充基础测试。
