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
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.zip,
        sizeBytes: zipBytes.length,
        sha256: hash,
        url: 'http://127.0.0.1:${server.port}/course.zip',
      ),
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
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.zip,
        sizeBytes: zipBytes.length,
        sha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        url: 'http://127.0.0.1:${server.port}/course.zip',
      ),
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
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.zip,
        sizeBytes: zipBytes.length,
        sha256: '',
        url: 'http://127.0.0.1:${server.port}/course.zip',
      ),
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

  test('segmented download merges and installs successfully', () async {
    const courseId = 'course-segmented-ok';
    final zipBytes = _buildValidCourseZip(courseId: courseId);
    final fixture = _buildSegmentedFixture(
      baseUrl: 'http://127.0.0.1:${server.port}',
      zipBytes: zipBytes,
      partSize: 512,
    );

    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/manifest.json') {
        final body = utf8.encode(jsonEncode(fixture.manifest));
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..headers.contentLength = body.length
          ..add(body);
        await req.response.close();
        return;
      }
      final bytes = fixture.partData[path];
      if (bytes == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      await _serveBytes(req, bytes);
    });

    final repo = DownloadCenterRepositoryImpl();
    final snapshots = <DownloadTaskSnapshot>[];
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Segmented',
      tags: const ['全部'],
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.segmentedZip,
        sizeBytes: zipBytes.length,
        sha256: sha256.convert(zipBytes).toString(),
        manifestUrl: 'http://127.0.0.1:${server.port}/manifest.json',
      ),
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

    expect(snapshots.any((s) => s.totalParts > 1), isTrue);
    expect(snapshots.last.status, DownloadStatus.installed);
    final taskJson =
        File('${tempDir.path}/.runtime/tasks/task_download_$courseId.json');
    expect(taskJson.existsSync(), isTrue);
  });

  test('segmented part hash mismatch fails and does not install', () async {
    const courseId = 'course-segmented-bad-hash';
    final zipBytes = _buildValidCourseZip(courseId: courseId);
    final fixture = _buildSegmentedFixture(
      baseUrl: 'http://127.0.0.1:${server.port}',
      zipBytes: zipBytes,
      partSize: 32 * 1024,
    );
    if (fixture.manifest['parts'] is List &&
        (fixture.manifest['parts'] as List).isNotEmpty) {
      (fixture.manifest['parts'] as List).first['sha256'] =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    }

    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/manifest.json') {
        final body = utf8.encode(jsonEncode(fixture.manifest));
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..headers.contentLength = body.length
          ..add(body);
        await req.response.close();
        return;
      }
      final bytes = fixture.partData[path];
      if (bytes == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      await _serveBytes(req, bytes);
    });

    final repo = DownloadCenterRepositoryImpl();
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Segmented Hash Fail',
      tags: const ['全部'],
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.segmentedZip,
        sizeBytes: zipBytes.length,
        sha256: sha256.convert(zipBytes).toString(),
        manifestUrl: 'http://127.0.0.1:${server.port}/manifest.json',
      ),
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

  test('segmented download resumes from partial part file', () async {
    const courseId = 'course-segmented-resume';
    final zipBytes = _buildValidCourseZip(courseId: courseId);
    final fixture = _buildSegmentedFixture(
      baseUrl: 'http://127.0.0.1:${server.port}',
      zipBytes: zipBytes,
      partSize: 512,
    );

    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/manifest.json') {
        final body = utf8.encode(jsonEncode(fixture.manifest));
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..headers.contentLength = body.length
          ..add(body);
        await req.response.close();
        return;
      }
      final bytes = fixture.partData[path];
      if (bytes == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      await _serveBytes(req, bytes, chunkSize: 2048);
    });

    final repo = DownloadCenterRepositoryImpl();
    final course = PresetCatalogCourse(
      id: courseId,
      title: 'Segmented Resume',
      tags: const ['全部'],
      version: '1.0.0',
      cover: null,
      asset: CourseAsset(
        mode: CourseAssetMode.segmentedZip,
        sizeBytes: zipBytes.length,
        sha256: sha256.convert(zipBytes).toString(),
        manifestUrl: 'http://127.0.0.1:${server.port}/manifest.json',
      ),
    );

    // Pre-create a partial first part to verify resumable ranged fetch.
    await repo.queryAvailableBytes();
    final tmpPart = File(
      '${tempDir.path}/.runtime/download_center/tmp/${courseId}_parts/part_0001',
    );
    await tmpPart.parent.create(recursive: true);
    final firstPartBytes = fixture.partData['/parts/part-0001']!;
    await tmpPart.writeAsBytes(
      firstPartBytes.sublist(0, firstPartBytes.length ~/ 2),
      flush: true,
    );

    final resumeSnapshots = <DownloadTaskSnapshot>[];
    await repo.startOrResumeDownload(
      course: course,
      snapshot: const DownloadTaskSnapshot(
        courseId: courseId,
        status: DownloadStatus.paused,
        downloadedBytes: 0,
        totalBytes: 0,
        currentPartIndex: 1,
        currentPartDownloadedBytes: 1,
      ),
      onProgress: resumeSnapshots.add,
    );
    expect(
      resumeSnapshots.any((s) => s.currentPartIndex >= 1),
      isTrue,
    );
    expect(resumeSnapshots.last.status, DownloadStatus.installed);
    final taskJson =
        File('${tempDir.path}/.runtime/tasks/task_download_$courseId.json');
    expect(taskJson.existsSync(), isTrue);
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

class _SegmentedFixture {
  final Map<String, dynamic> manifest;
  final Map<String, List<int>> partData;

  _SegmentedFixture({
    required this.manifest,
    required this.partData,
  });
}

_SegmentedFixture _buildSegmentedFixture({
  required String baseUrl,
  required List<int> zipBytes,
  required int partSize,
}) {
  final parts = <Map<String, dynamic>>[];
  final partData = <String, List<int>>{};
  var index = 1;
  for (var offset = 0; offset < zipBytes.length; offset += partSize) {
    final end = (offset + partSize < zipBytes.length)
        ? (offset + partSize)
        : zipBytes.length;
    final bytes = zipBytes.sublist(offset, end);
    final path = '/parts/part-${index.toString().padLeft(4, '0')}';
    parts.add({
      'index': index,
      'object_key': 'test$path',
      'size_bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'url': '$baseUrl$path',
    });
    partData[path] = bytes;
    index += 1;
  }

  final manifest = <String, dynamic>{
    'source_size_bytes': zipBytes.length,
    'source_sha256': sha256.convert(zipBytes).toString(),
    'parts': parts,
  };
  return _SegmentedFixture(manifest: manifest, partData: partData);
}

Future<void> _serveBytes(
  HttpRequest req,
  List<int> data, {
  int chunkSize = 4096,
}) async {
  var start = 0;
  final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
  if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
    final raw = rangeHeader.substring('bytes='.length);
    final begin = raw.split('-').first;
    start = int.tryParse(begin) ?? 0;
    if (start < 0 || start >= data.length) {
      req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await req.response.close();
      return;
    }
    req.response.statusCode = HttpStatus.partialContent;
    req.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-${data.length - 1}/${data.length}',
    );
  } else {
    req.response.statusCode = HttpStatus.ok;
  }
  final remain = data.sublist(start);
  req.response.headers.contentLength = remain.length;
  for (var i = 0; i < remain.length; i += chunkSize) {
    final end = (i + chunkSize < remain.length) ? i + chunkSize : remain.length;
    req.response.add(remain.sublist(i, end));
    await req.response.flush();
  }
  await req.response.close();
}
