## 1. 依赖配置

- [x] 1.1 确认 `just_audio` 和 `flutter_riverpod` 已添加到 `pubspec.yaml`
- [x] 1.2 运行 `flutter pub get` 确保依赖安装成功

## 2. 项目结构搭建

- [x] 2.1 创建 `lib/src/features/audio_player/` 目录
- [x] 2.2 创建 `lib/src/features/audio_player/providers/` 目录
- [x] 2.3 创建 `lib/src/features/audio_player/widgets/` 目录
- [x] 2.4 创建 `lib/src/features/audio_player/models/` 目录

## 3. Riverpod Provider 实现

- [x] 3.1 创建 `audio_player_provider.dart`
- [x] 3.2 定义 `AudioPlayerState` 模型（播放状态、进度、时长等）
- [x] 3.3 实现播放/暂停/停止方法
- [x] 3.4 实现倍速调整方法
- [x] 3.5 实现进度更新监听
- [x] 3.6 处理播放器资源释放（`ref.onDispose`）

## 4. UI 组件开发

- [x] 4.1 创建 `audio_player_controls.dart`（播放控制按钮）
- [x] 4.2 创建 `audio_progress_bar.dart`（进度条组件）
- [x] 4.3 创建 `playback_speed_selector.dart`（倍速选择器）
- [x] 4.4 创建 `audio_player_screen.dart`（完整播放器页面）

## 5. 集成测试

- [x] 5.1 测试音频文件加载
- [x] 5.2 测试播放/暂停功能
- [x] 5.3 测试倍速调整
- [x] 5.4 测试进度拖动
- [x] 5.5 测试播放完成后的状态重置

## 6. 文档与优化

- [x] 6.1 添加代码注释
- [x] 6.2 运行 `dart format` 格式化代码
- [x] 6.3 确保通过 `flutter analyze` 静态分析
