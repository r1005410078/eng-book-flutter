class SentenceDetail {
  final String id;
  final String text;
  final String translation;
  final String phonetic;
  final Map<String, String> grammarNotes;
  final Duration startTime;
  final Duration endTime;

  const SentenceDetail({
    required this.id,
    required this.text,
    required this.translation,
    required this.phonetic,
    required this.grammarNotes,
    required this.startTime,
    required this.endTime,
  });
}
