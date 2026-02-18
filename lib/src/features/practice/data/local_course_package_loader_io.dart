import 'dart:convert';
import 'dart:io';

import '../../../common/io/runtime_paths.dart';
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
  final runtimeTasks = await resolveRuntimeTasksDir();
  if (!runtimeTasks.existsSync()) return null;

  final taskFiles = runtimeTasks
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => f.uri.pathSegments.last.startsWith('task_'))
      .toList();

  DateTime? latestTime;
  String? latestPackage;

  for (final file in taskFiles) {
    dynamic task;
    try {
      task = jsonDecode(await file.readAsString());
    } catch (_) {
      continue;
    }
    if (task is! Map) continue;
    if ((task['status'] ?? '').toString() != 'ready') continue;

    final taskId = (task['task_id'] ?? '').toString();
    if (taskId.isEmpty) continue;
    final packageDir = Directory('${runtimeTasks.path}/$taskId/package');
    if (!packageDir.existsSync()) continue;

    final updatedAt = DateTime.tryParse((task['updated_at'] ?? '').toString());
    final ts = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (latestTime == null || ts.isAfter(latestTime)) {
      latestTime = ts;
      latestPackage = packageDir.path;
    }
  }

  return latestPackage;
}

Future<List<LocalCourseSummary>> listLocalCoursePackages() async {
  final runtimeTasks = await resolveRuntimeTasksDir();
  if (!runtimeTasks.existsSync()) return const [];

  final summaries = <LocalCourseSummary>[];
  final taskFiles = runtimeTasks
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => f.uri.pathSegments.last.startsWith('task_'))
      .toList();

  for (final file in taskFiles) {
    dynamic task;
    try {
      task = jsonDecode(await file.readAsString());
    } catch (_) {
      continue;
    }
    if (task is! Map) continue;
    if ((task['status'] ?? '').toString() != 'ready') continue;
    final taskId = (task['task_id'] ?? '').toString();
    if (taskId.isEmpty) continue;

    final packageDir = Directory('${runtimeTasks.path}/$taskId/package');
    final manifestFile = File('${packageDir.path}/course_manifest.json');
    if (!manifestFile.existsSync()) continue;

    dynamic manifest;
    try {
      manifest = jsonDecode(await manifestFile.readAsString());
    } catch (_) {
      continue;
    }
    if (manifest is! Map) continue;

    final lessons = manifest['lessons'];
    if (lessons is! List || lessons.isEmpty) continue;
    String? firstSentenceId;
    String mediaType = 'video';

    for (final lesson in lessons) {
      if (lesson is! Map) continue;
      final lessonPath = (lesson['path'] ?? '').toString();
      if (lessonPath.isEmpty) continue;
      final lessonFile = File('${packageDir.path}/$lessonPath');
      if (!lessonFile.existsSync()) continue;

      dynamic lessonJson;
      try {
        lessonJson = jsonDecode(await lessonFile.readAsString());
      } catch (_) {
        continue;
      }
      if (lessonJson is! Map) continue;

      final media =
          lessonJson['media'] is Map ? lessonJson['media'] as Map : {};
      mediaType = (media['type'] ?? 'video').toString();

      final sentences = lessonJson['sentences'];
      if (sentences is! List || sentences.isEmpty) continue;
      for (final sentence in sentences) {
        if (sentence is! Map) continue;
        final id = (sentence['sentence_id'] ?? '').toString();
        if (id.isEmpty) continue;
        firstSentenceId = id;
        break;
      }
      if (firstSentenceId != null) break;
    }

    if (firstSentenceId == null) continue;

    summaries.add(
      LocalCourseSummary(
        courseId: (manifest['course_id'] ?? 'local_course').toString(),
        title:
            (manifest['title'] ?? manifest['course_id'] ?? '本地课程').toString(),
        lessonCount: _toInt(manifest['lesson_count']),
        packageRoot: packageDir.path,
        firstSentenceId: firstSentenceId,
        mediaType: mediaType,
      ),
    );
  }

  summaries.sort((a, b) => b.packageRoot.compareTo(a.packageRoot));
  return summaries;
}

