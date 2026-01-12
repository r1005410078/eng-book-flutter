# Tasks

- [x] 在 `SentencePracticeScreen` 中引入 `audio_waveforms`, `path_provider`, `dart:io`。 <!-- id: 0 -->
- [x] 创建 `_downloadAudioFile(String url)` 方法，将音频保存到临时目录。 <!-- id: 1 -->
- [x] 初始化 `PlayerController` 并在 `initState` 中调用下载与 `preparePlayer`。 <!-- id: 2 -->
- [x] 更新 `_syncSentenceWithVideo` 逻辑：执行 `_waveformController.seekTo(...)` 以同步视觉进度。 <!-- id: 3 -->
- [x] 替换 `_buildWaveformArea` UI，使用 `AudioFileWaveforms` 组件。 <!-- id: 4 -->
- [x] 移除旧的 `generatedWaveformHeights` 常量。 <!-- id: 5 -->
