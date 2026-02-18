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
    await _ensureDirs();
    if (_active.containsKey(course.id)) return;

    final partFile = _partFile(course.id);
    if (!partFile.parent.existsSync()) {
      await partFile.parent.create(recursive: true);
    }

    var downloaded = partFile.existsSync() ? await partFile.length() : 0;
    final request = await HttpClient().getUrl(Uri.parse(course.url));
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
        : (snapshot.totalBytes > 0 ? snapshot.totalBytes : course.sizeBytes);
    final totalBytes =
        totalFromResponse > 0 ? totalFromResponse : course.sizeBytes;

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
              clearError: true,
            ),
          );
          await _installCourse(course.id, partFile);
          onProgress(
            snapshot.copyWith(
              status: DownloadStatus.installed,
              downloadedBytes: downloaded,
              totalBytes: totalBytes,
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

  @override
  Future<void> pauseDownload(String courseId) async {
    final active = _active[courseId];
    if (active == null) return;
    active.paused = true;
    await active.subscription?.cancel();
  }

  @override
  Future<void> cancelDownload(String courseId) async {
    await _ensureDirs();
    final active = _active[courseId];
    if (active != null) {
      active.canceled = true;
      await active.subscription?.cancel();
      _active.remove(courseId);
    }
    final part = _partFile(courseId);
    if (part.existsSync()) {
      await part.delete();
    }
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

class _ActiveDownload {
  bool paused = false;
  bool canceled = false;
  StreamSubscription<List<int>>? subscription;
}
