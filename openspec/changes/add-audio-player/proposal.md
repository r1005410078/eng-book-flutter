# Change: 添加音频播放器功能

## Why

100LS 训练法的核心是反复聆听英语素材，用户需要：

- 精确控制播放进度（倍速、AB 循环）
- 随时暂停/继续播放
- 支持多种音频格式

目前项目还没有音频播放能力，这是实现 100LS 训练法的基础功能。

## What Changes

- ✅ 集成 `just_audio` 库实现音频播放
- ✅ 提供播放/暂停/停止控制
- ✅ 支持倍速播放（0.5x - 2.0x）
- ✅ 支持进度条拖动
- ✅ 显示当前播放时间/总时长
- ✅ 使用 Riverpod 管理播放器状态
- ✅ AB 循环功能（可选，后续迭代）

## Impact

### 新增能力

- **Specs**: `audio-player`（新建）

### 涉及代码

- `lib/src/features/audio_player/` - 新建音频播放器功能模块
- `lib/src/features/audio_player/providers/audio_player_provider.dart` - Riverpod 状态管理
- `lib/src/features/audio_player/widgets/` - 播放器 UI 组件

### 依赖

- `just_audio: ^0.9.46` (已添加)
- `flutter_riverpod: ^2.6.1` (已添加)
