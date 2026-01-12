# 规格：Web 兼容性

## MODIFIED Requirements

### Requirement: Web 平台禁用波形

当应用运行在 Web 平台 (`kIsWeb` 为 true) 时，系统必须 (MUST) 禁用所有真实波形相关的逻辑和 UI。

#### Scenario: Web 环境运行

- **Given** 应用运行在 Web 浏览器中
- **Then** `_prepareWaveform` 不应执行
- **And** 波形区域 (`_buildWaveformArea`) 应隐藏或不显示 `AudioFileWaveforms` 组件
- **And** 不会有 `dart:io` 相关的运行时错误

### Requirement: 非 Web 平台保持原样

非 Web 平台（如 Android/iOS）必须 (MUST) 继续正常显示真实波形。

#### Scenario: 移动端运行

- **Given** 应用运行在 iOS 或 Android
- **Then** 波形功能正常初始化并显示
