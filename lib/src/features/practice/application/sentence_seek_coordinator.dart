class SentenceSeekCoordinator {
  const SentenceSeekCoordinator();

  Future<bool> perform({
    required int index,
    required int sentenceCount,
    required void Function() prepareTransition,
    Future<void> Function()? beforeSeek,
    required bool Function() isRequestCurrent,
    required Future<bool> Function() seekActiveMedia,
    required void Function() finalizeSeek,
    void Function()? onFinally,
  }) async {
    if (index < 0 || index >= sentenceCount) return false;
    prepareTransition();
    try {
      if (beforeSeek != null) {
        await beforeSeek();
      }
      if (!isRequestCurrent()) return true;
      final seeked = await seekActiveMedia();
      if (!seeked) return false;
      if (isRequestCurrent()) {
        finalizeSeek();
      }
      return true;
    } finally {
      onFinally?.call();
    }
  }
}
