import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engbooks/src/features/practice/data/local_course_package_loader.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir = await Directory.systemTemp.createTemp('course_loader_test_');
    Directory.current = tempDir;
  });

  tearDown(() async {
    Directory.current = originalCurrent;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createTaskPackage({
    required String taskId,
    required String updatedAt,
    required String courseId,
    required String title,
    required String mediaType,
  }) async {
    final tasksDir = Directory('${tempDir.path}/.runtime/tasks');
    await tasksDir.create(recursive: true);
    final packageDir = Directory('${tasksDir.path}/$taskId/package');
    final lessonsDir = Directory('${packageDir.path}/lessons/01');
    await lessonsDir.create(recursive: true);

    final taskJson = {
      'task_id': taskId,
      'status': 'ready',
      'updated_at': updatedAt,
    };
    await File('${tasksDir.path}/$taskId.json')
        .writeAsString(jsonEncode(taskJson));

    final manifest = {
      'course_id': courseId,
      'title': title,
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
      'media': {
        'type': mediaType,
        'path': mediaType == 'audio' ? 'media.mp3' : 'media.mp4'
      },
      'sentences': [
        {
          'sentence_id': '01-0001',
          'start_ms': 1000,
          'end_ms': 2500,
          'en': 'Hello and welcome.',
          'zh': '你好，欢迎你。',
          'ipa': '/həˈləʊ/',
          'grammar': {
            'pattern': '陈述句结构',
            'points': ['使用常见主谓结构表达信息。']
          },
          'usage': {'scene': 'greeting', 'tone': 'friendly'},
        },
      ],
    };
    await File('${lessonsDir.path}/lesson.json')
        .writeAsString(jsonEncode(lesson));
    await File(
            '${lessonsDir.path}/${mediaType == 'audio' ? 'media.mp3' : 'media.mp4'}')
        .writeAsString('mock');
  }

  test('discoverLatestReadyPackageRoot returns latest ready task package',
      () async {
    await createTaskPackage(
      taskId: 'task_old',
      updatedAt: '2026-02-16T08:00:00Z',
      courseId: 'course_old',
      title: 'Old',
      mediaType: 'video',
    );
    await createTaskPackage(
      taskId: 'task_new',
      updatedAt: '2026-02-16T09:00:00Z',
      courseId: 'course_new',
      title: 'New',
      mediaType: 'audio',
    );

    final root = await discoverLatestReadyPackageRoot();
    expect(root, isNotNull);
    expect(root!, endsWith('/.runtime/tasks/task_new/package'));
  });

  test(
      'listLocalCoursePackages and loadSentencesFromLocalPackage parse media and timeline',
      () async {
    await createTaskPackage(
      taskId: 'task_single',
      updatedAt: '2026-02-16T10:00:00Z',
      courseId: 'course_single',
      title: 'Single Course',
      mediaType: 'audio',
    );

    final list = await listLocalCoursePackages();
    expect(list.length, 1);
    expect(list.first.courseId, 'course_single');
    expect(list.first.mediaType, 'audio');
    expect(list.first.firstSentenceId, '01-0001');

    final loaded = await loadSentencesFromLocalPackage(
        packageRoot: list.first.packageRoot);
    expect(loaded.warning, isNull);
    expect(loaded.sentences.length, 1);
    final sentence = loaded.sentences.first;
    expect(sentence.id, '01-0001');
    expect(sentence.startTime, const Duration(milliseconds: 1000));
    expect(sentence.endTime, const Duration(milliseconds: 2500));
    expect(sentence.mediaType, 'audio');
    expect(sentence.mediaPath, isNotNull);
    expect(sentence.lessonId, '01');
    expect(sentence.courseTitle, 'Single Course');
  });

  test('sentenceExistsInLocalPackage validates sentence id by package',
      () async {
    await createTaskPackage(
      taskId: 'task_single',
      updatedAt: '2026-02-16T10:00:00Z',
      courseId: 'course_single',
      title: 'Single Course',
      mediaType: 'audio',
    );

    final list = await listLocalCoursePackages();
    expect(list, isNotEmpty);
    final packageRoot = list.first.packageRoot;

    final exists = await sentenceExistsInLocalPackage(
      packageRoot: packageRoot,
      sentenceId: '01-0001',
    );
    final missing = await sentenceExistsInLocalPackage(
      packageRoot: packageRoot,
      sentenceId: '01-9999',
    );
    expect(exists, isTrue);
    expect(missing, isFalse);
  });
}
