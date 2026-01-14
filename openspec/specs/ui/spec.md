# ui Specification

## Purpose
TBD - created by archiving change impl-playback-settings. Update Purpose after archive.
## Requirements
### Requirement: The Playback Settings screen allows configuring playback speed

The application MUST provide controls to adjust the audio playback speed. Available options should include 0.5x, 0.75x, and 1.0x (normal speed).

#### Scenario: User changes playback speed

Given the user is on the Playback Settings screen
When they tap "0.5x"
Then the playback speed is set to 0.5
And the "0.5x" button becomes active

### Requirement: The Playback Settings screen allows toggling subtitles

The application MUST allow users to toggle the visibility of English text, Chinese translation, and a "Blur Default" option for active recall practice.

#### Scenario: User toggles English subtitle

Given the English subtitle is ON
When the user taps the toggle
Then the English subtitle turns OFF

### Requirement: The Playback Settings screen allows configuring playback behavior

The application MUST allow configuration of playback behaviors such as loop count per sentence, auto-pause at the end of sentences, and auto-recording.

#### Scenario: User changes loop count

Given the loop count is 3
When the user taps "+"
Then the loop count becomes 4

### Requirement: The Playback Settings screen allows configuring font size

The application MUST provide a slider to adjust the text size of the subtitles, ranging from small to large.

#### Scenario: User changes font size

Given the font size slider is at standard position
When the user drags it to the right
Then the font size increases

### Requirement: 入口

必须 (MUST) 通过首页右上角的特定图标打开课程选择页面。

#### Scenario: 打开选择页

- **Given** 用户在首页
- **When** 用户点击右上角的“书本/菜单”图标
- **Then** 课程选择页面应以全屏弹窗的形式出现

### Requirement: 分类筛选

页面必须 (MUST) 显示一个横向滚动的分类列表。

#### Scenario: 选择分类

- **Given** 筛选栏显示“全部”、“我的”等
- **When** 用户点击“视频”
- **Then** 该标签变为激活状态（橙色背景）
- **And** 课程列表仅显示视频类型的课程（Mock 逻辑：更新 UI 状态即可）

### Requirement: 课程网格

页面必须 (MUST) 以网格布局展示课程。

#### Scenario: 查看课程

- **Given** 用户查看网格列表
- **Then** 每个卡片显示封面图、标题、章节数
- **And** 正在学习的课程显示“继续学习”标签
- **And** 不同的图标代表不同的媒体类型（播客 vs 视频） - (Mock 数据)

### Requirement: 课程详情查看

系统必须 (SHALL) 提供课程的详细信息视图，允许用户在开始学习前了解课程内容。

#### Scenario: 查看课程详情

- **WHEN** 用户在课程选择页面点击某个课程卡片
- **THEN** 应用跳转到课程详情页面
- **AND** 页面显示课程标题、作者、封面图和难度等级
- **AND** 页面显示统计信息，包括章节数、预计时长和总词汇量
- **AND** 页面显示“故事情节”部分，包含文本简介
- **AND** 页面显示“语法重点”部分，列出关键语法标签
- **AND** 页面显示“你将掌握”部分，列出课程价值点
- **AND** 底部固定展示一个“开始学习”按钮

