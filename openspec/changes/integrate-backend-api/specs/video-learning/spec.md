## ADDED Requirements
### Requirement: 视频数据获取 (Video Data Fetching)
系统必须支持从后端分页获取视频学习资源。

#### Scenario: 首页加载视频列表
- **WHEN** 用户进入首页
- **THEN** 调用 `GET /videos/?page=1&size=20`
- **AND** 仅展示状态为 `completed` 或 `processing` 的视频。

### Requirement: 学习内容获取 (Content Fetching)
系统必须获取视频的深层学习数据（字幕+AI分析）。

#### Scenario: 获取字幕详情
- **WHEN** 用户点击开始学习
- **THEN** 调用 `GET /videos/{id}/subtitles?include_grammar=true`
- **AND** 返回结果必须包含原文、翻译、音标和语法点解析。
