# 规格：进度 UI 联动

## MODIFIED Requirements

### Requirement: 进度条与内容同步

UI 必须 (MUST) 根据当前的播放时间自动更新显示的句子内容和进度条状态。

#### Scenario: 进度条显示

- **Given** 有 N 条句子数据
- **Then** 顶部 Header 应显示 N 个进度段（Pills）
- **And** 当前播放时间所在的句子对应的段应高亮显示（Active Color）

#### Scenario: 内容自动切换

- **Given** 视频正在播放
- **When** 播放时间进入下一句的时间范围
- **Then** 主界面的文本、翻译、音标应立即更新为下一句的内容
- **And** 顶部进度条的高亮位置应随之更新
