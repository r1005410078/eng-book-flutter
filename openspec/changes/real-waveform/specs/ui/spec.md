# 规格：真实波形显示

## MODIFIED Requirements

### Requirement: 音频预处理

系统必须 (MUST) 下载远程音频文件并在本地预处理，以便提取波形数据。

#### Scenario: 音频下载

- **Given** 页面初始化
- **Then** 系统应异步下载配置的音频 URL 到本地临时文件
- **And** 显示加载状态直至波形数据准备就绪

### Requirement: 真实波形渲染

波形区域必须 (MUST) 使用 `audio_waveforms` 插件渲染与当前音频匹配的真实波形。

#### Scenario: 波形外观

- **Given** 音频文件加载完成
- **Then** 显示 `AudioFileWaveforms` 组件
- **And** 波形颜色应使用主题色 (`accentColor`) 和浅色背景
- **And** 波形样式应为连续或柱状，符合视觉设计

### Requirement: 进度被动同步

波形组件的播放进度必须 (MUST) 跟随视频播放器同步。

#### Scenario: 播放同步

- **Given** 视频正在播放
- **When** 视频进度更新
- **Then** 波形组件的进度指针应跳转到相同的时间位置
- **Note** 这里我们仅使用 `AudioFileWaveforms` 进行显示，不使用它本身来控制播放（静音或仅作为 View）。
