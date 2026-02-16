## 1. 基础配置
- [ ] 1.1 添加 `dio` 依赖。
- [ ] 1.2 创建 `ApiClient`，设置 BaseURL 为 `http://192.168.2.10:8001/api/v1`。

## 2. 数据层 (Data Layer)
- [ ] 2.1 **Model 生成**: 根据 OpenAPI 定义创建 `VideoModel` 和 `SubtitleModel`。
- [ ] 2.2 **VideoRepository**:
    - 实现 `fetchVideos(page, size)`。
    - 实现 `fetchVideoDetail(id)`。
    - 实现 `fetchSubtitles(id)`。

## 3. UI 联调 (Presentation)
- [ ] 3.1 **首页 (Home)**:
    - 将原来的“学习路径 Mock 数据”替换为 `VideoRepository.fetchVideos`。
    - 展示视频封面 (Thumbnail) 和标题。
- [ ] 3.2 **学习页 (Learning)**:
    - 进入详情后调用 `fetchSubtitles`。
    - 展示字幕列表及其翻译/语法分析。
