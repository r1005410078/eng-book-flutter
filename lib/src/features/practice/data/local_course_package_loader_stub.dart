import '../domain/sentence_detail.dart';

class LocalSentenceLoadResult {
  final List<SentenceDetail> sentences;
  final String? warning;

  const LocalSentenceLoadResult({required this.sentences, this.warning});
}

Future<LocalSentenceLoadResult> loadSentencesFromLocalPackage({
  required String packageRoot,
}) async {
  return const LocalSentenceLoadResult(
    sentences: [],
    warning: '当前平台不支持本地课程包读取，已使用默认内容。',
  );
}
