import '../models/sentence.dart';

/// 模拟数据服务
///
/// 提供测试用的句子数据和音频信息
class MockDataService {
  MockDataService._();

  /// 示例音频 URL
  static const String audioUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  /// 示例封面图
  static const String coverUrl = 'https://picsum.photos/800/600';

  /// 示例视频 URL (Big Buck Bunny)
  static const String videoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  /// 示例句子数据
  ///
  /// 模拟一组对话数据，时间戳是虚构的
  static const List<Sentence> sentences = [
    Sentence(
      id: '1',
      text: "I think that's a wonderful idea.",
      translation: "我觉得那个主意很棒。",
      startTimeMs: 0,
      endTimeMs: 2000,
    ),
    Sentence(
      id: '2',
      text: "We should definitely go there this weekend.",
      translation: "我们需要这个周末去那里。",
      startTimeMs: 2000,
      endTimeMs: 4000,
    ),
    Sentence(
      id: '3',
      text: "Do you know if it's open on Sundays?",
      translation: "你知道它周日开门吗？",
      startTimeMs: 4000,
      endTimeMs: 6000,
    ),
    Sentence(
      id: '4',
      text: "Yes, I checked the website, it's open every day.",
      translation: "是的，我查了网站，它每天都开。",
      startTimeMs: 6000,
      endTimeMs: 8000,
    ),
    Sentence(
      id: '5',
      text: "That's perfect! Let's invite Sarah too.",
      translation: "太完美了！我们也邀请 Sarah 吧。",
      startTimeMs: 8000,
      endTimeMs: 10000,
    ),
  ];
}
