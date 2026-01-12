# 提案：Web 平台禁用波形功能

## 变更背景

`audio_waveforms` 插件及相关的文件操作 (`dart:io`) 不支持 Web 平台。为了保证 Web 端的兼容性和正常运行，需要检测当前平台。如果是 Web 平台，应禁用波形相关的初始化逻辑并隐藏波形 UI。

## 目标

1.  **平台检测**: 使用 `kIsWeb` 判断当前是否为 Web 环境。
2.  **逻辑保护**: 仅在非 Web 平台下执行 `_prepareWaveform`（下载与初始化控制器）。
3.  **UI 隐藏**: 在 Web 平台下，隐藏波形视图 (`_buildWaveformArea`) 或显示替代占位符。

## 范围

- `SentencePracticeScreen`:
  - `import 'flutter/foundation.dart'`.
  - `initState` / `_prepareWaveform`.
  - `_buildWaveformArea`.
  - `dispose` (避免释放未初始化的控制器).

## 风险

- 如果项目严格禁止 `import 'dart:io'` 出现在 Web 构建中，仅运行时的 `if (!kIsWeb)` 是不够的，还需要处理 import。但鉴于这是一个单文件修改任务，我们首先通过 `kIsWeb` 避免运行时错误。如果构建报错，可能需要移除 `dart:io` 并改用 universal 包（这超出了简单修改范围，暂不考虑，除非构建失败）。

_修正: 为了确保 Web 能编译， ideally 我们应该移除 `dart:io` 的直接引用，但代码里用了 `File` 类。如果不分拆文件，很难完全避开。我们先做逻辑屏蔽。_

## Tasks

- [ ] 引入 `flutter/foundation.dart`。 <!-- id: 0 -->
- [ ] 在 `initState` 中，仅当 `!kIsWeb` 时调用 `_prepareWaveform`。 <!-- id: 1 -->
- [ ] 修改 `_prepareWaveform`，增加 `if (kIsWeb) return;` 保护。 <!-- id: 2 -->
- [ ] 修改 `_buildWaveformArea`：如果是 Web，返回 `SizedBox.shrink()` 或简易占位。 <!-- id: 3 -->
- [ ] 修改 `dispose` 和其他调用处：检查 `_isWaveformReady` 或 `kIsWeb`，防止空指针或非法调用。 <!-- id: 4 -->
