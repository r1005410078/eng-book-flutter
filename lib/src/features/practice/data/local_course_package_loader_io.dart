import 'dart:convert';
import 'dart:io';

import '../domain/sentence_detail.dart';

class LocalSentenceLoadResult {
  final List<SentenceDetail> sentences;
  final String? warning;

  const LocalSentenceLoadResult({required this.sentences, this.warning});
}

Future<LocalSentenceLoadResult> loadSentencesFromLocalPackage({
  required String packageRoot,
}) async {
  final packageDir = Directory(packageRoot);
  if (!packageDir.existsSync()) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '本地课程包不存在，已使用默认内容。',
    );
  }

  final manifestFile = File('${packageDir.path}/course_manifest.json');
  if (!manifestFile.existsSync()) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '缺少 course_manifest.json，已使用默认内容。',
    );
  }

  dynamic manifest;
  try {
    manifest = jsonDecode(await manifestFile.readAsString());
  } catch (_) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程清单格式错误，已使用默认内容。',
    );
  }

  final lessons = manifest['lessons'];
  if (lessons is! List || lessons.isEmpty) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程清单为空，已使用默认内容。',
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
          'Grammar': (grammar['pattern'] ?? '').toString(),
        if (grammar['points'] is List && (grammar['points'] as List).isNotEmpty)
          'Grammar Points':
              (grammar['points'] as List).map((e) => e.toString()).join('; '),
        if ((usage['scene'] ?? '').toString().isNotEmpty)
          'Usage Scene': (usage['scene'] ?? '').toString(),
        if ((usage['tone'] ?? '').toString().isNotEmpty)
          'Tone': (usage['tone'] ?? '').toString(),
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
        ),
      );
    }
  }

  if (result.isEmpty) {
    return const LocalSentenceLoadResult(
      sentences: [],
      warning: '课程包缺少可用句子，已使用默认内容。',
    );
  }

  return LocalSentenceLoadResult(sentences: result);
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
