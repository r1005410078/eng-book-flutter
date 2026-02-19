import '../domain/sentence_detail.dart';

class PracticeLessonKeyService {
  const PracticeLessonKeyService();

  String keyFromParts({
    String? packageRoot,
    String? courseTitle,
    String? lessonId,
    String? lessonTitle,
    String? mediaPath,
  }) {
    final safePackageRoot = (packageRoot ?? '').trim();
    final safeCourseTitle = (courseTitle ?? '').trim();
    final scope = safePackageRoot.isNotEmpty
        ? 'pkg:$safePackageRoot'
        : (safeCourseTitle.isNotEmpty ? 'course:$safeCourseTitle' : 'global');

    final safeLessonId = (lessonId ?? '').trim();
    if (safeLessonId.isNotEmpty) return '$scope|lesson:$safeLessonId';

    final safeLessonTitle = (lessonTitle ?? '').trim();
    if (safeLessonTitle.isNotEmpty) return '$scope|title:$safeLessonTitle';

    final safeMediaPath = (mediaPath ?? '').trim();
    if (safeMediaPath.isNotEmpty) return '$scope|media:$safeMediaPath';

    return '$scope|default';
  }

  String keyFromSentence(
    SentenceDetail sentence, {
    String? fallbackPackageRoot,
    String? fallbackCourseTitle,
  }) {
    return keyFromParts(
      packageRoot: sentence.packageRoot ?? fallbackPackageRoot,
      courseTitle: sentence.courseTitle ?? fallbackCourseTitle,
      lessonId: sentence.lessonId,
      lessonTitle: sentence.lessonTitle,
      mediaPath: sentence.mediaPath,
    );
  }

  List<String> keysFromSentences(
    List<SentenceDetail> sentences, {
    String? fallbackPackageRoot,
    String? fallbackCourseTitle,
  }) {
    return List<String>.generate(
      sentences.length,
      (index) => keyFromSentence(
        sentences[index],
        fallbackPackageRoot: fallbackPackageRoot,
        fallbackCourseTitle: fallbackCourseTitle,
      ),
    );
  }
}
