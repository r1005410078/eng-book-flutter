/// 路由路径常量
///
/// 集中管理所有路由路径，避免硬编码
class Routes {
  Routes._();

  // 主页
  static const String home = '/';

  // 下载中心
  static const String downloadCenter = '/download-center';

  // 句子练习
  static const String sentencePractice = '/practice/sentence/:id';

  // 阅读练习 (文本模式)
  static const String readingPractice = '/practice/reading/:id';
}
