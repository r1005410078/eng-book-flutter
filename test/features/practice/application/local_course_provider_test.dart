import 'dart:convert';
import 'dart:io';

import 'package:engbooks/src/features/practice/application/local_course_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir =
        await Directory.systemTemp.createTemp('local_course_provider_test_');
    Directory.current = tempDir;
  });

  tearDown(() async {
    Directory.current = originalCurrent;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> _createPackage() async {
    final packageDir = Directory('${tempDir.path}/package');
    final lessonDir = Directory('${packageDir.path}/lessons/01');
    await lessonDir.create(recursive: true);

    final manifest = {
      'course_id': 'course_test',
      'title': 'Test Course',
      'lesson_count': 1,
      'lessons': [
        {'lesson_id': '01', 'path': 'lessons/01/lesson.json'},
      ],
    };
    await File('${packageDir.path}/course_manifest.json')
        .writeAsString(jsonEncode(manifest));

    final lesson = {
      'lesson_id': '01',
      'title': 'Lesson 01',
      'media': {'type': 'video', 'path': 'media.mp4'},
      'sentences': [
        {
          'sentence_id': '01-0001',
          'start_ms': 0,
          'end_ms': 1200,
          'en': 'Hello.',
          'zh': '你好。',
          'ipa': '/həˈləʊ/',
        },
      ],
    };
    await File('${lessonDir.path}/lesson.json')
        .writeAsString(jsonEncode(lesson));
    return packageDir.path;
  }

  test('localCourseSentencesProvider returns warning when context is missing',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(localCourseSentencesProvider.future);
    expect(result.sentences, isEmpty);
    expect(result.warning, isNotNull);
  });

  test('localCourseSentencesProvider returns sentences after setting context',
      () async {
    final packageRoot = await _createPackage();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(localCourseContextProvider.notifier).state =
        LocalCourseContext(
            packageRoot: packageRoot, courseTitle: 'Test Course');

    final result = await container.read(localCourseSentencesProvider.future);
    expect(result.warning, isNull);
    expect(result.sentences.length, 1);
    expect(result.sentences.first.id, '01-0001');
  });
}
