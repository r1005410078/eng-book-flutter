# Tasks

- [x] 在 `mock_data.dart` 中定义 `final mockSentences = [...]`，包含至少 4 条具有连续时间戳的句子。 <!-- id: 0 -->
- [x] 在 `SentencePracticeScreen` 中引入 `_sentences` 列表和 `_currentIndex` 状态。 <!-- id: 1 -->
- [x] 实现 `_syncSentenceWithVideo` 逻辑：监听 `_videoController` 进度，查找当前时间对应的句子 Index。 <!-- id: 2 -->
- [x] 更新 `_buildHeader`：根据 `_sentences.length` 生成进度条，并根据 `_currentIndex` 高亮。 <!-- id: 3 -->
- [x] 更新主视图 (`build`)：使用 `_sentences[_currentIndex]` 渲染文本和内容。 <!-- id: 4 -->