Future<LocalSentenceLoadResult> loadSentencesFromLocalPackage({
  required String packageRoot,
}) async {
  final packageDir = Directory(packageRoot);
  if (!packageDir.existsSync()) {
    return LocalSentenceLoadResult(
      sentences: [],
      warning: '本地课程包不存在($packageRoot)。',
    );
  }

  final manifestFile = File('${packageDir.path}/course_manifest.json');
  if (!manifestFile.existsSync()) {
    return LocalSentenceLoadResult(
      sentences: [],
      warning: '缺少 course_manifest.json($packageRoot)。',
    );
  }

  dynamic manifest;
  try {
    manifest = jsonDecode(await manifestFile.readAsString());
  } catch (_) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程清单格式错误。',
    );
  }

  final courseTitle =
      (manifest['title'] ?? manifest['course_id'] ?? '本地课程').toString();
  final lessons = manifest['lessons'];
  if (lessons is! List || lessons.isEmpty) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程清单为空。',
    );
  }

  final result = <SentenceDetail>[];

  for (final lesson in lessons) {
    if (lesson is! Map) continue;
    final lessonPath = lesson['path'];
    if (lessonPath is! String || lessonPath.isEmpty) continue;

    final lessonFile = File('${packageDir.path}/$lessonPath');
    if (!lessonFile.existsSync()) continue;

    dynamic lessonJson;
    try {
      lessonJson = jsonDecode(await lessonFile.readAsString());
    } catch (_) {
      continue;
    }

    final sentences = lessonJson['sentences'];
    if (sentences is! List) continue;
    final lessonId = (lessonJson['lesson_id'] ?? '').toString();
    final lessonTitle = (lessonJson['title'] ?? '').toString();
    final media =
        lessonJson['media'] is Map ? lessonJson['media'] as Map : const {};
    final mediaType = (media['type'] ?? 'video').toString();
    final mediaRelativePath = (media['path'] ?? '').toString();
    final mediaPath = mediaRelativePath.isEmpty
        ? null
        : '${lessonFile.parent.path}/$mediaRelativePath';

    for (final row in sentences) {
      if (row is! Map) continue;

      final id = (row['sentence_id'] ?? '').toString();
      final en = (row['en'] ?? '').toString();
      if (id.isEmpty || en.isEmpty) continue;

      final zh = (row['zh'] ?? '[待补充]').toString();
      final ipa = (row['ipa'] ?? '[pending]').toString();
      final startMs = _toInt(row['start_ms']);
      final endMs = _toInt(row['end_ms']);

      final grammar = row['grammar'] is Map ? row['grammar'] as Map : const {};
      final usage = row['usage'] is Map ? row['usage'] as Map : const {};

      final notes = <String, String>{
        if ((grammar['pattern'] ?? '').toString().isNotEmpty)
          '语法结构': (grammar['pattern'] ?? '').toString(),
        if (grammar['points'] is List && (grammar['points'] as List).isNotEmpty)
          '语法要点':
              (grammar['points'] as List).map((e) => e.toString()).join('; '),
        if ((usage['scene'] ?? '').toString().isNotEmpty)
          '使用场景': (usage['scene'] ?? '').toString(),
        if ((usage['tone'] ?? '').toString().isNotEmpty)
          '语气': (usage['tone'] ?? '').toString(),
      };

      result.add(
        SentenceDetail(
          id: id,
          text: en,
          translation: zh,
          phonetic: ipa,
          grammarNotes: notes,
          startTime: Duration(milliseconds: startMs),
          endTime: Duration(
            milliseconds: endMs > startMs ? endMs : startMs + 1000,
          ),
          lessonId: lessonId.isEmpty ? null : lessonId,
          lessonTitle: lessonTitle.isEmpty ? null : lessonTitle,
          mediaType: mediaType,
          mediaPath: mediaPath,
          courseTitle: courseTitle,
          packageRoot: packageDir.path,
        ),
      );
    }
  }

  if (result.isEmpty) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程包缺少可用句子。',
    );
  }

  return LocalSentenceLoadResult(sentences: result);
}

Future<bool> sentenceExistsInLocalPackage({
  required String packageRoot,
  required String sentenceId,
}) async {
  if (packageRoot.trim().isEmpty || sentenceId.trim().isEmpty) return false;
  final loaded = await loadSentencesFromLocalPackage(packageRoot: packageRoot);
  if (loaded.sentences.isEmpty) return false;
  return loaded.sentences.any((s) => s.id == sentenceId);
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
