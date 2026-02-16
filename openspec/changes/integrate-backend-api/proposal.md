# 集成后端视频学习 API (Integrate Video Learning API)

## 为什么 (Why)
后端目前提供了完整的视频上传、处理和字幕分析 API (`http://192.168.2.10:8001`)。我们需要将 Flutter App 对接到这些接口，通过视频列表和字幕详情来实现核心学习功能。

## 变更内容 (What Changes)
- **API Client**: 配置 BaseURL 为 `http://192.168.2.10:8001/api/v1`。
- **数据模型**:
    - `Video`: 对应 `VideoResponse` (id, title, thumbnail, difficulty, status, progress)。
    - `Subtitle`: 对应 `SubtitleWithGrammarResponse` (start/end, text, translation, grammar)。
- **视频列表页**: 对接 `GET /videos/`，展示学习视频流。
- **学习页**: 对接 `GET /videos/{id}/subtitles`，展示逐句学习内容。

## 影响范围 (Impact)
- `shared/api`: 新增通用 Client。
- `features/home`: 改造为视频列表展示。
- `features/learning`: 改造为基于视频/字幕的学习模式。
