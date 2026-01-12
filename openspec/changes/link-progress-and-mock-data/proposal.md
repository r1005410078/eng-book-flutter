# 提案：多句子数据 Mock 与进度联动

## 变更背景

当前 `SentencePracticeScreen` 仅展示单条 Mock 句子。用户希望增加更多字幕数据（Mock），并使顶部的“句子段落进度条”（Pills）与视频播放进度联动，即视频播放到哪一句，进度条就高亮显示哪一句，同时主显示区的内容也应随之切换。

## 目标

1.  **扩展 Mock 数据**: 创建包含多条句子（带时间戳）的列表 `mockSentences`。
2.  **进度条联动**: 顶部 Header 的进度条应显示句子总数，并根据当前视频播放进度高亮当前句子。
3.  **内容联动**: 主显示区（文本、音标、翻译）应根据视频当前播放位置自动切换显示对应的句子内容。

## 范围

- `lib/src/features/practice/data/mock_data.dart`: 添加 List 数据。
- `SentencePracticeScreen`:
  - 引入句子列表状态。
  - 监听视频/音频播放进度。
  - 根据进度计算当前句子 Index。
  - 更新 UI（Header 进度条、主文本区）。

## 风险

- 视频播放进度回调频率可能不够高，导致切换有轻微延迟（通常 Flutter VideoPlayer 500ms 一次，可能需要更频繁的 ticker 或 just_audio 的 stream）。_注：当前实现同时使用了 VideoPlayer 和 JustAudio，需确认主控是谁。目前 VideoPlayer 是背景，JustAudio 似乎没完全接管？之前的代码 `_videoController.play()` 和 `_audioPlayer.play()` 是同时调用的。如果视频是主轴，应该以视频位置为准。或者统一使用 just_audio 播放音频，video 仅作为静音背景？目前的实现是 VideoPlayer 播放网络视频（有声？）。BigBuckBunny 是有声的。之前的 `_audioPlayer` 是 mock 的 mp3。这会导致声音冲突。_
- **修正**: 鉴于 Mock 阶段，我们假设视频是主时间轴。我们将根据 VideoPlayer 的位置来切换句子。
