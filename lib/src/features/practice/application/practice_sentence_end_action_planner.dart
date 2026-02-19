enum SentenceEndAction {
  none,
  runShadowingStep,
  handleSentenceEnd,
}

class PracticeSentenceEndActionPlanner {
  const PracticeSentenceEndActionPlanner();

  SentenceEndAction plan({
    required bool isShadowingMode,
    required bool isShadowingBusy,
    required bool isPlaying,
    required bool isSeeking,
    required bool shouldAdvanceAtSentenceEnd,
  }) {
    if (!isPlaying || isSeeking || !shouldAdvanceAtSentenceEnd) {
      return SentenceEndAction.none;
    }
    if (isShadowingMode) {
      if (isShadowingBusy) return SentenceEndAction.none;
      return SentenceEndAction.runShadowingStep;
    }
    return SentenceEndAction.handleSentenceEnd;
  }
}
