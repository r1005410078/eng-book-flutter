class PracticeLessonPreviewPlanner {
  const PracticeLessonPreviewPlanner();

  Set<int> keepIndices({
    required int currentPage,
    required int pageCount,
    required int Function(int page) sentenceIndexForPage,
  }) {
    if (pageCount <= 0) return const <int>{};
    if (currentPage < 0 || currentPage >= pageCount) return const <int>{};

    final prevPage = currentPage - 1;
    final nextPage = currentPage + 1;
    return <int>{
      sentenceIndexForPage(currentPage),
      if (prevPage >= 0) sentenceIndexForPage(prevPage),
      if (nextPage < pageCount) sentenceIndexForPage(nextPage),
    };
  }

  List<int> staleIndices({
    required Iterable<int> cachedIndices,
    required Set<int> keepIndices,
  }) {
    return cachedIndices
        .where((index) => !keepIndices.contains(index))
        .toList();
  }
}
