# 规格：进度同步修复

## MODIFIED Requirements

### Requirement: 全程数据覆盖

为了保证拖拽进度条时总有内容显示，Mock 数据必须 (MUST) 覆盖足够长的视频时长。

#### Scenario: 拖拽至视频末尾

- **Given** 用户拖拽进度条到 5 分钟处
- **Then** 界面应显示该时间点对应的（模拟）句子内容
- **And** 顶部进度条应高亮对应的 Pill

### Requirement: 实时响应

视频控制器的位置变更必须 (MUST) 实时触发 UI 更新。

#### Scenario: 拖拽中更新

- **Given** 用户正在拖拽进度条（Scrubbing）
- **Then** 只要 `videoController.value.position` 发生变化，`_syncSentenceWithVideo` 就应执行并更新 `_currentIndex`
