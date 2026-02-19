# Change: Add Practice Playback Settings Integration

## Why
当前播放设置面板以 UI 配置为主，缺少与练习播放流程的完整联动。用户调整设置后可能无法即时影响当前练习，退出重进后也无法稳定恢复，影响学习连续性和设置可信度。

## What Changes
- 将播放设置统一接入练习播放主流程，确保设置项在当前会话中即时生效。
- 增加设置持久化与恢复机制，支持重进后保留最近一次有效设置。
- 明确播放行为冲突优先级（单句循环、自动录音）并统一执行顺序。
- 增加录音权限与平台能力降级策略，避免不支持场景导致流程中断。
- 补齐设置联动回归测试，覆盖设置变更、生效、恢复与冲突场景。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/practice/presentation/playback_settings_screen.dart`
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/application/*`
  - `lib/src/features/practice/data/*`
  - `test/features/practice/*`
