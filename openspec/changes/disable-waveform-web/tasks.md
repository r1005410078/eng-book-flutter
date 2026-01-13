# Tasks

- [x] 在 `SentencePracticeScreen` 中引入 `flutter/foundation.dart`。 <!-- id: 0 -->
- [x] 修改 `_prepareWaveform`：增加 `if (kIsWeb) return;` 守卫。 <!-- id: 1 -->
- [x] 修改 `initState`：仅在 `!kIsWeb` 时初始化波形控制器。 <!-- id: 2 -->
- [x] 修改 `_buildWaveformArea`：如果是 Web，不渲染波形组件。 <!-- id: 3 -->
- [x] 检查并保护所有对 `_waveformController` 的调用（dispose, listen 等）。 <!-- id: 4 -->
