# Change: 重构播放器 UI (沉浸式 100LS 模式)

## Why

现有的播放器界面较为基础，缺乏 100LS 训练法所需的沉浸感和核心交互元素。参考最新的设计图，我们需要：

1.  **提升视觉体验**：采用暗色主题，营造专注的学习氛围。
2.  **强化核心交互**：突出 "跟读/录音" 按钮，这是 100LS 中 "Speak" 的关键。
3.  **支持分句练习**：从单纯的进度条拖动，转向更适合学习的 "上一句/下一句" 导航。
4.  **内容可视化**：清晰展示当前句子的中英文对照，辅助理解。

## What Changes

### UI 重构

- 🎨 **整体风格**：全屏暗色模式，顶部带有课程信息的自定义导航栏。
- 🖼️ **视觉区域**：顶部展示场景图片/视频封面，叠加播放状态。
- 📝 **字幕区域**：
  - 高亮显示当前英文句子（大字号）。
  - 辅助显示中文翻译（小字号，灰色）。
  - 显示 "Original Audio" 标签。
- 📊 **进度显示**：
  - "进度"标签 + "句子 X/Y" 计数。
  - 细线条橙色进度条。
- 🎮 **底部控制栏**：
  - 悬浮胶囊样式。
  - 核心功能：上一句、录音（大橙色按钮）、下一句。
  - 评分/反馈胶囊显示（如 "92 分"）。

### 数据与逻辑 (MVP 阶段)

- 🏗️ **Mock 数据**：由于暂时没有真实的字幕文件，将硬编码或 Mock 一组句子数据 (Start, End, Text, Translation) 用于 UI 开发和验证。
- 🔄 **模拟分句导航**：实现简单的"上一句/下一句"逻辑，通过 Seek 跳转到特定时间点。

## Impact

### 涉及 Specs

- `audio-player` (MODIFIED)

### 涉及代码

- `lib/src/features/audio_player/screens/audio_player_screen.dart` (重写)
- `lib/src/features/audio_player/widgets/` (新增 lyric_view, control_bar 等组件)
- `lib/src/features/audio_player/models/` (新增 sentence_model.dart)
