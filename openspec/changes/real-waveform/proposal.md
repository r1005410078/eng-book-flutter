# 提案：使用音频插件绘制真实波形

## 变更背景

目前的音频波形是硬编码的静态数据 (`generatedWaveformHeights`)。用户希望使用 `audio_waveforms` 插件，根据实际的音频文件绘制真实的波形图，以提供更专业和准确的练习体验。

## 目标

1.  **实现音频文件下载**: 将远程音频文件 (`SoundHelix-Song-1.mp3`) 下载到本地临时目录。
2.  **集成 audio_waveforms**: 使用 `PlayerController` 加载本地音频文件并生成波形数据。
3.  **替换波形视图**: 使用 `AudioFileWaveforms` 替换现有的静态柱状图。
4.  **同步进度**: 确保波形图的进度显示与视频播放进度保持同步。

## 范围

- `SentencePracticeScreen`:
  - 增加文件下载逻辑。
  - 引入 `PlayerController` (`audio_waveforms` 包)。
  - 替换 `_buildWaveformArea`。
  - 在 `_syncSentenceWithVideo` 中同步波形进度。

## 风险

- **性能**: 下载和解析波形可能需要少量时间，需要处理加载状态。
- **同步**: `VideoPlayer` 和 `audio_waveforms` 的 `PlayerController` 是两个独立的播放控制器。我们将以 `VideoPlayer` 为主，手动同步 `PlayerController` 的进度，但这可能会导致波形指示器的移动不够平滑（取决于同步频率）。
