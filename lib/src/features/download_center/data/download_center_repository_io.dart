import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../../../common/io/runtime_paths.dart';
import '../domain/download_models.dart';
import 'download_center_repository_api.dart';
import 'preset_catalog_loader.dart';

class DownloadCenterRepositoryImpl implements DownloadCenterRepository {
  final Map<String, _ActiveDownload> _active = {};

  late Directory _rootDir;
  late Directory _tmpDir;
  late Directory _stagingDir;
  late File _stateFile;
  late Directory _runtimeTasksDir;
  bool _initialized = false;

  @override
  Future<int?> queryAvailableBytes() async {
    await _ensureDirs();
    try {
      final result = await Process.run('df', ['-k', _rootDir.path]);
      if (result.exitCode != 0) return null;
      final output = (result.stdout ?? '').toString().trim();
      if (output.isEmpty) return null;
      final lines =
          output.split('\n').where((e) => e.trim().isNotEmpty).toList();
      if (lines.length < 2) return null;
      final parts =
          lines.last.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.length < 4) return null;
      final availableKb = int.tryParse(parts[3]);
      if (availableKb == null || availableKb <= 0) return null;
      return availableKb * 1024;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, DownloadTaskSnapshot>> loadSnapshots() async {
    await _ensureDirs();
    if (!_stateFile.existsSync()) return {};
    try {
      final decoded = jsonDecode(await _stateFile.readAsString());
      if (decoded is! Map) return {};
      final result = <String, DownloadTaskSnapshot>{};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key.toString()] = DownloadTaskSnapshot.fromJson(value);
        } else if (value is Map) {
          result[key.toString()] =
              DownloadTaskSnapshot.fromJson(value.cast<String, dynamic>());
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> persistSnapshots(
    Map<String, DownloadTaskSnapshot> snapshots,
  ) async {
    await _ensureDirs();
    final body = <String, dynamic>{
      for (final e in snapshots.entries) e.key: e.value.toJson(),
    };
    await _stateFile.writeAsString(jsonEncode(body));
  }

  @override
  Future<bool> isInstalled(String courseId) async {
    await _ensureDirs();
    final taskJson = File('${_runtimeTasksDir.path}/${_taskId(courseId)}.json');
    final packageDir =
        Directory('${_runtimeTasksDir.path}/${_taskId(courseId)}/package');
    final manifest = File('${packageDir.path}/course_manifest.json');
    return taskJson.existsSync() &&
        packageDir.existsSync() &&
        manifest.existsSync();
  }

  @override
  Future<void> startOrResumeDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {
    return switch (course.asset.mode) {
      CourseAssetMode.zip => _startOrResumeZipDownload(
          course: course,
          snapshot: snapshot,
          onProgress: onProgress,
        ),
      CourseAssetMode.segmentedZip => _startOrResumeSegmentedDownload(
          course: course,
          snapshot: snapshot,
          onProgress: onProgress,
        ),
    };
  }

  Future<void> _startOrResumeZipDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {
    await _ensureDirs();
    if (_active.containsKey(course.id)) return;

    final partFile = _partFile(course.id);
    if (!partFile.parent.existsSync()) {
      await partFile.parent.create(recursive: true);
    }

    var downloaded = partFile.existsSync() ? await partFile.length() : 0;
    final url = course.asset.url;
    if (url == null || url.isEmpty) {
      throw Exception('目录协议错误：zip 模式缺少下载 URL');
    }
    final request = await HttpClient().getUrl(Uri.parse(url));
    if (downloaded > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$downloaded-');
    }

    final response = await request.close();
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw Exception('下载失败，HTTP ${response.statusCode}');
    }

    final isPartial = response.statusCode == 206;
    if (!isPartial && downloaded > 0) {
      downloaded = 0;
      if (partFile.existsSync()) {
        await partFile.delete();
      }
    }

    final totalFromResponse = response.contentLength > 0
        ? (downloaded + response.contentLength)
        : (snapshot.totalBytes > 0
            ? snapshot.totalBytes
            : course.asset.sizeBytes);
    final totalBytes =
        totalFromResponse > 0 ? totalFromResponse : course.asset.sizeBytes;

    final raf = await partFile.open(mode: FileMode.append);
    final active = _ActiveDownload();
    _active[course.id] = active;

    onProgress(
      snapshot.copyWith(
        status: DownloadStatus.downloading,
        downloadedBytes: downloaded,
        totalBytes: totalBytes,
        clearError: true,
      ),
    );

    final done = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    sub = response.listen(
      (chunk) {
        if (active.paused || active.canceled) return;
        raf.writeFromSync(chunk);
        downloaded += chunk.length;
        onProgress(
          snapshot.copyWith(
            status: DownloadStatus.downloading,
            downloadedBytes: downloaded,
            totalBytes: totalBytes,
            clearError: true,
          ),
        );
      },
      onError: (e) async {
        await raf.close();
        _active.remove(course.id);
        if (active.paused) {
          onProgress(
            snapshot.copyWith(
              status: DownloadStatus.paused,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
            ),
          );
          done.complete();
          return;
        }
        if (active.canceled) {
          done.complete();
          return;
        }
        done.completeError(e);
      },
      onDone: () async {
        await raf.close();
        _active.remove(course.id);

        if (active.canceled) {
          done.complete();
          return;
        }
        if (active.paused) {
          onProgress(
            snapshot.copyWith(
              status: DownloadStatus.paused,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
            ),
          );
          done.complete();
          return;
        }

        final complete =
            totalBytes <= 0 ? downloaded > 0 : downloaded >= totalBytes;
        if (!complete) {
          done.completeError(Exception('下载中断，请重试'));
          return;
        }

        try {
          await _verifyHashIfNeeded(file: partFile, expectedHash: course.hash);
          onProgress(
            snapshot.copyWith(
              status: DownloadStatus.installing,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
              currentPartIndex: 0,
              currentPartDownloadedBytes: 0,
              totalParts: 0,
              clearError: true,
            ),
          );
          await _installCourse(course.id, partFile);
          onProgress(
            snapshot.copyWith(
              status: DownloadStatus.installed,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
              currentPartIndex: 0,
              currentPartDownloadedBytes: 0,
              totalParts: 0,
              clearError: true,
            ),
          );
          if (partFile.existsSync()) {
            await partFile.delete();
          }
          done.complete();
        } catch (e) {
          await _cleanupInstallArtifacts(course.id);
          done.completeError(e);
        }
      },
      cancelOnError: false,
    );
    active.subscription = sub;
    await done.future;
  }

  Future<void> _startOrResumeSegmentedDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {
    await _ensureDirs();
    if (_active.containsKey(course.id)) return;

    final manifest = await _loadSegmentedManifest(course);
    if (manifest.parts.isEmpty) {
      throw Exception('分片清单无有效分片。');
    }

    final partsDir = Directory('${_tmpDir.path}/${course.id}_parts');
    if (!partsDir.existsSync()) {
      await partsDir.create(recursive: true);
    }
    final mergedFile = _partFile(course.id);

    final active = _ActiveDownload();
    _active[course.id] = active;
    final totalParts = manifest.parts.length;

    try {
      var completedBytes = await _computeVerifiedCompletedBytes(
        courseId: course.id,
        parts: manifest.parts,
      );
      onProgress(
        snapshot.copyWith(
          status: DownloadStatus.downloading,
          downloadedBytes: completedBytes,
          totalBytes: manifest.sourceSizeBytes,
          totalParts: totalParts,
          currentPartIndex: _findNextPartIndex(course.id, manifest.parts),
          currentPartDownloadedBytes: 0,
          clearError: true,
        ),
      );

      for (final part in manifest.parts) {
        if (active.canceled) return;

        final existingOk = await _isPartReady(
          courseId: course.id,
          part: part,
        );
        if (existingOk) {
          continue;
        }

        final partFile = _segmentPartFile(course.id, part.index);
        var downloaded = partFile.existsSync() ? await partFile.length() : 0;

        final request = await HttpClient().getUrl(Uri.parse(part.url));
        if (downloaded > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$downloaded-');
        }
        final response = await request.close();
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('分片 ${part.index} 下载失败，HTTP ${response.statusCode}');
        }

        final isPartial = response.statusCode == 206;
        if (!isPartial && downloaded > 0) {
          downloaded = 0;
          if (partFile.existsSync()) {
            await partFile.delete();
          }
        }

        final raf = await partFile.open(mode: FileMode.append);
        final done = Completer<void>();
        active.waiter = done;
        late final StreamSubscription<List<int>> sub;
        sub = response.listen(
          (chunk) {
            if (active.paused || active.canceled) return;
            raf.writeFromSync(chunk);
            downloaded += chunk.length;
            onProgress(
              snapshot.copyWith(
                status: DownloadStatus.downloading,
                downloadedBytes: completedBytes + downloaded,
                totalBytes: manifest.sourceSizeBytes,
                totalParts: totalParts,
                currentPartIndex: part.index,
                currentPartDownloadedBytes: downloaded,
                clearError: true,
              ),
            );
          },
          onError: (e) async {
            await raf.close();
            if (active.paused) {
              onProgress(
                snapshot.copyWith(
                  status: DownloadStatus.paused,
                  downloadedBytes: completedBytes + downloaded,
                  totalBytes: manifest.sourceSizeBytes,
                  totalParts: totalParts,
                  currentPartIndex: part.index,
                  currentPartDownloadedBytes: downloaded,
                ),
              );
              if (!done.isCompleted) done.complete();
              return;
            }
            if (active.canceled) {
              if (!done.isCompleted) done.complete();
              return;
            }
            if (!done.isCompleted) done.completeError(e);
          },
          onDone: () async {
            await raf.close();
            if (active.canceled) {
              if (!done.isCompleted) done.complete();
              return;
            }
            if (active.paused) {
              onProgress(
                snapshot.copyWith(
                  status: DownloadStatus.paused,
                  downloadedBytes: completedBytes + downloaded,
                  totalBytes: manifest.sourceSizeBytes,
                  totalParts: totalParts,
                  currentPartIndex: part.index,
                  currentPartDownloadedBytes: downloaded,
                ),
              );
              if (!done.isCompleted) done.complete();
              return;
            }
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: false,
        );
        active.subscription = sub;
        await done.future;
        active.waiter = null;
        if (active.paused || active.canceled) {
          return;
        }

        await _verifyPartHash(file: partFile, expectedHash: part.sha256);
        final fileSize = await partFile.length();
        if (fileSize != part.sizeBytes) {
          throw Exception('分片 ${part.index} 大小不匹配，请重试');
        }
        completedBytes += fileSize;
      }

      await _mergeParts(course.id, manifest.parts, mergedFile);
      await _verifyHashIfNeeded(
        file: mergedFile,
        expectedHash: manifest.sourceSha256,
      );
      final mergedSize = await mergedFile.length();
      if (mergedSize != manifest.sourceSizeBytes) {
        throw Exception('合并后文件大小不匹配，请重试');
      }

      onProgress(
        snapshot.copyWith(
          status: DownloadStatus.installing,
          downloadedBytes: manifest.sourceSizeBytes,
          totalBytes: manifest.sourceSizeBytes,
          totalParts: totalParts,
          currentPartIndex: totalParts,
          currentPartDownloadedBytes: 0,
          clearError: true,
        ),
      );

      await _installCourse(course.id, mergedFile);
      onProgress(
        snapshot.copyWith(
          status: DownloadStatus.installed,
          downloadedBytes: manifest.sourceSizeBytes,
          totalBytes: manifest.sourceSizeBytes,
          totalParts: totalParts,
          currentPartIndex: totalParts,
          currentPartDownloadedBytes: 0,
          clearError: true,
        ),
      );
      await _cleanupSegmentedTemp(course.id);
    } finally {
      _active.remove(course.id);
    }
  }

  @override
  Future<void> pauseDownload(String courseId) async {
    final active = _active[courseId];
    if (active == null) return;
    active.paused = true;
    await active.subscription?.cancel();
    if (!(active.waiter?.isCompleted ?? true)) {
      active.waiter?.complete();
    }
  }

  @override
  Future<void> cancelDownload(String courseId) async {
    await _ensureDirs();
    final active = _active[courseId];
    if (active != null) {
      active.canceled = true;
      await active.subscription?.cancel();
      if (!(active.waiter?.isCompleted ?? true)) {
        active.waiter?.complete();
      }
      _active.remove(courseId);
    }
    final part = _partFile(courseId);
    if (part.existsSync()) {
      await part.delete();
    }
    await _cleanupSegmentedTemp(courseId);
  }

  @override
  Future<void> deleteCourseArtifacts(String courseId) async {
    await _ensureDirs();
    await cancelDownload(courseId);
    final part = _partFile(courseId);
    if (part.existsSync()) await part.delete();

    final taskJson = File('${_runtimeTasksDir.path}/${_taskId(courseId)}.json');
    if (taskJson.existsSync()) {
      await taskJson.delete();
    }
    final taskDir = Directory('${_runtimeTasksDir.path}/${_taskId(courseId)}');
    if (taskDir.existsSync()) {
      await taskDir.delete(recursive: true);
    }

    final stage = Directory('${_stagingDir.path}/$courseId');
    if (stage.existsSync()) {
      await stage.delete(recursive: true);
    }
    await _cleanupSegmentedTemp(courseId);
  }

  @override
  Future<void> clearAllCourseArtifacts() async {
    await _ensureDirs();
    final activeIds = _active.keys.toList(growable: false);
    for (final courseId in activeIds) {
      await cancelDownload(courseId);
    }

    if (_rootDir.existsSync()) {
      await _rootDir.delete(recursive: true);
    }
    await _ensureDirs();

    if (!_runtimeTasksDir.existsSync()) return;
    for (final entity in _runtimeTasksDir.listSync()) {
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!name.startsWith('task_download_')) continue;
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<_SegmentedManifest> _loadSegmentedManifest(
    PresetCatalogCourse course,
  ) async {
    final inlineParts = course.asset.parts;
    if (inlineParts.isNotEmpty) {
      return _SegmentedManifest(
        sourceSizeBytes: course.asset.sizeBytes,
        sourceSha256: course.asset.sha256,
        parts: inlineParts
            .map(
              (p) => _SegmentedPart(
                index: p.index,
                objectKey: p.objectKey,
                sizeBytes: p.sizeBytes,
                sha256: p.sha256,
                url: p.url,
              ),
            )
            .toList(growable: false),
      );
    }

    final manifestUrl = course.asset.manifestUrl;
    if (manifestUrl == null || manifestUrl.isEmpty) {
      throw Exception('目录协议错误：segmented_zip 缺少 manifest_url');
    }

    final request = await HttpClient().getUrl(Uri.parse(manifestUrl));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('下载 manifest 失败，HTTP ${response.statusCode}');
    }
    final body = await utf8.decodeStream(response);
    final raw = jsonDecode(body);
    if (raw is! Map) {
      throw Exception('manifest 格式错误');
    }

    final sourceSizeBytes = _toInt(raw['source_size_bytes']);
    final sourceSha256 = (raw['source_sha256'] ?? '').toString().trim();
    if (sourceSizeBytes <= 0 || sourceSha256.isEmpty) {
      throw Exception('manifest 缺少源文件校验字段');
    }

    final rawParts = raw['parts'];
    if (rawParts is! List || rawParts.isEmpty) {
      throw Exception('manifest 缺少分片列表');
    }

    final parts = <_SegmentedPart>[];
    for (final row in rawParts) {
      if (row is! Map) continue;
      final index = _toInt(row['index']);
      final objectKey = (row['object_key'] ?? '').toString().trim();
      final sizeBytes = _toInt(row['size_bytes']);
      final sha256 = (row['sha256'] ?? '').toString().trim().toLowerCase();
      final url = (row['url'] ?? '').toString().trim();
      if (index <= 0 ||
          objectKey.isEmpty ||
          sizeBytes <= 0 ||
          sha256.isEmpty ||
          url.isEmpty) {
        continue;
      }
      parts.add(
        _SegmentedPart(
          index: index,
          objectKey: objectKey,
          sizeBytes: sizeBytes,
          sha256: sha256,
          url: url,
        ),
      );
    }
    parts.sort((a, b) => a.index.compareTo(b.index));
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].index != i + 1) {
        throw Exception('manifest 分片顺序错误');
      }
    }

    return _SegmentedManifest(
      sourceSizeBytes: sourceSizeBytes,
      sourceSha256: sourceSha256.toLowerCase(),
      parts: parts,
    );
  }

  Future<bool> _isPartReady({
    required String courseId,
    required _SegmentedPart part,
  }) async {
    final file = _segmentPartFile(courseId, part.index);
    if (!file.existsSync()) return false;
    final size = await file.length();
    if (size != part.sizeBytes) return false;
    final digest = await _sha256Of(file);
    return digest.toLowerCase() == part.sha256.toLowerCase();
  }

  Future<int> _computeVerifiedCompletedBytes({
    required String courseId,
    required List<_SegmentedPart> parts,
  }) async {
    var completed = 0;
    for (final part in parts) {
      final ok = await _isPartReady(courseId: courseId, part: part);
      if (!ok) {
        break;
      }
      completed += part.sizeBytes;
    }
    return completed;
  }

  int _findNextPartIndex(String courseId, List<_SegmentedPart> parts) {
    for (final part in parts) {
      final file = _segmentPartFile(courseId, part.index);
      if (!file.existsSync()) return part.index;
    }
    return parts.length;
  }

  Future<void> _verifyPartHash({
    required File file,
    required String expectedHash,
  }) async {
    final digest = await _sha256Of(file);
    if (digest.toLowerCase() != expectedHash.toLowerCase()) {
      throw Exception('分片校验失败，请重试');
    }
  }

  Future<void> _mergeParts(
    String courseId,
    List<_SegmentedPart> parts,
    File outFile,
  ) async {
    if (outFile.existsSync()) {
      await outFile.delete();
    }
    final sink = outFile.openWrite(mode: FileMode.writeOnlyAppend);
    try {
      for (final part in parts) {
        final partFile = _segmentPartFile(courseId, part.index);
        if (!partFile.existsSync()) {
          throw Exception('缺少分片 ${part.index}');
        }
        await sink.addStream(partFile.openRead());
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _cleanupSegmentedTemp(String courseId) async {
    final dir = _segmentPartsDir(courseId);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _installCourse(String courseId, File zipFile) async {
    final extractZip = File('${_tmpDir.path}/$courseId.zip');
    if (extractZip.existsSync()) {
      await extractZip.delete();
    }
    await zipFile.copy(extractZip.path);

    final stage = Directory('${_stagingDir.path}/$courseId');
    if (stage.existsSync()) {
      await stage.delete(recursive: true);
    }
    await stage.create(recursive: true);

    try {
      extractFileToDisk(extractZip.path, stage.path);
    } finally {
      if (extractZip.existsSync()) {
        await extractZip.delete();
      }
    }

    final packageRoot = await _findPackageRoot(stage);
    if (packageRoot == null) {
      throw Exception('安装失败：课程包缺少 course_manifest.json');
    }

    await _runtimeTasksDir.create(recursive: true);
    final taskId = _taskId(courseId);
    final taskDir = Directory('${_runtimeTasksDir.path}/$taskId');
    final packageDir = Directory('${taskDir.path}/package');
    final taskJson = File('${_runtimeTasksDir.path}/$taskId.json');

    if (taskDir.existsSync()) {
      await taskDir.delete(recursive: true);
    }
    await packageDir.create(recursive: true);
    await _copyDirectory(packageRoot, packageDir);

    await taskJson.writeAsString(
      jsonEncode({
        'task_id': taskId,
        'status': 'ready',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'download_center',
      }),
    );
  }

  Future<void> _cleanupInstallArtifacts(String courseId) async {
    final taskDir = Directory('${_runtimeTasksDir.path}/${_taskId(courseId)}');
    if (taskDir.existsSync()) {
      await taskDir.delete(recursive: true);
    }
    final taskJson = File('${_runtimeTasksDir.path}/${_taskId(courseId)}.json');
    if (taskJson.existsSync()) {
      await taskJson.delete();
    }
    final stage = Directory('${_stagingDir.path}/$courseId');
    if (stage.existsSync()) {
      await stage.delete(recursive: true);
    }
  }

  Future<void> _verifyHashIfNeeded({
    required File file,
    required String expectedHash,
  }) async {
    final hash = expectedHash.trim().toLowerCase();
    if (hash.isEmpty) return;
    if (hash.length < 16) return;

    final digest = await _sha256Of(file);
    if (digest.toLowerCase() != hash) {
      throw Exception('文件校验失败，请重试下载');
    }
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<Directory?> _findPackageRoot(Directory stageDir) async {
    final manifest = File('${stageDir.path}/course_manifest.json');
    if (manifest.existsSync()) return stageDir;

    final children =
        stageDir.listSync().whereType<Directory>().toList(growable: false);
    if (children.length == 1) {
      final nestedManifest =
          File('${children.first.path}/course_manifest.json');
      if (nestedManifest.existsSync()) {
        return children.first;
      }
    }
    return null;
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    await for (final entity in from.list(recursive: true, followLinks: false)) {
      final relative = entity.path.substring(from.path.length);
      final targetPath = '${to.path}$relative';
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        final target = File(targetPath);
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
      }
    }
  }

  String _taskId(String courseId) => 'task_download_$courseId';

  File _partFile(String courseId) => File('${_tmpDir.path}/$courseId.zip.part');
  Directory _segmentPartsDir(String courseId) =>
      Directory('${_tmpDir.path}/${courseId}_parts');
  File _segmentPartFile(String courseId, int index) => File(
      '${_segmentPartsDir(courseId).path}/part_${index.toString().padLeft(4, '0')}');

  Future<void> _ensureDirs() async {
    if (!_initialized) {
      final runtimeRoot = await resolveRuntimeRootDir();
      _rootDir = Directory('${runtimeRoot.path}/download_center');
      _tmpDir = Directory('${_rootDir.path}/tmp');
      _stagingDir = Directory('${_rootDir.path}/staging');
      _stateFile = File('${_rootDir.path}/download_state.json');
      _runtimeTasksDir = await resolveRuntimeTasksDir();
      _initialized = true;
    }
    await _rootDir.create(recursive: true);
    await _tmpDir.create(recursive: true);
    await _stagingDir.create(recursive: true);
  }
}

class _SegmentedManifest {
  final int sourceSizeBytes;
  final String sourceSha256;
  final List<_SegmentedPart> parts;

  const _SegmentedManifest({
    required this.sourceSizeBytes,
    required this.sourceSha256,
    required this.parts,
  });
}

class _SegmentedPart {
  final int index;
  final String objectKey;
  final int sizeBytes;
  final String sha256;
  final String url;

  const _SegmentedPart({
    required this.index,
    required this.objectKey,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });
}

class _ActiveDownload {
  bool paused = false;
  bool canceled = false;
  StreamSubscription<List<int>>? subscription;
  Completer<void>? waiter;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
