import '../application/practice_lesson_key_service.dart';
import '../data/learning_metrics_store.dart';
import '../data/local_course_package_loader.dart';
import '../domain/sentence_detail.dart';
import 'course_unit_picker_sheet.dart';

const _lessonKeyService = PracticeLessonKeyService();

Future<List<CourseUnitPickerCourse>> buildCourseUnitPickerCourses({
  required List<SentenceDetail> sentences,
  required int currentIndex,
  required String? currentPackageRoot,
  required String? currentCourseTitle,
  Future<List<LocalCourseCatalog>> Function()? loadCourseCatalogsOverride,
}) async {
  if (sentences.isEmpty) return const [];

  final currentSentence =
      sentences[currentIndex.clamp(0, sentences.length - 1)];
  final resolvedPackage =
      (currentPackageRoot ?? currentSentence.packageRoot ?? '').trim();
  final resolvedCourseTitle =
      (currentCourseTitle ?? currentSentence.courseTitle ?? '本地课程').trim();

  final map = <String, CourseUnitPickerCourse>{};
  final metricsSnapshot = await LearningMetricsStore.loadSnapshot();

  final catalogs =
      await (loadCourseCatalogsOverride?.call() ?? listLocalCourseCatalogs());
  for (final catalog in catalogs) {
    final root = catalog.packageRoot.trim();
    if (root.isEmpty || catalog.units.isEmpty) continue;
    final courseTotalSentences = catalog.units.fold<int>(
      0,
      (sum, unit) => sum + unit.sentenceCount,
    );
    final courseMetrics = metricsSnapshot.courseView(
      root,
      totalSentenceCount: courseTotalSentences,
    );
    final units = catalog.units.map((unit) {
      final lessonKey = _lessonKeyService.keyFromParts(
        packageRoot: root,
        lessonId: unit.lessonId,
        lessonTitle: unit.title,
      );
      final unitMetrics = metricsSnapshot.unitView(
        root,
        lessonKey,
        totalSentenceCount: unit.sentenceCount,
      );
      return CourseUnitPickerUnit(
        lessonKey: lessonKey,
        lessonId: unit.lessonId,
        lessonTitle: unit.title,
        firstSentenceId: unit.firstSentenceId,
        sentenceCount: unit.sentenceCount,
        practiceCount: unitMetrics.practiceCount,
        progressPercent: unitMetrics.progressPercent,
        proficiency: unitMetrics.proficiency,
        status: unitMetrics.status,
      );
    }).toList();
    map[root] = CourseUnitPickerCourse(
      packageRoot: root,
      courseTitle: catalog.title,
      units: units,
      practiceCount: courseMetrics.practiceCount,
      progressPercent: courseMetrics.progressPercent,
      proficiency: courseMetrics.proficiency,
    );
  }

  if (resolvedPackage.isNotEmpty) {
    final units = _buildUnitOptionsFromSentences(
      sentences,
      resolvedPackage,
      metricsSnapshot,
      fallbackPackageRoot: currentPackageRoot,
      fallbackCourseTitle: currentCourseTitle,
    );
    final courseMetrics = metricsSnapshot.courseView(
      resolvedPackage,
      totalSentenceCount: sentences.length,
    );
    final existing = map[resolvedPackage];
    final existingTitle = existing?.courseTitle.trim() ?? '';
    map[resolvedPackage] = CourseUnitPickerCourse(
      packageRoot: resolvedPackage,
      courseTitle: existingTitle.isNotEmpty
          ? existing!.courseTitle
          : resolvedCourseTitle,
      units: units,
      practiceCount: courseMetrics.practiceCount,
      progressPercent: courseMetrics.progressPercent,
      proficiency: courseMetrics.proficiency,
    );
  }

  final courses = map.values.toList();
  courses.sort((a, b) {
    if (a.packageRoot == resolvedPackage) return -1;
    if (b.packageRoot == resolvedPackage) return 1;
    return a.courseTitle.compareTo(b.courseTitle);
  });
  return courses;
}

List<CourseUnitPickerUnit> _buildUnitOptionsFromSentences(
  List<SentenceDetail> sentences,
  String packageRoot,
  LearningMetricsSnapshot metricsSnapshot, {
  String? fallbackPackageRoot,
  String? fallbackCourseTitle,
}) {
  if (sentences.isEmpty) return const [];
  final lessonKeys = _lessonKeyService.keysFromSentences(
    sentences,
    fallbackPackageRoot: fallbackPackageRoot,
    fallbackCourseTitle: fallbackCourseTitle,
  );
  final units = <CourseUnitPickerUnit>[];
  int start = 0;
  while (start < sentences.length) {
    final startSentence = sentences[start];
    final key = lessonKeys[start];
    int end = start;
    while (end + 1 < sentences.length && lessonKeys[end + 1] == key) {
      end++;
    }
    final lessonId = (startSentence.lessonId ?? '').trim();
    final lessonTitle = (startSentence.lessonTitle ?? '').trim();
    final displayTitle = lessonTitle.isNotEmpty
        ? lessonTitle
        : (lessonId.isNotEmpty ? '单元 $lessonId' : '单元 ${units.length + 1}');
    final unitMetrics = metricsSnapshot.unitView(
      packageRoot,
      key,
      totalSentenceCount: end - start + 1,
    );
    units.add(
      CourseUnitPickerUnit(
        lessonKey: key,
        lessonId: lessonId,
        lessonTitle: displayTitle,
        firstSentenceId: startSentence.id,
        sentenceCount: end - start + 1,
        practiceCount: unitMetrics.practiceCount,
        progressPercent: unitMetrics.progressPercent,
        proficiency: unitMetrics.proficiency,
        status: unitMetrics.status,
      ),
    );
    start = end + 1;
  }
  return units;
}
