import 'dart:convert';
import 'dart:io';

import 'package:engbooks/src/common/io/runtime_paths.dart';
import 'package:engbooks/src/features/download_center/data/preset_catalog_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir =
        await Directory.systemTemp.createTemp('preset_catalog_loader_test_');
    Directory.current = tempDir;
    debugSetRuntimeRootOverridePath('${tempDir.path}/.runtime');
  });

  tearDown(() async {
    debugSetRuntimeRootOverridePath(null);
    Directory.current = originalCurrent;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('parses new asset protocol from discovered local catalog', () async {
    final tasksDir = Directory('${tempDir.path}/.runtime/tasks');
    await tasksDir.create(recursive: true);
    final taskId = 'task_catalog_case';
    await File('${tasksDir.path}/$taskId.json').writeAsString(
      jsonEncode({
        'task_id': taskId,
        'status': 'ready',
        'updated_at': '2026-02-20T12:00:00Z',
      }),
    );

    final packageDir = Directory('${tasksDir.path}/$taskId/package');
    await packageDir.create(recursive: true);
    await File('${packageDir.path}/catalog.json').writeAsString(
      jsonEncode({
        'version': 1,
        'courses': [
          {
            'id': 'course_zip',
            'title': 'Zip Course',
            'tags': ['全部'],
            'version': '1.0.0',
            'cover': '',
            'asset': {
              'mode': 'zip',
              'url': 'http://example.com/course_zip.zip',
              'size_bytes': 12345,
              'sha256': 'a' * 64,
            },
          },
          {
            'id': 'course_seg',
            'title': 'Segmented Course',
            'tags': ['全部'],
            'version': '1.0.0',
            'cover': '',
            'asset': {
              'mode': 'segmented_zip',
              'manifest_url': 'http://example.com/course_seg.manifest.json',
              'size_bytes': 67890,
              'sha256': 'b' * 64,
            },
          },
        ],
      }),
    );

    final courses = await loadPresetCatalogCourses();
    expect(courses.length, 2);
    expect(courses.first.id, 'course_zip');
    expect(courses.first.asset.mode, CourseAssetMode.zip);
    expect(courses.first.asset.url, isNotEmpty);
    expect(courses.last.id, 'course_seg');
    expect(courses.last.asset.mode, CourseAssetMode.segmentedZip);
    expect(courses.last.asset.manifestUrl, isNotEmpty);
  });
}
