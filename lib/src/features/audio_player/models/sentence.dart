/// 句子模型
///
/// 表示音频中的一个句子，包含时间戳和文本内容
class Sentence {
  /// 唯一标识
  final String id;

  /// 英文原文
  final String text;

  /// 中文翻译
  final String translation;

  /// 开始时间（毫秒）
  final int startTimeMs;

  /// 结束时间（毫秒）
  final int endTimeMs;

  const Sentence({
    required this.id,
    required this.text,
    required this.translation,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  Duration get start => Duration(milliseconds: startTimeMs);
  Duration get end => Duration(milliseconds: endTimeMs);
  Duration get duration => end - start;

  /// 检查给定时间点是否在该句子范围内
  bool contains(Duration position) {
    return position.inMilliseconds >= startTimeMs &&
        position.inMilliseconds < endTimeMs;
  }
}
