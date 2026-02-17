# Change: Refactor To Short Video Learning Flow

## Why
当前学习流存在两类问题：
1. 首页到练习页路径偏长，进入练习前操作成本高。
2. 练习页“视频 + 字幕 + 语法常驻”容易打断心流，影响持续跟读。

为提升沉浸感和启动效率，需要将主学习路径重构为小视频风格交互，并把解释信息改为按需查看。

## What Changes
- 将首页重构为小视频学习主界面（首页即练习页），支持打开即学并恢复上次学习位置。
- 支持左右滑动切换句子（左滑下一句，右滑上一句）。
- 支持上下滑动切换单元（上滑下一单元，下滑上一单元）。
- 支持长按切换模式并进入跟读交互（按住播放/录音、松手结束）。
- 将语法/用法信息从常驻改为抽屉式按需展开，默认收起。
- 保持现有本地课程包读取与媒体播放能力，聚焦交互层重构。

## Impact
- Affected specs: `ui`
- Affected code:
  - `lib/src/features/home/presentation/home_screen.dart`
  - `lib/src/features/practice/presentation/sentence_practice_screen.dart`
  - `lib/src/features/practice/presentation/widgets/practice_controls.dart`
  - `lib/src/features/practice/presentation/reading_practice_screen.dart`
  - `lib/src/features/practice/application/local_course_provider.dart`
  - `lib/src/routing/*`
