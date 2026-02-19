import '../domain/sentence_detail.dart';

class PracticeSentencePositionMatcher {
  const PracticeSentencePositionMatcher();

  int? findIndexInBounds({
    required Duration position,
    required List<SentenceDetail> sentences,
    required int start,
    required int end,
  }) {
    if (sentences.isEmpty) return null;
    if (start < 0 || end < start || end >= sentences.length) return null;

    for (int i = start; i <= end; i++) {
      final sentence = sentences[i];
      if (position >= sentence.startTime && position < sentence.endTime) {
        return i;
      }
    }
    return null;
  }
}
