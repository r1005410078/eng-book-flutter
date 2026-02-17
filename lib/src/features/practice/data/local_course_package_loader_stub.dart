import '../domain/sentence_detail.dart';

class LocalCourseSummary {
  final String courseId;
  final String title;
  final int lessonCount;
  final String packageRoot;
  final String firstSentenceId;
  final String mediaType;

  const LocalCourseSummary({
    required this.courseId,
    required this.title,
    required this.lessonCount,
    required this.packageRoot,
    required this.firstSentenceId,
    required this.mediaType,
  });
}

class LocalSentenceLoadResult {
  final List<SentenceDetail> sentences;
  final String? warning;

  const LocalSentenceLoadResult({required this.sentences, this.warning});
}

Future<String?> discoverLatestReadyPackageRoot() async {
  return null;
}

Future<List<LocalCourseSummary>> listLocalCoursePackages() async {
  return const [];
}

Future<LocalSentenceLoadResult> loadSentencesFromLocalPackage({
  required String packageRoot,
}) async {
  return const LocalSentenceLoadResult(
    sentences: [],
    warning: '当前平台不支持本地课程包读取，已使用默认内容。',
  );
}
