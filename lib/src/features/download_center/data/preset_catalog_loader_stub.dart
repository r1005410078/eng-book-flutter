class PresetCatalogCourse {
  final String id;
  final String title;
  final List<String> tags;
  final int sizeBytes;
  final String version;
  final String url;
  final String hash;
  final String? cover;

  const PresetCatalogCourse({
    required this.id,
    required this.title,
    required this.tags,
    required this.sizeBytes,
    required this.version,
    required this.url,
    required this.hash,
    required this.cover,
  });
}

Future<List<PresetCatalogCourse>> loadPresetCatalogCourses() async {
  return const [];
}
