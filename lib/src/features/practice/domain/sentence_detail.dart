class SentenceDetail {
  final String id;
  final String text;
  final String translation;
  final String phonetic;
  final Map<String, String> grammarNotes;
  final Duration startTime;
  final Duration endTime;
  final String? lessonId;
  final String? lessonTitle;
  final String? mediaType;
  final String? mediaPath;
  final String? courseTitle;
  final String? packageRoot;

  const SentenceDetail({
    required this.id,
    required this.text,
    required this.translation,
    required this.phonetic,
    required this.grammarNotes,
    required this.startTime,
    required this.endTime,
    this.lessonId,
    this.lessonTitle,
    this.mediaType,
    this.mediaPath,
    this.courseTitle,
    this.packageRoot,
  });
}
