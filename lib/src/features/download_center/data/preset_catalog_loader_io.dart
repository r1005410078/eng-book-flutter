import 'dart:convert';
import 'dart:io';

import '../../../common/io/runtime_paths.dart';

class PresetCatalogCourse {
  final String id;
  final String title;
  final List<String> tags;
  final String version;
  final String? cover;
  final CourseAsset asset;

  const PresetCatalogCourse({
    required this.id,
    required this.title,
    required this.tags,
    required this.version,
    required this.cover,
    required this.asset,
  });

  int get sizeBytes => asset.sizeBytes;
  String get hash => asset.sha256;
}

enum CourseAssetMode { zip, segmentedZip }

class CourseAssetPart {
  final int index;
  final String objectKey;
  final int sizeBytes;
  final String sha256;
  final String url;

  const CourseAssetPart({
    required this.index,
    required this.objectKey,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });
}

class CourseAsset {
  final CourseAssetMode mode;
  final int sizeBytes;
  final String sha256;
  final String? url;
  final String? manifestUrl;
  final List<CourseAssetPart> parts;

  const CourseAsset({
    required this.mode,
    required this.sizeBytes,
    required this.sha256,
    this.url,
    this.manifestUrl,
    this.parts = const [],
  });
}

Future<List<PresetCatalogCourse>> loadPresetCatalogCourses() async {
  final dynamic raw = await _loadRawCatalog();
  if (raw is! Map) return const [];

  final entries = raw['courses'] ?? raw['items'] ?? raw['catalog'] ?? raw;
  final list = <PresetCatalogCourse>[];
  if (entries is List) {
    for (final item in entries) {
      if (item is! Map) continue;
      final id = (item['id'] ?? item['course_id'] ?? '').toString().trim();
      final title = (item['title'] ?? item['name'] ?? '').toString().trim();
      if (id.isEmpty || title.isEmpty) continue;
      final asset = _parseAsset(item['asset']);
      if (asset == null) continue;

      final tags = item['tags'] is List
          ? (item['tags'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final version = (item['version'] ?? '1.0.0').toString();
      final coverRaw = (item['cover'] ?? item['cover_url'] ?? '').toString();
      list.add(
        PresetCatalogCourse(
          id: id,
          title: title,
          tags: tags,
          version: version,
          cover: coverRaw.isEmpty ? null : coverRaw,
          asset: asset,
        ),
      );
    }
  }
  return list;
}

CourseAsset? _parseAsset(dynamic raw) {
  if (raw is! Map) return null;
  final modeRaw = (raw['mode'] ?? '').toString().trim().toLowerCase();
  final sizeBytes = _toInt(raw['size_bytes']);
  final sha256 = (raw['sha256'] ?? '').toString().trim().toLowerCase();
  if (sizeBytes <= 0 || sha256.isEmpty) return null;

  if (modeRaw == 'zip') {
    final url = (raw['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    return CourseAsset(
      mode: CourseAssetMode.zip,
      sizeBytes: sizeBytes,
      sha256: sha256,
      url: url,
    );
  }

  if (modeRaw == 'segmented_zip') {
    final manifestUrl = (raw['manifest_url'] ?? '').toString().trim();
    if (manifestUrl.isEmpty) return null;
    final partsRaw = raw['parts'];
    final parts = <CourseAssetPart>[];
    if (partsRaw is List) {
      for (final row in partsRaw) {
        if (row is! Map) continue;
        final index = _toInt(row['index']);
        final objectKey = (row['object_key'] ?? '').toString().trim();
        final partSize = _toInt(row['size_bytes']);
        final partSha = (row['sha256'] ?? '').toString().trim().toLowerCase();
        final partUrl = (row['url'] ?? '').toString().trim();
        if (index <= 0 ||
            objectKey.isEmpty ||
            partSize <= 0 ||
            partSha.isEmpty ||
            partUrl.isEmpty) {
          continue;
        }
        parts.add(
          CourseAssetPart(
            index: index,
            objectKey: objectKey,
            sizeBytes: partSize,
            sha256: partSha,
            url: partUrl,
          ),
        );
      }
      parts.sort((a, b) => a.index.compareTo(b.index));
    }
    return CourseAsset(
      mode: CourseAssetMode.segmentedZip,
      sizeBytes: sizeBytes,
      sha256: sha256,
      manifestUrl: manifestUrl,
      parts: parts,
    );
  }

  return null;
}

Future<dynamic> _loadRawCatalog() async {
  const fromDefine = String.fromEnvironment('COURSE_PIPELINE_CATALOG_URL');
  if (fromDefine.trim().isNotEmpty) {
    final parsed = Uri.tryParse(fromDefine.trim());
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      final remote = await _loadRemote(parsed);
      if (remote != null) return remote;
    } else {
      final local = await _loadLocalFile(fromDefine.trim());
      if (local != null) return local;
    }
  }

  final fallback = await _discoverLocalCatalog();
  return fallback ?? const <String, dynamic>{};
}

Future<dynamic> _loadRemote(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final body = await utf8.decodeStream(response);
    return jsonDecode(body);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<dynamic> _loadLocalFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final body = await file.readAsString();
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

Future<dynamic> _discoverLocalCatalog() async {
  final runtimeTasks = await resolveRuntimeTasksDir();
  if (!runtimeTasks.existsSync()) return null;

  DateTime? latestTime;
  File? latestCatalog;
  final taskFiles = runtimeTasks
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => f.uri.pathSegments.last.startsWith('task_'))
      .toList();

  for (final file in taskFiles) {
    try {
      final task = jsonDecode(await file.readAsString());
      if (task is! Map) continue;
      if ((task['status'] ?? '').toString() != 'ready') continue;
      final taskId = (task['task_id'] ?? '').toString();
      if (taskId.isEmpty) continue;
      final catalogFile =
          File('${runtimeTasks.path}/$taskId/package/catalog.json');
      if (!catalogFile.existsSync()) continue;
      final updatedAt =
          DateTime.tryParse((task['updated_at'] ?? '').toString());
      final ts = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latestTime == null || ts.isAfter(latestTime)) {
        latestTime = ts;
        latestCatalog = catalogFile;
      }
    } catch (_) {
      continue;
    }
  }

  if (latestCatalog == null) return null;
  try {
    return jsonDecode(await latestCatalog.readAsString());
  } catch (_) {
    return null;
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
