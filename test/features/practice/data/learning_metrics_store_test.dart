import 'package:engbooks/src/features/practice/data/learning_metrics_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first practice increases course and unit practice count', () async {
    await LearningMetricsStore.recordLessonEntry(
      packageRoot: '/pkg/a',
      lessonKey: 'pkg:/pkg/a|lesson:01',
      totalCourseSentences: 10,
      totalLessonSentences: 4,
    );
    await LearningMetricsStore.recordSentencePractice(
      packageRoot: '/pkg/a',
      lessonKey: 'pkg:/pkg/a|lesson:01',
      sentenceId: '01-0001',
      totalCourseSentences: 10,
      totalLessonSentences: 4,
    );

    final snapshot = await LearningMetricsStore.loadSnapshot();
    final courseView = snapshot.courseView('/pkg/a', totalSentenceCount: 10);
    final unitView = snapshot.unitView(
      '/pkg/a',
      'pkg:/pkg/a|lesson:01',
      totalSentenceCount: 4,
    );

    expect(courseView.practiceCount, 1);
    expect(unitView.practiceCount, 1);
    expect(courseView.progressPercent, closeTo(10, 0.001));
    expect(unitView.progressPercent, closeTo(25, 0.001));
    expect(unitView.status, PracticeStatus.inProgress);
  });

  test('metrics remain consistent after cross-course updates', () async {
    await LearningMetricsStore.recordLessonEntry(
      packageRoot: '/pkg/a',
      lessonKey: 'pkg:/pkg/a|lesson:01',
      totalCourseSentences: 5,
      totalLessonSentences: 2,
    );
    await LearningMetricsStore.recordSentencePractice(
      packageRoot: '/pkg/a',
      lessonKey: 'pkg:/pkg/a|lesson:01',
      sentenceId: 'a-1',
      totalCourseSentences: 5,
      totalLessonSentences: 2,
    );
    await LearningMetricsStore.recordLessonEntry(
      packageRoot: '/pkg/b',
      lessonKey: 'pkg:/pkg/b|lesson:01',
      totalCourseSentences: 8,
      totalLessonSentences: 4,
    );
    await LearningMetricsStore.recordSentencePractice(
      packageRoot: '/pkg/b',
      lessonKey: 'pkg:/pkg/b|lesson:01',
      sentenceId: 'b-1',
      totalCourseSentences: 8,
      totalLessonSentences: 4,
    );

    final snapshot = await LearningMetricsStore.loadSnapshot();
    final courseA = snapshot.courseView('/pkg/a', totalSentenceCount: 5);
    final courseB = snapshot.courseView('/pkg/b', totalSentenceCount: 8);

    expect(courseA.practiceCount, 1);
    expect(courseB.practiceCount, 1);
    expect(courseA.progressPercent, closeTo(20, 0.001));
    expect(courseB.progressPercent, closeTo(12.5, 0.001));
  });
}
