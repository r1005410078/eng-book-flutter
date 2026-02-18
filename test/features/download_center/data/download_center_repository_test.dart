import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:engbooks/src/common/io/runtime_paths.dart';
import 'package:engbooks/src/features/download_center/data/download_center_repository.dart';
import 'package:engbooks/src/features/download_center/data/preset_catalog_loader.dart';
import 'package:engbooks/src/features/download_center/domain/download_models.dart';
import 'package:engbooks/src/features/practice/data/local_course_package_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory originalCurrent;
  late Directory tempDir;
  late HttpServer server;

  setUp(() async {
    originalCurrent = Directory.current;
    tempDir =
        await Directory.systemTemp.createTemp('download_center_repo_test_');
    Directory.current = tempDir;
    debugSetRuntimeRootOverridePath('${tempDir.path}/.runtime');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
    debugSetRuntimeRootOverridePath(null);
    Directory.current = originalCurrent;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('download + install + delete integrates with local course loader',
      () async {
    const courseId = 'basic-jp-i';
    final zipBytes = _buildValidCourseZip(courseId: courseId);
    final hash = sha256.convert(zipBytes).toString();

    server.listen((req) {
      req.response
        ..statusCode = 200
        ..headers.contentLength = zipBytes.length
        ..add(zipBytes);
      req.response.close();
    });

    final repo = DownloadCenterRepositoryImpl();
    final snapshots = <DownloadTaskSnapshot>[];
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Course A',
      tags: const ['全部'],
      sizeBytes: zipBytes.length,
      version: '1.0.0',
      url: 'http://127.0.0.1:${server.port}/course.zip',
      hash: hash,
      cover: null,
    );

    await repo.startOrResumeDownload(
      course: course,
      snapshot: const DownloadTaskSnapshot(
        courseId: courseId,
        status: DownloadStatus.notDownloaded,
        downloadedBytes: 0,
        totalBytes: 0,
      ),
      onProgress: snapshots.add,
    );

    expect(snapshots.map((s) => s.status), contains(DownloadStatus.installing));
    expect(snapshots.last.status, DownloadStatus.installed);

    final courses = await listLocalCoursePackages();
    expect(courses.any((c) => c.courseId == courseId), isTrue);

    final exists = await sentenceExistsInLocalPackage(
      packageRoot:
          courses.firstWhere((c) => c.courseId == courseId).packageRoot,
      sentenceId: '01-0001',
    );
    expect(exists, isTrue);

    await repo.deleteCourseArtifacts(courseId);
    final afterDelete = await listLocalCoursePackages();
    expect(afterDelete.where((c) => c.courseId == courseId), isEmpty);
  });

  test('hash mismatch fails and does not create installed task', () async {
    const courseId = 'course-hash-fail';
    final zipBytes = _buildValidCourseZip(courseId: courseId);

    server.listen((req) {
      req.response
        ..statusCode = 200
        ..headers.contentLength = zipBytes.length
        ..add(zipBytes);
      req.response.close();
    });

    final repo = DownloadCenterRepositoryImpl();
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Course Hash Fail',
      tags: const ['全部'],
      sizeBytes: zipBytes.length,
      version: '1.0.0',
      url: 'http://127.0.0.1:${server.port}/course.zip',
      hash: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      cover: null,
    );

    await expectLater(
      repo.startOrResumeDownload(
        course: course,
        snapshot: const DownloadTaskSnapshot(
          courseId: courseId,
          status: DownloadStatus.notDownloaded,
          downloadedBytes: 0,
          totalBytes: 0,
        ),
        onProgress: (_) {},
      ),
      throwsException,
    );

    final taskJson =
        File('${tempDir.path}/.runtime/tasks/task_download_$courseId.json');
    expect(taskJson.existsSync(), isFalse);
  });

  test('invalid package install fails and leaves no installed task', () async {
    const courseId = 'course-invalid-package';
    final zipBytes = _buildInvalidZipWithoutManifest();

    server.listen((req) {
      req.response
        ..statusCode = 200
        ..headers.contentLength = zipBytes.length
        ..add(zipBytes);
      req.response.close();
    });

    final repo = DownloadCenterRepositoryImpl();
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Broken',
      tags: const ['全部'],
      sizeBytes: zipBytes.length,
      version: '1.0.0',
      url: 'http://127.0.0.1:${server.port}/course.zip',
      hash: '',
      cover: null,
    );

    await expectLater(
      repo.startOrResumeDownload(
        course: course,
        snapshot: const DownloadTaskSnapshot(
          courseId: courseId,
          status: DownloadStatus.notDownloaded,
          downloadedBytes: 0,
          totalBytes: 0,
        ),
        onProgress: (_) {},
      ),
      throwsException,
    );

    final taskJson =
        File('${tempDir.path}/.runtime/tasks/task_download_$courseId.json');
    final taskDir =
        Directory('${tempDir.path}/.runtime/tasks/task_download_$courseId');
    expect(taskJson.existsSync(), isFalse);
    expect(taskDir.existsSync(), isFalse);
  });
}

List<int> _buildValidCourseZip({required String courseId}) {
  final manifest = {
    'course_id': courseId,
    'title': 'Title $courseId',
    'lesson_count': 1,
    'lessons': [
      {'lesson_id': '01', 'path': 'lessons/01/lesson.json'},
    ],
  };
  final lesson = {
    'lesson_id': '01',
    'title': 'Lesson 01',
    'media': {'type': 'audio', 'path': 'media.mp3'},
    'sentences': [
      {
        'sentence_id': '01-0001',
        'start_ms': 0,
        'end_ms': 1000,
        'en': 'Hello',
        'zh': '你好',
        'ipa': '/həˈləʊ/',
      }
    ],
  };

  final archive = Archive()
    ..addFile(ArchiveFile(
      'course_manifest.json',
      utf8.encode(jsonEncode(manifest)).length,
      utf8.encode(jsonEncode(manifest)),
    ))
    ..addFile(ArchiveFile(
      'lessons/01/lesson.json',
      utf8.encode(jsonEncode(lesson)).length,
      utf8.encode(jsonEncode(lesson)),
    ))
    ..addFile(ArchiveFile('lessons/01/media.mp3', 4, utf8.encode('mock')));

  return ZipEncoder().encode(archive)!;
}

List<int> _buildInvalidZipWithoutManifest() {
  final archive = Archive()
    ..addFile(ArchiveFile('README.txt', 7, utf8.encode('invalid')));
  return ZipEncoder().encode(archive)!;
}
