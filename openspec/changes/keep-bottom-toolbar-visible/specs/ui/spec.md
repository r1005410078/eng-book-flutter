# 规格：底部工具栏可见性

## MODIFIED Requirements

### Requirement: 工具栏常驻显示

底部的操作工具栏（包含播放控制、录音、导航按钮）必须 (MUST) 始终保持可见，不受视频播放控制层自动隐藏逻辑的影响。

#### Scenario: 自动隐藏触发时

- **Given** 视频正在播放且无用户操作超过 3 秒
- **When** 视频区域的控制按钮（如播放/暂停遮罩、进度条）自动淡出隐藏时
- **Then** 底部的 `PracticeControls` 应保持完全不透明 (Opacity 1.0) 并可交互
