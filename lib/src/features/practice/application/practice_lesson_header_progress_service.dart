class PracticeLessonHeaderProgressService {
  const PracticeLessonHeaderProgressService();

  int displaySentenceIndex({
    required int currentLessonPage,
    required List<int> lessonStartIndices,
    required List<String> lessonKeys,
    required Map<String, int> lessonLastSentenceIndex,
  }) {
    if (lessonStartIndices.isEmpty || lessonKeys.isEmpty) return 0;

    final safePage = currentLessonPage.clamp(0, lessonStartIndices.length - 1);
    final lessonStart = lessonStartIndices[safePage];
    if (lessonStart < 0 || lessonStart >= lessonKeys.length) return 0;

    final lessonKey = lessonKeys[lessonStart];
    final remembered = lessonLastSentenceIndex[lessonKey];
    if (remembered == null) return lessonStart;
    if (remembered < 0 || remembered >= lessonKeys.length) return lessonStart;
    if (lessonKeys[remembered] != lessonKey) return lessonStart;
    return remembered;
  }
}
