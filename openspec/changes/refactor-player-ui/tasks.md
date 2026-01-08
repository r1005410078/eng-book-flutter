## 1. 准备工作

- [x] 1.1 创建 `Sentence` 模型（定义句子结构：id, text, translation, start, end）
- [x] 1.2 创建 Mock 数据服务（提供示例课程和句子数据）
- [x] 1.3 导入所需的图标资源（如果 Flutter 默认图标不够用，考虑 CupertinoIcons 或自定义 SVG）

## 2. UI 组件开发 (Atom)

- [x] 2.1 创建 `PlayerHeader` 组件：自定义 AppBar，显示课程标题和设置按钮
- [x] 2.2 创建 `VisualArea` 组件：显示封面图和播放按钮遮罩
- [x] 2.3 创建 `SentenceProgressBar` 组件：显示"进度"和"句子 X/Y"
- [x] 2.4 创建 `SubtitleDisplay` 组件：显示当前句子的中英文
- [x] 2.5 创建 `RecordControlBar` 组件：底部胶囊栏，包含上一句、录音、下一句按钮

## 3. 页面组装 (Screen)

- [x] 3.1 重构 `AudioPlayerScreen`：使用 `Scaffold` + `Stack` 或 `Column` 布局
- [x] 3.2 实现暗色主题适配（背景色、文字颜色）
- [x] 3.3 集成各子组件

## 4. 逻辑对接 (Wiring)

- [x] 4.1 更新 `AudioPlayerController` 或新建 `PlayerViewModel`
- [x] 4.2 实现"上一句/下一句"逻辑：计算目标时间点并 seek
- [x] 4.3 实现字幕同步逻辑：根据当前播放时间 (position) 高亮对应句子
- [x] 4.4 绑定录音按钮交互（仅 UI 状态反馈，实际录音功能由 `add-recording-feature` 实现）

## 5. 优化与测试

- [ ] 5.1 调整 UI 细节（间距、字号、颜色）以高度还原设计图
- [ ] 5.2 测试不同屏幕尺寸下的适配
