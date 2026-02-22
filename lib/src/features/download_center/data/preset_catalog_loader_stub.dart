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
  return const [];
}
