## MODIFIED Requirements

### Requirement: 音频播放控制

系统 SHALL 提供完整的音频播放控制功能，支持用户进行听力训练。

#### Scenario: 播放音频文件

- **GIVEN** 用户已选择一个音频文件
- **WHEN** 用户点击播放按钮
- **THEN** 系统应开始播放音频并显示播放状态

#### Scenario: 暂停播放

- **GIVEN** 音频正在播放
- **WHEN** 用户点击暂停按钮
- **THEN** 系统应暂停播放并保持当前进度

#### Scenario: 停止播放

- **GIVEN** 音频正在播放或已暂停
- **WHEN** 用户点击停止按钮
- **THEN** 系统应停止播放并重置进度到起点

#### Scenario: 分句导航 (新增)

- **GIVEN** 系统加载了带有时间戳的句子数据
- **WHEN** 用户点击"上一句"或"下一句"按钮
- **THEN** 播放器应跳转到上一句的开始时间或下一句的开始时间

---

## ADDED Requirements

### Requirement: 沉浸式学习界面

系统 SHALL 提供专为 100LS 设计的沉浸式学习界面 (Sentence Mode)。

#### Scenario: 字幕同步显示

- **GIVEN** 音频正在播放
- **THEN** 界面应实时显示当前播放内容对应的英文原文和中文翻译
- **AND** 高亮显示当前句子

#### Scenario: 录音交互入口

- **GIVEN** 用户处于 Sentence Mode
- **THEN** 界面底部应提供醒目的录音/跟读按钮
- **WHEN** 用户点击录音按钮
- **THEN** 系统应触发录音流程（具体录音逻辑由录音功能定义）

#### Scenario: 视觉反馈

- **GIVEN** 播放特定课程
- **THEN** 界面顶部应显示与课程内容相关的封面图或视频预览
- **AND** 整体界面采用暗色调以减少视觉干扰
