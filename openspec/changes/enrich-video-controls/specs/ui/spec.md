# UI Specification: Enriched Video Controls

## Layout Structure

```
┌─────────────────────────────────────────────────┐
│                  Video Content                  │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │ [Settings] [Subtitles]              (Top) │ │
│  │                                           │ │
│  │              [Play/Pause]                 │ │
│  │                                           │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │ ▁▂▃▂▁▃▄▃▂▁ (Waveform - subtle)    │ │ │
│  │  │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ │ │
│  │  │ ████████░░░░░░░░░░░░░░░░░░░░░░░░ │ │ │
│  │  │ (Progress Bar)                     │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  │  00:35 / 10:24  [▶] [🔊] [1x] [⛶]      │ │
│  │  (Time)        (Play)(Vol)(Speed)(Full) │ │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## Component Details

### 1. Time Display

- **位置**：控制栏左侧
- **格式**：`MM:SS / MM:SS`
- **样式**：
  - 字体：12px
  - 颜色：`Colors.white.withOpacity(0.9)`
  - 字体：等宽字体（Courier）

### 2. Play/Pause Button

- **位置**：时间显示右侧
- **尺寸**：32x32
- **图标**：`Icons.play_arrow` / `Icons.pause`
- **样式**：
  - 背景：半透明黑色圆形
  - 图标颜色：白色

### 3. Volume Control

- **位置**：播放按钮右侧
- **组件**：
  - 音量图标（可点击切换静音）
  - 音量滑块（hover 时显示）
- **图标状态**：
  - `volume_off`：静音
  - `volume_down`：低音量 (< 0.5)
  - `volume_up`：高音量 (>= 0.5)
- **滑块**：
  - 宽度：80px
  - 高度：4px
  - 颜色：橙色 (#FF9F29)

### 4. Playback Speed

- **位置**：音量控制右侧
- **显示**：当前速度（例如：`1x`, `1.5x`）
- **点击行为**：显示速度选择菜单
- **可选速度**：0.5x, 0.75x, 1x, 1.25x, 1.5x, 2x
- **样式**：
  - 字体：12px
  - 颜色：白色
  - 当前速度：橙色高亮

### 5. Fullscreen Button

- **位置**：控制栏最右侧
- **图标**：`Icons.fullscreen` / `Icons.fullscreen_exit`
- **尺寸**：24x24

## Spacing & Padding

- 控制栏内边距：`EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
- 控制项间距：8px
- 控制栏背景：`LinearGradient` 从透明到半透明黑色

## Interaction States

- **Hover**：图标亮度增加
- **Active**：橙色高亮
- **Disabled**：灰色，透明度 0.5

## Auto-hide Behavior

- 保持现有的 3 秒自动隐藏逻辑
- 用户交互时重新显示并重置计时器
- 暂停时始终显示
