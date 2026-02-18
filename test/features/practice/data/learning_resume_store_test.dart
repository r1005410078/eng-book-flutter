import 'package:engbooks/src/features/practice/data/learning_resume_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LearningResume stores and restores lessonId', () async {
    const resume = LearningResume(
      packageRoot: '/tmp/package',
      courseTitle: 'Course A',
      sentenceId: '01-0001',
      lessonId: '01',
    );

    await LearningResumeStore.save(resume);
    final loaded = await LearningResumeStore.load();

    expect(loaded, isNotNull);
    expect(loaded!.packageRoot, '/tmp/package');
    expect(loaded.courseTitle, 'Course A');
    expect(loaded.sentenceId, '01-0001');
    expect(loaded.lessonId, '01');
  });

  test('LearningResume keeps backward compatibility without lessonId', () {
    final loaded = LearningResume.fromJson({
      'packageRoot': '/tmp/package',
      'courseTitle': 'Course A',
      'sentenceId': '01-0001',
    });

    expect(loaded, isNotNull);
    expect(loaded!.lessonId, isNull);
  });

  test('rapid consecutive saves keep the last progress', () async {
    const first = LearningResume(
      packageRoot: '/tmp/package_a',
      courseTitle: 'Course A',
      sentenceId: '01-0001',
      lessonId: '01',
    );
    const second = LearningResume(
      packageRoot: '/tmp/package_b',
      courseTitle: 'Course B',
      sentenceId: '02-0003',
      lessonId: '02',
    );

    final pendingFirst = LearningResumeStore.save(first);
    final pendingSecond = LearningResumeStore.save(second);
    await Future.wait([pendingFirst, pendingSecond]);

    final loaded = await LearningResumeStore.load();
    expect(loaded, isNotNull);
    expect(loaded!.packageRoot, '/tmp/package_b');
    expect(loaded.courseTitle, 'Course B');
    expect(loaded.sentenceId, '02-0003');
    expect(loaded.lessonId, '02');
  });

  test('progress can be stored and loaded with arbitrary package path',
      () async {
    const resume = LearningResume(
      packageRoot: '/tmp/another-course',
      courseTitle: 'Any Course',
      sentenceId: '143',
      lessonId: null,
    );

    await LearningResumeStore.save(resume);
    final loaded = await LearningResumeStore.load();

    expect(loaded, isNotNull);
    expect(loaded!.packageRoot, '/tmp/another-course');
    expect(loaded.courseTitle, 'Any Course');
    expect(loaded.sentenceId, '143');
  });
}
