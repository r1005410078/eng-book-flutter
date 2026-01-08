# 设计：句子练习视图

## UI 架构

### 布局结构

- **根节点**: `Scaffold`，使用暗色主题。
- **背景**: `VideoPlayer` 组件，设置为 `BoxFit.cover`，带有半透明黑色遮罩以确保文字可读性。
- **顶部栏**: 自定义 `AppBar` 或 `SafeArea` 行，包含：
  - 关闭按钮（返回完整播放器/列表）。
  - 进度指示器（例如，“Fire 12”）。
- **内容区域 (居中/可滚动)**:
  - **可视化波形/音频指示器**: 音频的动态可视化。
  - **主要文本**: 大号、清晰的英语文本。
  - **音标**: 文本下方的 IPA 音标。
  - **翻译**: 默认隐藏，通过“点击显示翻译”按钮切换。
  - **关键词/标签**: 关键短语的 Chips（例如，“have been”，“all this time”）。
  - **语法注释**: 卡片式组件，解释语法点（例如，现在完成时）。
- **底部栏**: `ControlPanel`，包含：
  - 导航（上一句/下一句）。
  - 播放控制（播放/暂停，循环）。
  - 录音（麦克风按钮）。

## 数据模型

- **SentenceDetail**:
  - `String text` (文本)
  - `String translation` (翻译)
  - `String phonetic` (音标)
  - `Map<String, String> grammarNotes` (语法笔记，Key: 短语, Value: 解释)
  - `Duration startTime` (开始时间)
  - `Duration endTime` (结束时间)

## 状态管理

- 将使用 **Riverpod** 来：
  - 跟踪 `currentSentenceId`（当前句子 ID）。
  - 控制音频/视频跳转到特定句子范围。
  - 管理翻译的“隐藏/显示”状态。

## 路由

- 新路由路径: `/practice/:id` 或 `/player/practice`。
- 参数: `sentenceIndex` 或 `sentenceId`。

## 依赖

- `video_player` / `chewie` (或现有的 `better_player`) 用于背景视频。
- `just_audio` 用于精确的音频循环。
