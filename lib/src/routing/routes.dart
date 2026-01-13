/// 路由路径常量
///
/// 集中管理所有路由路径，避免硬编码
class Routes {
  Routes._();

  // 主页
  static const String home = '/';

  // 音频播放器
  static const String audioPlayer = '/audio-player';

  // 学习材料
  static const String materials = '/materials';

  // 练习记录
  static const String practice = '/practice';

  // 录音
  static const String recording = '/recording';

  // 句子练习
  static const String sentencePractice = '/practice/sentence/:id';

  // 播放设置
  static const String playbackSettings = '/practice/settings';

  // 阅读练习 (文本模式)
  static const String readingPractice = '/practice/reading/:id';
}
