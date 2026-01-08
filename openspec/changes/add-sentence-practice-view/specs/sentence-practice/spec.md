# 句子练习视图规范

## ADDED Requirements

### Requirement: 沉浸式练习界面 (Immersive Practice Interface)

应用 MUST 提供一个全屏的沉浸式练习界面，用于专注于单个句子。该视图集成了视频、文本、音标和语法辅助。

#### Scenario: 用户打开句子练习

- **Given** 用户在主播放器或句子列表中
- **When** 他们点击特定句子或“练习模式”
- **Then** `SentencePracticeScreen` 打开
- **And** 背景显示该句子的相关视频片段
- **And** 音频在该句子范围内循环播放

#### Scenario: 查看句子详情

- **Given** 用户在练习屏幕上
- **Then** 英语文本醒目地显示
- **And** IPA 音标显示在文本下方
- **And** 中文翻译隐藏在“点击显示翻译”按钮后面

#### Scenario: 查看翻译

- **Given** 翻译被隐藏
- **When** 用户点击“点击显示翻译”
- **Then** 中文翻译文本显示出来
- **And** 按钮消失

#### Scenario: 语法注释

- **Given** 句子有相关的语法点（例如，“have been”）
- **Then** 这些短语会被高亮显示或以标签形式显示
- **And** 底部显示一个“语法注释”卡片，解释规则（例如，现在完成时）

### Requirement: 播放控制 (Playback Control)

练习视图 MUST 允许用户控制播放，包括循环当前句子以及导航到上一句/下一句。

#### Scenario: 音频循环

- **Given** 练习会话处于活动状态
- **Then** 音频/视频仅在当前句子的开始/结束时间戳内播放
- **And** 它会自动无限重复（循环），直到导航离开

#### Scenario: 导航

- **When** 用户点击“下一句”（右箭头）
- **Then** 应用前进到下一个句子
- **And** 立即更新文本、视频同步和语法注释
