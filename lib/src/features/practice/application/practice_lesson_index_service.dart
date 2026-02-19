class PracticeLessonIndexService {
  const PracticeLessonIndexService();

  int lessonPageForSentenceIndex({
    required List<int> lessonStartIndices,
    required int sentenceIndex,
  }) {
    if (lessonStartIndices.isEmpty) return 0;
    for (int i = lessonStartIndices.length - 1; i >= 0; i--) {
      if (sentenceIndex >= lessonStartIndices[i]) return i;
    }
    return 0;
  }

  ({int start, int end}) boundsForIndex({
    required List<String> lessonKeys,
    required int index,
  }) {
    if (lessonKeys.isEmpty) return (start: 0, end: 0);
    final safeIndex = index.clamp(0, lessonKeys.length - 1);
    final key = lessonKeys[safeIndex];

    var start = safeIndex;
    while (start - 1 >= 0 && lessonKeys[start - 1] == key) {
      start--;
    }

    var end = safeIndex;
    while (end + 1 < lessonKeys.length && lessonKeys[end + 1] == key) {
      end++;
    }

    return (start: start, end: end);
  }

  ({int indexInLesson, int totalInLesson}) progressForIndex({
    required List<String> lessonKeys,
    required int index,
  }) {
    if (lessonKeys.isEmpty) {
      return (indexInLesson: 1, totalInLesson: 1);
    }
    final bounds = boundsForIndex(lessonKeys: lessonKeys, index: index);
    return (
      indexInLesson: (index.clamp(0, lessonKeys.length - 1) - bounds.start) + 1,
      totalInLesson: (bounds.end - bounds.start) + 1,
    );
  }

  int targetSentenceIndexForLessonPage({
    required int page,
    required List<int> lessonStartIndices,
    required List<String> lessonKeys,
    required Map<String, int> lessonLastSentenceIndex,
  }) {
    if (lessonStartIndices.isEmpty || lessonKeys.isEmpty) return 0;
    if (page < 0 || page >= lessonStartIndices.length) return 0;

    final startIndex = lessonStartIndices[page];
    if (startIndex < 0 || startIndex >= lessonKeys.length) return 0;
    final key = lessonKeys[startIndex];
    final remembered = lessonLastSentenceIndex[key];
    if (remembered == null) return startIndex;
    if (remembered < 0 || remembered >= lessonKeys.length) return startIndex;
    if (lessonKeys[remembered] != key) return startIndex;
    return remembered;
  }
}
